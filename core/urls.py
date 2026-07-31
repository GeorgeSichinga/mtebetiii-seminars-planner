from django.urls import path
from . import views


def trigger_error(request):
    division_by_zero = 1 / 0


def sentry_check(request):
    from django.conf import settings
    from django.http import HttpResponse
    dsn = getattr(settings, "SENTRY_DSN", "")
    if dsn:
        return HttpResponse(f"SENTRY_DSN is set, starts with: {dsn[:20]}...")
    return HttpResponse("SENTRY_DSN is NOT set (empty string)")


urlpatterns = [
    path("sentry-debug/", trigger_error),
    path("sentry-check/", sentry_check),
    path("", views.starter_pack, name="starter_pack"),
    path("portal/", views.portal, name="portal"),
    path("dashboard/", views.dashboard, name="dashboard"),
    path("dashboard/<int:student_id>/", views.dashboard, name="dashboard"),
    path("dashboard/login/request/", views.request_magic_link, name="request_magic_link"),
    path("dashboard/login/password/", views.password_login, name="password_login"),
    path("dashboard/login/<str:token>/", views.dashboard_login, name="dashboard_login"),
    path("dashboard/logout/", views.dashboard_logout, name="dashboard_logout"),
    path("schedule/", views.schedule, name="schedule"),
    path("notes/", views.notes, name="notes"),
    path("assignments/", views.assignments, name="assignments"),
    path("assignments/<int:assignment_id>/toggle/", views.toggle_assignment_done, name="toggle_assignment_done"),
    path("notes/<int:note_id>/attachment/", views.note_attachment, name="note_attachment"),
    path("schedule/<int:session_id>/toggle/", views.toggle_session_complete, name="toggle_session_complete"),
    path("schedule/<int:session_id>/calendar.ics", views.session_ics, name="session_ics"),
]