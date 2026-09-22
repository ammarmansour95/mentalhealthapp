from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from messaging.models import Conversation, Message
from messaging.serializers import ConversationSerializer, MessageSerializer
from appointments.models import Appointment
from patients.models import PatientProfile
from doctors.models import DoctorProfile
from core.models import Notification, AuditLog
from core.sms_service import send_emergency_crisis_sms


def get_chat_window_status(patient: PatientProfile, doctor: DoctorProfile, current_user):
    """
    Evaluates whether the clinical chat window between patient and doctor is currently active.
    Rules:
    1. Doctors can always message their patients.
    2. Patients can message if they have a CONFIRMED appointment today or within a 24-hour post-session window.
    3. Outside this window, regular messages are locked unless sent via Emergency Bypass.
    """
    if current_user.role == 'DOCTOR':
        return {
            'is_window_open': True,
            'window_reason': 'صلاحية المراسلة الطبية مفتوحة دائماً للطبيب المعالج.',
            'next_appointment': None
        }

    now = timezone.now()
    today = now.date()
    yesterday = today - timezone.timedelta(days=1)

    # 1. Active appointment today
    active_appt_today = Appointment.objects.filter(
        patient=patient,
        doctor=doctor,
        status='CONFIRMED',
        appointment_date=today
    ).first()

    if active_appt_today:
        return {
            'is_window_open': True,
            'window_reason': f"جلسة استشارية مؤكدة اليوم ({active_appt_today.start_time.strftime('%H:%M')}). نافذة المراسلة مفتوحة.",
            'next_appointment': {
                'id': str(active_appt_today.id),
                'date': str(active_appt_today.appointment_date),
                'time': str(active_appt_today.start_time)
            }
        }

    # 2. Recent appointment in the 24-hour follow-up window
    recent_followup = Appointment.objects.filter(
        patient=patient,
        doctor=doctor,
        status__in=['CONFIRMED', 'COMPLETED'],
        appointment_date__gte=yesterday,
        appointment_date__lte=today
    ).order_by('-appointment_date', '-start_time').first()

    if recent_followup:
        return {
            'is_window_open': True,
            'window_reason': 'نافذة المتابعة والاستفسارات مفتوحة (أقل من 24 ساعة بعد آخر موعد).',
            'next_appointment': {
                'id': str(recent_followup.id),
                'date': str(recent_followup.appointment_date),
                'time': str(recent_followup.start_time)
            }
        }

    # 3. Chat is locked - check if there's any upcoming confirmed appointment
    next_appt = Appointment.objects.filter(
        patient=patient,
        doctor=doctor,
        status='CONFIRMED',
        appointment_date__gt=today
    ).order_by('appointment_date', 'start_time').first()

    next_data = None
    if next_appt:
        next_data = {
            'id': str(next_appt.id),
            'date': str(next_appt.appointment_date),
            'time': str(next_appt.start_time)
        }
        reason = f"المحادثة مقفلة حالياً. موعدك القادم مع الطبيب بتاريخ {next_appt.appointment_date} الساعة {next_appt.start_time.strftime('%H:%M')}."
    else:
        reason = "المحادثة مقفلة. يُسمح بالمراسلة أثناء موعد الجلسة وفترة المتابعة (24 ساعة). يرجى حجز موعد للتواصل."

    return {
        'is_window_open': False,
        'window_reason': reason,
        'next_appointment': next_data
    }


class ConversationListView(generics.ListAPIView):
    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'PATIENT' and hasattr(user, 'patient_profile'):
            return Conversation.objects.filter(patient=user.patient_profile)
        elif user.role == 'DOCTOR' and hasattr(user, 'doctor_profile'):
            return Conversation.objects.filter(doctor=user.doctor_profile)
        return Conversation.objects.none()


class GetOrCreateConversationView(APIView):
    """
    Gets or creates a conversation between the authenticated user and their doctor/patient.
    Also returns the active appointment window status.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user

        if user.role == 'PATIENT':
            if not hasattr(user, 'patient_profile'):
                return Response({'success': False, 'message': 'الملف الشخصي للمريض غير موجود.'}, status=status.HTTP_400_BAD_REQUEST)
            patient = user.patient_profile
            doc_identifier = request.data.get('doctor_id') or request.data.get('other_user_id')
            if not doc_identifier:
                return Response({'success': False, 'message': 'يجب تحديد معرف الطبيب (doctor_id أو other_user_id).'}, status=status.HTTP_400_BAD_REQUEST)
            try:
                doctor = DoctorProfile.objects.filter(id=doc_identifier).first() or DoctorProfile.objects.filter(user_id=doc_identifier).first()
                if not doctor:
                    return Response({'success': False, 'message': 'الطبيب غير موجود.'}, status=status.HTTP_404_NOT_FOUND)
            except Exception:
                return Response({'success': False, 'message': 'الطبيب غير موجود.'}, status=status.HTTP_404_NOT_FOUND)

        elif user.role == 'DOCTOR':
            if not hasattr(user, 'doctor_profile'):
                return Response({'success': False, 'message': 'الملف المهني للطبيب غير موجود.'}, status=status.HTTP_400_BAD_REQUEST)
            doctor = user.doctor_profile
            pat_identifier = request.data.get('patient_id') or request.data.get('other_user_id')
            if not pat_identifier:
                return Response({'success': False, 'message': 'يجب تحديد معرف المريض (patient_id أو other_user_id).'}, status=status.HTTP_400_BAD_REQUEST)
            try:
                patient = PatientProfile.objects.filter(id=pat_identifier).first() or PatientProfile.objects.filter(user_id=pat_identifier).first()
                if not patient:
                    return Response({'success': False, 'message': 'المريض غير موجود.'}, status=status.HTTP_404_NOT_FOUND)
            except Exception:
                return Response({'success': False, 'message': 'المريض غير موجود.'}, status=status.HTTP_404_NOT_FOUND)
        else:
            return Response({'success': False, 'message': 'غير مصرح للمشرفين ببدء محادثات مباشرة.'}, status=status.HTTP_403_FORBIDDEN)

        conv, _ = Conversation.objects.get_or_create(patient=patient, doctor=doctor)
        window_status = get_chat_window_status(patient, doctor, user)

        return Response({
            'success': True,
            'conversation': ConversationSerializer(conv, context={'request': request}).data,
            'window_status': window_status,
            **window_status
        }, status=status.HTTP_200_OK)


class ConversationMessagesView(APIView):
    """
    Retrieves messages for a conversation and marks unread messages as read.
    Also returns real-time appointment window status.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, conversation_id):
        user = request.user
        try:
            conv = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Response({'success': False, 'message': 'المحادثة غير موجودة.'}, status=status.HTTP_404_NOT_FOUND)

        # Authorization check
        if user.role == 'PATIENT' and conv.patient.user_id != user.id:
            return Response({'success': False, 'message': 'غير مصرح لك بعرض هذه المحادثة.'}, status=status.HTTP_403_FORBIDDEN)
        if user.role == 'DOCTOR' and conv.doctor.user_id != user.id:
            return Response({'success': False, 'message': 'غير مصرح لك بعرض هذه المحادثة.'}, status=status.HTTP_403_FORBIDDEN)

        # Mark unread incoming messages as read
        conv.messages.exclude(sender=user).filter(is_read=False).update(
            is_read=True,
            read_at=timezone.now()
        )

        messages = conv.messages.all()
        serialized = MessageSerializer(messages, many=True, context={'request': request}).data
        window_status = get_chat_window_status(conv.patient, conv.doctor, user)

        return Response({
            'success': True,
            'messages': serialized,
            'conversation': ConversationSerializer(conv, context={'request': request}).data,
            **window_status
        }, status=status.HTTP_200_OK)


class SendMessageView(APIView):
    """
    Sends an encrypted clinical message.
    Enforces appointment time-window restrictions for patients, with Emergency Bypass capability.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        conv_id = request.data.get('conversation_id')
        content = request.data.get('content', '').strip()
        is_emergency = request.data.get('is_emergency', False) in [True, 'true', '1', 1]
        emergency_reason = request.data.get('emergency_reason', '').strip()

        if not content:
            return Response({'success': False, 'message': 'محتوى الرسالة لا يمكن أن يكون فارغاً.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            conv = Conversation.objects.get(id=conv_id)
        except Conversation.DoesNotExist:
            return Response({'success': False, 'message': 'المحادثة غير موجودة.'}, status=status.HTTP_404_NOT_FOUND)

        user = request.user

        # Authorization check
        if user.role == 'PATIENT' and conv.patient.user_id != user.id:
            return Response({'success': False, 'message': 'غير مصرح لك بالإرسال في هذه المحادثة.'}, status=status.HTTP_403_FORBIDDEN)
        if user.role == 'DOCTOR' and conv.doctor.user_id != user.id:
            return Response({'success': False, 'message': 'غير مصرح لك بالإرسال في هذه المحادثة.'}, status=status.HTTP_403_FORBIDDEN)

        # Check Appointment Window for Patient
        if user.role == 'PATIENT':
            window_status = get_chat_window_status(conv.patient, conv.doctor, user)
            if not window_status['is_window_open'] and not is_emergency:
                return Response({
                    'success': False,
                    'code': 'CHAT_WINDOW_CLOSED',
                    'message': window_status['window_reason'],
                    'can_emergency_bypass': True
                }, status=status.HTTP_200_OK)

        # Create Message
        msg = Message.objects.create(
            conversation=conv,
            sender=user,
            content_encrypted=content,
            is_emergency=is_emergency,
            emergency_reason=emergency_reason if is_emergency else ''
        )
        conv.save()

        # Recipient determination
        recipient_user = conv.doctor.user if user.role == 'PATIENT' else conv.patient.user
        sender_name = user.get_full_name() or user.email

        # Notification & Emergency Protocol
        if is_emergency:
            # Urgent Crisis Dispatch to Doctor and Admins
            doctor_phone = getattr(conv.doctor.user, 'phone_number', '') or ''
            patient_phone = getattr(conv.patient.user, 'phone_number', '') or 'غير مسجل'

            Notification.objects.create(
                recipient=conv.doctor.user,
                title="🚨 نداء طوارئ سريري حرج عبر المحادثة",
                message=f"قام المريض {sender_name} (هاتف: {patient_phone}) بإرسال نداء استغاثة طارئ: «{content[:100]}» - السبب: {emergency_reason or 'أزمة نفسية حادة'}",
                notification_type='CRISIS_ALERT',
                metadata={
                    'conversation_id': str(conv.id),
                    'patient_name': sender_name,
                    'patient_phone': patient_phone,
                    'trigger_text': content,
                    'severity': 'CRITICAL'
                }
            )

            # Alert Admins
            from accounts.models import User as UserModel
            for admin_user in UserModel.objects.filter(role='ADMIN', is_active=True):
                Notification.objects.create(
                    recipient=admin_user,
                    title="🚨 نداء طوارئ سريري حرج عبر المحادثة",
                    message=f"أطلق المريض {sender_name} (هاتف: {patient_phone}) نداء طوارئ عبر محادثة د. {conv.doctor.user.get_full_name()}.",
                    notification_type='CRISIS_ALERT',
                    metadata={
                        'conversation_id': str(conv.id),
                        'patient_name': sender_name,
                        'patient_phone': patient_phone,
                        'trigger_text': content,
                        'severity': 'CRITICAL'
                    }
                )

            # Audit Log
            AuditLog.objects.create(
                user=user,
                action='CRISIS_SAFETY_PROTOCOL_ACTIVATED',
                details={'source': 'DIRECT_CHAT_EMERGENCY_BYPASS', 'conversation_id': str(conv.id)}
            )

            # Send Emergency SMS to doctor
            if doctor_phone:
                send_emergency_crisis_sms(doctor_phone, sender_name, content)
        else:
            # Regular Notification for New Message
            Notification.objects.create(
                recipient=recipient_user,
                title=f"رسالة جديدة من {sender_name}",
                message=content[:120],
                notification_type='NEW_MESSAGE',
                metadata={
                    'conversation_id': str(conv.id),
                    'sender_name': sender_name,
                    'sender_id': str(user.id)
                }
            )

        return Response({
            'success': True,
            'message': MessageSerializer(msg, context={'request': request}).data
        }, status=status.HTTP_201_CREATED)


class DoctorCrisisEscalationView(APIView):
    """
    Allows a doctor to escalate an urgent crisis for a patient directly from the chat screen.
    Sends CRISIS_ALERT notification to admins, logs in AuditLog, and notifies emergency dispatch.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, conversation_id):
        user = request.user
        if user.role != 'DOCTOR':
            return Response({'success': False, 'message': 'هذا الإجراء مخصص للأطباء فقط.'}, status=status.HTTP_403_FORBIDDEN)

        try:
            conv = Conversation.objects.get(id=conversation_id, doctor__user=user)
        except Conversation.DoesNotExist:
            return Response({'success': False, 'message': 'المحادثة غير موجودة.'}, status=status.HTTP_404_NOT_FOUND)

        notes = request.data.get('notes', '').strip()
        patient = conv.patient
        patient_name = patient.user.get_full_name() or patient.user.email
        patient_phone = patient.user.phone_number or 'غير مسجل'

        # Send alert to admins
        from accounts.models import User as UserModel
        for admin in UserModel.objects.filter(role='ADMIN', is_active=True):
            Notification.objects.create(
                recipient=admin,
                title="🚨 تصعيد طوارئ سريرية من الطبيب المشرف",
                message=f"قام د. {user.get_full_name()} بتصعيد حالة طوارئ للمريض {patient_name} (هاتف: {patient_phone}). الملاحظات: {notes or 'اشتباه بخطر وشيك'}",
                notification_type='CRISIS_ALERT',
                metadata={
                    'conversation_id': str(conv.id),
                    'patient_id': str(patient.id),
                    'patient_name': patient_name,
                    'patient_phone': patient_phone,
                    'doctor_name': user.get_full_name(),
                    'doctor_notes': notes,
                    'severity': 'CRITICAL',
                }
            )

        AuditLog.objects.create(
            user=user,
            action='DOCTOR_CRISIS_ESCALATION',
            details={
                'conversation_id': str(conv.id),
                'patient_name': patient_name,
                'patient_phone': patient_phone,
                'doctor_notes': notes
            }
        )

        return Response({
            'success': True,
            'message': 'تم تصعيد بلاغ الطوارئ السريري إلى إدارة المنصة بنجاح.'
        }, status=status.HTTP_200_OK)


