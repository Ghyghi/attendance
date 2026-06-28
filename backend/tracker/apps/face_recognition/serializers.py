from rest_framework import serializers
from .models import FaceEncoding


class FaceEncodingSerializer(serializers.ModelSerializer):
    class Meta:
        model  = FaceEncoding
        fields = ['id', 'student', 'enrollment_photo', 'enrolled_at', 'updated_at']
        read_only_fields = ['id', 'enrolled_at', 'updated_at']


class FaceEnrollSerializer(serializers.Serializer):
    """Payload for enrolling a student face — admin uploads a photo."""
    # CHANGED from IntegerField to CharField: short IDs are 7-digit
    # numeric STRINGS (e.g. "0042193"), not integers. IntegerField would
    # silently strip a leading zero (e.g. "0042193" -> 42193), which
    # would then fail to match any real student row — every enroll
    # request would 404 with student_id values that have a leading zero,
    # and silently corrupt the lookup for ones that don't.
    student_id = serializers.CharField(max_length=7)
    # Photo as base64 string OR uploaded file — we accept base64 here for API simplicity
    photo      = serializers.CharField(help_text='Base64-encoded image')