from django.urls import path
from ai_engine.views import (
    StartAIInterviewView,
    AIInterviewTurnView,
    CompleteAIInterviewView,
    AIReportListView,
    AIReportDetailView,
    DoctorReviewReportView
)

urlpatterns = [
    path('interview/start/', StartAIInterviewView.as_view(), name='ai-interview-start'),
    path('interview/<uuid:session_id>/message/', AIInterviewTurnView.as_view(), name='ai-interview-message'),
    path('interview/<uuid:session_id>/complete/', CompleteAIInterviewView.as_view(), name='ai-interview-complete'),
    path('reports/', AIReportListView.as_view(), name='ai-reports-list'),
    path('reports/<uuid:pk>/', AIReportDetailView.as_view(), name='ai-report-detail'),
    path('reports/<uuid:pk>/review/', DoctorReviewReportView.as_view(), name='ai-report-doctor-review'),
]
