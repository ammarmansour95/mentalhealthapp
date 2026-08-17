from django.db import models
from django.conf import settings
from core.models import TimeStampedModel


class DoctorProfile(TimeStampedModel):
    SPECIALTY_CHOICES = (
        ('CLINICAL_PSYCHOLOGY', 'Clinical Psychology (علاج نفسي إكلينيكي)'),
        ('PSYCHIATRY', 'Psychiatry (طب نفسي)'),
        ('CBT_SPECIALIST', 'Cognitive Behavioral Therapy - CBT (علاج سلوكي معرفي)'),
        ('CHILD_ADOLESCENT', 'Child & Adolescent Psychology (طب نفسي للأطفال والمراهقين)'),
        ('ANXIETY_MOOD', 'Anxiety & Mood Disorders (اضطرابات القلق والمزاج)'),
        ('TRAUMA_PTSD', 'Trauma & PTSD (الصدمات النفسية)'),
        ('FAMILY_COUNSELING', 'Family & Relationship Counseling (إرشاد أسري وزوجي)'),
        ('ADDICTION', 'Addiction Rehabilitation (علاج الإدمان)'),
    )

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='doctor_profile'
    )
    title = models.CharField(max_length=64, default='Dr.', help_text="e.g. Dr., Consultant, Specialist")
    specialty = models.CharField(max_length=64, choices=SPECIALTY_CHOICES, default='CLINICAL_PSYCHOLOGY', db_index=True)
    license_number = models.CharField(max_length=64, blank=True)
    years_of_experience = models.PositiveIntegerField(default=0)
    bio = models.TextField(blank=True)
    consultation_fee = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    
    # Verification Pipeline (BR-001)
    is_verified = models.BooleanField(default=False, db_index=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='verified_doctors'
    )
    rejection_reason = models.TextField(blank=True)

    # Ratings & Stats
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=5.00)
    total_reviews = models.PositiveIntegerField(default=0)

    def __str__(self):
        return f"{self.title} {self.user.get_full_name() or self.user.email} - {self.get_specialty_display()}"


class DoctorQualification(TimeStampedModel):
    STATUS_CHOICES = (
        ('PENDING', 'Pending Review'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
    )

    doctor = models.ForeignKey(
        DoctorProfile,
        on_delete=models.CASCADE,
        related_name='qualifications'
    )
    degree_title = models.CharField(max_length=256)
    institution_name = models.CharField(max_length=256)
    graduation_year = models.PositiveIntegerField(null=True, blank=True)
    document_file = models.FileField(upload_to='doctor_qualifications/', blank=True, null=True)
    verification_status = models.CharField(max_length=16, choices=STATUS_CHOICES, default='PENDING', db_index=True)
    admin_notes = models.TextField(blank=True)

    def __str__(self):
        return f"{self.degree_title} ({self.institution_name}) - {self.doctor.user.get_full_name()}"


class DoctorAvailability(TimeStampedModel):
    DAY_CHOICES = (
        (0, 'Monday (الاثنين)'),
        (1, 'Tuesday (الثلاثاء)'),
        (2, 'Wednesday (الأربعاء)'),
        (3, 'Thursday (الخميس)'),
        (4, 'Friday (الجمعة)'),
        (5, 'Saturday (السبت)'),
        (6, 'Sunday (الأحد)'),
    )

    doctor = models.ForeignKey(
        DoctorProfile,
        on_delete=models.CASCADE,
        related_name='availabilities'
    )
    day_of_week = models.IntegerField(choices=DAY_CHOICES, db_index=True)
    start_time = models.TimeField()
    end_time = models.TimeField()
    slot_duration_minutes = models.PositiveIntegerField(default=45)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['day_of_week', 'start_time']

    def __str__(self):
        return f"{self.doctor.user.get_full_name()} - Day {self.day_of_week}: {self.start_time} to {self.end_time}"
