from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    CustomTokenObtainPairView, LogoutView,
    MeView, ChangePasswordView,
    UserListCreateView, UserDetailView,
    SuperuserUserListCreateView,
)

urlpatterns = [
    # Auth
    path('login/',           CustomTokenObtainPairView.as_view(), name='token-obtain'),
    path('token/refresh/',   TokenRefreshView.as_view(),          name='token-refresh'),
    path('logout/',          LogoutView.as_view(),                name='logout'),

    # Current user
    path('me/',              MeView.as_view(),                    name='me'),
    path('me/password/',     ChangePasswordView.as_view(),        name='change-password'),

    # Admin: manage users in their own school
    path('users/',           UserListCreateView.as_view(),        name='user-list-create'),
    path('users/<str:pk>/',  UserDetailView.as_view(),            name='user-detail'),

    # Superuser: manage users (e.g. first admin) across any school
    path('superuser/users/', SuperuserUserListCreateView.as_view(), name='superuser-user-list-create'),
]