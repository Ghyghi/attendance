"""
QR code generation service.

Generates a QR code image from an attendance session code
and saves it to media/qr_codes/.
"""
import io
import logging
import os

import qrcode
from django.core.files.base import ContentFile

logger = logging.getLogger(__name__)


def generate_qr_code(session):
    """
    Generates a QR PNG for the given AttendanceSession and
    saves it to session.qr_image. Returns the updated session.
    """
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=10,
        border=4,
    )
    qr.add_data(session.code)
    qr.make(fit=True)

    img = qr.make_image(fill_color='black', back_color='white')

    buffer = io.BytesIO()
    img.save(buffer, format='PNG')
    buffer.seek(0)

    filename = f'qr_{session.code}.png'
    session.qr_image.save(filename, ContentFile(buffer.read()), save=True)

    logger.debug('QR code generated for session %s', session.code)
    return session