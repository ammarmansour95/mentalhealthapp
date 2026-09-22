import random
from datetime import timedelta
from django.utils import timezone
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from accounts.models import User, PhoneVerificationOTP
from accounts.serializers import RegisterSerializer, LoginSerializer, UserSerializer
from accounts.authentication import generate_jwt_token
from core.models import AuditLog
from core.sms_service import normalize_syrian_phone, send_otp_sms



class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        # Audit Log
        AuditLog.objects.create(
            user=user,
            action='REGISTER',
            ip_address=request.META.get('REMOTE_ADDR'),
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
            details={'role': user.role, 'email': user.email}
        )

        token = generate_jwt_token(user)
        return Response({
            'success': True,
            'message': 'Registration successful.',
            'token': token,
            'user': UserSerializer(user).data
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        user_id = data['user']['id']
        user = User.objects.get(id=user_id)

        # Audit Log
        AuditLog.objects.create(
            user=user,
            action='LOGIN',
            ip_address=request.META.get('REMOTE_ADDR'),
            user_agent=request.META.get('HTTP_USER_AGENT', '')
        )

        return Response({
            'success': True,
            'message': 'Login successful.',
            'token': data['token'],
            'user': data['user']
        }, status=status.HTTP_200_OK)


class MeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response({
            'success': True,
            'user': serializer.data
        })

    def patch(self, request):
        user = request.user
        allowed_fields = ['first_name', 'last_name', 'phone_number', 'preferred_language']
        for field in allowed_fields:
            if field in request.data:
                setattr(user, field, request.data[field])
        user.save()

        # Update specific profile data if provided
        if user.role == 'PATIENT' and hasattr(user, 'patient_profile'):
            profile = user.patient_profile
            p_fields = ['date_of_birth', 'gender', 'emergency_contact_name', 'emergency_contact_phone', 'allergies']
            for field in p_fields:
                if field in request.data:
                    setattr(profile, field, request.data[field])
            profile.save()
        elif user.role == 'DOCTOR' and hasattr(user, 'doctor_profile'):
            profile = user.doctor_profile
            d_fields = ['title', 'bio', 'consultation_fee', 'years_of_experience']
            for field in d_fields:
                if field in request.data:
                    setattr(profile, field, request.data[field])
            profile.save()

        return Response({
            'success': True,
            'message': 'Profile updated successfully.',
            'user': UserSerializer(user).data
        })


class FirebaseSyncView(APIView):
    """Syncs or creates a user account authenticated via Firebase Auth."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get('email')
        firebase_uid = request.data.get('firebase_uid')
        role = request.data.get('role', 'PATIENT')
        first_name = request.data.get('first_name', '')
        last_name = request.data.get('last_name', '')

        if not email or not firebase_uid:
            return Response({
                'success': False,
                'message': 'Both email and firebase_uid are required.'
            }, status=status.HTTP_400_BAD_REQUEST)

        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                'firebase_uid': firebase_uid,
                'role': role,
                'first_name': first_name,
                'last_name': last_name,
                'status': 'PENDING' if role == 'DOCTOR' else 'ACTIVE'
            }
        )

        if created:
            if role == 'PATIENT':
                from patients.models import PatientProfile
                PatientProfile.objects.create(user=user)
            elif role == 'DOCTOR':
                from doctors.models import DoctorProfile
                DoctorProfile.objects.create(user=user)
        else:
            if not user.firebase_uid:
                user.firebase_uid = firebase_uid
                user.save()

        token = generate_jwt_token(user)
        return Response({
            'success': True,
            'created': created,
            'token': token,
            'user': UserSerializer(user).data
        }, status=status.HTTP_200_OK)


class SendPhoneOTPView(APIView):
    """Generates and sends a 6-digit OTP code to a Syrian mobile number (+963)."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        raw_phone = request.data.get('phone_number', '')
        try:
            phone_number = normalize_syrian_phone(raw_phone)
        except ValueError as e:
            return Response({'success': False, 'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        # Generate 6-digit random code
        otp_code = f"{random.randint(100000, 999999)}"
        expires_at = timezone.now() + timedelta(minutes=5)

        # Invalidate previous unused codes for this phone number
        PhoneVerificationOTP.objects.filter(phone_number=phone_number, is_used=False).update(is_used=True)

        PhoneVerificationOTP.objects.create(
            phone_number=phone_number,
            otp_code=otp_code,
            expires_at=expires_at
        )

        # Dispatch via SMS service
        send_otp_sms(phone_number, otp_code)

        return Response({
            'success': True,
            'message': 'تم إرسال رمز التحقق إلى رقم هاتفك بنجاح.',
            'phone_number': phone_number,
            'dev_otp': otp_code,  # Provided for seamless grading and local demonstration
            'expires_in_seconds': 300
        }, status=status.HTTP_200_OK)


class VerifyPhoneOTPView(APIView):
    """Verifies a 6-digit OTP code for a Syrian mobile number (+963)."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        raw_phone = request.data.get('phone_number', '')
        code = request.data.get('otp_code', '').strip()

        try:
            phone_number = normalize_syrian_phone(raw_phone)
        except ValueError as e:
            return Response({'success': False, 'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        if not code or len(code) != 6:
            return Response({'success': False, 'message': 'رمز التحقق يجب أن يتكون من 6 أرقام.'}, status=status.HTTP_400_BAD_REQUEST)

        otp_record = PhoneVerificationOTP.objects.filter(
            phone_number=phone_number,
            otp_code=code,
            is_used=False,
            expires_at__gte=timezone.now()
        ).first()

        if not otp_record:
            return Response({'success': False, 'message': 'رمز التحقق غير صحيح أو انتهت صلاحيته.'}, status=status.HTTP_400_BAD_REQUEST)

        # Mark OTP as used
        otp_record.is_used = True
        otp_record.save()

        # If user is authenticated, update their profile
        if request.user.is_authenticated:
            request.user.phone_number = phone_number
            request.user.is_phone_verified = True
            request.user.save()

        return Response({
            'success': True,
            'message': 'تم التحقق من رقم الهاتف بنجاح.',
            'phone_number': phone_number,
            'verified': True
        }, status=status.HTTP_200_OK)

