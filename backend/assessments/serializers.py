from rest_framework import serializers
from assessments.models import (
    AssessmentDefinition, AssessmentQuestion, AssessmentOption,
    PatientAssessmentSubmission, AssessmentAnswer
)


class AssessmentOptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = AssessmentOption
        fields = ['id', 'score_value', 'label_en', 'label_ar']


class AssessmentQuestionSerializer(serializers.ModelSerializer):
    options = AssessmentOptionSerializer(many=True, read_only=True)

    class Meta:
        model = AssessmentQuestion
        fields = ['id', 'order', 'text_en', 'text_ar', 'options']


class AssessmentDefinitionSerializer(serializers.ModelSerializer):
    questions = AssessmentQuestionSerializer(many=True, read_only=True)

    class Meta:
        model = AssessmentDefinition
        fields = ['id', 'code', 'title_en', 'title_ar', 'description_en', 'description_ar', 'category', 'questions']


class AssessmentAnswerInputSerializer(serializers.Serializer):
    question_id = serializers.UUIDField()
    option_id = serializers.UUIDField()


class AssessmentSubmitSerializer(serializers.Serializer):
    assessment_code = serializers.CharField()
    answers = AssessmentAnswerInputSerializer(many=True)

    def create(self, validated_data):
        user = self.context['request'].user
        patient_profile = user.patient_profile
        code = validated_data['assessment_code']
        answers_data = validated_data['answers']

        assessment = AssessmentDefinition.objects.get(code=code)
        
        total_score = 0
        answer_objects = []

        for item in answers_data:
            question = AssessmentQuestion.objects.get(id=item['question_id'], assessment=assessment)
            option = AssessmentOption.objects.get(id=item['option_id'], question=question)
            total_score += option.score_value
            answer_objects.append((question, option, option.score_value))

        # Calculate Severity Level & Interpretations
        severity_level = 'MINIMAL'
        interp_en = ''
        interp_ar = ''

        if code == 'PHQ-9':
            if total_score <= 4:
                severity_level = 'MINIMAL'
                interp_en = "Minimal or no depression symptoms."
                interp_ar = "أعراض اكتئاب طفيفة أو غير موجودة."
            elif total_score <= 9:
                severity_level = 'MILD'
                interp_en = "Mild depression symptoms. Watchful waiting recommended."
                interp_ar = "أعراض اكتئاب بسيطة. يُوصى بالمتابعة الذاتية ومراقبة الأعراض."
            elif total_score <= 14:
                severity_level = 'MODERATE'
                interp_en = "Moderate depression symptoms. Professional counseling suggested."
                interp_ar = "أعراض اكتئاب متوسطة. يُنصح بطلب الاستشارة النفسية المتخصصة."
            elif total_score <= 19:
                severity_level = 'MODERATELY_SEVERE'
                interp_en = "Moderately severe depression. Active treatment indicated."
                interp_ar = "أعراض اكتئاب شديدة نسبياً. تستدعي التدخل السريري من طبيب مختص."
            else:
                severity_level = 'SEVERE'
                interp_en = "Severe depression. Immediate professional intervention indicated."
                interp_ar = "أعراض اكتئاب شديدة. تتطلب استشارة طبية ونفسية عاجلة."
        elif code == 'GAD-7':
            if total_score <= 4:
                severity_level = 'MINIMAL'
                interp_en = "Minimal anxiety."
                interp_ar = "مستوى قلق طبيعي وط his."
            elif total_score <= 9:
                severity_level = 'MILD'
                interp_en = "Mild anxiety symptoms."
                interp_ar = "أعراض قلق بسيطة."
            elif total_score <= 14:
                severity_level = 'MODERATE'
                interp_en = "Moderate anxiety. Clinical evaluation recommended."
                interp_ar = "أعراض قلق متوسطة. يُنصح بالاستشارة النفسية (CBT)."
            else:
                severity_level = 'SEVERE'
                interp_en = "Severe anxiety symptoms. Active treatment recommended."
                interp_ar = "أعراض قلق شديدة. تتطلب تدخلاً علاجياً متخصصاً."

        submission = PatientAssessmentSubmission.objects.create(
            patient=patient_profile,
            assessment=assessment,
            total_score=total_score,
            severity_level=severity_level,
            interpretation_en=interp_en,
            interpretation_ar=interp_ar
        )

        for q, opt, score in answer_objects:
            AssessmentAnswer.objects.create(
                submission=submission,
                question=q,
                selected_option=opt,
                score=score
            )

        return submission


class PatientAssessmentSubmissionSerializer(serializers.ModelSerializer):
    assessment_code = serializers.CharField(source='assessment.code', read_only=True)
    assessment_title_ar = serializers.CharField(source='assessment.title_ar', read_only=True)
    severity_level_display = serializers.CharField(source='get_severity_level_display', read_only=True)

    class Meta:
        model = PatientAssessmentSubmission
        fields = [
            'id', 'assessment_code', 'assessment_title_ar', 'total_score',
            'severity_level', 'severity_level_display',
            'interpretation_en', 'interpretation_ar', 'created_at'
        ]
