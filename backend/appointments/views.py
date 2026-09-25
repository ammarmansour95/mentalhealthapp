from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db import transaction
from appointments.models import Appointment
from appointments.serializers import AppointmentSerializer, BookAppointmentSerializer
from doctors.models import DoctorProfile
from core.permissions import IsPatient, IsDoctor
from core.models import AuditLog


class MyAppointmentsListView(generics.ListAPIView):
    serializer_class = AppointmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'PATIENT' and hasattr(user, 'patient_profile'):
            return Appointment.objects.filter(patient=user.patient_profile).order_by('-appointment_date', '-start_time')
        elif user.role == 'DOCTOR' and hasattr(user, 'doctor_profile'):
            return Appointment.objects.filter(doctor=user.doctor_profile).order_by('-appointment_date', '-start_time')
        elif user.role == 'ADMIN':
            return Appointment.objects.all().order_by('-appointment_date', '-start_time')
        return Appointment.objects.none()


class BookAppointmentView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsPatient]

    def post(self, request):
        patient = request.user.patient_profile
        serializer = BookAppointmentSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        data = serializer.validated_data

        try:
            doctor = DoctorProfile.objects.get(id=data['doctor_id'], is_verified=True)
        except DoctorProfile.DoesNotExist:
            return Response({'success': False, 'message': 'Verified doctor not found.'}, status=status.HTTP_404_NOT_FOUND)

        appointment_date = data['appointment_date']
        start_time = data['start_time']
        end_time = data.get('end_time')

        # Prevent booking in the past
        if appointment_date < timezone.now().date():
            return Response({
                'success': False,
                'message': 'لا يمكن حجز موعد في تاريخ سابق.'
            }, status=status.HTTP_400_BAD_REQUEST)

        # 1. Enforce doctor availability schedule
        active_avails = doctor.availabilities.filter(is_active=True)
        if active_avails.exists():
            dow = appointment_date.weekday()
            day_avail = active_avails.filter(day_of_week=dow).first()
            if not day_avail:
                return Response({
                    'success': False,
                    'message': 'عذراً، الطبيب غير متاح لاستقبال المواعيد في هذا اليوم. يرجى مراجعة أيام عمل الطبيب المتاحة.'
                }, status=status.HTTP_400_BAD_REQUEST)

            if start_time < day_avail.start_time or start_time >= day_avail.end_time:
                return Response({
                    'success': False,
                    'message': f'عذراً، الوقت المختار خارج ساعات عمل الطبيب ({day_avail.start_time.strftime("%H:%M")} - {day_avail.end_time.strftime("%H:%M")}).'
                }, status=status.HTTP_400_BAD_REQUEST)

        # 2. Check for slot collision / double booking
        already_booked = Appointment.objects.filter(
            doctor=doctor,
            appointment_date=appointment_date,
            start_time=start_time,
            status__in=['PENDING', 'CONFIRMED']
        ).exists()
        if already_booked:
            return Response({
                'success': False,
                'message': 'عذراً، هذا الموعد محجوز مسبقاً. يرجى اختيار وقت آخر.'
            }, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            # Atomically lock and create appointment with PENDING status (requires doctor confirmation)
            appointment = Appointment.objects.create(
                patient=patient,
                doctor=doctor,
                appointment_date=appointment_date,
                start_time=start_time,
                end_time=end_time,
                patient_notes=data.get('patient_notes', ''),
                status='PENDING'
            )

        # Audit Log
        AuditLog.objects.create(
            user=request.user,
            action='APPOINTMENT_BOOKED',
            ip_address=request.META.get('REMOTE_ADDR'),
            details={'appointment_id': str(appointment.id), 'doctor': doctor.user.email}
        )

        # Send Real-time In-App Notification to Doctor and Patient
        try:
            from core.notifications_service import notify_doctor_new_appointment, notify_patient_appointment_booked
            notify_doctor_new_appointment(appointment)
            notify_patient_appointment_booked(appointment)
        except Exception:
            pass

        return Response({
            'success': True,
            'message': 'Appointment successfully booked and confirmed.',
            'appointment': AppointmentSerializer(appointment).data
        }, status=status.HTTP_201_CREATED)


class UpdateAppointmentStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, pk):
        try:
            appointment = Appointment.objects.get(id=pk)
        except Appointment.DoesNotExist:
            return Response({'success': False, 'message': 'Appointment not found.'}, status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get('status')
        if new_status not in ['CONFIRMED', 'CANCELLED', 'COMPLETED', 'NO_SHOW']:
            return Response({'success': False, 'message': 'Invalid status.'}, status=status.HTTP_400_BAD_REQUEST)

        if new_status == 'CANCELLED':
            # Enforce 2-hour cancellation policy for patients
            if request.user.role == 'PATIENT':
                from django.utils import timezone
                import datetime

                appt_dt = datetime.datetime.combine(appointment.appointment_date, appointment.start_time)
                if timezone.is_naive(appt_dt):
                    appt_dt = timezone.make_aware(appt_dt, timezone.get_current_timezone())

                now = timezone.now()
                if (appt_dt - now) < datetime.timedelta(hours=2):
                    return Response({
                        'success': False,
                        'message': 'لا يمكن إلغاء الموعد قبل أقل من ساعتين من موعد بدء الجلسة وفقاً لسياسة الإلغاء.'
                    }, status=status.HTTP_400_BAD_REQUEST)

            appointment.cancellation_reason = request.data.get('cancellation_reason', 'Cancelled by patient' if request.user.role == 'PATIENT' else '')
            appointment.cancelled_by = request.user

        # Doctor private session notes
        if 'session_notes' in request.data and request.user.role == 'DOCTOR':
            appointment.session_notes_encrypted = request.data['session_notes']

        appointment.status = new_status
        appointment.save()

        # Send Real-time Status Change Notification
        try:
            from core.notifications_service import notify_appointment_status_change
            notify_appointment_status_change(
                appointment=appointment,
                new_status=new_status,
                cancelled_by=request.user,
                reason=appointment.cancellation_reason
            )
        except Exception:
            pass

        return Response({
            'success': True,
            'message': f'Appointment status updated to {new_status}.',
            'appointment': AppointmentSerializer(appointment).data
        })
