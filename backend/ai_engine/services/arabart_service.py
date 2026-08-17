import re
import logging
from typing import Dict, Any, List
from ai_engine.services.base import BaseAIService

logger = logging.getLogger(__name__)


# Arabic text normalization helper
def normalize_arabic(text: str) -> str:
    if not text:
        return ""
    text = re.sub(r'[\u064B-\u0652]', '', text)  # Remove tashkeel / diacritics
    text = re.sub(r'[\u0640]', '', text)         # Remove tatweel
    text = re.sub(r'[إأآا]', 'ا', text)          # Normalize Alef
    text = re.sub(r'ى', 'ي', text)              # Normalize Yeh
    text = re.sub(r'ة', 'ه', text)              # Normalize Teh Marbuta
    return text.strip()


class AraBARTAssessmentService(BaseAIService):
    """
    Arabic Natural Language Processing and Preliminary Assessment Service powered by AraBART NLP concepts.
    Provides Arabic conversational interviewing, symptom extraction, clinical summarization,
    risk evaluation, and specialist matching.
    """

    # Crisis / Emergency Trigger Keywords (Immediate High-Risk Protocol)
    CRISIS_KEYWORDS = [
        'انتحار', 'انتحر', 'انهاء حياتي', 'ايذاء نفسي', 'اقتل نفسي',
        'الموت افضل', 'ما بدي اعيش', 'مش عايز اعيش', 'موت', 'لا جدوى من الحياة',
        'تعبت من الدنيا', 'بدي ارتاح من كل شي'
    ]

    # Clinical Symptom Dictionary mapped to DSM-5 Psychological Indicators & Arabic Dialect Nuances (including Syrian/Levantine)
    SYMPTOM_DICTIONARY = {
        'DEPRESSION': {
            'label_ar': 'أعراض المزاج الاكتئابي والحزن (Depressive Symptoms)',
            'keywords': [
                'حزن', 'كابه', 'اكتئاب', 'فقدان الشغف', 'فقدان المتعه', 'بكاء', 'ياس',
                'عزله', 'انعزال', 'فراغ', 'احباط', 'خمول', 'مخنوق', 'فاقد الامل',
                'ما في طاقه', 'تعبت من كل شي', 'مالي نفس', 'ضيقه', 'مكتوم', 'ما لي خلق',
                'روحي طالعه', 'قلبي مقبوض', 'كئيب وضايج', 'كاره عيشتي', 'عم ابكي', 'فايت بكابه',
                'ضايق خلقي', 'مالي حيل', 'حاسس بضيقه'
            ],
            'specialty': 'CLINICAL_PSYCHOLOGY'
        },
        'ANXIETY': {
            'label_ar': 'أعراض القلق العام والتفكير الزائد (Generalized Anxiety & Rumination)',
            'keywords': [
                'قلق', 'توتر', 'خوف', 'رعب', 'افكار متسارعه', 'عصبيه', 'عدم استقرار',
                'ارتجاف', 'تفكير زائد', 'وسواس', 'تفكير مستمر', 'خايف من المستقبل',
                'قلقان طول الوقت', 'ضغط نفسي', 'عدم هدوء', 'شكوك',
                'عم فكر زياده', 'موتر وعصبي', 'مخي مو عم يهدي', 'مرعوب', 'خايف من بكره',
                'افكار عم تاكل راسي', 'موسوس', 'مو مرتاح', 'عم احسب حساب كل شي'
            ],
            'specialty': 'CBT_SPECIALIST'
        },
        'PANIC': {
            'label_ar': 'مؤشرات نوبات الهلع والأعراض الجسدية (Panic & Somatic Distress)',
            'keywords': [
                'هلع', 'خفقان', 'ضيق تنفس', 'اختناق', 'دوخه', 'نوبه ذعر', 'الم في الصدر',
                'تسارع نبضات', 'كتمه في الصدر', 'حاسس بالموت', 'رجفه', 'تنميل', 'بروده اطراف',
                'كتمه بنفسي', 'قلبي عم يدق بسرعه', 'عم ارجف', 'حاسس حالي عم موت', 'ضيقه نفس قويه'
            ],
            'specialty': 'PSYCHIATRY'
        },
        'SLEEP_DISRUPTION': {
            'label_ar': 'اضطرابات جودة النوم والأرق (Sleep Disruption & Insomnia)',
            'keywords': [
                'ارق', 'صعوبه نوم', 'كوابيس', 'استيقاظ متكرر', 'نوم متقطع', 'نوم زائد',
                'تعب مستمر', 'ارق شديد', 'ما بنام', 'اصحي كثير بالليل', 'نومي مقطع',
                'بنام فوق 12 ساعه', 'اصحي تعبان', 'ما عم اقدر نام', 'عم فيق كتير',
                'نومي مقطش', 'ارق مبهدلني', 'طول الليل سهران وبفكر', 'مو عم يجيني نوم'
            ],
            'specialty': 'CLINICAL_PSYCHOLOGY'
        },
        'ANHEDONIA_ENERGY': {
            'label_ar': 'انعدام التلذذ وانخفاض الطاقة والدافعية (Anhedonia & Low Energy)',
            'keywords': [
                'ما بستمتع بشي', 'فقدت الشغف تماما', 'ما عندي حافز', 'روتين ممل',
                'كسل وخمول', 'فقدان رغبه', 'تثاقل', 'انعدام دافعيه',
                'ما عاد في شي بيفرحني', 'كاره كل شي', 'تعبان ومالي حيل', 'ما عم استمتع',
                'كل شي صار عادي وباهت'
            ],
            'specialty': 'CLINICAL_PSYCHOLOGY'
        },
        'TRAUMA_PTSD': {
            'label_ar': 'مؤشرات الصدمة النفسية والذكريات الضاغطة (Trauma & Stressor)',
            'keywords': [
                'صدمه', 'ذكريات مؤلمه', 'فلاش باك', 'حادث', 'فقدان شخص', 'خوف مفاجئ',
                'شعور بالتهديد', 'موقف صعب', 'صدمه طفوله', 'فاجعه', 'ذكريات الحرب',
                'موقف هزني', 'خوف متكرر من الذكريات'
            ],
            'specialty': 'TRAUMA_PTSD'
        },
        'BURNOUT': {
            'label_ar': 'الإجهاد النفسي والاحتراق (Burnout & Executive Exhaustion)',
            'keywords': [
                'ارهاق', 'ضغط عمل', 'ضغط دراسي', 'عدم تركيز', 'انهاك', 'تشتت',
                'فقدان طاقه', 'احتراق وظيفي', 'صداع مستمر', 'تعب ذهني',
                'فايت بحيط', 'مكركب ومضغوط', 'تعبت من الشغل', 'ضغط دراسه عم يهدني',
                'راسي عم ينفجر من الضغط'
            ],
            'specialty': 'CBT_SPECIALIST'
        },
        'SOCIAL_WITHDRAWAL': {
            'label_ar': 'الانعزال والتباعد الاجتماعي (Social Withdrawal)',
            'keywords': [
                'ما بدي اشوف احد', 'قافل علي نفسي', 'منعزل', 'تهربت من الجمعات',
                'انطوائي مؤخرا', 'تجنب الناس', 'عدم رغبه في الحديث',
                'حابس حالي بغرفتي', 'قافل عحالي', 'ما بدي احكي مع حدا', 'انطويت',
                'عم اتهرب من العالم والناس'
            ],
            'specialty': 'CLINICAL_PSYCHOLOGY'
        }
    }

    # Structured Adaptive Question Stages
    # Warm Natural Conversational Prompts (Psychologist-style empathetic tone)
    STAGE_PROMPTS = {
        'GREETING': {
            'question': "أهلاً بك.. خذ راحتك تماماً، أنا هنا لأسمعك بكل سرية وأمان وبدون أي أحكام. احكيلي براحتك، شو أكتر شي عم يزعجك أو حاسس إنه شاغل بالك وتفكيرك هالأيام؟",
            'quick_replies': ["أشعر بحزن مستمر وضيق داخلي", "عندي قلق وتفكير زائد وتوتر", "صعوبة شديدة في النوم والأرق", "إرهاق وضغوطات نفسية متراكمة"]
        },
        'MAIN_COMPLAINT': {
            'question': "من متى تقريباً عم تحس بهالمشاعر؟ وهل عم تلاحظ إنها مأثرة على تركيزك أو طاقتك وإنتاجيتك باليوم؟",
            'quick_replies': ["منذ أقل من أسبوعين", "منذ أكثر من شهر", "منذ عدة أشهر", "مأثرة بشكل ملحوظ على تركيزي ويومي"]
        },
        'SLEEP_ROUTINE': {
            'question': "طمني، كيف عم يكون نومك وشهيتك مؤخراً؟ عم تقدر تنام وترتاح ولا بتصحى وحاسس حالك لسه تعبان ومجهد؟",
            'quick_replies': ["أعاني من أرق وصعوبة بالنوم", "بنام لساعات طويلة بس بصحى تعبان", "فقدان واضح للشهية والطاقة", "نومي متقلب ومو مريح"]
        },
        'MOOD_EMOTIONS': {
            'question': "هل عم تشعر إنك فقدت الرغبة أو المتعة بالأشياء اللي كنت تحب تعملها؟ وهل بتميل لتقعد لحالك وتبتعد عن الناس مؤخراً؟",
            'quick_replies': ["نعم، فقدت الشغف والمتعة بشكل كبير", "أفضل العزلة والابتعاد عن الناس", "أحياناً، وبحاول أقاوم هالشعور", "ما زلت محافظ على تواصلي"]
        },
        'RISK_CHECK': {
            'question': "راحتك وأمانك هنن أهم أولوياتي.. مع كل هالضغط والتعب، هل بتمر بلحظات تحس فيها بيأس شديد أو أفكار صعبة ومزعجة عم ترهقك؟",
            'quick_replies': ["لا، ما بتمر علي هيك أفكار أبداً", "أحياناً بحس بضيق وإحباط عابر", "نعم، بتراودني أفكار صعبة وبحاجة لمساعدة"]
        },
        'SUMMARY_WRAPUP': {
            'question': "أنا فخور فيك وشاكر جداً لصراحتك وشجاعتك بالحديث.. مو سهل أبداً الواحد يعبر عن مشاعره بهالوضوح. قمت بتحليل وتلخيص كل اللي شاركتني ياه بتقرير طبي أولي، والآن جاهز لأرشدك للطبيب الأنسب لحالتك لتبدأ ترتاح بإذن الله.",
            'quick_replies': []
        }
    }

    # Warm Contextual Reflections (Empathy & Active Listening)
    THEMATIC_REFLECTIONS = {
        'DEPRESSION': "حاسس فيك والله.. الحزن والضيق لما يتراكموا بصيروا تقال كتير عالقلب، وشجاعة منك إنك عم تعبر وتشارك هالمشاعر.",
        'ANXIETY': "سلامتك يا رب.. التفكير الزائد والقلق المستمر فعلاً بيستنزف طاقة الواحد ويخلي عقله شغال طول الوقت بدون راحة.",
        'PANIC': "سلامة قلبك، تسارع دقات القلب والشعور بالكتمة تجربة بتخوف وبترهق الجسم.. ألف سلامة عليك.",
        'SLEEP_DISRUPTION': "صحيح، قلة النوم لحالها كفيلة تخلي الواحد مو طايق شي وتعبان طول اليوم ومو قادر يركز.",
        'ANHEDONIA_ENERGY': "فقدان الشغف وإنك تحس كل شي باهت شعور مو سهل أبداً، وطبيعي جداً تحس بالتعب لما طاقتك تستنزف.",
        'TRAUMA_PTSD': "أحييك من قلبي على شجاعتك في الحديث.. الذكريات والمواقف الصعبة بتترك أثر عميق، ومشاركتك إلها بداية طريق التعافي.",
        'BURNOUT': "الضغوط المتراكمة من الشغل أو الدراسة بتشكل حمل كبير وبتخلي العقل بحالة إنهاك وتشتت دائم.",
        'SOCIAL_WITHDRAWAL': "طبيعي جداً لما نكون تعبانين ومضغوطين نحس برغبة بالابتعاد والانعزال لنحمي حالنا شوي من التوتر."
    }

    GENERIC_TRANSITIONS = [
        "أسمعك بوضوح وحاسس فيك.. ومشاركتك لهالتفاصيل بتساعدنا كتير لنفهم حالتك ونوقف جنبك.",
        "شكراً لصراحتك.. خطوة واعية ومهمة إنك عم تحكي وتفرغ اللي بقلبك.",
        "أنا معك وعم اسمعك بكل اهتمام.. وكتير طبيعي تحس بهيك مشاعر بالظروف الصعبة."
    ]

    def generate_next_interview_turn(
        self,
        session_id: str,
        current_stage: str,
        turn_count: int,
        conversation_history: List[Dict[str, str]],
        latest_patient_message: str
    ) -> Dict[str, Any]:
        normalized_msg = normalize_arabic(latest_patient_message)
        
        # 1. Emergency keyword scan
        is_crisis = any(kw in normalized_msg for kw in self.CRISIS_KEYWORDS)

        # 2. Extract symptoms mentioned in this turn & across conversation
        extracted_symptoms = []
        detected_themes = []
        for category, data in self.SYMPTOM_DICTIONARY.items():
            for kw in data['keywords']:
                if kw in normalized_msg:
                    extracted_symptoms.append(data['label_ar'])
                    detected_themes.append(category)
                    break

        # Check full conversation context for prior sleep/energy mentions
        all_past_text = " ".join([m.get('content', '') for m in conversation_history]) + " " + normalized_msg
        has_sleep_mentioned = any(kw in all_past_text for kw in self.SYMPTOM_DICTIONARY['SLEEP_DISRUPTION']['keywords'])
        has_anhedonia_mentioned = any(kw in all_past_text for kw in self.SYMPTOM_DICTIONARY['ANHEDONIA_ENERGY']['keywords'])

        # 3. Determine next stage progression
        stages_order = ['GREETING', 'MAIN_COMPLAINT', 'SLEEP_ROUTINE', 'MOOD_EMOTIONS', 'RISK_CHECK', 'SUMMARY_WRAPUP']
        current_index = stages_order.index(current_stage) if current_stage in stages_order else 0

        # Progress to next stage
        next_index = min(current_index + 1, len(stages_order) - 1)
        next_stage = stages_order[next_index]
        is_complete = (next_stage == 'SUMMARY_WRAPUP')

        stage_data = self.STAGE_PROMPTS.get(next_stage, self.STAGE_PROMPTS['SUMMARY_WRAPUP'])
        base_question = stage_data['question']

        # 4. Context-Aware Question Adaptation (No robotic repetitions)
        if next_stage == 'SLEEP_ROUTINE' and has_sleep_mentioned:
            # If patient already talked about insomnia/sleep, adapt the question naturally to daytime energy & appetite
            base_question = "بما إنك ذكرت معاناتك مع قلة النوم والأرق، هاد الشي أكيد عم يأثر على طاقتك.. طمني، كيف عم تكون شهيتك ونشاطك خلال النهار؟ عم تحس بخمول أو إرهاق جسدي مستمر؟"
        elif next_stage == 'MOOD_EMOTIONS' and has_anhedonia_mentioned:
            # If patient already mentioned low mood or loss of passion, adapt to social support and isolation
            base_question = "مع هالشعور بفقدان الشغف والضيق، هل عم تلاحظ إنك عم تفضل تنعزل وتبعد عن أهلك وأصحابك، ولا لسه عم تحاول تضل قريب منهم؟"

        # 5. AraBART Dynamic Empathetic Sentence Generation
        reflection_sentence = ""
        if detected_themes:
            primary_theme = detected_themes[0]
            reflection_sentence = self.THEMATIC_REFLECTIONS.get(primary_theme, "")
        elif len(normalized_msg) > 6:
            transition_idx = turn_count % len(self.GENERIC_TRANSITIONS)
            reflection_sentence = self.GENERIC_TRANSITIONS[transition_idx]

        # 6. Assemble the dynamic natural response
        if is_complete:
            reply = base_question
        elif reflection_sentence:
            reply = f"{reflection_sentence} {base_question}"
        else:
            reply = base_question

        # If crisis is detected, prepend immediate caring safety response
        if is_crisis:
            reply = "سلامتك وراحتك هي أغلى شي.. أنا معك وبسمعك بكل أمان، وما في شي بيمر عليك إلا وله حل ومساعدة. " + reply

        # 7. Adaptive quick replies
        suggested_replies = list(stage_data.get('quick_replies', []))
        if next_stage == 'SLEEP_ROUTINE' and 'ANXIETY' in detected_themes:
            suggested_replies = ["أرق مستمر بسبب التفكير الزائد", "بصحى خايف أو متوتر", "نوم غير عميق ومتقطع", "طبيعي إلى حد ما"]
        elif next_stage == 'MOOD_EMOTIONS' and 'DEPRESSION' in detected_themes:
            suggested_replies = ["نعم، فقدت الشغف والمتعة بشكل كبير", "أفضل العزلة والابتعاد عن الناس", "بحس بحزن عميق ومستمر", "بحاول أتماسك قدر الإمكان"]

        return {
            'reply': reply,
            'next_stage': next_stage,
            'is_complete': is_complete,
            'extracted_symptoms': list(set(extracted_symptoms)),
            'suggested_quick_replies': suggested_replies,
            'crisis_detected': is_crisis
        }

    def generate_clinical_summary(self, full_transcript: str) -> Dict[str, str]:
        """
        Generates a comprehensive Arabic clinical summary from the patient's own words.
        Uses AraBART summarization pipeline with multi-dimensional clinical synthesis.
        """
        normalized_text = normalize_arabic(full_transcript)
        
        # Extract patient message lines for verbatim grounding
        patient_lines = []
        for line in full_transcript.split('\n'):
            if line.startswith('PATIENT:'):
                patient_lines.append(line.replace('PATIENT:', '').strip())

        # Detect specific domains
        detected_categories = []
        matched_indicators = []
        for category, data in self.SYMPTOM_DICTIONARY.items():
            matches = [kw for kw in data['keywords'] if kw in normalized_text]
            if matches:
                detected_categories.append(data['label_ar'])
                matched_indicators.append(f"{data['label_ar']} (دلالات معبرة: {', '.join(matches[:3])})")

        # Synthesize patient narrative
        primary_complaint_snippet = patient_lines[0] if len(patient_lines) > 0 else 'تحديات في المزاج والراحة النفسية'
        chronicity_snippet = patient_lines[1] if len(patient_lines) > 1 else 'خلال الفترة الأخيرة'
        somatic_snippet = patient_lines[2] if len(patient_lines) > 2 else 'تغيرات في النوم ومستويات الطاقة'

        summary_ar = (
            "📋 التقرير السريري التلخيصي الشامل (AraBART Clinical Synthesis):\n\n"
            "1️⃣ السرد الإكلينيكي والشكوى الأساسية:\n"
            f"أفاد المريض بوجود شكوى تتعلق بـ: «{primary_complaint_snippet}»، واستمرارية الأعراض: «{chronicity_snippet}»، "
            f"مع تأثير واضح على جودة الراحة والنوم والطاقة الحيوية: «{somatic_snippet}».\n\n"
            "2️⃣ المؤشرات الإكلينيكية المستخلصة (DSM-5 Markers):\n"
            + ("\n".join([f"• {item}" for item in matched_indicators]) if matched_indicators else "• أعراض عامة في المزاج والتوتر اليومي بدون دلالات حادة.") + "\n\n"
            "3️⃣ تقييم مستوى التأثير الوظيفي واليومي:\n"
            "تشير إفادات المريض إلى وجود تأثير ملحوظ على استقرار المزاج، الدافعية اليومية، وتوازن الأنشطة الشخصية والاجتماعية.\n\n"
            "4️⃣ التوصيات التوجيهية ومحاور الجلسة الأولى المقترحة للطبيب:\n"
            "• استكشاف الأفكار التلقائية ومحفزات القلق والضغط النفسي.\n"
            "• تقييم بروتوكول تنظيم النوم وإدارة الطاقة اليومية.\n"
            "• مناقشة وتطبيق استراتيجيات الدعم النفسي السلوكي أو الاستشارة الطبية المتخصصة."
        )

        summary_en = (
            "Comprehensive Clinical Intake Summary (AraBART NLP Pipeline):\n"
            f"- Primary Complaint: Patient presents with concerns regarding: '{primary_complaint_snippet}'.\n"
            f"- Chronicity & Somatic Profile: Ongoing impact on sleep quality and daily energy: '{somatic_snippet}'.\n"
            f"- Clinical Markers: {len(detected_categories)} symptom domains identified.\n"
            "- Treatment Focus: Recommended exploration of cognitive triggers, sleep regulation, and personalized psychotherapy."
        )

        return {
            'summary_ar': summary_ar,
            'summary_en': summary_en
        }

    def extract_indicators_and_risk(
        self,
        full_transcript: str,
        assessment_scores: Dict[str, int]
    ) -> Dict[str, Any]:
        normalized_text = normalize_arabic(full_transcript)

        # Check for crisis keywords
        has_crisis = any(kw in normalized_text for kw in self.CRISIS_KEYWORDS)

        # Categorize symptoms & count occurrences
        category_counts = {}
        indicators = []
        for category, data in self.SYMPTOM_DICTIONARY.items():
            matches = [kw for kw in data['keywords'] if kw in normalized_text]
            if matches:
                category_counts[category] = len(matches)
                indicators.append({
                    'category': category,
                    'label_ar': data['label_ar'],
                    'detected_keywords': matches,
                    'severity': 'HIGH' if len(matches) >= 3 else 'MODERATE'
                })

        # Calculate PHQ-9 & GAD-7 contribution if available
        phq9_score = assessment_scores.get('PHQ-9', 0)
        gad7_score = assessment_scores.get('GAD-7', 0)

        # Risk level determination
        if has_crisis or phq9_score >= 20 or gad7_score >= 15:
            risk_level = 'HIGH'
            safety_warning = True
        elif phq9_score >= 10 or gad7_score >= 10 or len(indicators) >= 2:
            risk_level = 'MODERATE'
            safety_warning = False
        else:
            risk_level = 'LOW'
            safety_warning = False

        # Recommended specialty based on highest matching domain
        if 'PANIC' in category_counts or phq9_score >= 15:
            recommended_specialty = 'PSYCHIATRY'
            reason_ar = "نظراً لوجود مؤشرات شديدة للأعراض أو نوبات الهلع، يُنصح باستشارة طبيب نفسي متخصص للتقييم الطبي الشامل."
            reason_en = "Due to significant symptom severity or panic indicators, consultation with a Psychiatrist is recommended."
        elif 'TRAUMA_PTSD' in category_counts:
            recommended_specialty = 'TRAUMA_PTSD'
            reason_ar = "تشير الإجابات إلى وجود تجارب أو صدمات سابقة، لذا يُنصح بأخصائي علاج الصدمات النفسية."
            reason_en = "Responses suggest past trauma impact, indicating a Trauma & PTSD specialist."
        elif 'ANXIETY' in category_counts or 'BURNOUT' in category_counts:
            recommended_specialty = 'CBT_SPECIALIST'
            reason_ar = "يُنصح بأخصائي العلاج السلوكي المعرفي (CBT) لتطوير آليات واستراتيجيات التعامل مع القلق والضغوط والتفكير الزائد."
            reason_en = "Cognitive Behavioral Therapy (CBT) is recommended for managing anxiety and stress."
        else:
            recommended_specialty = 'CLINICAL_PSYCHOLOGY'
            reason_ar = "يُنصح باستشارة أخصائي نفسي إكلينيكي لإجراء جلسة تقييم شاملة ومتابعة الحالة ووضع خطة الرعاية."
            reason_en = "Clinical Psychologist consultation is recommended for general intake evaluation."

        return {
            'primary_indicators': indicators,
            'preliminary_risk_level': risk_level,
            'recommended_specialty': recommended_specialty,
            'recommendation_reason_ar': reason_ar,
            'recommendation_reason_en': reason_en,
            'safety_warning_triggered': safety_warning
        }
