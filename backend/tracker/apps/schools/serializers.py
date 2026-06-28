from rest_framework import serializers
from .models import School, Classroom
from apps.users.serializers import UserSerializer


class SchoolSerializer(serializers.ModelSerializer):
    class Meta:
        model  = School
        fields = [
            'id', 'name', 'address',
            'latitude', 'longitude', 'radius_m',
            'created_by', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'updated_at']

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)


class ClassroomSerializer(serializers.ModelSerializer):
    teachers_detail = UserSerializer(source='teachers', many=True, read_only=True)
    # Was a plain UserSerializer(many=True) — now a SerializerMethodField so
    # each student can carry their attendance % for THIS classroom alongside
    # their profile fields. Computed the same way as
    # apps.attendance.views.StudentModuleStatsView (real submitted
    # AttendanceSession count as the denominator, not the admin-set
    # `num_sessions` "planned" field), so this number always matches what
    # the student sees on their own history screen.
    students_detail = serializers.SerializerMethodField()

    class Meta:
        model  = Classroom
        fields = [
            'id', 'school', 'name',
            'num_sessions', 'min_attendance_pct',
            'begin_date', 'end_date', 'session_time',
            'teachers', 'students',
            'teachers_detail', 'students_detail',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
        extra_kwargs = {
            'teachers': {'write_only': True},
            'students': {'write_only': True},
        }

    def get_students_detail(self, classroom):
        # Local import avoids a hard module-level dependency from
        # schools -> attendance; attendance.models only references
        # schools.Classroom via a lazy string FK, so this direction
        # (schools.serializers -> attendance.models) doesn't create a
        # cycle, but keeping it function-local makes that explicit rather
        # than relying on import order at module load time.
        from apps.attendance.models import AttendanceRecord

        total_sessions = classroom.sessions.count()
        students = classroom.students.all()

        result = []
        for student in students:
            present_count = AttendanceRecord.objects.filter(
                session__classroom=classroom,
                student=student,
                status=AttendanceRecord.Status.PRESENT,
            ).count()

            if total_sessions > 0:
                attendance_pct = round((present_count / total_sessions) * 100, 1)
            else:
                attendance_pct = 0.0

            data = UserSerializer(student).data
            data['attendance_pct'] = attendance_pct
            data['present_count'] = present_count
            data['total_sessions'] = total_sessions
            result.append(data)

        return result

    # ── added_to_module notifications ────────────────────────────────
    #
    # Both create() and update() can set the teachers/students M2M in one
    # shot (ModelSerializer's default M2M handling calls .set() on each),
    # which doesn't distinguish "kept from before" from "newly added" —
    # only the diff between before/after membership tells us who should
    # actually be notified. create() is the simple case (classroom didn't
    # exist before, so every initial teacher/student is new by
    # definition); update() needs an explicit before/after snapshot,
    # since the frontend's add-roster flow always sends the FULL merged
    # list (see SchoolsRepository._patchRoster), not just the delta.

    def create(self, validated_data):
        classroom = super().create(validated_data)

        from apps.notifications.services import notify_added_to_module

        for teacher in classroom.teachers.all():
            notify_added_to_module(teacher, classroom)
        for student in classroom.students.all():
            notify_added_to_module(student, classroom)

        return classroom

    def update(self, instance, validated_data):
        previous_teacher_ids = set(instance.teachers.values_list('pk', flat=True))
        previous_student_ids = set(instance.students.values_list('pk', flat=True))

        classroom = super().update(instance, validated_data)

        from apps.notifications.services import notify_added_to_module

        new_teacher_ids = set(classroom.teachers.values_list('pk', flat=True)) - previous_teacher_ids
        new_student_ids = set(classroom.students.values_list('pk', flat=True)) - previous_student_ids

        if new_teacher_ids:
            for teacher in classroom.teachers.filter(pk__in=new_teacher_ids):
                notify_added_to_module(teacher, classroom)
        if new_student_ids:
            for student in classroom.students.filter(pk__in=new_student_ids):
                notify_added_to_module(student, classroom)

        return classroom