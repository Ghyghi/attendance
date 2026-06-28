from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import AttendanceSession, AttendanceRecord
from .serializers import (
    AttendanceSessionSerializer,
    AttendanceSessionCreateSerializer,
    AttendanceRecordSerializer,
    AttendanceSubmitSerializer,
    TeacherMarkAbsentSerializer,
    TeacherOverrideStatusSerializer,
    StudentModuleStatsSerializer,
)
from .services import process_attendance_submission
from .qr_service import generate_qr_code
from apps.users.permissions import IsTeacher, IsStudent, IsAdminOrTeacher
from apps.schools.models import Classroom
from apps.notifications.services import (
    notify_session_started,
    notify_status_changed,
)


class SessionListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsTeacher]

    def get_serializer_class(self):
        if self.request.method == "POST":
            return AttendanceSessionCreateSerializer
        return AttendanceSessionSerializer

    def create(self, request, *args, **kwargs):
        serializer = AttendanceSessionCreateSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)

        session = serializer.save()
        generate_qr_code(session)

        for student in session.classroom.students.all():
            notify_session_started(student, session)

        return Response(
            AttendanceSessionSerializer(session).data,
            status=status.HTTP_201_CREATED,
        )

    def get_queryset(self):
        return AttendanceSession.objects.filter(
            teacher=self.request.user
        ).select_related("classroom")

class SessionDetailView(generics.RetrieveUpdateAPIView):
    """Teacher: view or close (is_active=False) a session."""
    serializer_class   = AttendanceSessionSerializer
    permission_classes = [IsTeacher]

    def get_queryset(self):
        return AttendanceSession.objects.filter(teacher=self.request.user)


class SessionRecordsView(generics.ListAPIView):
    """
    Admin / Teacher: list all attendance records for a given session,
    including absent records created by the teacher.
    """
    serializer_class   = AttendanceRecordSerializer
    permission_classes = [IsAdminOrTeacher]

    def get_queryset(self):
        user = self.request.user
        session_id = self.kwargs['session_id']
        sessions = AttendanceSession.objects.filter(
            pk=session_id,
            classroom__school=user.school,
        )
        if user.is_teacher:
            sessions = sessions.filter(teacher=user)

        return AttendanceRecord.objects.filter(
            session__in=sessions,
        ).select_related('student')


class TeacherMarkAbsentView(APIView):
    """
    Teacher: mark specific students as absent for a session that
    has ended (or is still active). Creates an AttendanceRecord with
    status=ABSENT for each student_id supplied. If a record already
    exists for a student (e.g. they self-submitted as present), it is
    left unchanged — only truly missing students get an absent record.

    POST /attendance/sessions/<session_id>/mark-absent/
    Body: {"student_ids": [1, 2, 3]}
    """
    permission_classes = [IsTeacher]

    def post(self, request, session_id):
        serializer = TeacherMarkAbsentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        student_ids = serializer.validated_data['student_ids']

        # Verify teacher owns this session
        try:
            session = AttendanceSession.objects.select_related(
                'classroom'
            ).get(pk=session_id, teacher=request.user)
        except AttendanceSession.DoesNotExist:
            return Response(
                {'detail': 'Session not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Only students enrolled in the classroom can be marked
        enrolled_ids = set(
            session.classroom.students.filter(pk__in=student_ids).values_list('pk', flat=True)
        )
        not_enrolled = [sid for sid in student_ids if sid not in enrolled_ids]
        if not_enrolled:
            return Response(
                {'detail': f'Students not enrolled in this classroom: {not_enrolled}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        created_records = []
        for sid in enrolled_ids:
            record, created = AttendanceRecord.objects.get_or_create(
                session=session,
                student_id=sid,
                defaults={
                    'status': AttendanceRecord.Status.ABSENT,
                    'code_verified': False,
                    'gps_verified': False,
                    'face_verified': False,
                    'is_teacher_edited': True,
                },
            )
            if created:
                created_records.append(record)
                notify_status_changed(record)

        return Response(
            AttendanceRecordSerializer(created_records, many=True).data,
            status=status.HTTP_201_CREATED,
        )


class TeacherOverrideRecordView(APIView):
    """
    Teacher: override the status of an existing attendance record.
    Primary use-case: flip absent → present after the session ends,
    for a student who was physically present but couldn't self-submit
    (e.g. dead phone battery, no GPS signal).

    PATCH /attendance/records/<record_id>/override/
    Body: {"status": "present"}
    """
    permission_classes = [IsTeacher]

    def patch(self, request, record_id):
        serializer = TeacherOverrideStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_status = serializer.validated_data['status']

        try:
            record = AttendanceRecord.objects.select_related(
                'session__teacher'
            ).get(pk=record_id, session__teacher=request.user)
        except AttendanceRecord.DoesNotExist:
            return Response(
                {'detail': 'Record not found or not yours to modify.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        record.status = new_status
        record.is_teacher_edited = True
        record.save(update_fields=['status', 'is_teacher_edited', 'updated_at'])
        notify_status_changed(record)
        return Response(AttendanceRecordSerializer(record).data)


class AbsentStudentsView(APIView):
    """
    Teacher: list students enrolled in a session's classroom who have
    NOT yet submitted attendance (i.e. have no record for this session).
    This is the source list the teacher uses when deciding who to mark absent.

    GET /attendance/sessions/<session_id>/absent-students/
    """
    permission_classes = [IsTeacher]

    def get(self, request, session_id):
        try:
            session = AttendanceSession.objects.select_related(
                'classroom'
            ).get(pk=session_id, teacher=request.user)
        except AttendanceSession.DoesNotExist:
            return Response(
                {'detail': 'Session not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        submitted_student_ids = AttendanceRecord.objects.filter(
            session=session
        ).values_list('student_id', flat=True)

        absent_students = session.classroom.students.exclude(
            pk__in=submitted_student_ids
        )

        from apps.users.serializers import UserSerializer
        return Response(UserSerializer(absent_students, many=True).data)


class SubmitAttendanceView(APIView):
    """
    Student: submit QR code + GPS + selfie.
    Runs the full three-step verification chain.
    """
    permission_classes = [IsStudent]

    def post(self, request):
        serializer = AttendanceSubmitSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        data = serializer.validated_data
        record, errors = process_attendance_submission(
            student   = request.user,
            code      = data['code'],
            lat       = data['latitude'],
            lng       = data['longitude'],
            selfie_b64= data['selfie'],
        )

        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)

        return Response(
            AttendanceRecordSerializer(record).data,
            status=status.HTTP_201_CREATED,
        )


class StudentAttendanceHistoryView(generics.ListAPIView):
    """Student: view their own attendance history (flat list, newest first)."""
    serializer_class   = AttendanceRecordSerializer
    permission_classes = [IsStudent]

    def get_queryset(self):
        return AttendanceRecord.objects.filter(
            student=self.request.user
        ).select_related('session__classroom')


class StudentModuleStatsView(APIView):
    """
    Student: attendance stats grouped by module (classroom).
    Returns one entry per enrolled classroom with present/absent counts,
    attendance percentage, and the full record list for that module.

    GET /attendance/module-stats/
    """
    permission_classes = [IsStudent]

    def get(self, request):
        student = request.user
        classrooms = student.enrolled_classrooms.select_related('school').all()

        result = []
        for classroom in classrooms:
            # All sessions for this classroom
            session_ids = classroom.sessions.values_list('pk', flat=True)
            total_sessions = session_ids.count()

            records = AttendanceRecord.objects.filter(
                session_id__in=session_ids,
                student=student,
            ).select_related('student', 'session')

            present_count = records.filter(status=AttendanceRecord.Status.PRESENT).count()
            absent_count  = records.filter(status=AttendanceRecord.Status.ABSENT).count()

            if total_sessions > 0:
                attendance_pct = round((present_count / total_sessions) * 100, 1)
            else:
                attendance_pct = 0.0

            min_pct = classroom.min_attendance_pct
            is_below = attendance_pct < min_pct if total_sessions > 0 else False

            result.append({
                'classroom_id':       classroom.pk,
                'classroom_name':     classroom.name,
                'total_sessions':     total_sessions,
                'present_count':      present_count,
                'absent_count':       absent_count,
                'attendance_pct':     attendance_pct,
                'min_attendance_pct': min_pct,
                'is_below_minimum':   is_below,
                'records':            records,
            })

        serializer = StudentModuleStatsSerializer(result, many=True)
        return Response(serializer.data)
