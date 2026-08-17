from django.urls import path
from appointments.views import MyAppointmentsListView, BookAppointmentView, UpdateAppointmentStatusView

urlpatterns = [
    path('', MyAppointmentsListView.as_view(), name='my-appointments'),
    path('book/', BookAppointmentView.as_view(), name='book-appointment'),
    path('<uuid:pk>/status/', UpdateAppointmentStatusView.as_view(), name='update-appointment-status'),
]
