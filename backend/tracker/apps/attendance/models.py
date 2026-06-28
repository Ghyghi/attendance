import random
import string
from django.db import models
from django.conf import settings
from django.utils import timezone
from apps.common.id_generator import make_short_id_default


def _generate_code():
    """Random uppercase alphanumeric code, length from settings.

    NOTE: this is the student-facing session join code (e.g. "67LIJG"),
    a completely separate concept from the row's `id` primary key below.
    The short-ID change applies only to `id` — `code` keeps its existing
    format and generator untouched.
    """
    length = getattr(settings, 'ATTENDANCE_CODE_LENGTH', 6)
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=length))


class AttendanceSession(models.Model):
    id = models.CharField(
        primary_key=True,
        max_length=7,
        editable=False,
        default=make_short_id_default('attendance', 'AttendanceSession'),
    )

    classroom = models.ForeignKey(
        'schools.Classroom',
        on_delete=models.CASCADE,
        related_name='sessions',
    )
    teacher = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='created_sessions',
        limit_choices_to={'role': 'teacher'},
    )

    # The short code students type if they can't scan the QR
    code       = models.CharField(max_length=20, unique=True, default=_generate_code)
    expires_at = models.DateTimeField()
    is_active  = models.BooleanField(default=True)

    # Optional: store the QR image path so we don't regenerate on every request
    qr_image   = models.ImageField(upload_to='qr_codes/', null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # ------------------------------------------------------------------
    def save(self, *args, **kwargs):
        if not self.expires_at:
            ttl = getattr(settings, 'ATTENDANCE_SESSION_TTL_MINUTES', 15)
            self.expires_at = timezone.now() + timezone.timedelta(minutes=ttl)
        super().save(*args, **kwargs)

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at

    @property
    def is_valid(self):
        return self.is_active and not self.is_expired

    def __str__(self):
        return f'Session {self.code} — {self.classroom} ({self.teacher})'

    class Meta:
        ordering = ['-created_at']


class AttendanceRecord(models.Model):
    id = models.CharField(
        primary_key=True,
        max_length=7,
        editable=False,
        default=make_short_id_default('attendance', 'AttendanceRecord'),
    )

    class Status(models.TextChoices):
        PRESENT = 'present', 'Present'
        ABSENT  = 'absent',  'Absent'
        LATE    = 'late',    'Late'

    session = models.ForeignKey(
        AttendanceSession,
        on_delete=models.CASCADE,
        related_name='records',
    )
    student = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='attendance_records',
        limit_choices_to={'role': 'student'},
    )

    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.PRESENT,
    )

    # GPS snapshot at time of submission
    latitude  = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)

    # Verification flags — all three must be True for a PRESENT mark
    gps_verified  = models.BooleanField(default=False)
    face_verified = models.BooleanField(default=False)
    code_verified = models.BooleanField(default=True)  # implied by reaching this point

    # Set True whenever a teacher creates or modifies this record directly
    # (TeacherMarkAbsentView, TeacherOverrideRecordView) rather than the
    # student self-submitting via the verification chain in services.py.
    # Surfaced in the UI as a "Teacher-edited" tag so it's clear which
    # records reflect the student's own GPS/face submission vs a manual
    # teacher correction.
    is_teacher_edited = models.BooleanField(default=False)

    # Raw distances for audit / debugging
    gps_distance_m   = models.FloatField(null=True, blank=True, help_text='Metres from school centre at submission time')
    face_distance    = models.FloatField(null=True, blank=True, help_text='Cosine distance from enrolled encoding')

    marked_at  = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        # A student can only have one record per session
        unique_together = ('session', 'student')
        ordering = ['-marked_at']

    def __str__(self):
        return f'{self.student} — {self.session.code} — {self.status}'