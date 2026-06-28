from django.contrib import admin
from .models import AttendanceSession, AttendanceRecord

@admin.register(AttendanceSession)
class SessionAdmin(admin.ModelAdmin):
    list_display  = ['code', 'classroom', 'teacher', 'expires_at', 'is_active']
    list_filter   = ['is_active', 'classroom__school']
    search_fields = ['code']

@admin.register(AttendanceRecord)
class RecordAdmin(admin.ModelAdmin):
    list_display  = ['student', 'session', 'status', 'gps_verified', 'face_verified', 'marked_at']
    list_filter   = ['status', 'gps_verified', 'face_verified']