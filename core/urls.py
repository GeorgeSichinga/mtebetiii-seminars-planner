from django.urls import path
from . import views

urlpatterns = [
    path("", views.starter_pack, name="starter_pack"),
    path("dashboard/", views.dashboard, name="dashboard"),
    path("dashboard/<int:student_id>/", views.dashboard, name="dashboard"),
    path("dashboard/login/request/", views.request_magic_link, name="request_magic_link"),
    path("dashboard/login/<str:token>/", views.dashboard_login, name="dashboard_login"),
    path("dashboard/logout/", views.dashboard_logout, name="dashboard_logout"),
    path("schedule/", views.schedule, name="schedule"),
    path("notes/", views.notes, name="notes"),
    path("schedule/<int:session_id>/toggle/", views.toggle_session_complete, name="toggle_session_complete"),
    path("schedule/<int:session_id>/calendar.ics", views.session_ics, name="session_ics"),
]
