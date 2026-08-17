from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status
from accounts.models import User
from doctors.models import DoctorProfile
from patients.models import PatientProfile
from assessments.models import AssessmentDefinition, AssessmentQuestion, AssessmentOption, PatientAssessmentSubmission
from appointments.models import Appointment
from ai_engine.models import AIInterviewSession, AIReport
from ai_engine.services.factory import get_ai_service


class MentalHealthPlatformIntegrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Seed Scale
        self.phq9 = AssessmentDefinition.objects.create(
            code='PHQ-9',
            title_en='PHQ-9',
            title_ar='مقياس الاكتئاب',
            category='DEPRESSION'
        )
        self.q1 = AssessmentQuestion.objects.create(
            assessment=self.phq9,
            order=1,
            text_en='Depressed mood',
            text_ar='شعور بالحزن'
        )
        self.opt0 = AssessmentOption.objects.create(question=self.q1, score_value=0, label_en='None', label_ar='لا شيء')
        self.opt3 = AssessmentOption.objects.create(question=self.q1, score_value=3, label_en='Nearly every day', label_ar='كل يوم')

        # Admin
        self.admin = User.objects.create_superuser(
            email='admin@test.com',
            password='AdminPass123!',
            first_name='Admin',
            last_name='User'
        )

        # Doctor (Pending verification)
        self.doctor_user = User.objects.create_user(
            email='doc@test.com',
            password='DocPass123!',
            first_name='Doctor',
            last_name='Tariq',
            role='DOCTOR',
            status='PENDING'
        )
        self.doctor_profile = DoctorProfile.objects.create(
            user=self.doctor_user,
            specialty='CBT_SPECIALIST',
            is_verified=False
        )

        # Patient
        self.patient_user = User.objects.create_user(
            email='patient@test.com',
            password='PatientPass123!',
            first_name='Ahmad',
            last_name='Ali',
            role='PATIENT',
            status='ACTIVE'
        )
        self.patient_profile = PatientProfile.objects.create(
            user=self.patient_user,
            gender='MALE'
        )

    def test_01_user_login_and_jwt_issuance(self):
        res = self.client.post('/api/auth/login/', {
            'email': 'patient@test.com',
            'password': 'PatientPass123!'
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['success'])
        self.assertIn('token', res.data)
        self.assertEqual(res.data['user']['email'], 'patient@test.com')

    def test_02_admin_verify_doctor(self):
        # Login as Admin
        self.client.force_authenticate(user=self.admin)
        res = self.client.patch(f'/api/doctors/{self.doctor_profile.id}/verify/', {
            'action': 'APPROVE'
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.doctor_profile.refresh_from_db()
        self.assertTrue(self.doctor_profile.is_verified)
        self.assertEqual(self.doctor_profile.user.status, 'ACTIVE')

    def test_03_assessment_submission_and_scoring(self):
        self.client.force_authenticate(user=self.patient_user)
        payload = {
            'assessment_code': 'PHQ-9',
            'answers': [
                {'question_id': str(self.q1.id), 'option_id': str(self.opt3.id)}
            ]
        }
        res = self.client.post('/api/assessments/submit/', payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['submission']['total_score'], 3)
        self.assertEqual(res.data['submission']['severity_level'], 'MINIMAL')

    def test_04_ai_interview_and_arabart_report_synthesis(self):
        self.client.force_authenticate(user=self.patient_user)
        
        # 1. Start Interview
        start_res = self.client.post('/api/ai/interview/start/')
        self.assertEqual(start_res.status_code, status.HTTP_201_CREATED)
        session_id = start_res.data['session_id']

        # 2. Send Message
        turn_res = self.client.post(f'/api/ai/interview/{session_id}/message/', {
            'message': 'أشعر بالحزن الشديد وفقدان الشغف وصعوبة في النوم منذ أسبوعين'
        })
        self.assertEqual(turn_res.status_code, status.HTTP_200_OK)
        self.assertTrue(turn_res.data['success'])
        self.assertIn('ai_reply', turn_res.data)

        # 3. Complete Interview & Synthesize Report
        complete_res = self.client.post(f'/api/ai/interview/{session_id}/complete/')
        self.assertEqual(complete_res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(complete_res.data['success'])
        
        report_data = complete_res.data['report']
        self.assertIsNotNone(report_data['summary_ar_encrypted'])
        self.assertIn(report_data['preliminary_risk_level'], ['LOW', 'MODERATE', 'HIGH'])
        self.assertTrue(len(report_data['disclaimer_notice']) > 0)

    def test_05_appointment_booking_and_conflict_prevention(self):
        # Approve doctor first
        self.doctor_profile.is_verified = True
        self.doctor_profile.save()

        self.client.force_authenticate(user=self.patient_user)
        booking_payload = {
            'doctor_id': str(self.doctor_profile.id),
            'appointment_date': '2026-09-01',
            'start_time': '10:00:00',
            'end_time': '10:45:00',
            'patient_notes': 'Need consultation for anxiety'
        }

        # 1. First booking succeeds with PENDING status
        res1 = self.client.post('/api/appointments/book/', booking_payload, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res1.data['appointment']['status'], 'PENDING')
        appt_id = res1.data['appointment']['id']

        # 2. Doctor confirms appointment
        self.client.force_authenticate(user=self.doctor_user)
        confirm_res = self.client.patch(f'/api/appointments/{appt_id}/status/', {'status': 'CONFIRMED'})
        self.assertEqual(confirm_res.status_code, status.HTTP_200_OK)
        # 3. Verify booked-slots endpoint returns '10:00:00'
        slots_res = self.client.get(f'/api/doctors/{self.doctor_profile.id}/booked-slots/?date=2026-09-01')
        self.assertEqual(slots_res.status_code, status.HTTP_200_OK)
        self.assertIn('10:00:00', slots_res.data['booked_slots'])

        # 4. Duplicate booking for the same slot is prevented (BR-006)
        self.client.force_authenticate(user=self.patient_user)
        res2 = self.client.post('/api/appointments/book/', booking_payload, format='json')
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)

        # 5. Patient cancels appointment (> 2 hours before scheduled time -> Success)
        cancel_res = self.client.patch(f'/api/appointments/{appt_id}/status/', {
            'status': 'CANCELLED',
            'cancellation_reason': 'Schedule conflict'
        })
        self.assertEqual(cancel_res.status_code, status.HTTP_200_OK)
        self.assertEqual(cancel_res.data['appointment']['status'], 'CANCELLED')
