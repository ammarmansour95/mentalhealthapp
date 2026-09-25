from django.db import models
from django.conf import settings
from core.models import TimeStampedModel
from core.encryption import EncryptedTextField
from patients.models import PatientProfile
from doctors.models import DoctorProfile


class Conversation(TimeStampedModel):
    patient = models.ForeignKey(
        PatientProfile,
        on_delete=models.CASCADE,
        related_name='conversations'
    )
    doctor = models.ForeignKey(
        DoctorProfile,
        on_delete=models.CASCADE,
        related_name='conversations'
    )
    is_active = models.BooleanField(default=True)
    doctor_unlocked_until = models.DateTimeField(null=True, blank=True, help_text="Doctor manual chat unlock expiration time for the patient")

    class Meta:
        unique_together = ('patient', 'doctor')
        ordering = ['-updated_at']

    def __str__(self):
        return f"Conversation: {self.patient.user.get_full_name()} & Dr. {self.doctor.user.get_full_name()}"


class Message(TimeStampedModel):
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='messages'
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_messages'
    )
    
    # Message content encrypted at rest (AES-256)
    content_encrypted = EncryptedTextField()
    attachment = models.FileField(upload_to='chat_attachments/', blank=True, null=True)
    is_emergency = models.BooleanField(default=False, db_index=True, help_text="Emergency bypass flag used outside appointment window")
    emergency_reason = models.TextField(blank=True, default='')
    is_read = models.BooleanField(default=False, db_index=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"Message from {self.sender.email} at {self.created_at}"
