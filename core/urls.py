from django.urls import path
from . import views

urlpatterns = [
    path("", views.starter_pack, name="starter_pack"),
    path("dashboard/", views.dashboard, name="dashboard"),
    path("dashboard/<int:student_id>/", views.dashboard, name="dashboard"),
    path("schedule/", views.schedule, name="schedule"),
    path("notes/", views.notes, name="notes"),
    path("schedule/<int:session_id>/toggle/", views.toggle_session_complete, name="toggle_session_complete"),
    path("schedule/<int:session_id>/calendar.ics", views.session_ics, name="session_ics"),
]
