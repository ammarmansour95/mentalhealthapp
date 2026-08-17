import mimetypes
from django.http import HttpResponse, Http404
from django.core.files.base import ContentFile
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from doctors.models import DoctorProfile, DoctorQualification, DoctorAvailability
from doctors.serializers import (
    DoctorProfileSerializer,
    DoctorQualificationSerializer,
    DoctorAvailabilitySerializer
)
from core.permissions import IsDoctor, IsAdminUserRole
from core.encryption import encrypt_bytes, decrypt_bytes


class DoctorListView(generics.ListAPIView):
    """Public doctor directory with specialty and search filtering."""
    serializer_class = DoctorProfileSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        queryset = DoctorProfile.objects.filter(is_verified=True)
        specialty = self.request.query_params.get('specialty')
        search = self.request.query_params.get('search')

        if specialty:
            queryset = queryset.filter(specialty=specialty)
        if search:
            queryset = queryset.filter(user__first_name__icontains=search) | queryset.filter(user__last_name__icontains=search)
        return queryset


class DoctorDetailView(generics.RetrieveAPIView):
    queryset = DoctorProfile.objects.all()
    serializer_class = DoctorProfileSerializer
    permission_classes = [permissions.AllowAny]


from rest_framework.parsers import MultiPartParser, FormParser, JSONParser


class DoctorProfileMeView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        user = request.user
        if hasattr(user, 'doctor_profile'):
            doctor = user.doctor_profile
        elif user.role == 'DOCTOR':
            doctor, _ = DoctorProfile.objects.get_or_create(user=user)
        else:
            return Response({'success': False, 'message': 'Only doctors can access this endpoint.'}, status=status.HTTP_403_FORBIDDEN)

        return Response({
            'success': True,
            'doctor': DoctorProfileSerializer(doctor).data
        })

    def patch(self, request):
        user = request.user
        if hasattr(user, 'doctor_profile'):
            doctor = user.doctor_profile
        elif user.role == 'DOCTOR':
            doctor, _ = DoctorProfile.objects.get_or_create(user=user)
        else:
            return Response({'success': False, 'message': 'Only doctors can access this endpoint.'}, status=status.HTTP_403_FORBIDDEN)

        specialty = request.data.get('specialty')
        license_number = request.data.get('license_number', '').strip()
        years_of_exp = request.data.get('years_of_experience')
        bio = request.data.get('bio', '').strip()
        degree_title = request.data.get('degree_title', '').strip()
        institution_name = request.data.get('institution_name', '').strip()
        document_name = request.data.get('document_name', '').strip()
        document_file = request.FILES.get('document_file')

        if document_file:
            document_name = document_file.name

        if specialty:
            doctor.specialty = specialty
        if license_number:
            doctor.license_number = license_number
        if years_of_exp is not None:
            try:
                doctor.years_of_experience = int(years_of_exp)
            except (ValueError, TypeError):
                pass
        if bio:
            doctor.bio = bio
        doctor.save()

        # Create or update pending qualification proof with AES-256 Encrypted file
        if degree_title or institution_name or document_name or document_file:
            qual_data = {
                'degree_title': degree_title or 'ترخيص مزاولة مهنة معتمد',
                'institution_name': institution_name or 'الهيئة السعودية للتخصصات الصحية',
                'admin_notes': f"وثيقة مرفقة: {document_name}" if document_name else '',
                'verification_status': 'PENDING'
            }
            if document_file:
                raw_bytes = document_file.read()
                encrypted_bytes = encrypt_bytes(raw_bytes)
                qual_data['document_file'] = ContentFile(encrypted_bytes, name=document_file.name)

            DoctorQualification.objects.create(
                doctor=doctor,
                **qual_data
            )
            # Clear previous rejection reason now that the doctor has re-submitted documents
            doctor.rejection_reason = ''
            doctor.save()

        return Response({
            'success': True,
            'message': 'تم إرسال وتشفير بيانات وتراخيص الاعتماد بنجاح (AES-256)، وهي قيد المراجعة لدى المشرف.',
            'doctor': DoctorProfileSerializer(doctor).data
        })


class DoctorQualificationDocumentStreamView(APIView):
    """
    Secure endpoint that decrypts and streams medical documents (PDF/JPG)
    only to authorized admins or the owning doctor.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        try:
            qual = DoctorQualification.objects.select_related('doctor__user').get(pk=pk)
        except DoctorQualification.DoesNotExist:
            raise Http404("Document not found.")

        # Access Control: Only staff/admin or the owning doctor can view
        if request.user.role != 'ADMIN' and request.user != qual.doctor.user and not request.user.is_staff:
            return Response({'error': 'Unauthorized to view this confidential medical document.'}, status=status.HTTP_403_FORBIDDEN)

        if not qual.document_file:
            raise Http404("No file attached.")

        try:
            qual.document_file.open('rb')
            encrypted_data = qual.document_file.read()
            qual.document_file.close()
            decrypted_data = decrypt_bytes(encrypted_data)
        except Exception as e:
            return Response({'error': f'Decryption error: {e}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        filename = qual.document_file.name.split('/')[-1]
        content_type, _ = mimetypes.guess_type(filename)
        if not content_type:
            content_type = 'application/pdf' if filename.lower().endswith('.pdf') else 'image/jpeg'

        response = HttpResponse(decrypted_data, content_type=content_type)
        response['Content-Disposition'] = f'inline; filename="{filename}"'
        return response


class DoctorQualificationUploadView(generics.CreateAPIView):
    serializer_class = DoctorQualificationSerializer
    permission_classes = [permissions.IsAuthenticated, IsDoctor]

    def perform_create(self, serializer):
        doctor = self.request.user.doctor_profile
        serializer.save(doctor=doctor, verification_status='PENDING')


class DoctorAvailabilityManageView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDoctor]

    def get(self, request):
        doctor = request.user.doctor_profile
        availabilities = doctor.availabilities.all()
        return Response({
            'success': True,
            'availabilities': DoctorAvailabilitySerializer(availabilities, many=True).data
        })

    def post(self, request):
        doctor = request.user.doctor_profile
        data = request.data

        # Support bulk weekly schedule replacement
        if isinstance(data, list) or (isinstance(data, dict) and 'schedules' in data):
            schedule_list = data if isinstance(data, list) else data['schedules']
            doctor.availabilities.all().delete()
            created = []
            for item in schedule_list:
                serializer = DoctorAvailabilitySerializer(data=item)
                if serializer.is_valid():
                    obj = serializer.save(doctor=doctor)
                    created.append(obj)
            return Response({
                'success': True,
                'message': 'تم حفظ وتحديث جدول أوقات وساعات العمل الأسبوعية بنجاح.',
                'availabilities': DoctorAvailabilitySerializer(created, many=True).data
            }, status=status.HTTP_200_OK)

        serializer = DoctorAvailabilitySerializer(data=data)
        serializer.is_valid(raise_exception=True)
        obj = serializer.save(doctor=doctor)
        return Response({
            'success': True,
            'message': 'تم إضافة فترة العمل بنجاح.',
            'availability': DoctorAvailabilitySerializer(obj).data
        }, status=status.HTTP_201_CREATED)


class DoctorBookedSlotsView(APIView):
    """Returns all booked/occupied time slots and doctor working slots for a specific date."""
    permission_classes = [permissions.AllowAny]

    def get(self, request, pk):
        from appointments.models import Appointment
        import datetime

        date_str = request.query_params.get('date')
        if not date_str:
            date_str = datetime.date.today().isoformat()

        try:
            parsed_date = datetime.date.fromisoformat(date_str)
        except ValueError:
            parsed_date = datetime.date.today()
            date_str = parsed_date.isoformat()

        try:
            doctor = DoctorProfile.objects.get(id=pk)
        except DoctorProfile.DoesNotExist:
            return Response({'success': False, 'message': 'Doctor not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Check working day availability
        active_avails = doctor.availabilities.filter(is_active=True)
        dow = parsed_date.weekday()
        day_avail = active_avails.filter(day_of_week=dow).first()

        day_names_ar = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد']
        current_day_name = day_names_ar[dow]

        is_available_day = True
        available_slots = []
        if active_avails.exists():
            if not day_avail:
                is_available_day = False
                available_slots = ['09:00:00', '10:00:00', '11:00:00', '14:00:00', '15:00:00', '16:00:00']
            else:
                import datetime as dt
                cur = dt.datetime.combine(parsed_date, day_avail.start_time)
                end = dt.datetime.combine(parsed_date, day_avail.end_time)
                duration = dt.timedelta(minutes=day_avail.slot_duration_minutes or 45)
                while cur + duration <= end:
                    available_slots.append(cur.strftime('%H:%M:%S'))
                    cur += duration
        else:
            # Default working slots if doctor hasn't configured custom hours
            available_slots = ['09:00:00', '10:00:00', '11:00:00', '14:00:00', '15:00:00', '16:00:00']

        # Find active appointments (both PENDING and CONFIRMED hold the slot)
        active_appointments = Appointment.objects.filter(
            doctor_id=pk,
            appointment_date=date_str,
            status__in=['PENDING', 'CONFIRMED']
        )

        booked_slots = [
            appt.start_time.strftime('%H:%M:%S') for appt in active_appointments
        ]

        active_days_summary = [
            f"{av.get_day_of_week_display().split(' ')[0]} ({av.start_time.strftime('%H:%M')} - {av.end_time.strftime('%H:%M')})"
            for av in active_avails
        ]

        return Response({
            'success': True,
            'doctor_id': str(pk),
            'date': date_str,
            'day_name': current_day_name,
            'is_available_day': is_available_day,
            'available_slots': available_slots,
            'booked_slots': booked_slots,
            'active_days_summary': active_days_summary
        })


class AdminVerifyDoctorView(APIView):
    """Admin verifies and approves or rejects doctor qualification."""
    permission_classes = [permissions.IsAuthenticated, IsAdminUserRole]

    def patch(self, request, pk):
        try:
            doctor = DoctorProfile.objects.get(id=pk)
        except DoctorProfile.DoesNotExist:
            return Response({'success': False, 'message': 'Doctor not found.'}, status=status.HTTP_404_NOT_FOUND)

        action = request.data.get('action')  # 'APPROVE' or 'REJECT'
        reason = request.data.get('reason', '')

        if action == 'APPROVE':
            doctor.is_verified = True
            doctor.user.status = 'ACTIVE'
            doctor.user.save()
            doctor.rejection_reason = ''
            doctor.save()
            doctor.qualifications.filter(verification_status='PENDING').update(verification_status='APPROVED')
            message = 'Doctor approved successfully.'
        elif action == 'REJECT':
            doctor.is_verified = False
            doctor.user.status = 'PENDING'
            doctor.user.save()
            doctor.rejection_reason = reason
            doctor.save()
            doctor.qualifications.filter(verification_status='PENDING').update(verification_status='REJECTED', admin_notes=reason)
            message = 'تم رفض الوثيقة وإشعار الطبيب بالملاحظات لإعادة تقديمها.'
        else:
            return Response({'success': False, 'message': 'Invalid action. Use APPROVE or REJECT.'}, status=status.HTTP_400_BAD_REQUEST)

        return Response({
            'success': True,
            'message': message,
            'doctor': DoctorProfileSerializer(doctor).data
        })
