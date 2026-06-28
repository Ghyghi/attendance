from rest_framework import serializers
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Notification
        fields = [
            'id', 'kind', 'title', 'body',
            'is_read', 'session', 'created_at',
        ]
        read_only_fields = ['id', 'kind', 'title', 'body', 'session', 'created_at']