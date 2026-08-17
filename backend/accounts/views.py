from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from accounts.models import User
from accounts.serializers import RegisterSerializer, LoginSerializer, UserSerializer
from accounts.authentication import generate_jwt_token
from core.models import AuditLog


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
