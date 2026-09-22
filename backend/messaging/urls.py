from django.urls import path
from messaging.views import (
    ConversationListView, ConversationMessagesView, SendMessageView,
    GetOrCreateConversationView, DoctorCrisisEscalationView
)

urlpatterns = [
    path('conversations/', ConversationListView.as_view(), name='conversation-list'),
    path('conversations/start/', GetOrCreateConversationView.as_view(), name='conversation-start'),
    path('conversations/<uuid:conversation_id>/messages/', ConversationMessagesView.as_view(), name='conversation-messages'),
    path('conversations/<uuid:conversation_id>/escalate-crisis/', DoctorCrisisEscalationView.as_view(), name='doctor-escalate-crisis'),
    path('send/', SendMessageView.as_view(), name='send-message'),
    path('messages/send/', SendMessageView.as_view(), name='messages-send'),
]
