import logging
from typing import Dict, Any, Optional
from django.contrib.auth import get_user_model
from django.utils import timezone
from core.models import Notification

logger = logging.getLogger(__name__)
User = get_user_model()


def send_notification(
    recipient,
    title: str,
    message: str,
    notification_type: str,
    metadata: Optional[Dict[str, Any]] = None
) -> Optional[Notification]:
    """Creates a notification record in the database for the given recipient."""
    try:
        if not recipient:
            return None
        
        return Notification.objects.create(
            recipient=recipient,
            title=title,
            message=message,
            notification_type=notification_type,
            metadata=metadata or {}
        )
    except Exception as e:
        logger.error(f"Failed to create notification for {recipient}: {e}")
        return None


def notify_doctor_new_appointment(appointment):
    """Notifies the doctor when a patient books a new appointment slot (PENDING)."""
    doctor_user = getattr(appointment.doctor, 'user', None)
    patient_name = appointment.patient.user.get_full_name() if appointment.patient and appointment.patient.user else 'مريض'
    date_str = appointment.appointment_date.strftime('%Y-%m-%d')
    time_str = appointment.start_time.strftime('%H:%M')

    title = "طلب موعد جديد ⏳"
    message = f"قام المريض «{patient_name}» بطلب حجز موعد بتاريخ {date_str} الساعة {time_str}. يرجى مراجعة وتأكيد الموعد."
    
    return send_notification(
        recipient=doctor_user,
        title=title,
        message=message,
        notification_type='APPOINTMENT_REQUESTED',
        metadata={
            'appointment_id': str(appointment.id),
            'patient_id': str(appointment.patient.id),
            'date': date_str,
            'time': time_str,
        }
    )


def notify_appointment_status_change(appointment, new_status: str, cancelled_by=None, reason: str = ''):
    """Notifies patient or doctor when appointment status changes."""
    date_str = appointment.appointment_date.strftime('%Y-%m-%d')
    time_str = appointment.start_time.strftime('%H:%M')
    doctor_name = appointment.doctor.user.get_full_name() if appointment.doctor and appointment.doctor.user else 'طبيب'
    patient_name = appointment.patient.user.get_full_name() if appointment.patient and appointment.patient.user else 'مريض'

    if new_status == 'CONFIRMED':
        # Notify Patient
        title = "تم تأكيد موعدك بنجاح ✓"
        message = f"قام د. {doctor_name} بقبول وتأكيد موعد جلستك بتاريخ {date_str} الساعة {time_str}. نتمنى لك جلسة مثمرة ومفيدة."
        return send_notification(
            recipient=appointment.patient.user,
            title=title,
            message=message,
            notification_type='APPOINTMENT_CONFIRMED',
            metadata={'appointment_id': str(appointment.id), 'doctor_id': str(appointment.doctor.id)}
        )

    elif new_status == 'CANCELLED':
        if cancelled_by and getattr(cancelled_by, 'role', '') == 'PATIENT':
            # Patient cancelled -> Notify Doctor
            reason_snippet = f" - السبب: {reason}" if reason else ""
            title = "إشعار إلغاء موعد من قِبل المريض ⚠️"
            message = f"قام المريض «{patient_name}» بإلغاء موعده المحدد بتاريخ {date_str} الساعة {time_str}{reason_snippet}."
            return send_notification(
                recipient=appointment.doctor.user,
                title=title,
                message=message,
                notification_type='APPOINTMENT_CANCELLED',
                metadata={'appointment_id': str(appointment.id), 'cancelled_by': 'PATIENT', 'reason': reason}
            )
        else:
            # Doctor/Admin cancelled -> Notify Patient
            reason_snippet = f" (السبب: {reason})" if reason else ""
            title = "تم إلغاء الموعد 🚫"
            message = f"نعتذر منك، تم إلغاء موعدك مع د. {doctor_name} بتاريخ {date_str} الساعة {time_str}{reason_snippet}."
            return send_notification(
                recipient=appointment.patient.user,
                title=title,
                message=message,
                notification_type='APPOINTMENT_CANCELLED',
                metadata={'appointment_id': str(appointment.id), 'cancelled_by': 'DOCTOR', 'reason': reason}
            )


def notify_admins_new_doctor_application(doctor_profile):
    """Notifies all system administrators when a new doctor submits license credentials."""
    doctor_name = doctor_profile.user.get_full_name() if doctor_profile.user else 'طبيب جديد'
    specialty = doctor_profile.get_specialty_display() if hasattr(doctor_profile, 'get_specialty_display') else doctor_profile.specialty

    title = "طلب اعتماد طبيب جديد 🩺"
    message = f"قدّم د. {doctor_name} ({specialty}) وثائق الترخيص المهني للمراجعة والاعتماد."

    admin_users = User.objects.filter(role='ADMIN')
    notifications = []
    for admin in admin_users:
        n = send_notification(
            recipient=admin,
            title=title,
            message=message,
            notification_type='DOCTOR_APPLICATION_SUBMITTED',
            metadata={'doctor_id': str(doctor_profile.id), 'license': doctor_profile.license_number}
        )
        if n:
            notifications.append(n)
    return notifications


def notify_doctor_verification_result(doctor_profile, is_approved: bool, notes: str = ''):
    """Notifies the doctor when their license is approved or rejected by an admin."""
    if is_approved:
        title = "تهانينا! تم اعتماد حسابك المهني ✓"
        message = "تمت مراجعة ترخيصك الطبي وتصنيفك المهني بنجاح. حسابك الآن مفعل ويمكنك استقبال المواعيد والتواصل مع المرضى."
        n_type = 'DOCTOR_VERIFIED'
    else:
        title = "تنبيه: مراجعة وثائق الترخيص الطبي ⚠️"
        message = f"تعذر اعتماد الوثائق المقدمة حالياً. ملاحظات الإدارة: {notes or 'يرجى إعادة رفع صورة واضحة من وثيقة الترخيص سارية المفعول.'}"
        n_type = 'DOCTOR_REJECTED'

    return send_notification(
        recipient=doctor_profile.user,
        title=title,
        message=message,
        notification_type=n_type,
        metadata={'is_approved': is_approved}
    )


def generate_session_reminders():
    """Generates session reminder notifications for appointments occurring today."""
    from appointments.models import Appointment
    import datetime

    today = timezone.now().date()
    today_confirmed_appts = Appointment.objects.filter(
        appointment_date=today,
        status='CONFIRMED'
    )

    created_count = 0
    for appt in today_confirmed_appts:
        time_str = appt.start_time.strftime('%H:%M')
        doctor_name = appt.doctor.user.get_full_name()
        patient_name = appt.patient.user.get_full_name()

        # Check if reminder already sent today
        already_sent = Notification.objects.filter(
            recipient=appt.patient.user,
            notification_type='SESSION_REMINDER',
            metadata__appointment_id=str(appt.id),
            created_at__date=today
        ).exists()

        if not already_sent:
            # 1. Patient reminder
            send_notification(
                recipient=appt.patient.user,
                title="تذكير بموعد الجلسة اليوم ⏰",
                message=f"تذكير: موعد جلستك العلاجية مع د. {doctor_name} اليوم الساعة {time_str}. نتمنى لك جلسة مفيدة.",
                notification_type='SESSION_REMINDER',
                metadata={'appointment_id': str(appt.id)}
            )
            # 2. Doctor reminder
            send_notification(
                recipient=appt.doctor.user,
                title="تذكير بموعد جلسة اليوم ⏰",
                message=f"تذكير: موعد جلسة مع المريض «{patient_name}» اليوم الساعة {time_str}.",
                notification_type='SESSION_REMINDER',
                metadata={'appointment_id': str(appt.id)}
            )
            created_count += 2

    return created_count
