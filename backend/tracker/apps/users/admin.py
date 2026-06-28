from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display  = ['id','username', 'first_name', 'last_name', 'email', 'role', 'school', 'is_active']
    list_filter   = ['role', 'school', 'is_active']
    search_fields = ['username', 'first_name', 'last_name', 'email']
    fieldsets     = UserAdmin.fieldsets + (
        ('App Fields', {'fields': ('role', 'school', 'phone_number', 'profile_picture')}),
    )