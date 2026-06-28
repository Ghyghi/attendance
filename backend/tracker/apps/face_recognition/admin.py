from django.contrib import admin
from .models import FaceEncoding

@admin.register(FaceEncoding)
class FaceEncodingAdmin(admin.ModelAdmin):
    list_display  = ['student','encoding', 'enrolled_at', 'updated_at']
    search_fields = ['student__username', 'student__first_name']