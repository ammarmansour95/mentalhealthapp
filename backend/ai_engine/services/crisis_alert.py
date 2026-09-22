import logging
from django.utils import timezone
from django.contrib.auth import get_user_model
from core.models import Notification, AuditLog
from ai_engine.models import AIReport

logger = logging.getLogger(__name__)
User = get_user_model()


def trigger_patient_crisis_alert(patient, session, trigger_message: str):
    """
    Emergency clinical intervention protocol:
    Dispatches instant CRISIS_ALERT notifications to Admins and Doctors,
    and ensures an emergency HIGH-risk AI report is recorded for clinical oversight.
    """
    try:
        patient_name = patient.user.get_full_name() or patient.user.email
        patient_phone = getattr(patient.user, 'phone_number', '') or 'غير مسجل'
        clean_trigger = trigger_message.strip()[:200]

        # 1. Deduplicate: avoid spamming multiple alerts in the same 10-minute window for the same session
        recent_cutoff = timezone.now() - timezone.timedelta(minutes=10)
        already_alerted = Notification.objects.filter(
            notification_type='CRISIS_ALERT',
            metadata__session_id=str(session.id),
            created_at__gte=recent_cutoff
        ).exists()

        if already_alerted:
            logger.info(f"Crisis alert already dispatched recently for session {session.id}")
            return

        # 2. Determine recipients:
        # A) All System Admins
        # B) Doctors who have appointments with this patient (assigned doctors)
        # C) All active verified Doctors (psychiatrists & psychologists)
        recipients = set()
        for admin in User.objects.filter(role='ADMIN', is_active=True):
            recipients.add(admin)

        # Assigned doctors from appointments
        assigned_doc_users = User.objects.filter(
            doctor_profile__appointments__patient=patient,
            is_active=True
        )
        for doc_user in assigned_doc_users:
            recipients.add(doc_user)

        # All verified active doctors
        for doc_user in User.objects.filter(role='DOCTOR', is_active=True, doctor_profile__is_verified=True):
            recipients.add(doc_user)

        # Fallback: If no doctors are verified yet, alert all active doctors
        if not any(u.role == 'DOCTOR' for u in recipients):
            for doc_user in User.objects.filter(role='DOCTOR', is_active=True):
                recipients.add(doc_user)

        # 3. Create Notification for each recipient
        title = "🚨 تنبيه طوارئ حرج: رصد مؤشرات انتحار أو إيذاء النفس"
        message = (
            f"تنبيه سريري عاجل: المريض {patient_name} (رقم الهاتف: {patient_phone}) "
            f"أطلق إشارات خطر فورية ورغبة في إيذاء النفس أثناء المحادثة السريرية: «{clean_trigger}». "
            f"يرجى اتخاذ الإجراء الطبي العاجل والاطلاع على التقرير السريري."
        )
        metadata = {
            'patient_id': str(patient.id),
            'patient_name': patient_name,
            'patient_phone': patient_phone,
            'session_id': str(session.id),
            'trigger_text': clean_trigger,
            'severity': 'CRITICAL',
            'urgency': 'IMMEDIATE_ACTION_REQUIRED'
        }

        notifications_to_create = [
            Notification(
                recipient=u,
                title=title,
                message=message,
                notification_type='CRISIS_ALERT',
                metadata=metadata
            )
            for u in recipients
        ]
        if notifications_to_create:
            Notification.objects.bulk_create(notifications_to_create)
            logger.warning(f"🚨 Dispatched CRISIS_ALERT to {len(notifications_to_create)} recipients for patient {patient_name}")

            # Dispatch emergency SMS alerts to doctors and admins
            from core.sms_service import send_emergency_crisis_sms
            for u in recipients:
                if u.phone_number:
                    try:
                        send_emergency_crisis_sms(
                            phone_number=u.phone_number,
                            patient_name=patient_name,
                            trigger_text=clean_trigger
                        )
                    except Exception as sms_err:
                        logger.warning(f"Could not send crisis SMS to {u.phone_number}: {sms_err}")

        # 4. Auto-create or escalate an Emergency AIReport
        report = AIReport.objects.filter(interview_session=session).first()
        emergency_summary_ar = (
            f"🚨 تنبيه طوارئ سريرية حرجة (Immediate Safety Intervention):\n"
            f"تم رصد إشارات خطر فورية وأفكار إيذاء نفس أو رغبة بالانتحار صادرة عن المريض أثناء المحادثة السريرية المباشرة:\n"
            f"«{clean_trigger}»\n\n"
            f"المريض: {patient_name} | هاتف: {patient_phone}\n\n"
            f"التوصية الطبية العاجلة:\n"
            f"• تحويل الحالة فوراً إلى طبيب نفسي مناوب (On-call Psychiatrist).\n"
            f"• التحقق من سلامة المريض عبر الاتصال المباشر بخط الطوارئ أو مرافقيه.\n"
            f"• تفعيل بروتوكول منع إيذاء النفس الإكلينيكي المعتمد."
        )

        emergency_summary_en = (
            f"CRITICAL CLINICAL EMERGENCY ALERT:\n"
            f"Direct suicide or self-harm ideation expressed during clinical intake: '{clean_trigger}'.\n"
            f"Immediate psychiatric intervention and safety protocol required."
        )

        if not report:
            AIReport.objects.create(
                patient=patient,
                interview_session=session,
                summary_ar_encrypted=emergency_summary_ar,
                summary_en_encrypted=emergency_summary_en,
                primary_indicators=[{
                    'category': 'CRISIS_EMERGENCY',
                    'label_ar': 'أفكار انتحار أو إيذاء النفس (Suicidal Ideation)',
                    'detected_keywords': ['إشارات خطر فورية'],
                    'similarity': 1.0,
                    'severity': 'HIGH'
                }],
                preliminary_risk_level='HIGH',
                recommended_specialty='PSYCHIATRY',
                recommendation_reason_ar='رصد مؤشرات إيذاء نفس أو انتحار صريحة - تتطلب تدخلاً طبياً ونفسياً عاجلاً وفورياً.',
                recommendation_reason_en='Explicit self-harm or suicidal ideation detected. Urgent psychiatric intervention required.',
                safety_warning_triggered=True
            )
        else:
            report.preliminary_risk_level = 'HIGH'
            report.safety_warning_triggered = True
            report.recommended_specialty = 'PSYCHIATRY'
            report.save()

        # 5. Audit Log
        AuditLog.objects.create(
            user=patient.user,
            action='CRISIS_SAFETY_PROTOCOL_ACTIVATED',
            details={
                'patient_id': str(patient.id),
                'session_id': str(session.id),
                'recipients_count': len(notifications_to_create),
                'severity': 'HIGH'
            }
        )
    except Exception as e:
        logger.error(f"Error triggering patient crisis alert: {e}", exc_info=True)
