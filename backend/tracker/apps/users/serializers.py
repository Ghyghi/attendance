from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .models import User


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Adds role, full name, and school_id to the JWT response payload."""

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['role']      = user.role
        token['full_name'] = user.get_full_name()
        token['school_id'] = user.school_id
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data['role']      = self.user.role
        data['full_name'] = self.user.get_full_name()
        data['school_id'] = self.user.school_id
        return data


class UserSerializer(serializers.ModelSerializer):
    """Read-only public profile."""

    class Meta:
        model  = User
        fields = [
            'id', 'username', 'first_name', 'last_name',
            'email', 'role', 'school', 'phone_number',
            'profile_picture', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class UserCreateSerializer(serializers.ModelSerializer):
    """Used by admins to create teacher / student accounts."""

    password = serializers.CharField(
        write_only=True,
        required=True,
        validators=[validate_password],
    )
    password2 = serializers.CharField(write_only=True, required=True)

    class Meta:
        model  = User
        fields = [
            'username', 'first_name', 'last_name', 'email',
            'role', 'school', 'phone_number', 'password', 'password2',
        ]

    def validate(self, attrs):
        if attrs['password'] != attrs.pop('password2'):
            raise serializers.ValidationError({'password': 'Passwords do not match.'})
        return attrs

    def create(self, validated_data):
        password = validated_data.pop('password')
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user


class UserUpdateSerializer(serializers.ModelSerializer):
    """Allows partial updates to a user profile."""

    class Meta:
        model  = User
        fields = ['first_name', 'last_name', 'email', 'phone_number', 'profile_picture']


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True, write_only=True)
    new_password = serializers.CharField(
        required=True,
        write_only=True,
        validators=[validate_password],
    )