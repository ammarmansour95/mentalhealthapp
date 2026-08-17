from rest_framework import serializers
from treatment.models import TreatmentPlan, TreatmentGoal, ProgressRecord
from doctors.serializers import DoctorProfileSerializer


class TreatmentGoalSerializer(serializers.ModelSerializer):
    class Meta:
        model = TreatmentGoal
        fields = ['id', 'title', 'description', 'target_date', 'is_completed', 'order']


class TreatmentPlanSerializer(serializers.ModelSerializer):
    goals = TreatmentGoalSerializer(many=True, read_only=True)
    doctor_name = serializers.CharField(source='doctor.user.get_full_name', read_only=True)
    patient_name = serializers.CharField(source='patient.user.get_full_name', read_only=True)

    class Meta:
        model = TreatmentPlan
        fields = [
            'id', 'patient', 'patient_name', 'doctor', 'doctor_name',
            'title', 'diagnosis_summary_encrypted', 'clinical_notes_encrypted',
            'start_date', 'review_date', 'status', 'goals', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class ProgressRecordSerializer(serializers.ModelSerializer):
    sleep_hours = serializers.FloatField()
    mood_score = serializers.IntegerField()

    class Meta:
        model = ProgressRecord
        fields = [
            'id', 'patient', 'plan', 'mood_score', 'sleep_hours',
            'anxiety_level', 'notes_encrypted', 'log_date', 'created_at'
        ]
        read_only_fields = ['id', 'patient', 'created_at', 'log_date']
