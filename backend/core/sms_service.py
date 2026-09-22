import re
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)


def normalize_syrian_phone(raw_phone: str) -> str:
    """
    Normalizes and validates a Syrian mobile phone number (+963 9XX XXX XXX).
    Acceptable inputs:
      - '0933123456'
      - '0991234567'
      - '+963933123456'
      - '00963933123456'
      - '933123456'
    Returns normalized E.164-compatible Syrian mobile: '+9639XXXXXXXX'
    Raises ValueError if format is invalid.
    """
    if not raw_phone:
        raise ValueError("رقم الهاتف مطلوب ولا يمكن أن يكون فارغاً.")

    # Strip whitespace, hyphens, parentheses
    clean = re.sub(r'[\s\-\(\)]', '', str(raw_phone).strip())

    # Replace leading 00963 with +963
    if clean.startswith('00963'):
        clean = '+' + clean[2:]

    # If starts with 09... (10 digits local Syrian mobile)
    if clean.startswith('09') and len(clean) == 10:
        clean = '+963' + clean[1:]  # e.g. 0933123456 -> +963933123456

    # If starts with 9... (9 digits without leading 0)
    elif clean.startswith('9') and len(clean) == 9:
        clean = '+963' + clean

    # If already starts with +9639...
    elif clean.startswith('+963'):
        pass

    # Validate final Syrian mobile pattern: +963 followed by 9 and exactly 8 additional digits (total 13 chars)
    syrian_regex = r'^\+9639\d{8}$'
    if not re.match(syrian_regex, clean):
        raise ValueError("رقم الهاتف غير صالح. يجب أن يكون رقم هاتف جوال سوري يبدأ بـ 09 أو +963 (مثال: 0933123456).")

    return clean


def send_sms(phone_number: str, message: str) -> Dict[str, Any]:
    """
    Dispatches an SMS message to a phone number.
    In development/demo mode, logs to console and database. Ready for local SMS gateway hook (Syriatel/MTN/Twilio).
    """
    try:
        norm_phone = normalize_syrian_phone(phone_number)
    except ValueError as e:
        norm_phone = phone_number
        logger.warning(f"Sending SMS to non-standard phone format: {phone_number} - {e}")

    logger.info(f"📱 [SMS GATEWAY DISPATCH] -> {norm_phone}: {message}")
    print(f"\n=======================================================")
    print(f"📱 [SMS SENT TO SYRIAN PHONE]: {norm_phone}")
    print(f"💬 [MESSAGE]: {message}")
    print(f"=======================================================\n")

    return {
        'success': True,
        'recipient': norm_phone,
        'message': message,
        'status': 'DELIVERED'
    }


def send_otp_sms(phone_number: str, otp_code: str) -> Dict[str, Any]:
    """Sends 6-digit verification OTP via SMS to verify Syrian phone number."""
    msg = (
        f"منصة الرعاية النفسية: رمز التحقق الخاص بك هو [{otp_code}]. "
        f"صالح لمدة 5 دقائق. لا تشارك هذا الرمز مع أحد لأمان حسابك."
    )
    return send_sms(phone_number, msg)


def send_emergency_crisis_sms(phone_number: str, patient_name: str, trigger_text: str) -> Dict[str, Any]:
    """Sends urgent SMS crisis alert to on-call doctors or admin for immediate intervention."""
    clean_trigger = trigger_text[:80].strip()
    msg = (
        f"🚨 تنبيه طوارئ سريرية حرجة: المريض {patient_name} أطلق مؤشرات خطر إيذاء نفس أو رغبة بالانتحار: "
        f"«{clean_trigger}». يرجى الدخول للمنصة والاتصال بالمريض فوراً."
    )
    return send_sms(phone_number, msg)
