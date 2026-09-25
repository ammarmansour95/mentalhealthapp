import datetime
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


def get_chat_window_status(patient: PatientProfile, doctor: DoctorProfile, current_user, conversation=None):
    """
    Evaluates whether the clinical chat window between patient and doctor is currently active.
    Rules:
    1. Doctors can always message their patients (is_window_open = True).
    2. If the doctor has manually unlocked the conversation (doctor_unlocked_until > now), window is OPEN for the patient.
    3. Patients can message if they have a CONFIRMED or COMPLETED appointment within the 24-hour window
       (i.e. up to 24 hours before appointment start through 24 hours after appointment end, or on appointment day).
    4. Outside this window, regular messages are locked unless sent via Emergency Bypass.
    """
    now = timezone.now()
    today = now.date()

    if conversation is None and patient and doctor:
        conversation = Conversation.objects.filter(patient=patient, doctor=doctor).first()

    is_doctor_unlocked = False
    if conversation and conversation.doctor_unlocked_until and conversation.doctor_unlocked_until > now:
        is_doctor_unlocked = True

    if current_user.role == 'DOCTOR':
        # Calculate whether the window would be open for the patient
        # Create a transient check for the patient
        patient_window_open = False
        patient_window_reason = ''
        if is_doctor_unlocked:
            hours_left = max(1, int((conversation.doctor_unlocked_until - now).total_seconds() // 3600))
            patient_window_open = True
            patient_window_reason = f"تم فتح المحادثة للمريض استثنائياً (متبقي {hours_left} ساعة)."
        else:
            # Check appointments
            candidate_appts = Appointment.objects.filter(
                patient=patient,
                doctor=doctor,
                status__in=['CONFIRMED', 'COMPLETED']
            ).order_by('-appointment_date', '-start_time')
            for appt in candidate_appts:
                appt_start_dt = timezone.make_aware(datetime.datetime.combine(appt.appointment_date, appt.start_time))
                appt_end_dt = timezone.make_aware(datetime.datetime.combine(appt.appointment_date, appt.end_time))
                window_start = appt_start_dt - datetime.timedelta(hours=24)
                window_end = appt_end_dt + datetime.timedelta(hours=24)
                if appt.status == 'CONFIRMED' and (appt.appointment_date == today or (window_start <= now <= window_end)):
                    patient_window_open = True
                    patient_window_reason = 'جلسة مؤكدة ضمن نافذة 24 ساعة.'
                    break
                elif appt.status == 'COMPLETED' and (now <= window_end and now >= (appt_start_dt - datetime.timedelta(hours=2))):
                    patient_window_open = True
                    patient_window_reason = 'نافذة متابعة ما بعد الجلسة مفتوحة.'
                    break

        return {
            'is_window_open': True,
            'is_open': True,
            'window_reason': 'صلاحية المراسلة الطبية مفتوحة دائماً للطبيب المعالج.',
            'reason': 'صلاحية المراسلة الطبية مفتوحة دائماً للطبيب المعالج.',
            'is_patient_window_open': patient_window_open,
            'is_doctor_unlocked': is_doctor_unlocked,
            'doctor_unlocked_until': conversation.doctor_unlocked_until.isoformat() if (conversation and conversation.doctor_unlocked_until) else None,
            'next_appointment': None,
            'active_appointment': None
        }

    # If Doctor manually unlocked the window for the patient:
    if is_doctor_unlocked:
        hours_left = max(1, int((conversation.doctor_unlocked_until - now).total_seconds() // 3600))
        return {
            'is_window_open': True,
            'is_open': True,
            'is_doctor_unlocked': True,
            'doctor_unlocked_until': conversation.doctor_unlocked_until.isoformat() if conversation.doctor_unlocked_until else None,
            'window_reason': f"قام الطبيب المعالج بفتح المحادثة استثنائياً لمتابعة حالتك (متبقي {hours_left} ساعة).",
            'reason': f"قام الطبيب المعالج بفتح المحادثة استثنائياً لمتابعة حالتك (متبقي {hours_left} ساعة).",
            'next_appointment': None,
            'active_appointment': None
        }

    # Retrieve all confirmed and completed appointments between patient and doctor
    candidate_appts = Appointment.objects.filter(
        patient=patient,
        doctor=doctor,
        status__in=['CONFIRMED', 'COMPLETED']
    ).order_by('-appointment_date', '-start_time')

    open_window_appt = None
    window_reason = ''

    for appt in candidate_appts:
        appt_start_dt = timezone.make_aware(datetime.datetime.combine(appt.appointment_date, appt.start_time))
        appt_end_dt = timezone.make_aware(datetime.datetime.combine(appt.appointment_date, appt.end_time))

        # 24 hours window around the appointment
        window_start = appt_start_dt - datetime.timedelta(hours=24)
        window_end = appt_end_dt + datetime.timedelta(hours=24)

        if appt.status == 'CONFIRMED':
            if appt.appointment_date == today or (window_start <= now <= window_end):
                open_window_appt = appt
                if appt.appointment_date == today:
                    window_reason = f"جلسة استشارية مؤكدة اليوم ({appt.start_time.strftime('%H:%M')}). نافذة المراسلة مفتوحة."
                elif now < appt_start_dt:
                    hours_until = max(1, int((appt_start_dt - now).total_seconds() // 3600))
                    window_reason = f"نافذة المراسلة مفتوحة (موعد جلستك القادمة بعد {hours_until} ساعة)."
                else:
                    hours_remaining = max(1, int((window_end - now).total_seconds() // 3600))
                    window_reason = f"نافذة المتابعة مفتوحة (متبقي {hours_remaining} ساعة بعد الجلسة)."
                break

        elif appt.status == 'COMPLETED':
            if now <= window_end and now >= (appt_start_dt - datetime.timedelta(hours=2)):
                open_window_appt = appt
                hours_remaining = max(1, int((window_end - now).total_seconds() // 3600))
                window_reason = f"نافذة المتابعة والاستفسارات مفتوحة (متبقي {hours_remaining} ساعة على إغلاق النافذة)."
                break

    if open_window_appt:
        appt_data = {
            'id': str(open_window_appt.id),
            'date': str(open_window_appt.appointment_date),
            'time': open_window_appt.start_time.strftime('%H:%M'),
            'status': open_window_appt.status
        }
        return {
            'is_window_open': True,
            'is_open': True,
            'is_doctor_unlocked': False,
            'window_reason': window_reason,
            'reason': window_reason,
            'next_appointment': appt_data,
            'active_appointment': appt_data
        }

    # If window is NOT open: Find the next upcoming confirmed appointment
    next_appt = Appointment.objects.filter(
        patient=patient,
        doctor=doctor,
        status='CONFIRMED',
        appointment_date__gte=today
    ).order_by('appointment_date', 'start_time').first()

    if next_appt:
        next_start_dt = timezone.make_aware(datetime.datetime.combine(next_appt.appointment_date, next_appt.start_time))
        if next_start_dt < now:
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
            'time': next_appt.start_time.strftime('%H:%M'),
            'status': next_appt.status
        }
        reason = f"المحادثة مقفلة حالياً. موعدك القادم مع الطبيب بتاريخ {next_appt.appointment_date} الساعة {next_appt.start_time.strftime('%H:%M')} (تفتح المحادثة قبل الموعد بـ 24 ساعة)."
    else:
        reason = "المحادثة مقفلة. يُسمح بالمراسلة أثناء موعد الجلسة وفترة المتابعة (24 ساعة). يرجى حجز موعد جديد للتواصل."

    return {
        'is_window_open': False,
        'is_open': False,
        'is_doctor_unlocked': False,
        'window_reason': reason,
        'reason': reason,
        'next_appointment': next_data,
        'active_appointment': None
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
        if user.role == 'DOCTOR':
            raw_sender = (user.get_full_name() or "الطبيب").strip()
            sender_name = raw_sender if raw_sender.startswith('د.') else f"د. {raw_sender}"

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
            doc_raw_admin = (conv.doctor.user.get_full_name() or "طبيب").strip()
            doc_admin_display = doc_raw_admin if doc_raw_admin.startswith('د.') else f"د. {doc_raw_admin}"
            for admin_user in UserModel.objects.filter(role='ADMIN', is_active=True):
                Notification.objects.create(
                    recipient=admin_user,
                    title="🚨 نداء طوارئ سريري حرج عبر المحادثة",
                    message=f"أطلق المريض {sender_name} (هاتف: {patient_phone}) نداء طوارئ عبر محادثة {doc_admin_display}.",
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

        conv = Conversation.objects.filter(id=conversation_id).first()
        if not conv:
            return Response({'success': False, 'message': 'المحادثة غير موجودة.'}, status=status.HTTP_404_NOT_FOUND)

        if user.role != 'ADMIN' and conv.doctor.user != user:
            return Response({'success': False, 'message': 'غير مصرح لك بإدارة هذه المحادثة (خاصة بطبيب آخر).'}, status=status.HTTP_403_FORBIDDEN)

        notes = request.data.get('notes', '').strip()
        patient = conv.patient
        patient_name = patient.user.get_full_name() or patient.user.email
        patient_phone = patient.user.phone_number or 'غير مسجل'

        # Send alert to admins
        from accounts.models import User as UserModel
        doc_raw_admin = (user.get_full_name() or "الطبيب المشرف").strip()
        doc_admin_display = doc_raw_admin if doc_raw_admin.startswith('د.') else f"د. {doc_raw_admin}"
        for admin in UserModel.objects.filter(role='ADMIN', is_active=True):
            Notification.objects.create(
                recipient=admin,
                title="🚨 تصعيد طوارئ سريرية من الطبيب المشرف",
                message=f"قام {doc_admin_display} بتصعيد حالة طوارئ للمريض {patient_name} (هاتف: {patient_phone}). الملاحظات: {notes or 'اشتباه بخطر وشيك'}",
                notification_type='CRISIS_ALERT',
                metadata={
                    'conversation_id': str(conv.id),
                    'patient_id': str(patient.id),
                    'patient_name': patient_name,
                    'patient_phone': patient_phone,
                    'doctor_name': doc_admin_display,
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


class DoctorToggleUnlockChatView(APIView):
    """
    Allows treating doctors to manually unlock or lock the chat window for the patient
    (e.g., unlocking for 24 or 48 hours for special clinical follow-up).
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, conversation_id):
        user = request.user
        if user.role != 'DOCTOR':
            return Response({'success': False, 'message': 'صلاحية فتح المحادثة مقصورة على الأطباء المعتمدين فقط.'}, status=status.HTTP_403_FORBIDDEN)

        conv = Conversation.objects.filter(id=conversation_id).first()
        if not conv:
            return Response({'success': False, 'message': 'المحادثة غير موجودة.'}, status=status.HTTP_404_NOT_FOUND)

        if user.role != 'ADMIN' and conv.doctor.user != user:
            return Response({'success': False, 'message': 'غير مصرح لك بإدارة هذه المحادثة (خاصة بطبيب آخر).'}, status=status.HTTP_403_FORBIDDEN)

        action = request.data.get('action', 'unlock')  # 'unlock' or 'lock'
        hours = int(request.data.get('hours', 24))

        if action == 'unlock':
            conv.doctor_unlocked_until = timezone.now() + datetime.timedelta(hours=hours)
            conv.save(update_fields=['doctor_unlocked_until'])

            # Send Notification to Patient
            raw_doc_name = (user.get_full_name() or "الطبيب المعالج").strip()
            doctor_name = raw_doc_name if raw_doc_name.startswith('د.') else f"د. {raw_doc_name}"
            Notification.objects.create(
                recipient=conv.patient.user,
                title="🔓 تم فتح نافذة المحادثة من قبل الطبيب",
                message=f"قام {doctor_name} بفتح نافذة المحادثة المباشرة معك لمدة {hours} ساعة للمتابعة واستقبال استفساراتك.",
                notification_type='SYSTEM_UPDATE',
                metadata={'conversation_id': str(conv.id)}
            )

            # Audit Log
            AuditLog.objects.create(
                user=user,
                action='DOCTOR_UNLOCKED_CHAT_WINDOW',
                details={'conversation_id': str(conv.id), 'hours': hours, 'patient_id': str(conv.patient.id)}
            )

            msg = f"تم فتح المحادثة للمريض بنجاح لمدة {hours} ساعة."
        else:
            conv.doctor_unlocked_until = None
            conv.save(update_fields=['doctor_unlocked_until'])

            AuditLog.objects.create(
                user=user,
                action='DOCTOR_LOCKED_CHAT_WINDOW',
                details={'conversation_id': str(conv.id), 'patient_id': str(conv.patient.id)}
            )

            msg = "تم إعادة قفل المحادثة للمريض."

        window_status = get_chat_window_status(conv.patient, conv.doctor, conv.patient.user, conversation=conv)

        return Response({
            'success': True,
            'message': msg,
            'conversation': ConversationSerializer(conv, context={'request': request}).data,
            'window_status': window_status,
            **window_status
        }, status=status.HTTP_200_OK)


