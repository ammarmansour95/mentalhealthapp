import os
import threading
from django.apps import AppConfig


class AiEngineConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'ai_engine'

    def ready(self):
        # Warm up MARBERTv2 weights asynchronously on server boot so the first patient response is instantaneous
        if os.environ.get('RUN_MAIN') == 'true':
            def _warmup():
                try:
                    from ai_engine.services.factory import get_ai_service
                    svc = get_ai_service()
                    svc.get_nlp_engine()
                except Exception:
                    pass

            thread = threading.Thread(target=_warmup, daemon=True, name="MARBERT-Warmup")
            thread.start()
