from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from ai_engine.models import AIInterviewSession, AIInterviewMessage, AIReport
from ai_engine.serializers import (
    AIInterviewSessionSerializer,
    AIInterviewMessageSerializer,
    AIReportSerializer
)
from ai_engine.services.factory import get_ai_service
from assessments.models import PatientAssessmentSubmission
from core.permissions import IsPatient, IsDoctor
from core.models import AuditLog


class StartAIInterviewView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsPatient]

    def post(self, request):
        patient = request.user.patient_profile
        
        # Check if there is an active session, or create a new one
        session = AIInterviewSession.objects.create(
            patient=patient,
            status='IN_PROGRESS',
            current_stage='GREETING',
            turn_count=0
        )

        ai_service = get_ai_service()
        # Initial greeting from AraBART engine
        greeting_data = getattr(ai_service, 'STAGE_PROMPTS', {}).get(
            'GREETING',
            {'question': 'أهلاً بك، كيف يمكنني مساعدتك اليوم؟', 'quick_replies': []}
        )

        # Save AI initial message
        ai_message = AIInterviewMessage.objects.create(
            session=session,
            sender='AI',
            content_encrypted=greeting_data['question']
        )

        return Response({
            'success': True,
            'session_id': str(session.id),
            'stage': session.current_stage,
            'ai_message': AIInterviewMessageSerializer(ai_message).data,
            'quick_replies': greeting_data.get('quick_replies', [])
        }, status=status.HTTP_201_CREATED)


class AIInterviewTurnView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        user = request.user
        if hasattr(user, 'patient_profile'):
            patient = user.patient_profile
        elif user.role == 'PATIENT':
            from accounts.models import PatientProfile
            patient, _ = PatientProfile.objects.get_or_create(user=user)
        else:
            return Response({'success': False, 'message': 'Only patients can send interview messages.'}, status=status.HTTP_403_FORBIDDEN)

        user_message_text = request.data.get('message', '').strip()

        if not user_message_text:
            return Response({
                'success': False,
                'message': 'Message content cannot be empty.'
            }, status=status.HTTP_400_BAD_REQUEST)

        session = AIInterviewSession.objects.filter(id=session_id, patient=patient).first()
        if not session:
            return Response({
                'success': False,
                'message': 'Interview session not found.'
            }, status=status.HTTP_404_NOT_FOUND)

        if session.status == 'COMPLETED':
            return Response({
                'success': True,
                'is_complete': True,
                'current_stage': 'COMPLETED',
                'ai_reply': {
                    'content_encrypted': 'شكراً لك. اكتملت هذه المقابلة بنجاح، يمكنك الضغط على زر (إنهاء وإنشاء التقرير السريري الأولي) بالأسفل لعرض تقريرك الطبي.'
                },
                'suggested_quick_replies': []
            })

        # 1. Save Patient Message
        patient_msg = AIInterviewMessage.objects.create(
            session=session,
            sender='PATIENT',
            content_encrypted=user_message_text
        )

        # 2. Call AI Service (AraBART NLP engine)
        ai_service = get_ai_service()
        history = [
            {'sender': m.sender, 'content': m.content_encrypted}
            for m in session.messages.all().order_by('created_at')
        ]

        turn_result = ai_service.generate_next_interview_turn(
            session_id=str(session.id),
            current_stage=session.current_stage,
            turn_count=session.turn_count,
            conversation_history=history,
            latest_patient_message=user_message_text
        )

        # Extract symptoms into patient message
        patient_msg.extracted_symptoms = turn_result.get('extracted_symptoms', [])
        patient_msg.save()

        # 3. Emergency Safety Protocol: Alert Doctors & Admins Instantly
        if turn_result.get('crisis_detected', False):
            from ai_engine.services.crisis_alert import trigger_patient_crisis_alert
            trigger_patient_crisis_alert(patient, session, user_message_text)

        # 4. Update Session State
        session.current_stage = turn_result['next_stage']
        session.turn_count += 1
        if turn_result['is_complete']:
            session.status = 'COMPLETED'
            session.completed_at = timezone.now()
        session.save()

        # 4. Save AI Response Message
        ai_reply = AIInterviewMessage.objects.create(
            session=session,
            sender='AI',
            content_encrypted=turn_result['reply']
        )

        return Response({
            'success': True,
            'ai_reply': AIInterviewMessageSerializer(ai_reply).data,
            'current_stage': session.current_stage,
            'is_complete': turn_result['is_complete'],
            'suggested_quick_replies': turn_result.get('suggested_quick_replies', []),
            'crisis_detected': turn_result.get('crisis_detected', False)
        })


class CompleteAIInterviewView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        user = request.user
        if hasattr(user, 'patient_profile'):
            patient = user.patient_profile
        elif user.role == 'PATIENT':
            from accounts.models import PatientProfile
            patient, _ = PatientProfile.objects.get_or_create(user=user)
        else:
            return Response({'success': False, 'message': 'Only patients can complete interviews.'}, status=status.HTTP_403_FORBIDDEN)

        session = AIInterviewSession.objects.filter(id=session_id, patient=patient).first()
        if not session:
            return Response({'success': False, 'message': 'Interview session not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Return existing report if already created for this session
        existing_report = AIReport.objects.filter(interview_session=session).first()
        if existing_report:
            return Response({
                'success': True,
                'message': 'Report retrieved successfully.',
                'report': AIReportSerializer(existing_report).data
            })

        session.status = 'COMPLETED'
        session.completed_at = timezone.now()
        session.save()

        # Compile full conversation transcript
        transcript_lines = []
        for msg in session.messages.all().order_by('created_at'):
            transcript_lines.append(f"{msg.sender}: {msg.content_encrypted}")
        full_transcript = "\n".join(transcript_lines)

        # Find recent completed assessments from the last 24 hours (PHQ-9, GAD-7)
        cutoff_time = timezone.now() - timezone.timedelta(hours=24)
        recent_submissions = PatientAssessmentSubmission.objects.filter(
            patient=patient,
            created_at__gte=cutoff_time
        ).order_by('-created_at')
        
        assessment_scores = {}
        latest_sub = recent_submissions.first()
        for sub in recent_submissions[:3]:
            assessment_scores[sub.assessment.code] = sub.total_score

        # Run AraBART Summarization and Indicator Extraction
        ai_service = get_ai_service()
        clinical_summaries = ai_service.generate_clinical_summary(full_transcript)
        analysis_result = ai_service.extract_indicators_and_risk(full_transcript, assessment_scores)

        # Create Structured AI Report
        report = AIReport.objects.create(
            patient=patient,
            interview_session=session,
            assessment_submission=latest_sub,
            summary_ar_encrypted=clinical_summaries['summary_ar'],
            summary_en_encrypted=clinical_summaries['summary_en'],
            primary_indicators=analysis_result['primary_indicators'],
            preliminary_risk_level=analysis_result['preliminary_risk_level'],
            recommended_specialty=analysis_result['recommended_specialty'],
            recommendation_reason_ar=analysis_result['recommendation_reason_ar'],
            recommendation_reason_en=analysis_result['recommendation_reason_en'],
            safety_warning_triggered=analysis_result['safety_warning_triggered']
        )

        # Trigger emergency alert to Doctors & Admins if high risk or safety warning
        if report.safety_warning_triggered or report.preliminary_risk_level == 'HIGH':
            from ai_engine.services.crisis_alert import trigger_patient_crisis_alert
            trigger_patient_crisis_alert(patient, session, full_transcript)

        # Audit Log
        AuditLog.objects.create(
            user=request.user,
            action='AI_REPORT_GENERATED',
            ip_address=request.META.get('REMOTE_ADDR'),
            details={'report_id': str(report.id), 'risk_level': report.preliminary_risk_level}
        )

        return Response({
            'success': True,
            'message': 'AI Preliminary Clinical Report synthesized successfully.',
            'report': AIReportSerializer(report).data
        }, status=status.HTTP_201_CREATED)


class AIReportListView(generics.ListAPIView):
    serializer_class = AIReportSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'PATIENT' and hasattr(user, 'patient_profile'):
            return AIReport.objects.filter(patient=user.patient_profile)
        elif user.role == 'DOCTOR' and hasattr(user, 'doctor_profile'):
            # Doctors can view reports of patients who booked with them
            patient_id = self.request.query_params.get('patient_id')
            if patient_id:
                return AIReport.objects.filter(patient_id=patient_id)
            return AIReport.objects.all()
        elif user.role == 'ADMIN':
            return AIReport.objects.all()
        return AIReport.objects.none()


class AIReportDetailView(generics.RetrieveAPIView):
    serializer_class = AIReportSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'PATIENT':
            return AIReport.objects.filter(patient__user=user)
        elif user.role in ['DOCTOR', 'ADMIN']:
            return AIReport.objects.all()
        return AIReport.objects.none()


class DoctorReviewReportView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDoctor]

    def patch(self, request, pk):
        doctor = request.user.doctor_profile
        try:
            report = AIReport.objects.get(id=pk)
        except AIReport.DoesNotExist:
            return Response({'success': False, 'message': 'Report not found.'}, status=status.HTTP_404_NOT_FOUND)

        notes = request.data.get('doctor_notes', '')
        report.is_reviewed_by_doctor = True
        report.reviewed_by = doctor
        report.doctor_review_notes_encrypted = notes
        report.reviewed_at = timezone.now()
        report.save()

        return Response({
            'success': True,
            'message': 'Report successfully reviewed and clinical notes saved.',
            'report': AIReportSerializer(report).data
        })
