from django.db import models
from django.conf import settings


class School(models.Model):
    name       = models.CharField(max_length=255)
    address    = models.TextField(blank=True)
    latitude   = models.FloatField()
    longitude  = models.FloatField()
    radius_m   = models.PositiveIntegerField(
        default=100,
        help_text='Geofence radius in metres. Students must be within this distance to mark attendance.',
    )

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='owned_schools',
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name

    class Meta:
        ordering = ['name']


class Classroom(models.Model):
    """
    Represents a module/class within a school.
    The UI refers to this as a "Module" but the database table and
    Django internals keep the name Classroom to avoid a migration rename.
    """

    class SessionTime(models.TextChoices):
        DAY     = 'day',     'Day'
        EVENING = 'evening', 'Evening'
        NIGHT   = 'night',   'Night'

    school  = models.ForeignKey(
        School,
        on_delete=models.CASCADE,
        related_name='classrooms',
    )
    # "name" is the module name — kept short per the new spec ("name only")
    name    = models.CharField(max_length=100, help_text='Module name, e.g. "Advanced Mathematics"')

    # ── New Module fields ────────────────────────────────────────────
    # Total number of sessions planned for this module.
    num_sessions = models.PositiveIntegerField(
        default=0,
        help_text='Total planned sessions for this module.',
    )
    # Minimum attendance percentage required (0–100). The backend enforces
    # nothing with this value — it is informational for teachers and students.
    min_attendance_pct = models.PositiveSmallIntegerField(
        default=75,
        help_text='Minimum attendance percentage required (0–100).',
    )
    begin_date = models.DateField(null=True, blank=True)
    end_date   = models.DateField(null=True, blank=True)
    session_time = models.CharField(
        max_length=10,
        choices=SessionTime.choices,
        default=SessionTime.DAY,
    )

    teachers = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        blank=True,
        related_name='teaching_classrooms',
        limit_choices_to={'role': 'teacher'},
    )
    students = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        blank=True,
        related_name='enrolled_classrooms',
        limit_choices_to={'role': 'student'},
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.school.name} — {self.name}'

    class Meta:
        ordering = ['school', 'name']