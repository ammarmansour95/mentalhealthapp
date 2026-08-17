import uuid
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models


class UserManager(BaseUserManager):
    """Custom manager for email-based or username-based authentication."""
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('The Email field must be set')
        email = self.normalize_email(email)
        extra_fields.setdefault('username', email)
        user = self.model(email=email, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', 'ADMIN')
        extra_fields.setdefault('status', 'ACTIVE')
        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    ROLE_CHOICES = (
        ('PATIENT', 'Patient'),
        ('DOCTOR', 'Doctor'),
        ('ADMIN', 'Administrator'),
    )

    STATUS_CHOICES = (
        ('PENDING', 'Pending Verification'),
        ('ACTIVE', 'Active'),
        ('SUSPENDED', 'Suspended'),
        ('REJECTED', 'Rejected'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True, db_index=True)
    role = models.CharField(max_length=16, choices=ROLE_CHOICES, default='PATIENT', db_index=True)
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default='ACTIVE', db_index=True)
    phone_number = models.CharField(max_length=32, blank=True, null=True)
    firebase_uid = models.CharField(max_length=128, blank=True, null=True, unique=True, db_index=True)
    preferred_language = models.CharField(max_length=8, default='ar', choices=(('ar', 'Arabic'), ('en', 'English')))
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    def __str__(self):
        return f"{self.get_full_name() or self.email} ({self.role})"
