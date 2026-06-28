from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),

    # API v1
    path('api/v1/auth/',         include('apps.users.urls')),
    path('api/v1/schools/',      include('apps.schools.urls')),
    path('api/v1/attendance/',   include('apps.attendance.urls')),
    path('api/v1/face/',         include('apps.face_recognition.urls')),
    path('api/v1/notifications/',include('apps.notifications.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
