from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import FaceEncoding
from .serializers import FaceEnrollSerializer, FaceEncodingSerializer
from .services import enroll_face
from apps.users.models import User
from apps.users.permissions import IsAdmin
from apps.notifications.services import notify_face_enrolled


class EnrollFaceView(APIView):
    """Admin: enroll a student's face encoding from a base64 photo."""
    permission_classes = [IsAdmin]

    def post(self, request):
        serializer = FaceEnrollSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        student_id = serializer.validated_data['student_id']
        photo_b64  = serializer.validated_data['photo']

        # Validate student belongs to admin's school
        try:
            student = User.objects.get(
                pk=student_id,
                role=User.Role.STUDENT,
                school=request.user.school,
            )
        except User.DoesNotExist:
            return Response(
                {'student_id': 'Student not found in your school.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        face_enc, error = enroll_face(student, photo_b64)

        if error:
            return Response({'detail': error}, status=status.HTTP_400_BAD_REQUEST)

        notify_face_enrolled(student)

        return Response(
            FaceEncodingSerializer(face_enc).data,
            status=status.HTTP_201_CREATED,
        )


class FaceEncodingDetailView(APIView):
    """Admin: check enrollment status for a student."""
    permission_classes = [IsAdmin]

    def get(self, request, student_id):
        try:
            enc = FaceEncoding.objects.get(
                student_id=student_id,
                student__school=request.user.school,
            )
            return Response(FaceEncodingSerializer(enc).data)
        except FaceEncoding.DoesNotExist:
            return Response(
                {'detail': 'No face enrolled for this student.'},
                status=status.HTTP_404_NOT_FOUND,
            )

    def delete(self, request, student_id):
        """Remove a student's face enrollment."""
        try:
            enc = FaceEncoding.objects.get(
                student_id=student_id,
                student__school=request.user.school,
            )
            enc.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except FaceEncoding.DoesNotExist:
            return Response(
                {'detail': 'No face enrolled for this student.'},
                status=status.HTTP_404_NOT_FOUND,
            )