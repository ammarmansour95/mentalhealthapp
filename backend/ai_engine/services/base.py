from abc import ABC, abstractmethod
from typing import Dict, Any, List


class BaseAIService(ABC):
    """
    Abstract AI Service Interface following the Strategy Pattern.
    Decouples the application from specific AI models / providers (AraBART, Gemini, OpenAI, LLaMA),
    enabling plug-and-play AI model upgrades as required by Section 22 and Section 34 of the SRS.
    """

    @abstractmethod
    def generate_next_interview_turn(
        self,
        session_id: str,
        current_stage: str,
        turn_count: int,
        conversation_history: List[Dict[str, str]],
        latest_patient_message: str
    ) -> Dict[str, Any]:
        """
        Conducts an adaptive turn in the psychological interview.
        Returns:
            {
                'reply': str,
                'next_stage': str,
                'is_complete': bool,
                'extracted_symptoms': list,
                'suggested_quick_replies': list
            }
        """
        pass

    @abstractmethod
    def generate_clinical_summary(self, full_transcript: str) -> Dict[str, str]:
        """
        Generates an Arabic clinical narrative summary from the full interview transcript.
        Returns:
            {
                'summary_ar': str,
                'summary_en': str
            }
        """
        pass

    @abstractmethod
    def extract_indicators_and_risk(
        self,
        full_transcript: str,
        assessment_scores: Dict[str, int]
    ) -> Dict[str, Any]:
        """
        Extracts condition indicators, calculates preliminary risk level, and suggests specialist.
        Returns:
            {
                'primary_indicators': list,
                'preliminary_risk_level': str,  # 'LOW', 'MODERATE', 'HIGH'
                'recommended_specialty': str,
                'recommendation_reason_ar': str,
                'recommendation_reason_en': str,
                'safety_warning_triggered': bool
            }
        """
        pass
