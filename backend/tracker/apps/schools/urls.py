from django.urls import path
from .views import (
    SchoolListCreateView, SchoolDetailView,
    ClassroomListCreateView, ClassroomDetailView,
)

urlpatterns = [
    # IMPORTANT: more specific literal paths (classrooms/...) MUST come
    # before the generic <str:pk>/ pattern. Django resolves URL patterns
    # in declaration order, and <str:pk> matches ANY string segment —
    # including the literal word "classrooms". With <int:pk> (the
    # original, pre-short-ID converter) this ordering didn't matter,
    # since "classrooms" can never match an int converter. Switching to
    # <str:pk> for short-ID support exposed this latent ordering issue:
    # every request to /schools/classrooms/ was being swallowed by
    # SchoolDetailView with pk="classrooms" instead of reaching
    # ClassroomListCreateView — which is exactly why POST returned 405
    # (SchoolDetailView is RetrieveUpdateDestroyAPIView; it has no POST
    # handler at all).
    path('classrooms/',            ClassroomListCreateView.as_view(),name='classroom-list'),
    path('classrooms/<str:pk>/',   ClassroomDetailView.as_view(),   name='classroom-detail'),
    path('',                       SchoolListCreateView.as_view(),  name='school-list'),
    path('<str:pk>/',              SchoolDetailView.as_view(),      name='school-detail'),
]