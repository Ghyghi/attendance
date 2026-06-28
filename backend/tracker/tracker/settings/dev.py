from .base import *
from dotenv import load_dotenv
import os
load_dotenv()  # Load environment variables from .env file

DEBUG = True

ALLOWED_HOSTS = ['*']

# --- Dev DB (override if needed via env) ---
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME', 'attendance_db'),
        'USER': os.getenv('DB_USER', 'attendance_user'),
        'PASSWORD': os.getenv('DB_PASSWORD', 'attendance_pass'),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
    }
}

# --- CORS: allow Flutter dev origins ---
CORS_ALLOWED_ORIGINS = [
    'http://localhost:3000',
    'http://127.0.0.1:3000',
    'http://10.0.2.2:8000',   # Android emulator → host machine
]

# --- Dev shortcuts: skip heavy verification during development ---
DEBUG_SKIP_FACE = False
DEBUG_SKIP_GPS = False

# --- Faster password hashing in tests ---
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.MD5PasswordHasher',
]

# --- Email: print to console in dev ---
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
