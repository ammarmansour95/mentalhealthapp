from rest_framework import serializers
from appointments.models import Appointment
from doctors.serializers import DoctorProfileSerializer
from accounts.serializers import PatientProfileSerializer


class AppointmentSerializer(serializers.ModelSerializer):
    doctor_details = DoctorProfileSerializer(source='doctor', read_only=True)
    patient_id = serializers.CharField(source='patient.id', read_only=True)
    patient_name = serializers.CharField(source='patient.user.get_full_name', read_only=True)
    patient_email = serializers.CharField(source='patient.user.email', read_only=True)
    patient_risk_level = serializers.SerializerMethodField()
    is_cancelled_by_patient = serializers.SerializerMethodField()

    class Meta:
        model = Appointment
        fields = [
            'id', 'patient', 'patient_id', 'patient_name', 'patient_email',
            'patient_risk_level', 'doctor', 'doctor_details', 'appointment_date',
            'start_time', 'end_time', 'status', 'patient_notes',
            'session_notes_encrypted', 'cancellation_reason', 'is_cancelled_by_patient',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'patient', 'created_at', 'updated_at']

    def get_patient_risk_level(self, obj):
        if hasattr(obj.patient, 'ai_reports'):
            latest_report = obj.patient.ai_reports.order_by('-created_at').first()
            if latest_report:
                return latest_report.preliminary_risk_level
        return 'LOW'

    def get_is_cancelled_by_patient(self, obj):
        return obj.status == 'CANCELLED' and obj.cancelled_by and obj.cancelled_by.role == 'PATIENT'


class BookAppointmentSerializer(serializers.Serializer):
    doctor_id = serializers.UUIDField()
    appointment_date = serializers.DateField()
    start_time = serializers.TimeField()
    end_time = serializers.TimeField()
    patient_notes = serializers.CharField(required=False, allow_blank=True)

    def validate(self, data):
        doctor_id = data.get('doctor_id')
        date = data.get('appointment_date')
        start = data.get('start_time')

        # Check double-booking constraint (BR-006)
        existing = Appointment.objects.filter(
            doctor_id=doctor_id,
            appointment_date=date,
            start_time=start,
            status__in=['PENDING', 'CONFIRMED']
        ).exists()

        if existing:
            raise serializers.ValidationError("This appointment time slot is already booked. Please choose another time.")

        return data
