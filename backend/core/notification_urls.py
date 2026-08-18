from django.urls import path
from core.views import (
    NotificationListView,
    MarkNotificationReadView,
    MarkAllNotificationsReadView,
    UnreadNotificationCountView
)

urlpatterns = [
    path('', NotificationListView.as_view(), name='notification-list'),
    path('<uuid:pk>/read/', MarkNotificationReadView.as_view(), name='notification-read'),
    path('mark-all-read/', MarkAllNotificationsReadView.as_view(), name='notification-mark-all-read'),
    path('unread-count/', UnreadNotificationCountView.as_view(), name='notification-unread-count'),
]
