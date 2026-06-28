from django.db import models
from django.conf import settings
import numpy as np
from apps.common.id_generator import make_short_id_default


class FaceEncoding(models.Model):
    """
    Stores a single enrolled face encoding per student.
    The encoding is the raw bytes of a numpy float64 array produced
    by DeepFace with the Facenet512 model (512 dimensions).
    """
    id = models.CharField(
        primary_key=True,
        max_length=7,
        editable=False,
        default=make_short_id_default('face_recognition', 'FaceEncoding'),
    )

    student = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='face_encoding',
        limit_choices_to={'role': 'student'},
    )

    # Raw bytes: numpy array → array.tobytes() → stored here
    encoding = models.BinaryField()

    # Path to the enrollment photo — kept for re-enrollment / audit
    enrollment_photo = models.ImageField(
        upload_to='enrollment_photos/',
        null=True,
        blank=True,
    )

    enrolled_at = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    # ------------------------------------------------------------------
    # Helpers to convert between bytes and numpy array
    # ------------------------------------------------------------------
    def get_encoding_array(self) -> np.ndarray:
        """Return the stored bytes as a numpy float64 array."""
        return np.frombuffer(bytes(self.encoding), dtype=np.float64)

    def set_encoding_array(self, array: np.ndarray):
        """Store a numpy float64 array as bytes."""
        self.encoding = array.astype(np.float64).tobytes()

    def __str__(self):
        return f'FaceEncoding — {self.student}'

    class Meta:
        verbose_name = 'Face Encoding'
        verbose_name_plural = 'Face Encodings'