from rest_framework import serializers
from doctors.models import DoctorProfile, DoctorQualification, DoctorAvailability


class DoctorQualificationSerializer(serializers.ModelSerializer):
    document_url = serializers.SerializerMethodField()

    class Meta:
        model = DoctorQualification
        fields = [
            'id', 'degree_title', 'institution_name', 'graduation_year',
            'document_file', 'document_url', 'verification_status', 'admin_notes', 'created_at'
        ]
        read_only_fields = ['id', 'verification_status', 'created_at']

    def get_document_url(self, obj):
        if obj.document_file:
            return f'/api/doctors/qualifications/{obj.id}/document/'
        return None


class DoctorAvailabilitySerializer(serializers.ModelSerializer):
    day_display = serializers.CharField(source='get_day_of_week_display', read_only=True)

    class Meta:
        model = DoctorAvailability
        fields = ['id', 'day_of_week', 'day_display', 'start_time', 'end_time', 'slot_duration_minutes', 'is_active']


class DoctorProfileSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source='user.get_full_name', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    specialty_display = serializers.CharField(source='get_specialty_display', read_only=True)
    avatar = serializers.ImageField(source='user.avatar', read_only=True)
    qualifications = DoctorQualificationSerializer(many=True, read_only=True)
    availabilities = DoctorAvailabilitySerializer(many=True, read_only=True)
    latest_qualification_status = serializers.SerializerMethodField()

    class Meta:
        model = DoctorProfile
        fields = [
            'id', 'full_name', 'email', 'avatar', 'title', 'specialty',
            'specialty_display', 'license_number', 'years_of_experience',
            'bio', 'consultation_fee', 'is_verified', 'rejection_reason',
            'latest_qualification_status', 'rating', 'total_reviews',
            'qualifications', 'availabilities'
        ]
        read_only_fields = ['id', 'is_verified', 'rating', 'total_reviews']

    def get_latest_qualification_status(self, obj):
        latest = obj.qualifications.order_by('-created_at').first()
        if latest:
            return latest.verification_status
        return 'NO_SUBMISSION'

