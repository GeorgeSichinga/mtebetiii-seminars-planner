from datetime import timedelta

from django.shortcuts import render, redirect, get_object_or_404
from django.http import HttpResponse
from django.contrib import messages
from django.utils import timezone
from django.core.signing import TimestampSigner, BadSignature, SignatureExpired
from django.core.mail import send_mail
from django.conf import settings
from django.urls import reverse

from .forms import StudentIntakeForm, SessionForm, NoteForm
from .models import Student, Topic, StudentTopicSelection, Session, Assignment, Note


def starter_pack(request):
    """Registration for new visitors, or private curriculum picker once logged in."""
    logged_in_student = None
    student_id_in_session = request.session.get("student_id")
    if student_id_in_session:
        logged_in_student = Student.objects.filter(id=student_id_in_session).first()

    topics = Topic.objects.all()
    tracks = {}
    for topic in topics:
        tracks.setdefault(topic.track, []).append(topic)

    if logged_in_student:
        if request.method == "POST" and "save_topics" in request.POST:
            selected_ids = set(int(i) for i in request.POST.getlist("topics"))
            existing_ids = set(
                StudentTopicSelection.objects.filter(student=logged_in_student)
                .values_list("topic_id", flat=True)
            )
            for topic_id in selected_ids - existing_ids:
                StudentTopicSelection.objects.get_or_create(
                    student=logged_in_student, topic_id=topic_id
                )
            StudentTopicSelection.objects.filter(
                student=logged_in_student
            ).exclude(topic_id__in=selected_ids).delete()
            messages.success(request, "Your curriculum has been updated.")
            return redirect("starter_pack")

        if request.method == "POST" and "set_password" in request.POST:
            new_password = request.POST.get("new_password", "").strip()
            if len(new_password) < 6:
                messages.error(request, "Password must be at least 6 characters.")
            else:
                logged_in_student.set_password(new_password)
                logged_in_student.save(update_fields=["password_hash"])
                messages.success(request, "Password set. You can now log in with it next time.")
            return redirect("starter_pack")

        selected_topic_ids = set(
            StudentTopicSelection.objects.filter(student=logged_in_student)
            .values_list("topic_id", flat=True)
        )
        context = {
            "student": logged_in_student,
            "tracks": tracks,
            "topic_count": topics.count(),
            "selected_topic_ids": selected_topic_ids,
            "has_password": bool(logged_in_student.password_hash),
        }
        return render(request, "core/starter_pack.html", context)

    if request.method == "POST":
        form = StudentIntakeForm(request.POST)
        if form.is_valid():
            student = form.save()
            request.session["student_id"] = student.id
            messages.success(request, f"Welcome, {student.name}. Now pick the topics you want to cover.")
            return redirect("starter_pack")
    else:
        form = StudentIntakeForm()

    context = {
        "student": None,
        "form": form,
        "topic_count": topics.count(),
    }
    return render(request, "core/starter_pack.html", context)


SIGNER = TimestampSigner(salt="mtebetiii-dashboard-login")
MAGIC_LINK_MAX_AGE = 60 * 15  # 15 minutes


def dashboard(request, student_id=None):
    student = None
    selections = []
    assignments = []

    if student_id:
        candidate = get_object_or_404(Student, id=student_id)
        if request.session.get("student_id") == candidate.id:
            student = candidate
        else:
            messages.error(request, "Please log in to view that dashboard.")
            return redirect("dashboard")

    if student:
        selections = (
            StudentTopicSelection.objects.filter(student=student)
            .select_related("topic")
        )
        assignments = Assignment.objects.filter(student=student)

    context = {
        "student": student,
        "selections": selections,
        "assignments": assignments,
    }
    return render(request, "core/dashboard.html", context)


def request_magic_link(request):
    email = request.POST.get("email", "").strip()
    if not email:
        messages.error(request, "Please enter your registered email.")
        return redirect("dashboard")

    student = Student.objects.filter(email__iexact=email).first()
    if not student:
        messages.error(request, "No student found with that email. Register on the Starter Pack page first.")
        return redirect("dashboard")

    token = SIGNER.sign(str(student.id))
    link = request.build_absolute_uri(reverse("dashboard_login", args=[token]))

    send_mail(
        "Your dashboard login link",
        f"Hi {student.name},\n\nClick this link to view your dashboard "
        f"(valid for 15 minutes):\n\n{link}\n",
        getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@example.com"),
        [student.email],
        fail_silently=False,
    )

    messages.success(request, "A login link has been sent to your email. Check your inbox.")
    return redirect("dashboard")


def password_login(request):
    email = request.POST.get("email", "").strip()
    password = request.POST.get("password", "").strip()

    student = Student.objects.filter(email__iexact=email).first()
    if not student or not student.check_password(password):
        messages.error(request, "Incorrect email or password.")
        return redirect("dashboard")

    request.session["student_id"] = student.id
    messages.success(request, f"Welcome back, {student.name}.")
    return redirect("dashboard", student_id=student.id)


def dashboard_login(request, token):
    try:
        student_id = int(SIGNER.unsign(token, max_age=MAGIC_LINK_MAX_AGE))
    except SignatureExpired:
        messages.error(request, "That login link has expired. Please request a new one.")
        return redirect("dashboard")
    except BadSignature:
        messages.error(request, "That login link is invalid.")
        return redirect("dashboard")

    student = get_object_or_404(Student, id=student_id)
    request.session["student_id"] = student.id
    messages.success(request, f"Welcome back, {student.name}.")
    return redirect("dashboard", student_id=student.id)


def dashboard_logout(request):
    request.session.pop("student_id", None)
    messages.success(request, "Logged out.")
    return redirect("dashboard")


def schedule(request):
    sessions = Session.objects.select_related("student", "topic").all()

    if request.method == "POST":
        form = SessionForm(request.POST)
        role = request.POST.get("role", "teacher")

        if form.is_valid():
            session = form.save(commit=False)

            if role == "student" and not session.student_id:
                email = form.cleaned_data.get("student_email", "").strip()
                try:
                    session.student = Student.objects.get(email__iexact=email)
                except Student.DoesNotExist:
                    messages.error(
                        request,
                        "We could not find a student with that email. "
                        "Register on the Starter Pack page first."
                    )
                    context = {"form": form, "sessions": sessions}
                    return render(request, "core/schedule.html", context)

            if not session.student_id:
                messages.error(request, "Please select a student, or provide your registered email.")
                context = {"form": form, "sessions": sessions}
                return render(request, "core/schedule.html", context)

            session.save()
            messages.success(request, "Session scheduled.")
            return redirect("schedule")
    else:
        form = SessionForm()

    context = {
        "form": form,
        "sessions": sessions,
    }
    return render(request, "core/schedule.html", context)


def session_ics(request, session_id):
    session = get_object_or_404(Session, id=session_id)

    start = session.scheduled_for
    end = start + timedelta(hours=1)

    def fmt(dt):
        return dt.strftime("%Y%m%dT%H%M%S")

    topic_line = f" - {session.topic.title}" if session.topic else ""
    summary = f"Session with {session.student.name}{topic_line}"
    description = (session.notes or "").replace("\n", "\\n").replace(",", "\\,")

    ics_content = (
        "BEGIN:VCALENDAR\r\n"
        "VERSION:2.0\r\n"
        "PRODID:-//Mtebetiii Seminars and Talks//EN\r\n"
        "BEGIN:VEVENT\r\n"
        f"UID:session-{session.id}@mtebetiii-seminars\r\n"
        f"DTSTAMP:{fmt(timezone.now())}\r\n"
        f"DTSTART:{fmt(start)}\r\n"
        f"DTEND:{fmt(end)}\r\n"
        f"SUMMARY:{summary}\r\n"
        f"DESCRIPTION:{description}\r\n"
        "END:VEVENT\r\n"
        "END:VCALENDAR\r\n"
    )

    response = HttpResponse(ics_content, content_type="text/calendar")
    response["Content-Disposition"] = f'attachment; filename="session-{session.id}.ics"'
    return response


def toggle_session_complete(request, session_id):
    session = get_object_or_404(Session, id=session_id)
    session.is_completed = not session.is_completed
    session.save()
    return redirect("schedule")


def notes(request):
    all_notes = Note.objects.all()

    if request.method == "POST":
        form = NoteForm(request.POST, request.FILES)
        if form.is_valid():
            form.save()
            messages.success(request, "Note uploaded.")
            return redirect("notes")
    else:
        form = NoteForm()

    context = {
        "form": form,
        "notes": all_notes,
    }
    return render(request, "core/notes.html", context)
