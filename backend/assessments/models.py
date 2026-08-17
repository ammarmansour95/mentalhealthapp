from django.db import models
from core.models import TimeStampedModel
from patients.models import PatientProfile


class AssessmentDefinition(TimeStampedModel):
    CATEGORY_CHOICES = (
        ('DEPRESSION', 'Depression (الاكتئاب)'),
        ('ANXIETY', 'Anxiety (القلق)'),
        ('STRESS', 'Stress (التوتر والضغط النفسي)'),
        ('GENERAL', 'General Wellness (الصحة العامة)'),
    )

    code = models.CharField(max_length=32, unique=True, db_index=True)
    title_en = models.CharField(max_length=256)
    title_ar = models.CharField(max_length=256)
    description_en = models.TextField(blank=True)
    description_ar = models.TextField(blank=True)
    category = models.CharField(max_length=32, choices=CATEGORY_CHOICES, default='GENERAL')
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.code} - {self.title_ar} ({self.title_en})"


class AssessmentQuestion(TimeStampedModel):
    assessment = models.ForeignKey(
        AssessmentDefinition,
        on_delete=models.CASCADE,
        related_name='questions'
    )
    order = models.PositiveIntegerField(default=1)
    text_en = models.TextField()
    text_ar = models.TextField()

    class Meta:
        ordering = ['assessment', 'order']

    def __str__(self):
        return f"[{self.assessment.code}] Q{self.order}: {self.text_en[:40]}..."


class AssessmentOption(TimeStampedModel):
    question = models.ForeignKey(
        AssessmentQuestion,
        on_delete=models.CASCADE,
        related_name='options'
    )
    score_value = models.IntegerField(default=0)
    label_en = models.CharField(max_length=128)
    label_ar = models.CharField(max_length=128)

    class Meta:
        ordering = ['score_value']

    def __str__(self):
        return f"Q{self.question.order} Option ({self.score_value}): {self.label_ar}"


class PatientAssessmentSubmission(TimeStampedModel):
    SEVERITY_CHOICES = (
        ('MINIMAL', 'Minimal / None (طبيعي / طفيف)'),
        ('MILD', 'Mild (بسيط)'),
        ('MODERATE', 'Moderate (متوسط)'),
        ('MODERATELY_SEVERE', 'Moderately Severe (شديد نسبياً)'),
        ('SEVERE', 'Severe (شديد)'),
    )

    patient = models.ForeignKey(
        PatientProfile,
        on_delete=models.CASCADE,
        related_name='assessment_submissions'
    )
    assessment = models.ForeignKey(
        AssessmentDefinition,
        on_delete=models.CASCADE,
        related_name='submissions'
    )
    total_score = models.PositiveIntegerField(default=0)
    severity_level = models.CharField(max_length=32, choices=SEVERITY_CHOICES, default='MINIMAL')
    interpretation_en = models.TextField(blank=True)
    interpretation_ar = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.patient.user.email} - {self.assessment.code}: Score {self.total_score} ({self.severity_level})"


class AssessmentAnswer(TimeStampedModel):
    submission = models.ForeignKey(
        PatientAssessmentSubmission,
        on_delete=models.CASCADE,
        related_name='answers'
    )
    question = models.ForeignKey(
        AssessmentQuestion,
        on_delete=models.CASCADE
    )
    selected_option = models.ForeignKey(
        AssessmentOption,
        on_delete=models.CASCADE
    )
    score = models.IntegerField(default=0)

    def __str__(self):
        return f"Submission {self.submission.id} - Q{self.question.order}: {self.score}"
