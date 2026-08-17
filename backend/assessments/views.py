from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from assessments.models import AssessmentDefinition, PatientAssessmentSubmission
from assessments.serializers import (
    AssessmentDefinitionSerializer,
    AssessmentSubmitSerializer,
    PatientAssessmentSubmissionSerializer
)
from core.permissions import IsPatient
from core.models import AuditLog


class AssessmentListView(generics.ListAPIView):
    queryset = AssessmentDefinition.objects.filter(is_active=True)
    serializer_class = AssessmentDefinitionSerializer
    permission_classes = [permissions.IsAuthenticated]


class AssessmentDetailView(generics.RetrieveAPIView):
    queryset = AssessmentDefinition.objects.filter(is_active=True)
    serializer_class = AssessmentDefinitionSerializer
    lookup_field = 'code'
    permission_classes = [permissions.IsAuthenticated]


class AssessmentSubmitView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsPatient]

    def post(self, request):
        serializer = AssessmentSubmitSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        submission = serializer.save()

        # Audit Log
        AuditLog.objects.create(
            user=request.user,
            action='ASSESSMENT_SUBMITTED',
            ip_address=request.META.get('REMOTE_ADDR'),
            details={'assessment': submission.assessment.code, 'score': submission.total_score}
        )

        return Response({
            'success': True,
            'message': 'Assessment submitted and scored successfully.',
            'submission': PatientAssessmentSubmissionSerializer(submission).data
        }, status=status.HTTP_201_CREATED)


class PatientAssessmentHistoryView(generics.ListAPIView):
    serializer_class = PatientAssessmentSubmissionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'PATIENT' and hasattr(user, 'patient_profile'):
            return PatientAssessmentSubmission.objects.filter(patient=user.patient_profile)
        elif user.role in ['DOCTOR', 'ADMIN']:
            patient_id = self.request.query_params.get('patient_id')
            if patient_id:
                return PatientAssessmentSubmission.objects.filter(patient_id=patient_id)
        return PatientAssessmentSubmission.objects.none()
