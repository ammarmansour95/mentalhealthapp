from django.conf import settings
from ai_engine.services.base import BaseAIService
from ai_engine.services.marbert_service import MARBERTAssessmentService

_service_instance = None


def get_ai_service() -> BaseAIService:
    """
    Factory function returning the configured AI Service.
    Defaults to the fine-tuned MARBERTv2 Deep Learning sequence classifier.
    """
    global _service_instance
    if _service_instance is None:
        provider = getattr(settings, 'AI_PROVIDER', 'marbert').lower()
        if provider in ('marbert', 'arabert', 'arabart'):
            _service_instance = MARBERTAssessmentService()
        else:
            _service_instance = MARBERTAssessmentService()
    return _service_instance
