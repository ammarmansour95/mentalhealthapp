from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import permissions, status
from accounts.models import User
from patients.models import PatientProfile
from doctors.models import DoctorProfile, DoctorQualification
from appointments.models import Appointment
from assessments.models import PatientAssessmentSubmission
from ai_engine.models import AIInterviewSession, AIReport
from core.models import AuditLog
from core.permissions import IsAdminUserRole
from doctors.serializers import DoctorProfileSerializer


class AdminPlatformMetricsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUserRole]

    def get(self, request):
        total_patients = PatientProfile.objects.count()
        total_doctors = DoctorProfile.objects.count()
        verified_doctors = DoctorProfile.objects.filter(is_verified=True).count()
        pending_doctors = DoctorProfile.objects.filter(is_verified=False).count()

        total_appointments = Appointment.objects.count()
        completed_appointments = Appointment.objects.filter(status='COMPLETED').count()

        total_assessments = PatientAssessmentSubmission.objects.count()
        total_ai_sessions = AIInterviewSession.objects.count()
        total_ai_reports = AIReport.objects.count()

        high_risk_reports = AIReport.objects.filter(preliminary_risk_level='HIGH').count()
        moderate_risk_reports = AIReport.objects.filter(preliminary_risk_level='MODERATE').count()
        low_risk_reports = AIReport.objects.filter(preliminary_risk_level='LOW').count()

        return Response({
            'success': True,
            'metrics': {
                'users': {
                    'total_patients': total_patients,
                    'total_doctors': total_doctors,
                    'verified_doctors': verified_doctors,
                    'pending_verification_doctors': pending_doctors,
                },
                'clinical_and_ai': {
                    'total_assessments_taken': total_assessments,
                    'total_ai_interviews': total_ai_sessions,
                    'total_ai_reports': total_ai_reports,
                    'risk_breakdown': {
                        'high': high_risk_reports,
                        'moderate': moderate_risk_reports,
                        'low': low_risk_reports
                    }
                },
                'appointments': {
                    'total_booked': total_appointments,
                    'completed': completed_appointments,
                }
            }
        })


class AdminPendingDoctorsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUserRole]

    def get(self, request):
        pending = DoctorProfile.objects.filter(is_verified=False)
        return Response({
            'success': True,
            'pending_doctors': DoctorProfileSerializer(pending, many=True).data
        })


class AdminAuditLogsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUserRole]

    def get(self, request):
        logs = AuditLog.objects.all()[:50]
        data = [
            {
                'id': str(l.id),
                'action': l.action,
                'action_display': l.get_action_display(),
                'user': l.user.email if l.user else 'System',
                'ip_address': l.ip_address,
                'details': l.details,
                'created_at': l.created_at
            }
            for l in logs
        ]
        return Response({'success': True, 'logs': data})
