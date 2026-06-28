from rest_framework import generics, permissions
from .models import School, Classroom
from .serializers import SchoolSerializer, ClassroomSerializer
from apps.users.permissions import IsAdmin, IsAdminOrTeacher, IsAdminOrTeacherOrStudent


class SchoolListCreateView(generics.ListCreateAPIView):
    """
    Superuser-only: register a new school (name, GPS coordinates, geofence
    radius) or list all schools. Regular role='admin' users do NOT manage
    School records — they're scoped to the school assigned to their
    account and manage teachers/students/classrooms within it instead.
    """
    serializer_class   = SchoolSerializer
    permission_classes = [permissions.IsAdminUser]  # is_staff / superuser
    queryset            = School.objects.all()


class SchoolDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Superuser-only: view, edit, or remove a school's core info."""
    serializer_class   = SchoolSerializer
    permission_classes = [permissions.IsAdminUser]
    queryset            = School.objects.all()


class ClassroomListCreateView(generics.ListCreateAPIView):
    serializer_class   = ClassroomSerializer
    permission_classes = [IsAdminOrTeacherOrStudent]

    def get_queryset(self):
        user = self.request.user
        if user.is_admin:
            return Classroom.objects.filter(school=user.school)
        """Teacher and Student only see their classes"""
        if user.is_teacher:
            return user.teaching_classrooms.filter(school=user.school)
        return user.enrolled_classrooms.filter(school=user.school)


class ClassroomDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class   = ClassroomSerializer
    permission_classes = [IsAdminOrTeacher]

    def get_queryset(self):
        user = self.request.user
        if user.is_admin:
            return Classroom.objects.filter(school=user.school)
        return user.teaching_classrooms.filter(school=user.school)