from rest_framework.permissions import BasePermission
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status


class IsPatient(BasePermission):
    """Allows access only to authenticated users with role PATIENT."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.role == 'PATIENT')


class IsDoctor(BasePermission):
    """Allows access only to authenticated users with role DOCTOR."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.role == 'DOCTOR')


class IsVerifiedDoctor(BasePermission):
    """Allows access only to approved & verified doctors."""
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated and request.user.role == 'DOCTOR'):
            return False
        # Check doctor profile verification status
        doctor_profile = getattr(request.user, 'doctor_profile', None)
        return bool(doctor_profile and doctor_profile.is_verified)


class IsAdminUserRole(BasePermission):
    """Allows access only to users with role ADMIN or staff/superuser."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and (request.user.role == 'ADMIN' or request.user.is_staff))


def custom_exception_handler(exc, context):
    """Standardized JSON response envelope for errors across the platform."""
    response = exception_handler(exc, context)

    if response is not None:
        message = 'حدث خطأ في التحقق من البيانات.'
        if isinstance(response.data, dict):
            if 'detail' in response.data:
                message = str(response.data['detail'])
            elif 'non_field_errors' in response.data:
                first_err = response.data['non_field_errors']
                message = first_err[0] if isinstance(first_err, list) else str(first_err)
            else:
                first_key = next(iter(response.data))
                first_val = response.data[first_key]
                err_text = first_val[0] if isinstance(first_val, list) and len(first_val) > 0 else str(first_val)
                
                # Friendly Arabic translations
                if 'user with this email already exists' in err_text.lower():
                    message = 'هذا البريد الإلكتروني مسجل مسبقاً، يرجى تسجيل الدخول أو استخدام بريد آخر.'
                elif 'this field is required' in err_text.lower():
                    message = f'حقل ({first_key}) مطلوب ولا يمكن تركه فارغاً.'
                elif 'at least 6 characters' in err_text.lower() or 'at least 8 characters' in err_text.lower():
                    message = 'كلمة المرور يجب أن لا تقل عن 6 خانات.'
                elif 'invalid email' in err_text.lower():
                    message = 'البريد الإلكتروني غير صالح.'
                else:
                    message = f"{first_key}: {err_text}"

        # General auth error translations
        if message == 'Invalid email or password.':
            message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.'

        custom_data = {
            'success': False,
            'error_type': exc.__class__.__name__,
            'status_code': response.status_code,
            'message': message,
            'errors': response.data
        }
        response.data = custom_data

    return response
