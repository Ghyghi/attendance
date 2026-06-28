from django.db import models
from django.conf import settings
from apps.common.id_generator import make_short_id_default


class Notification(models.Model):
    id = models.CharField(
        primary_key=True,
        max_length=7,
        editable=False,
        default=make_short_id_default('notifications', 'Notification'),
    )

    class Kind(models.TextChoices):
        SESSION_STARTED   = 'session_started',   'Session Started'
        ATTENDANCE_MARKED = 'attendance_marked',  'Attendance Marked'
        SESSION_EXPIRED   = 'session_expired',    'Session Expired'
        ADDED_TO_MODULE   = 'added_to_module',    'Added to Module'
        STATUS_CHANGED    = 'status_changed',     'Status Changed'
        FACE_ENROLLED     = 'face_enrolled',      'Face Enrolled'
        GENERAL           = 'general',            'General'

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications',
    )
    kind    = models.CharField(max_length=30, choices=Kind.choices, default=Kind.GENERAL)
    title   = models.CharField(max_length=255)
    body    = models.TextField()
    is_read = models.BooleanField(default=False)

    # Optional link back to a session or record
    session = models.ForeignKey(
        'attendance.AttendanceSession',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='notifications',
    )

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'[{self.kind}] → {self.recipient} | {self.title}'

    class Meta:
        ordering = ['-created_at']