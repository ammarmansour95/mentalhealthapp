import os
from django.core.management.base import BaseCommand
from accounts.models import User
from patients.models import PatientProfile
from doctors.models import DoctorProfile, DoctorAvailability
from assessments.models import AssessmentDefinition, AssessmentQuestion, AssessmentOption


class Command(BaseCommand):
    help = 'Seeds initial psychological assessments (PHQ-9, GAD-7) and sample users for testing'

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE("Seeding database with clinical scales and test accounts..."))

        # 1. Create Administrator
        admin_email = 'admin@mentalhealth.com'
        if not User.objects.filter(email=admin_email).exists():
            admin_user = User.objects.create_superuser(
                email=admin_email,
                password='AdminPassword123!',
                first_name='System',
                last_name='Administrator'
            )
            self.stdout.write(self.style.SUCCESS(f"Created Admin: {admin_email} / AdminPassword123!"))

        # 2. Create Sample Verified Doctor (CBT & Clinical Psychologist)
        doc_email = 'dr.sarah@mentalhealth.com'
        if not User.objects.filter(email=doc_email).exists():
            doc_user = User.objects.create_user(
                email=doc_email,
                password='DoctorPassword123!',
                first_name='سارة',
                last_name='المنصور',
                role='DOCTOR',
                status='ACTIVE'
            )
            doc_profile = DoctorProfile.objects.create(
                user=doc_user,
                title='دكتورة',
                specialty='CBT_SPECIALIST',
                license_number='LIC-SA-2024-8891',
                years_of_experience=8,
                bio='استشارية العلاج السلوكي المعرفي والاضطرابات المزاجية والقلق. حاصلة على البورد العربي في علم النفس الإكلينيكي.',
                consultation_fee=150.00,
                is_verified=True,
                rating=4.95,
                total_reviews=42
            )
            # Create Availability Slots (Mon-Thu 09:00 - 17:00)
            for day in range(0, 4):
                DoctorAvailability.objects.create(
                    doctor=doc_profile,
                    day_of_week=day,
                    start_time='09:00',
                    end_time='17:00',
                    slot_duration_minutes=45
                )
            self.stdout.write(self.style.SUCCESS(f"Created Verified Doctor: {doc_email} / DoctorPassword123!"))

        # 3. Create Sample Patient
        patient_email = 'patient@mentalhealth.com'
        if not User.objects.filter(email=patient_email).exists():
            pat_user = User.objects.create_user(
                email=patient_email,
                password='PatientPassword123!',
                first_name='أحمد',
                last_name='خالد',
                role='PATIENT',
                status='ACTIVE'
            )
            PatientProfile.objects.create(
                user=pat_user,
                gender='MALE',
                emergency_contact_name='خالد المنصور',
                emergency_contact_phone='+966500000001'
            )
            self.stdout.write(self.style.SUCCESS(f"Created Patient: {patient_email} / PatientPassword123!"))

        # 4. Seed PHQ-9 (Patient Health Questionnaire-9 for Depression)
        phq9, created = AssessmentDefinition.objects.get_or_create(
            code='PHQ-9',
            defaults={
                'title_en': 'Patient Health Questionnaire-9 (PHQ-9)',
                'title_ar': 'مقياس تقييم صحة المريض للاكتئاب (PHQ-9)',
                'description_en': 'Standard 9-item clinical scale for screening and measuring depression severity.',
                'description_ar': 'أداة سريرية قياسية مكونة من 9 أسئلة لفحص وقياس شدة الأعراض الاكتئابية خلال الأسبوعين الماضيين.',
                'category': 'DEPRESSION'
            }
        )

        phq9_questions = [
            ("Little interest or pleasure in doing things", "قلة الاهتمام أو المتعة في ممارسة الأنشطة المعتادة"),
            ("Feeling down, depressed, or hopeless", "الشعور بالحزن أو الإحباط أو اليأس"),
            ("Trouble falling or staying asleep, or sleeping too much", "صعوبة في النوم أو الاستيقاظ المتكرر، أو النوم لساعات طويلة جداً"),
            ("Feeling tired or having little energy", "الشعور بالتعب أو قلة الطاقة والإرهاق السريع"),
            ("Poor appetite or overeating", "ضعف الشهية أو الإفراط الملحوظ في تناول الطعام"),
            ("Feeling bad about yourself — or that you are a failure", "الشعور بالسوء تجاه نفسك أو أنك خذلت نفسك أو عائلتك"),
            ("Trouble concentrating on things, such as reading or watching TV", "صعوبة في التركيز على الأمور كالقراءة أو العمل أو مشاهدة التلفاز"),
            ("Moving or speaking slowly, or being overly fidgety / restless", "البطء في الحركة والكلام، أو العكس كالشعور بالتململ الشديد والحركة الزائدة"),
            ("Thoughts that you would be better off dead or hurting yourself", "أفكار تراودك بأنك ستكون أفضل حالاً لو مت أو إيذاء نفسك")
        ]

        likert_options = [
            (0, "Not at all", "لا على الإطلاق"),
            (1, "Several days", "عدة أيام"),
            (2, "More than half the days", "أكثر من نصف الأيام"),
            (3, "Nearly every day", "كل يوم تقريباً")
        ]

        if created or phq9.questions.count() == 0:
            for idx, (en_q, ar_q) in enumerate(phq9_questions, start=1):
                q = AssessmentQuestion.objects.create(
                    assessment=phq9,
                    order=idx,
                    text_en=en_q,
                    text_ar=ar_q
                )
                for score, en_opt, ar_opt in likert_options:
                    AssessmentOption.objects.create(
                        question=q,
                        score_value=score,
                        label_en=en_opt,
                        label_ar=ar_opt
                    )
            self.stdout.write(self.style.SUCCESS("Seeded PHQ-9 Questions & Likert Options"))

        # 5. Seed GAD-7 (Generalized Anxiety Disorder 7-item Scale)
        gad7, g_created = AssessmentDefinition.objects.get_or_create(
            code='GAD-7',
            defaults={
                'title_en': 'Generalized Anxiety Disorder-7 (GAD-7)',
                'title_ar': 'مقياس اضطراب القلق العام (GAD-7)',
                'description_en': 'Standard 7-item clinical scale for screening and measuring generalized anxiety.',
                'description_ar': 'أداة قياسية لفحص وقياس شدة أعراض القلق العام والتوتر خلال الأسبوعين الماضيين.',
                'category': 'ANXIETY'
            }
        )

        gad7_questions = [
            ("Feeling nervous, anxious, or on edge", "الشعور بالعصبية أو القلق أو التوتر الزائد"),
            ("Not being able to stop or control worrying", "عدم القدرة على إيقاف القلق أو السيطرة عليه"),
            ("Worrying too much about different things", "القلق المفرط بشأن أمور مختلفة"),
            ("Trouble relaxing", "صعوبة في الاسترخاء والراحة"),
            ("Being so restless that it is hard to sit still", "الشعور بالتململ وعدم القدرة على الجلوس بهدوء"),
            ("Becoming easily annoyed or irritable", "سرعة الانزعاج وسهولة الاستثارة والغضب"),
            ("Feeling afraid, as if something awful might happen", "الشعور بالخوف كأن شيئاً سيئاً وفضيعاً على وشك الحدوث")
        ]

        if g_created or gad7.questions.count() == 0:
            for idx, (en_q, ar_q) in enumerate(gad7_questions, start=1):
                q = AssessmentQuestion.objects.create(
                    assessment=gad7,
                    order=idx,
                    text_en=en_q,
                    text_ar=ar_q
                )
                for score, en_opt, ar_opt in likert_options:
                    AssessmentOption.objects.create(
                        question=q,
                        score_value=score,
                        label_en=en_opt,
                        label_ar=ar_opt
                    )
            self.stdout.write(self.style.SUCCESS("Seeded GAD-7 Questions & Likert Options"))

        self.stdout.write(self.style.SUCCESS("Database seeding completed successfully!"))
