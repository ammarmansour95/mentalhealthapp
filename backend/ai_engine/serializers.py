from rest_framework import serializers
from ai_engine.models import AIInterviewSession, AIInterviewMessage, AIReport
from doctors.serializers import DoctorProfileSerializer


class AIInterviewMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIInterviewMessage
        fields = ['id', 'sender', 'content_encrypted', 'extracted_symptoms', 'sentiment_tag', 'created_at']


class AIInterviewSessionSerializer(serializers.ModelSerializer):
    messages = AIInterviewMessageSerializer(many=True, read_only=True)

    class Meta:
        model = AIInterviewSession
        fields = ['id', 'status', 'current_stage', 'turn_count', 'started_at', 'completed_at', 'messages']


class AIReportSerializer(serializers.ModelSerializer):
    patient_id = serializers.CharField(source='patient.id', read_only=True)
    patient_name = serializers.CharField(source='patient.user.get_full_name', read_only=True)
    patient_email = serializers.CharField(source='patient.user.email', read_only=True)
    reviewed_by_doctor = DoctorProfileSerializer(source='reviewed_by', read_only=True)
    recommended_specialty_display = serializers.CharField(source='get_recommended_specialty_display', read_only=True)
    preliminary_risk_level_display = serializers.CharField(source='get_preliminary_risk_level_display', read_only=True)

    class Meta:
        model = AIReport
        fields = [
            'id', 'patient', 'patient_id', 'patient_name', 'patient_email',
            'interview_session', 'assessment_submission',
            'summary_ar_encrypted', 'summary_en_encrypted',
            'primary_indicators', 'preliminary_risk_level', 'preliminary_risk_level_display',
            'recommended_specialty', 'recommended_specialty_display',
            'recommendation_reason_ar', 'recommendation_reason_en',
            'safety_warning_triggered', 'disclaimer_notice',
            'is_reviewed_by_doctor', 'reviewed_by_doctor',
            'doctor_review_notes_encrypted', 'reviewed_at',
            'created_at'
        ]
        read_only_fields = ['id', 'created_at']
