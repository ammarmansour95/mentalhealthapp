from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from messaging.models import Conversation, Message
from messaging.serializers import ConversationSerializer, MessageSerializer


class ConversationListView(generics.ListAPIView):
    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'PATIENT' and hasattr(user, 'patient_profile'):
            return Conversation.objects.filter(patient=user.patient_profile)
        elif user.role == 'DOCTOR' and hasattr(user, 'doctor_profile'):
            return Conversation.objects.filter(doctor=user.doctor_profile)
        return Conversation.objects.none()


class ConversationMessagesView(generics.ListAPIView):
    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        conv_id = self.kwargs.get('conversation_id')
        user = self.request.user
        conv = Conversation.objects.filter(id=conv_id).first()
        if not conv:
            return Message.objects.none()

        # Check authorization (BR-002, BR-003)
        if user.role == 'PATIENT' and conv.patient.user_id != user.id:
            return Message.objects.none()
        if user.role == 'DOCTOR' and conv.doctor.user_id != user.id:
            return Message.objects.none()

        # Mark unread messages as read
        conv.messages.exclude(sender=user).filter(is_read=False).update(is_read=True)

        return conv.messages.all()


class SendMessageView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        conv_id = request.data.get('conversation_id')
        content = request.data.get('content', '').strip()

        if not content:
            return Response({'success': False, 'message': 'Message cannot be empty.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            conv = Conversation.objects.get(id=conv_id)
        except Conversation.DoesNotExist:
            return Response({'success': False, 'message': 'Conversation not found.'}, status=status.HTTP_404_NOT_FOUND)

        msg = Message.objects.create(
            conversation=conv,
            sender=request.user,
            content_encrypted=content
        )
        conv.save()  # update updated_at timestamp

        return Response({
            'success': True,
            'message': MessageSerializer(msg, context={'request': request}).data
        }, status=status.HTTP_201_CREATED)
