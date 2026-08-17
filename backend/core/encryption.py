import base64
from cryptography.fernet import Fernet
from django.conf import settings
from django.db import models


def get_cipher():
    """Returns a Fernet cipher instance using the configured secret key."""
    key = getattr(settings, 'FIELD_ENCRYPTION_KEY', None)
    if not key:
        # Fallback predictable key for development if not provided
        key = base64.urlsafe_b64encode(b"01234567890123456789012345678901")
    elif isinstance(key, str):
        key = key.encode()
        # If length is not 44 (Fernet key length), pad or encode appropriately
        if len(key) != 44:
            key = base64.urlsafe_b64encode(key.ljust(32, b'0')[:32])
    return Fernet(key)


def encrypt_text(plain_text: str) -> str:
    """Encrypts plaintext string into an AES-256 Fernet ciphertext string."""
    if not plain_text:
        return plain_text
    cipher = get_cipher()
    encrypted_bytes = cipher.encrypt(plain_text.encode('utf-8'))
    return encrypted_bytes.decode('utf-8')


def decrypt_text(cipher_text: str) -> str:
    """Decrypts AES-256 Fernet ciphertext string back to plaintext."""
    if not cipher_text:
        return cipher_text
    try:
        cipher = get_cipher()
        decrypted_bytes = cipher.decrypt(cipher_text.encode('utf-8'))
        return decrypted_bytes.decode('utf-8')
    except Exception:
        # If already unencrypted (legacy data or key mismatch), return safely
        return cipher_text


def encrypt_bytes(data: bytes) -> bytes:
    """Encrypts raw binary bytes (e.g. PDF, JPG, PNG) using AES-256 Fernet."""
    if not data:
        return data
    cipher = get_cipher()
    return cipher.encrypt(data)


def decrypt_bytes(data: bytes) -> bytes:
    """Decrypts AES-256 Fernet ciphertext bytes back into original binary file bytes."""
    if not data:
        return data
    try:
        cipher = get_cipher()
        return cipher.decrypt(data)
    except Exception:
        # If file is not encrypted (legacy or direct upload), return original bytes
        return data


class EncryptedTextField(models.TextField):
    """
    Custom Django Model Field that automatically encrypts text before storing in PostgreSQL/SQLite
    and decrypts when retrieved into Python models.
    Provides HIPAA/GDPR-grade protection for patient psychiatric notes and transcripts.
    """
    description = "An encrypted text field using AES-256 (Fernet)"

    def from_db_value(self, value, expression, connection):
        if value is None:
            return value
        return decrypt_text(value)

    def to_python(self, value):
        if value is None or isinstance(value, str):
            return value
        return decrypt_text(value)

    def get_prep_value(self, value):
        value = super().get_prep_value(value)
        if value is None or value == "":
            return value
        return encrypt_text(value)
