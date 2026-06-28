"""
Attendance verification service.

Runs the three-step chain in order:
  1. Code validity (not expired, is_active)
  2. GPS geofence   (student within school radius)
  3. Face match     (DeepFace cosine distance below threshold)

Each step returns (passed: bool, detail: str).
If DEBUG_SKIP_GPS / DEBUG_SKIP_FACE are True, those steps auto-pass.
"""
import base64
import logging
import tempfile
import os

import numpy as np
from django.conf import settings
from django.utils import timezone
from geopy.distance import geodesic

from .models import AttendanceSession, AttendanceRecord

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Step 1 — Code check
# ---------------------------------------------------------------------------

def verify_code(code: str):
    """
    Returns (session, error_message).
    session is None if code is invalid/expired.
    """
    try:
        session = AttendanceSession.objects.select_related(
            'classroom__school', 'teacher'
        ).get(code=code)
    except AttendanceSession.DoesNotExist:
        return None, 'Invalid attendance code.'

    if not session.is_active:
        return None, 'This attendance session has been closed by the teacher.'

    if session.is_expired:
        return None, 'This attendance code has expired.'

    return session, None


# ---------------------------------------------------------------------------
# Step 2 — GPS geofence
# ---------------------------------------------------------------------------

def verify_gps(session: AttendanceSession, lat: float, lng: float):
    """
    Returns (passed: bool, distance_m: float, detail: str).
    """
    if getattr(settings, 'DEBUG_SKIP_GPS', False):
        logger.debug('GPS check skipped (DEBUG_SKIP_GPS=True)')
        return True, 0.0, 'GPS check skipped in dev mode.'

    school = session.classroom.school
    student_pos = (lat, lng)
    school_pos  = (school.latitude, school.longitude)

    distance_m = geodesic(student_pos, school_pos).meters

    if distance_m <= school.radius_m:
        return True, distance_m, f'Within geofence ({distance_m:.1f}m from school).'
    else:
        return False, distance_m, (
            f'Too far from school: {distance_m:.1f}m '
            f'(allowed radius: {school.radius_m}m).'
        )


# ---------------------------------------------------------------------------
# Step 3 — Face verification
# ---------------------------------------------------------------------------

def verify_face(student, selfie_b64: str):
    """
    Returns (passed: bool, distance: float | None, detail: str).

    selfie_b64: base64-encoded JPEG or PNG of the student's selfie.
    """
    if getattr(settings, 'DEBUG_SKIP_FACE', False):
        logger.debug('Face check skipped (DEBUG_SKIP_FACE=True)')
        return True, None, 'Face check skipped in dev mode.'

    # Check that the student has an enrolled encoding
    try:
        face_enc_obj = student.face_encoding
    except Exception:
        return False, None, 'No enrolled face found for this student.'

    enrolled_array = face_enc_obj.get_encoding_array()

    # Decode base64 selfie → temporary image file
    try:
        image_bytes = base64.b64decode(selfie_b64)
    except Exception:
        return False, None, 'Invalid selfie image data.'

    # Write to a temp file — DeepFace expects a file path or numpy array
    suffix = '.jpg'
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(image_bytes)
        tmp_path = tmp.name

    try:
        from deepface import DeepFace

        # Get embedding for the selfie
        result = DeepFace.represent(
            img_path=tmp_path,
            model_name=settings.FACE_MODEL,          # 'Facenet512'
            detector_backend=settings.FACE_DETECTOR, # 'opencv'
            enforce_detection=True,
        )

        if not result:
            return False, None, 'No face detected in selfie.'

        selfie_array = np.array(result[0]['embedding'], dtype=np.float64)

        # Cosine distance
        dot      = np.dot(enrolled_array, selfie_array)
        norm_a   = np.linalg.norm(enrolled_array)
        norm_b   = np.linalg.norm(selfie_array)
        cosine_similarity = dot / (norm_a * norm_b + 1e-10)
        distance = 1.0 - cosine_similarity   # cosine distance: 0 = identical

        threshold = getattr(settings, 'FACE_DISTANCE_THRESHOLD', 0.40)
        passed    = distance <= threshold

        detail = (
            f'Face matched (distance={distance:.4f}).'
            if passed
            else f'Face did not match (distance={distance:.4f}, threshold={threshold}).'
        )
        return passed, float(distance), detail

    except Exception as exc:
        logger.exception('Face verification error: %s', exc)
        return False, None, f'Face verification error: {exc}'

    finally:
        os.unlink(tmp_path)


# ---------------------------------------------------------------------------
# Orchestrator: run all three steps and create the AttendanceRecord
# ---------------------------------------------------------------------------

def process_attendance_submission(student, code: str, lat: float, lng: float, selfie_b64: str):
    """
    Runs the full verification chain.
    Returns (record | None, errors: dict).
    """
    # --- Step 1: Code ---
    session, code_error = verify_code(code)
    if code_error:
        return None, {'code': code_error}

    # Guard: student must be enrolled in this classroom
    if not session.classroom.students.filter(pk=student.pk).exists():
        return None, {'code': 'You are not enrolled in this classroom.'}

    # Guard: no duplicate submission
    if AttendanceRecord.objects.filter(session=session, student=student).exists():
        return None, {'code': 'Attendance already submitted for this session.'}

    # --- Step 2: GPS ---
    # Short-circuit here: face verification is a synchronous, expensive
    # DeepFace call (no task queue yet), so don't pay that cost if the
    # student isn't even in the geofence.
    gps_passed, gps_distance, gps_detail = verify_gps(session, lat, lng)
    if not gps_passed:
        return None, {'gps': gps_detail}

    # --- Step 3: Face ---
    face_passed, face_distance, face_detail = verify_face(student, selfie_b64)
    if not face_passed:
        return None, {'face': face_detail}

    # --- All checks passed → mark present ---
    record = AttendanceRecord.objects.create(
        session       = session,
        student       = student,
        status        = AttendanceRecord.Status.PRESENT,
        latitude      = lat,
        longitude     = lng,
        gps_verified  = gps_passed,
        face_verified = face_passed,
        code_verified = True,
        gps_distance_m= gps_distance,
        face_distance = face_distance,
    )

    # Update student's last known position
    student.last_latitude  = lat
    student.last_longitude = lng
    student.save(update_fields=['last_latitude', 'last_longitude'])

    return record, {}