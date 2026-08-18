from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('accounts.urls')),
    path('api/assessments/', include('assessments.urls')),
    path('api/ai/', include('ai_engine.urls')),
    path('api/doctors/', include('doctors.urls')),
    path('api/appointments/', include('appointments.urls')),
    path('api/treatment/', include('treatment.urls')),
    path('api/messaging/', include('messaging.urls')),
    path('api/admin/', include('core.urls')),
    path('api/notifications/', include('core.notification_urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
