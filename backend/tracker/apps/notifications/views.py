from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated

from .models import Notification
from .serializers import NotificationSerializer


class UnreadCountView(APIView):
    """
    Lightweight unread-count endpoint, separate from the full list view.
    The bottom-nav badge needs to refresh fairly often (on every screen
    that might change notification state, e.g. after a session starts or
    a record is overridden) without pulling the full notification list
    and bodies each time just to get a number.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        count = Notification.objects.filter(
            recipient=request.user, is_read=False
        ).count()
        return Response({'unread_count': count})


class NotificationListView(generics.ListAPIView):
    """Any authenticated user: list their notifications (newest first)."""
    serializer_class   = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = Notification.objects.filter(recipient=self.request.user)
        unread_only = self.request.query_params.get('unread')
        if unread_only:
            qs = qs.filter(is_read=False)
        return qs


class MarkNotificationReadView(APIView):
    """Mark a single notification as read."""
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        try:
            notif = Notification.objects.get(pk=pk, recipient=request.user)
            notif.is_read = True
            notif.save(update_fields=['is_read'])
            return Response(NotificationSerializer(notif).data)
        except Notification.DoesNotExist:
            return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)


class MarkAllReadView(APIView):
    """Mark all of the current user's notifications as read."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        count = Notification.objects.filter(
            recipient=request.user, is_read=False
        ).update(is_read=True)
        return Response({'marked_read': count})