from django.db import models
from django.conf import settings
from core.models import TimeStampedModel
from core.encryption import EncryptedTextField
from patients.models import PatientProfile
from doctors.models import DoctorProfile


class Appointment(TimeStampedModel):
    STATUS_CHOICES = (
        ('PENDING', 'Pending Confirmation'),
        ('CONFIRMED', 'Confirmed'),
        ('COMPLETED', 'Completed'),
        ('CANCELLED', 'Cancelled'),
        ('NO_SHOW', 'No Show'),
    )

    patient = models.ForeignKey(
        PatientProfile,
        on_delete=models.CASCADE,
        related_name='appointments'
    )
    doctor = models.ForeignKey(
        DoctorProfile,
        on_delete=models.CASCADE,
        related_name='appointments'
    )
    appointment_date = models.DateField(db_index=True)
    start_time = models.TimeField()
    end_time = models.TimeField()
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default='CONFIRMED', db_index=True)
    patient_notes = models.TextField(blank=True, help_text="Reason for visit provided by patient")
    
    # Doctor's private medical session notes (Encrypted at Rest)
    session_notes_encrypted = EncryptedTextField(blank=True, default='')

    cancellation_reason = models.TextField(blank=True)
    cancelled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='cancelled_appointments'
    )

    class Meta:
        ordering = ['appointment_date', 'start_time']
        # Prevent double-booking for the same doctor at the same date and time (BR-006)
        constraints = [
            models.UniqueConstraint(
                fields=['doctor', 'appointment_date', 'start_time'],
                condition=models.Q(status__in=['PENDING', 'CONFIRMED']),
                name='unique_doctor_active_appointment_slot'
            )
        ]

    def __str__(self):
        return f"Appointment: {self.patient.user.get_full_name()} with Dr. {self.doctor.user.get_full_name()} on {self.appointment_date} at {self.start_time}"
