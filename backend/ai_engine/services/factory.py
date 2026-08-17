from django.conf import settings
from ai_engine.services.base import BaseAIService
from ai_engine.services.arabart_service import AraBARTAssessmentService

_service_instance = None


def get_ai_service() -> BaseAIService:
    """
    Factory function returning the configured AI Service.
    Easily configurable to switch between AraBART, Gemini, OpenAI, or hybrid LLM providers.
    """
    global _service_instance
    if _service_instance is None:
        provider = getattr(settings, 'AI_PROVIDER', 'arabart').lower()
        if provider == 'arabart':
            _service_instance = AraBARTAssessmentService()
        else:
            # Fallback to AraBART service
            _service_instance = AraBARTAssessmentService()
    return _service_instance
