from django.urls import path
from .views import EnrollFaceView, FaceEncodingDetailView

urlpatterns = [
    path('enroll/',                      EnrollFaceView.as_view(),          name='face-enroll'),
    path('student/<str:student_id>/',    FaceEncodingDetailView.as_view(),  name='face-encoding-detail'),
]