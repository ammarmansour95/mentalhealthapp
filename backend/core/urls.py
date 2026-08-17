from django.urls import path
from core.views import AdminPlatformMetricsView, AdminPendingDoctorsView, AdminAuditLogsView

urlpatterns = [
    path('metrics/', AdminPlatformMetricsView.as_view(), name='admin-metrics'),
    path('pending-doctors/', AdminPendingDoctorsView.as_view(), name='admin-pending-doctors'),
    path('audit-logs/', AdminAuditLogsView.as_view(), name='admin-audit-logs'),
]
