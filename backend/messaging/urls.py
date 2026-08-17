from django.urls import path
from messaging.views import ConversationListView, ConversationMessagesView, SendMessageView

urlpatterns = [
    path('conversations/', ConversationListView.as_view(), name='conversation-list'),
    path('conversations/<uuid:conversation_id>/messages/', ConversationMessagesView.as_view(), name='conversation-messages'),
    path('send/', SendMessageView.as_view(), name='send-message'),
]
