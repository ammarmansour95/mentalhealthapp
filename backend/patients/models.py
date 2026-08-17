from django.db import models
from django.conf import settings
from core.models import TimeStampedModel
from core.encryption import EncryptedTextField


class PatientProfile(TimeStampedModel):
    GENDER_CHOICES = (
        ('MALE', 'Male'),
        ('FEMALE', 'Female'),
        ('OTHER', 'Other'),
        ('PREFER_NOT_TO_SAY', 'Prefer not to say'),
    )

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='patient_profile'
    )
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=24, choices=GENDER_CHOICES, default='PREFER_NOT_TO_SAY')
    emergency_contact_name = models.CharField(max_length=128, blank=True)
    emergency_contact_phone = models.CharField(max_length=32, blank=True)
    
    # Sensitive Health Information Encrypted at Rest (AES-256)
    medical_history_encrypted = EncryptedTextField(blank=True, default='')
    current_medications_encrypted = EncryptedTextField(blank=True, default='')
    allergies = models.CharField(max_length=256, blank=True)
    notes_encrypted = EncryptedTextField(blank=True, default='')

    def __str__(self):
        return f"Patient: {self.user.get_full_name() or self.user.email}"
