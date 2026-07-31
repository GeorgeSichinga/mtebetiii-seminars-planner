from django.urls import path
from . import views


def trigger_error(request):
    division_by_zero = 1 / 0


def sentry_check(request):
    from django.conf import settings
    from django.http import HttpResponse
    import sentry_sdk

    dsn = getattr(settings, "SENTRY_DSN", "")
    client = sentry_sdk.get_client()
    is_active = client.is_active()

    if is_active:
        sentry_sdk.capture_message("Manual test message from /sentry-check/")
        return HttpResponse(
            f"SENTRY_DSN present: yes. SDK client active: {is_active}. "
            f"Test message sent - check Sentry Issues tab for 'Manual test message from /sentry-check/'."
        )
    return HttpResponse(
        f"SENTRY_DSN present: {bool(dsn)}. SDK client active: {is_active}. "
        f"The SDK did not initialize even though DSN is set - check for an exception during sentry_sdk.init() at startup."
    )


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