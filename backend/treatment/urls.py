from django.urls import path
from treatment.views import (
    ActiveTreatmentPlanView,
    CreateTreatmentPlanView,
    LogProgressRecordView,
    ProgressHistoryView
)

urlpatterns = [
    path('active/', ActiveTreatmentPlanView.as_view(), name='active-treatment-plan'),
    path('create/', CreateTreatmentPlanView.as_view(), name='create-treatment-plan'),
    path('progress/', ProgressHistoryView.as_view(), name='progress-root'),
    path('progress/log/', LogProgressRecordView.as_view(), name='log-progress'),
    path('progress/history/', ProgressHistoryView.as_view(), name='progress-history'),
]
