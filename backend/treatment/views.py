from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from treatment.models import TreatmentPlan, TreatmentGoal, ProgressRecord
from treatment.serializers import (
    TreatmentPlanSerializer,
    TreatmentGoalSerializer,
    ProgressRecordSerializer
)
from core.permissions import IsDoctor, IsPatient
from core.models import AuditLog


class ActiveTreatmentPlanView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role == 'PATIENT' and hasattr(user, 'patient_profile'):
            plan = TreatmentPlan.objects.filter(patient=user.patient_profile, status='ACTIVE').first()
        elif user.role == 'DOCTOR' and hasattr(user, 'doctor_profile'):
            patient_id = request.query_params.get('patient_id')
            plan = TreatmentPlan.objects.filter(patient_id=patient_id, status='ACTIVE').first()
        else:
            plan = None

        if not plan:
            return Response({'success': False, 'message': 'No active treatment plan found.'}, status=status.HTTP_404_NOT_FOUND)

        return Response({
            'success': True,
            'plan': TreatmentPlanSerializer(plan).data
        })


class CreateTreatmentPlanView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDoctor]

    def post(self, request):
        doctor = request.user.doctor_profile
        patient_id = request.data.get('patient_id')
        title = request.data.get('title', 'خطة العلاج والمتابعة النفسية')
        diagnosis = request.data.get('diagnosis_summary', '')
        notes = request.data.get('clinical_notes', '')
        goals_data = request.data.get('goals', [])

        plan = TreatmentPlan.objects.create(
            doctor=doctor,
            patient_id=patient_id,
            title=title,
            diagnosis_summary_encrypted=diagnosis,
            clinical_notes_encrypted=notes,
            status='ACTIVE'
        )

        for idx, g in enumerate(goals_data, start=1):
            TreatmentGoal.objects.create(
                plan=plan,
                title=g.get('title', ''),
                description=g.get('description', ''),
                target_date=g.get('target_date'),
                order=idx
            )

        # Audit Log
        AuditLog.objects.create(
            user=request.user,
            action='TREATMENT_PLAN_UPDATED',
            ip_address=request.META.get('REMOTE_ADDR'),
            details={'plan_id': str(plan.id), 'patient_id': str(patient_id)}
        )

        return Response({
            'success': True,
            'message': 'Treatment plan created successfully.',
            'plan': TreatmentPlanSerializer(plan).data
        }, status=status.HTTP_201_CREATED)


class LogProgressRecordView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        if hasattr(user, 'patient_profile'):
            patient = user.patient_profile
        elif user.role == 'PATIENT':
            from accounts.models import PatientProfile
            patient, _ = PatientProfile.objects.get_or_create(user=user)
        else:
            return Response({'success': False, 'message': 'Only patients can log daily progress.'}, status=status.HTTP_403_FORBIDDEN)

        mood_score = int(request.data.get('mood_score', 5))
        sleep_hours = float(request.data.get('sleep_hours', 7.0))
        anxiety_level = int(request.data.get('anxiety_level', 1))
        notes = request.data.get('notes', '')

        from django.utils import timezone
        today = timezone.now().date()

        # Link active plan if exists
        active_plan = TreatmentPlan.objects.filter(patient=patient, status='ACTIVE').first()

        # Check if record for today already exists
        existing_record = ProgressRecord.objects.filter(patient=patient, log_date=today).first()

        if existing_record:
            existing_record.sleep_hours = sleep_hours
            existing_record.mood_score = mood_score
            existing_record.anxiety_level = anxiety_level
            if notes:
                existing_record.notes_encrypted = notes
            if active_plan:
                existing_record.plan = active_plan
            existing_record.save()
            record = existing_record
            msg = 'تم تحديث سجل اليوم بنجاح.'
        else:
            record = ProgressRecord.objects.create(
                patient=patient,
                plan=active_plan,
                mood_score=mood_score,
                sleep_hours=sleep_hours,
                anxiety_level=anxiety_level,
                notes_encrypted=notes
            )
            msg = 'تم تسجيل مؤشرات اليوم بنجاح.'

        return Response({
            'success': True,
            'message': msg,
            'record': ProgressRecordSerializer(record).data
        }, status=status.HTTP_200_OK if existing_record else status.HTTP_201_CREATED)


class ProgressHistoryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if hasattr(user, 'patient_profile'):
            patient = user.patient_profile
            records_qs = ProgressRecord.objects.filter(patient=patient).order_by('-log_date', '-updated_at')[:30]
        elif user.role == 'PATIENT':
            from accounts.models import PatientProfile
            patient, _ = PatientProfile.objects.get_or_create(user=user)
            records_qs = ProgressRecord.objects.filter(patient=patient).order_by('-log_date', '-updated_at')[:30]
        elif user.role in ['DOCTOR', 'ADMIN']:
            patient_id = request.query_params.get('patient_id')
            if patient_id:
                records_qs = ProgressRecord.objects.filter(patient_id=patient_id).order_by('-log_date', '-updated_at')[:30]
            else:
                records_qs = ProgressRecord.objects.none()
        else:
            records_qs = ProgressRecord.objects.none()

        records_data = ProgressRecordSerializer(records_qs, many=True).data

        # Compute summary metrics
        total = len(records_data)
        if total > 0:
            avg_mood = round(sum(r['mood_score'] for r in records_data) / total, 1)
            avg_sleep = round(sum(float(r['sleep_hours']) for r in records_data) / total, 1)
        else:
            avg_mood = 0.0
            avg_sleep = 0.0

        return Response({
            'success': True,
            'count': total,
            'avg_mood': avg_mood,
            'avg_sleep': avg_sleep,
            'results': records_data
        })
