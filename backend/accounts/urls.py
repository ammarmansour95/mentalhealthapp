from django.urls import path
from accounts.views import (
    RegisterView, LoginView, MeView, FirebaseSyncView,
    SendPhoneOTPView, VerifyPhoneOTPView
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='auth-register'),
    path('login/', LoginView.as_view(), name='auth-login'),
    path('me/', MeView.as_view(), name='auth-me'),
    path('firebase-sync/', FirebaseSyncView.as_view(), name='auth-firebase-sync'),
    path('phone/send-otp/', SendPhoneOTPView.as_view(), name='auth-phone-send-otp'),
    path('phone/verify-otp/', VerifyPhoneOTPView.as_view(), name='auth-phone-verify-otp'),
]
