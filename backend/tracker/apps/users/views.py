from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User
from .serializers import (
    UserSerializer, UserCreateSerializer,
    UserUpdateSerializer, ChangePasswordSerializer,
    CustomTokenObtainPairSerializer,
)
from .permissions import IsAdmin, IsAdminOrTeacher


class CustomTokenObtainPairView(TokenObtainPairView):
    """Login — returns access + refresh tokens with role info embedded."""
    serializer_class = CustomTokenObtainPairSerializer


class LogoutView(APIView):
    """Blacklists the refresh token, effectively logging the user out."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data['refresh']
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response({'detail': 'Successfully logged out.'}, status=status.HTTP_200_OK)
        except KeyError:
            return Response({'detail': 'Refresh token required.'}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)


class MeView(generics.RetrieveUpdateAPIView):
    """Get or update the currently authenticated user's profile."""
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method in ('PUT', 'PATCH'):
            return UserUpdateSerializer
        return UserSerializer

    def get_object(self):
        return self.request.user


class ChangePasswordView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = request.user
        if not user.check_password(serializer.validated_data['old_password']):
            return Response(
                {'old_password': 'Incorrect password.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.set_password(serializer.validated_data['new_password'])
        user.save()
        return Response({'detail': 'Password changed successfully.'})


class UserListCreateView(generics.ListCreateAPIView):
    """
    Admin-only: list all users in their school, or create a new user
    (teacher/student) within it.
    """
    permission_classes = [IsAdmin]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return UserCreateSerializer
        return UserSerializer

    def get_queryset(self):
        qs = User.objects.filter(school=self.request.user.school)
        role = self.request.query_params.get('role')
        if role:
            qs = qs.filter(role=role)
        return qs

    def perform_create(self, serializer):
        # Force new users into the admin's own school
        serializer.save(school=self.request.user.school)


class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Admin-only: retrieve, update or delete a user within their school."""
    permission_classes = [IsAdmin]
    serializer_class = UserSerializer

    def get_queryset(self):
        return User.objects.filter(school=self.request.user.school)


class SuperuserUserListCreateView(generics.ListCreateAPIView):
    """
    Superuser-only: list all users across every school, or create a user
    (typically the first 'admin'-role account) for any school. This is
    the counterpart to superuser-only School registration — a school is
    useless until someone with role='admin' is attached to it, and
    regular admins can't create themselves.
    """
    permission_classes = [permissions.IsAdminUser]
    queryset = User.objects.all()

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return UserCreateSerializer
        return UserSerializer

    def get_queryset(self):
        qs = User.objects.all()
        school_id = self.request.query_params.get('school')
        role = self.request.query_params.get('role')
        if school_id:
            qs = qs.filter(school_id=school_id)
        if role:
            qs = qs.filter(role=role)
        return qs