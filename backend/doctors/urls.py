from django.urls import path
from doctors.views import (
    DoctorListView,
    DoctorDetailView,
    DoctorProfileMeView,
    DoctorQualificationUploadView,
    DoctorQualificationDocumentStreamView,
    DoctorAvailabilityManageView,
    DoctorBookedSlotsView,
    AdminVerifyDoctorView
)

urlpatterns = [
    path('', DoctorListView.as_view(), name='doctor-list'),
    path('profile/me/', DoctorProfileMeView.as_view(), name='doctor-profile-me'),
    path('<uuid:pk>/', DoctorDetailView.as_view(), name='doctor-detail'),
    path('<uuid:pk>/booked-slots/', DoctorBookedSlotsView.as_view(), name='doctor-booked-slots'),
    path('qualifications/upload/', DoctorQualificationUploadView.as_view(), name='doctor-qual-upload'),
    path('qualifications/<int:pk>/document/', DoctorQualificationDocumentStreamView.as_view(), name='doctor-qual-document'),
    path('availability/', DoctorAvailabilityManageView.as_view(), name='doctor-availability'),
    path('<uuid:pk>/verify/', AdminVerifyDoctorView.as_view(), name='admin-verify-doctor'),
]

