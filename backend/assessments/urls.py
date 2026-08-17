from django.urls import path
from assessments.views import (
    AssessmentListView,
    AssessmentDetailView,
    AssessmentSubmitView,
    PatientAssessmentHistoryView
)

urlpatterns = [
    path('', AssessmentListView.as_view(), name='assessment-list'),
    path('history/', PatientAssessmentHistoryView.as_view(), name='assessment-history'),
    path('submit/', AssessmentSubmitView.as_view(), name='assessment-submit'),
    path('<str:code>/', AssessmentDetailView.as_view(), name='assessment-detail'),
]
