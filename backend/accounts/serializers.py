from rest_framework import serializers
from django.contrib.auth import authenticate
from accounts.models import User
from accounts.authentication import generate_jwt_token
from patients.models import PatientProfile
from doctors.models import DoctorProfile


class PatientProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = PatientProfile
        fields = [
            'id', 'date_of_birth', 'gender', 'emergency_contact_name',
            'emergency_contact_phone', 'allergies', 'created_at'
        ]


class DoctorProfileSerializer(serializers.ModelSerializer):
    specialty_display = serializers.CharField(source='get_specialty_display', read_only=True)

    class Meta:
        model = DoctorProfile
        fields = [
            'id', 'title', 'specialty', 'specialty_display', 'license_number',
            'years_of_experience', 'bio', 'consultation_fee', 'is_verified',
            'rating', 'total_reviews'
        ]


from core.sms_service import normalize_syrian_phone
from datetime import date

class UserSerializer(serializers.ModelSerializer):
    patient_profile = PatientProfileSerializer(read_only=True)
    doctor_profile = DoctorProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = [
            'id', 'email', 'first_name', 'last_name', 'role', 'status',
            'phone_number', 'is_phone_verified', 'age', 'preferred_language', 'avatar',
            'patient_profile', 'doctor_profile', 'created_at'
        ]
        read_only_fields = ['id', 'status', 'created_at']


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    role = serializers.ChoiceField(choices=User.ROLE_CHOICES, default='PATIENT')
    first_name = serializers.CharField(required=True, allow_blank=False)
    last_name = serializers.CharField(required=True, allow_blank=False)
    phone_number = serializers.CharField(required=True, allow_blank=False, help_text="Syrian mobile number (+9639... / 09...)")
    age = serializers.IntegerField(required=True, min_value=12, max_value=110, help_text="Age in years")
    
    # Doctor specific optional fields during initial signup
    specialty = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    license_number = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    years_of_experience = serializers.IntegerField(required=False, default=0, allow_null=True)

    class Meta:
        model = User
        fields = [
            'email', 'password', 'first_name', 'last_name', 'role',
            'phone_number', 'age', 'preferred_language', 'specialty',
            'license_number', 'years_of_experience'
        ]

    def validate_phone_number(self, value):
        try:
            return normalize_syrian_phone(value)
        except ValueError as e:
            raise serializers.ValidationError(str(e))

    def create(self, validated_data):
        specialty = validated_data.pop('specialty', None)
        license_number = validated_data.pop('license_number', '')
        years_of_experience = validated_data.pop('years_of_experience', 0)
        password = validated_data.pop('password')
        role = validated_data.get('role', 'PATIENT')
        age = validated_data.get('age')

        # Clean email
        validated_data['email'] = validated_data['email'].strip().lower()

        # If doctor registers, status starts as PENDING until verified by Admin (BR-001)
        status = 'PENDING' if role == 'DOCTOR' else 'ACTIVE'
        validated_data['status'] = status

        user = User.objects.create_user(password=password, **validated_data)

        if role == 'PATIENT':
            approx_dob = None
            if age:
                approx_dob = date(date.today().year - age, 1, 1)
            PatientProfile.objects.create(user=user, date_of_birth=approx_dob)
        elif role == 'DOCTOR':
            DoctorProfile.objects.create(
                user=user,
                specialty=specialty if specialty else 'CLINICAL_PSYCHOLOGY',
                license_number=license_number if license_number else '',
                years_of_experience=years_of_experience if years_of_experience else 0,
                is_verified=False
            )

        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')

        # Robust case-insensitive email lookup
        user = User.objects.filter(email__iexact=email).first()
        if not user or not user.check_password(password):
            raise serializers.ValidationError('البريد الإلكتروني أو كلمة المرور غير صحيحة.')

        if user.status == 'SUSPENDED':
            raise serializers.ValidationError('تم تعليق هذا الحساب. يرجى التواصل مع إدارة المنصة.')

        token = generate_jwt_token(user)
        return {
            'token': token,
            'user': UserSerializer(user).data
        }
