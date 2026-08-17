from rest_framework import serializers
from messaging.models import Conversation, Message
from accounts.serializers import UserSerializer


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source='sender.get_full_name', read_only=True)
    is_me = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = [
            'id', 'conversation', 'sender', 'sender_name',
            'content_encrypted', 'attachment', 'is_read',
            'read_at', 'is_me', 'created_at'
        ]
        read_only_fields = ['id', 'sender', 'is_read', 'created_at']

    def get_is_me(self, obj):
        request = self.context.get('request')
        if request and request.user:
            return obj.sender_id == request.user.id
        return False


class ConversationSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.get_full_name', read_only=True)
    patient_avatar = serializers.ImageField(source='patient.user.avatar', read_only=True)
    doctor_name = serializers.CharField(source='doctor.user.get_full_name', read_only=True)
    doctor_avatar = serializers.ImageField(source='doctor.user.avatar', read_only=True)
    last_message = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            'id', 'patient', 'patient_name', 'patient_avatar',
            'doctor', 'doctor_name', 'doctor_avatar',
            'is_active', 'last_message', 'updated_at'
        ]

    def get_last_message(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        if msg:
            return {
                'content': msg.content_encrypted,
                'created_at': msg.created_at,
                'is_read': msg.is_read
            }
        return None
