"""
Legacy alias module redirecting AraBART service calls to the upgraded MARBERTv2 service.
Maintains full backward compatibility across legacy routes, serializers, and tests.
"""
from ai_engine.services.marbert_service import (
    MARBERTAssessmentService as AraBARTAssessmentService,
    MARBERTAssessmentService,
    normalize_arabic
)

__all__ = ['AraBARTAssessmentService', 'MARBERTAssessmentService', 'normalize_arabic']
