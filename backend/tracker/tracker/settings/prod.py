import os
from dotenv import load_dotenv
from .base import *

DEBUG = False
load_dotenv()

SECRET_KEY = os.getenv('DJANGO_SECRET_KEY')

ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', '').split(',')

# --- Production DB from environment ---
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME'),
        'USER': os.getenv('DB_USER'),
        'PASSWORD': os.getenv('DB_PASSWORD'),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
        'CONN_MAX_AGE': 60,
    }
}

# --- CORS: production origins from env ---
CORS_ALLOWED_ORIGINS = os.getenv('CORS_ORIGINS', '').split(',')

# --- Security headers ---
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

# --- Face recognition: stricter in prod ---
FACE_DISTANCE_THRESHOLD = 0.35

# --- Never skip verification in production ---
DEBUG_SKIP_FACE = False
DEBUG_SKIP_GPS = False
