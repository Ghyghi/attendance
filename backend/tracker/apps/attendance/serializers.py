from rest_framework import serializers
from django.utils import timezone
from .models import AttendanceSession, AttendanceRecord
from apps.users.serializers import UserSerializer


class AttendanceSessionSerializer(serializers.ModelSerializer):
    is_expired = serializers.ReadOnlyField()
    is_valid   = serializers.ReadOnlyField()
    present_count = serializers.SerializerMethodField()
    absent_count  = serializers.SerializerMethodField()

    class Meta:
        model  = AttendanceSession
        fields = [
            'id', 'classroom', 'teacher', 'code',
            'expires_at', 'is_active', 'is_expired', 'is_valid',
            'qr_image', 'present_count', 'absent_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'code', 'expires_at', 'teacher',
            'qr_image', 'created_at', 'updated_at',
        ]

    def get_present_count(self, obj):
        return obj.records.filter(status=AttendanceRecord.Status.PRESENT).count()

    def get_absent_count(self, obj):
        return obj.records.filter(status=AttendanceRecord.Status.ABSENT).count()


class AttendanceSessionCreateSerializer(serializers.ModelSerializer):
    """Minimal serializer used when a teacher starts a new session."""

    class Meta:
        model  = AttendanceSession
        fields = ['classroom']

    def create(self, validated_data):
        validated_data['teacher'] = self.context['request'].user
        return super().create(validated_data)


class AttendanceRecordSerializer(serializers.ModelSerializer):
    student_detail = UserSerializer(source='student', read_only=True)
    session_code   = serializers.SerializerMethodField()

    class Meta:
        model  = AttendanceRecord
        fields = [
            'id', 'session', 'session_code', 'student', 'student_detail',
            'status', 'latitude', 'longitude',
            'gps_verified', 'face_verified', 'code_verified',
            'gps_distance_m', 'face_distance', 'is_teacher_edited',
            'marked_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'session_code', 'gps_verified', 'face_verified', 'code_verified',
            'gps_distance_m', 'face_distance', 'is_teacher_edited',
            'marked_at', 'updated_at',
        ]

    def get_session_code(self, obj):
        return obj.session.code


class TeacherMarkAbsentSerializer(serializers.Serializer):
    """
    Payload for a teacher manually creating an absent record for students
    who did not self-submit. Accepts a list of student PKs and creates
    (or returns existing) an AttendanceRecord with status=ABSENT for each.
    """
    student_ids = serializers.ListField(
        child=serializers.CharField(),
        min_length=1,
        help_text='List of student IDs to mark as absent for this session.',
    )


class TeacherOverrideStatusSerializer(serializers.Serializer):
    """
    Payload for a teacher overriding a single record's status
    (e.g. flipping absent → present after the session ends).
    """
    status = serializers.ChoiceField(choices=AttendanceRecord.Status.choices)


class AttendanceSubmitSerializer(serializers.Serializer):
    """
    Payload sent by the student's Flutter app.
    All three fields are required; server then runs the verification chain.
    """
    code      = serializers.CharField(max_length=20)
    latitude  = serializers.FloatField()
    longitude = serializers.FloatField()
    # Selfie as a base64-encoded JPEG/PNG string
    selfie    = serializers.CharField()   # base64

    def validate_code(self, value):
        return value.strip().upper()

    def validate_selfie(self, value):
        if not value:
            raise serializers.ValidationError('Selfie image is required.')
        return value


# ── Module attendance stats ──────────────────────────────────────────────

class StudentModuleStatsSerializer(serializers.Serializer):
    """
    Per-student attendance stats for a given module (classroom).
    Returned by the module-stats endpoint used by the history screen.
    """
    classroom_id   = serializers.CharField()
    classroom_name = serializers.CharField()
    total_sessions = serializers.IntegerField()
    present_count  = serializers.IntegerField()
    absent_count   = serializers.IntegerField()
    attendance_pct = serializers.FloatField()
    min_attendance_pct = serializers.IntegerField()
    is_below_minimum   = serializers.BooleanField()
    records        = AttendanceRecordSerializer(many=True)