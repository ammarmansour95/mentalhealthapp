from django.db import models
from core.models import TimeStampedModel
from core.encryption import EncryptedTextField
from patients.models import PatientProfile
from doctors.models import DoctorProfile


class TreatmentPlan(TimeStampedModel):
    STATUS_CHOICES = (
        ('ACTIVE', 'Active (قيد التنفيذ)'),
        ('COMPLETED', 'Completed (مكتملة)'),
        ('PAUSED', 'Paused (موقوفة مؤقتاً)'),
    )

    patient = models.ForeignKey(
        PatientProfile,
        on_delete=models.CASCADE,
        related_name='treatment_plans'
    )
    doctor = models.ForeignKey(
        DoctorProfile,
        on_delete=models.CASCADE,
        related_name='created_treatment_plans'
    )
    title = models.CharField(max_length=256, default='خطة الرعاية والمتابعة النفسية')
    
    # Diagnosis summary and treatment approach encrypted at rest
    diagnosis_summary_encrypted = EncryptedTextField(blank=True, default='')
    clinical_notes_encrypted = EncryptedTextField(blank=True, default='')

    start_date = models.DateField(auto_now_add=True)
    review_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default='ACTIVE', db_index=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Treatment Plan for {self.patient.user.get_full_name()} by Dr. {self.doctor.user.get_full_name()}"


class TreatmentGoal(TimeStampedModel):
    plan = models.ForeignKey(
        TreatmentPlan,
        on_delete=models.CASCADE,
        related_name='goals'
    )
    title = models.CharField(max_length=256)
    description = models.TextField(blank=True)
    target_date = models.DateField(null=True, blank=True)
    is_completed = models.BooleanField(default=False)
    order = models.PositiveIntegerField(default=1)

    class Meta:
        ordering = ['order', 'created_at']

    def __str__(self):
        return f"Goal {self.order}: {self.title} [{'Done' if self.is_completed else 'Pending'}]"


class ProgressRecord(TimeStampedModel):
    patient = models.ForeignKey(
        PatientProfile,
        on_delete=models.CASCADE,
        related_name='progress_records'
    )
    plan = models.ForeignKey(
        TreatmentPlan,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='progress_records'
    )
    mood_score = models.IntegerField(help_text="Mood score from 1 (Very Low) to 10 (Excellent)")
    sleep_hours = models.DecimalField(max_digits=4, decimal_places=1, default=7.0)
    anxiety_level = models.IntegerField(default=1, help_text="1 (None) to 5 (Severe)")
    
    notes_encrypted = EncryptedTextField(blank=True, default='')
    log_date = models.DateField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-log_date', '-created_at']

    def __str__(self):
        return f"Progress {self.patient.user.email} on {self.log_date}: Mood {self.mood_score}/10"
