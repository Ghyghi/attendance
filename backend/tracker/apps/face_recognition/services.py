"""
Face enrollment service.

Called by the admin when registering a student's face.
Extracts the Facenet512 embedding via DeepFace and stores it
as raw bytes in the FaceEncoding model.
"""
import base64
import logging
import os
import tempfile

import numpy as np
from django.conf import settings

from .models import FaceEncoding

logger = logging.getLogger(__name__)


def enroll_face(student, photo_b64: str):
    """
    Enroll (or re-enroll) a student's face from a base64 photo.
    Returns (face_encoding_obj | None, error_message | None).
    """
    # Decode base64
    try:
        image_bytes = base64.b64decode(photo_b64)
    except Exception:
        return None, 'Invalid base64 image data.'

    # Write to temp file
    with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as tmp:
        tmp.write(image_bytes)
        tmp_path = tmp.name

    try:
        from deepface import DeepFace

        result = DeepFace.represent(
            img_path=tmp_path,
            model_name=settings.FACE_MODEL,          # 'Facenet512'
            detector_backend=settings.FACE_DETECTOR, # 'opencv'
            enforce_detection=True,
        )

        if not result:
            return None, 'No face detected in the provided photo.'

        embedding = np.array(result[0]['embedding'], dtype=np.float64)

        # Upsert FaceEncoding
        face_enc, _ = FaceEncoding.objects.get_or_create(student=student)
        face_enc.set_encoding_array(embedding)
        face_enc.save()

        logger.info('Face enrolled for student %s (id=%s)', student, student.pk)
        return face_enc, None

    except Exception as exc:
        logger.exception('Face enrollment error for student %s: %s', student.pk, exc)
        return None, f'Face enrollment failed: {exc}'

    finally:
        os.unlink(tmp_path)