import jwt
import datetime
from django.conf import settings
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from accounts.models import User


def generate_jwt_token(user: User) -> str:
    """Generates a standard JWT token for the user."""
    payload = {
        'user_id': str(user.id),
        'email': user.email,
        'role': user.role,
        'status': user.status,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(days=7),
        'iat': datetime.datetime.utcnow()
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm='HS256')


class FirebaseOrJWTAuthentication(BaseAuthentication):
    """
    Unified Authentication backend supporting:
    1. Direct Bearer JWT Tokens signed by backend secret
    2. Firebase ID Tokens (optional server-side validation)
    """
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return None

        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            return None

        token = parts[1]

        # 1. Try decoding standard JWT
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=['HS256'])
            user_id = payload.get('user_id')
            user = User.objects.filter(id=user_id).first()
            if not user:
                raise AuthenticationFailed('User not found.')
            if user.status in ['SUSPENDED', 'REJECTED']:
                raise AuthenticationFailed('This user account is not active.')
            return (user, token)
        except jwt.ExpiredSignatureError:
            raise AuthenticationFailed('Authentication token has expired.')
        except jwt.InvalidTokenError:
            pass

        # 2. Check if it is a Firebase UID token simulation / header
        firebase_user = User.objects.filter(firebase_uid=token).first()
        if firebase_user:
            return (firebase_user, token)

        raise AuthenticationFailed('Invalid authentication token.')
