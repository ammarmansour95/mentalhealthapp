from rest_framework import serializers
from messaging.models import Conversation, Message
from accounts.serializers import UserSerializer


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()
    content = serializers.CharField(source='content_encrypted', read_only=True)
    is_me = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = [
            'id', 'conversation', 'sender', 'sender_name',
            'content', 'content_encrypted', 'attachment', 'is_emergency',
            'emergency_reason', 'is_read', 'read_at', 'is_me', 'created_at'
        ]
        read_only_fields = ['id', 'sender', 'is_read', 'created_at']

    def get_sender_name(self, obj):
        if not obj.sender:
            return ""
        name = (obj.sender.get_full_name() or obj.sender.email).strip()
        if obj.sender.role == 'DOCTOR':
            return name if name.startswith('د.') else f"د. {name}"
        return name

    def get_is_me(self, obj):
        request = self.context.get('request')
        if request and request.user:
            return obj.sender_id == request.user.id
        return False


class ConversationSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.get_full_name', read_only=True)
    patient_avatar = serializers.ImageField(source='patient.user.avatar', read_only=True)
    patient_phone = serializers.CharField(source='patient.user.phone_number', read_only=True)
    patient_age = serializers.IntegerField(source='patient.user.age', read_only=True)
    doctor_name = serializers.SerializerMethodField()
    doctor_avatar = serializers.ImageField(source='doctor.user.avatar', read_only=True)
    doctor_phone = serializers.CharField(source='doctor.user.phone_number', read_only=True)
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    total_messages_count = serializers.SerializerMethodField()
    is_doctor_unlocked = serializers.SerializerMethodField()
    is_window_open_for_patient = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            'id', 'patient', 'patient_name', 'patient_avatar', 'patient_phone', 'patient_age',
            'doctor', 'doctor_name', 'doctor_avatar', 'doctor_phone',
            'is_active', 'doctor_unlocked_until', 'is_doctor_unlocked',
            'is_window_open_for_patient', 'unread_count', 'total_messages_count',
            'last_message', 'updated_at'
        ]

    def get_doctor_name(self, obj):
        if not obj.doctor or not obj.doctor.user:
            return ""
        name = (obj.doctor.user.get_full_name() or obj.doctor.user.email).strip()
        return name if name.startswith('د.') else f"د. {name}"

    def get_last_message(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        if msg:
            return {
                'content': msg.content_encrypted,
                'created_at': msg.created_at,
                'is_read': msg.is_read
            }
        return None

    def get_unread_count(self, obj):
        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            return obj.messages.exclude(sender=request.user).filter(is_read=False).count()
        return 0

    def get_total_messages_count(self, obj):
        return obj.messages.count()

    def get_is_doctor_unlocked(self, obj):
        if obj.doctor_unlocked_until:
            from django.utils import timezone
            return obj.doctor_unlocked_until > timezone.now()
        return False

    def get_is_window_open_for_patient(self, obj):
        from messaging.views import get_chat_window_status
        status = get_chat_window_status(obj.patient, obj.doctor, obj.patient.user, conversation=obj)
        return status.get('is_window_open', False)
