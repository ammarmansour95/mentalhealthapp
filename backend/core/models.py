import uuid
from django.db import models
from django.conf import settings


class TimeStampedModel(models.Model):
    """Abstract base model with auto-managed UUID primary key and timestamps."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class AuditLog(TimeStampedModel):
    """System-wide audit trail for compliance, security events, and doctor verification actions."""
    ACTION_CHOICES = (
        ('LOGIN', 'User Login'),
        ('LOGOUT', 'User Logout'),
        ('REGISTER', 'User Registration'),
        ('DOCTOR_VERIFY_APPROVED', 'Doctor Qualification Approved'),
        ('DOCTOR_VERIFY_REJECTED', 'Doctor Qualification Rejected'),
        ('ASSESSMENT_SUBMITTED', 'Assessment Submitted'),
        ('AI_INTERVIEW_COMPLETED', 'AI Interview Completed'),
        ('AI_REPORT_GENERATED', 'AI Preliminary Report Generated'),
        ('APPOINTMENT_BOOKED', 'Appointment Booked'),
        ('APPOINTMENT_CANCELLED', 'Appointment Cancelled'),
        ('TREATMENT_PLAN_UPDATED', 'Treatment Plan Updated'),
        ('UNAUTHORIZED_ACCESS_ATTEMPT', 'Unauthorized Access Attempt'),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='audit_logs'
    )
    action = models.CharField(max_length=64, choices=ACTION_CHOICES, db_index=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=512, blank=True)
    details = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        user_str = self.user.email if self.user else "Anonymous/System"
        return f"[{self.created_at.strftime('%Y-%m-%d %H:%M')}] {self.action} by {user_str}"
