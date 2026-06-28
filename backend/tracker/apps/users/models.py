from django.contrib.auth.models import AbstractUser
from django.db import models
from apps.common.id_generator import make_short_id_default


class User(AbstractUser):
    # AbstractUser normally provides an auto-incrementing `id` —
    # overriding it here to the shared 7-digit short ID. This must be
    # declared explicitly (not just relying on a base class field) so
    # makemigrations sees it as part of this model's initial migration
    # rather than trying to alter an inherited field after the fact.
    id = models.CharField(
        primary_key=True,
        max_length=7,
        editable=False,
        default=make_short_id_default('users', 'User'),
    )

    class Role(models.TextChoices):
        ADMIN   = 'admin',   'Admin'
        TEACHER = 'teacher', 'Teacher'
        STUDENT = 'student', 'Student'

    role = models.CharField(
        max_length=10,
        choices=Role.choices,
        default=Role.STUDENT,
    )

    # school is nullable so superusers / platform admins need no school
    school = models.ForeignKey(
        'schools.School',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='users',
    )

    phone_number    = models.CharField(max_length=20, blank=True)
    profile_picture = models.ImageField(
        upload_to='profile_pictures/',
        null=True,
        blank=True,
    )

    # Last known position (updated on each attendance submission)
    last_latitude  = models.FloatField(null=True, blank=True)
    last_longitude = models.FloatField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def is_admin(self):
        return self.role == self.Role.ADMIN

    @property
    def is_teacher(self):
        return self.role == self.Role.TEACHER

    @property
    def is_student(self):
        return self.role == self.Role.STUDENT

    def __str__(self):
        return f'{self.get_full_name() or self.username} ({self.role})'

    class Meta:
        ordering = ['last_name', 'first_name']