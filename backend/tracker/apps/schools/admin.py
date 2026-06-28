from django.contrib import admin
from .models import School, Classroom

@admin.register(School)
class SchoolAdmin(admin.ModelAdmin):
    list_display  = ['name', 'latitude', 'longitude', 'radius_m', 'created_by']
    search_fields = ['name']

@admin.register(Classroom)
class ClassroomAdmin(admin.ModelAdmin):
    list_display  = ['name', 'school', 'session_time']
    list_filter   = ['school']
    filter_horizontal = ['teachers', 'students']