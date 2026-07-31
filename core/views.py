from datetime import timedelta

from django.shortcuts import render, redirect, get_object_or_404
from django.http import HttpResponse, FileResponse, Http404
from django.contrib import messages
from django.utils import timezone
from django.core.signing import TimestampSigner, BadSignature, SignatureExpired
from django.core.mail import send_mail
from django.conf import settings
from django.urls import reverse
from django.core.cache import cache

from .forms import StudentIntakeForm, SessionForm, NoteForm, AssignmentForm
from .models import Student, Topic, StudentTopicSelection, Session, Assignment, Note


def get_logged_in_student(request):
    student_id = request.session.get("student_id")
    if student_id:
        return Student.objects.filter(id=student_id).first()
    return None


def starter_pack(request):
    """Registration for new visitors, or private curriculum picker once logged in."""
    logged_in_student = get_logged_in_student(request)

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
            return redirect("portal")

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


def portal(request):
    student = get_logged_in_student(request)
    if not student:
        messages.error(request, "Please log in to view your portal.")
        return redirect("dashboard")
    return render(request, "core/portal.html", {"student": student})


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


def students_overview(request):
    """Teacher-only: see every student's topic picks and notify them it's been noted."""
    logged_in_student = get_logged_in_student(request)
    if not logged_in_student or not logged_in_student.is_teacher:
        messages.error(request, "Please log in as a teacher to view this page.")
        return redirect("dashboard")

    if request.method == "POST" and "notify_student" in request.POST:
        student = get_object_or_404(Student, id=request.POST.get("notify_student"))
        selections = (
            StudentTopicSelection.objects.filter(student=student)
            .select_related("topic")
        )
        if not selections:
            messages.error(request, f"{student.name} has not picked any topics yet.")
            return redirect("students_overview")

        topic_lines = "\n".join(f"- {s.topic.title}" for s in selections)
        send_mail(
            "Your topic selections have been noted - Mtebetiii Seminars and Talks",
            (
                f"Hi {student.name},\n\n"
                f"This is a note to let you know I have seen and noted the topics "
                f"you selected:\n\n{topic_lines}\n\n"
                f"Please reply to this email (or message me on WhatsApp) to let me "
                f"know when you would like to start the learning process, and any "
                f"scheduling preferences you have.\n\n"
                f"Talk soon."
            ),
            getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@example.com"),
            [student.email],
            fail_silently=True,
        )
        student.selections_acknowledged_at = timezone.now()
        student.save(update_fields=["selections_acknowledged_at"])
        messages.success(request, f"Notified {student.name} about their topic selections.")
        return redirect("students_overview")

    students = (
        Student.objects.filter(is_teacher=False)
        .prefetch_related("topic_selections__topic")
        .order_by("-created_at")
    )

    context = {"students": students}
    return render(request, "core/students_overview.html", context)


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
        f"Hi {student.name},\n\nClick this link to log in "
        f"(valid for 15 minutes):\n\n{link}\n",
        getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@example.com"),
        [student.email],
        fail_silently=False,
    )

    messages.success(request, "A login link has been sent to your email. Check your inbox.")
    return redirect("dashboard")


MAX_LOGIN_ATTEMPTS = 5
LOGIN_LOCKOUT_SECONDS = 60 * 15  # 15 minutes


def password_login(request):
    email = request.POST.get("email", "").strip()
    password = request.POST.get("password", "").strip()

    attempts_key = f"login_attempts:{email.lower()}"
    attempts = cache.get(attempts_key, 0)

    if attempts >= MAX_LOGIN_ATTEMPTS:
        messages.error(request, "Too many failed attempts. Please try again in 15 minutes, or use the login link option.")
        return redirect("dashboard")

    student = Student.objects.filter(email__iexact=email).first()
    if not student or not student.check_password(password):
        cache.set(attempts_key, attempts + 1, timeout=LOGIN_LOCKOUT_SECONDS)
        messages.error(request, "Incorrect email or password.")
        return redirect("dashboard")

    cache.delete(attempts_key)
    request.session["student_id"] = student.id
    messages.success(request, f"Welcome back, {student.name}.")
    return redirect("portal")


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
    return redirect("portal")


def dashboard_logout(request):
    request.session.pop("student_id", None)
    messages.success(request, "Logged out.")
    return redirect("dashboard")


def schedule(request):
    """Scheduling requires login. Teachers can book with any student.
    Regular students can only book a session with the teacher, for themselves."""
    logged_in_student = get_logged_in_student(request)
    if not logged_in_student:
        messages.error(request, "Please log in to schedule a session.")
        return redirect("dashboard")

    sessions = Session.objects.select_related("student", "topic").all()
    if not logged_in_student.is_teacher:
        sessions = sessions.filter(student=logged_in_student)

    if request.method == "POST":
        form = SessionForm(request.POST)
        if form.is_valid():
            session = form.save(commit=False)

            if logged_in_student.is_teacher:
                if not session.student_id:
                    messages.error(request, "Please select a student.")
                    context = {"form": form, "sessions": sessions, "is_teacher": True}
                    return render(request, "core/schedule.html", context)
            else:
                session.student = logged_in_student

            session.save()

            teacher = Student.objects.filter(is_teacher=True).first()
            topic_line = f" on {session.topic.title}" if session.topic else ""
            ics_link = request.build_absolute_uri(reverse("session_ics", args=[session.id]))
            details = (
                f"Session with {session.student.name}{topic_line}\n"
                f"When: {session.scheduled_for:%Y-%m-%d %H:%M}\n"
                f"Notes: {session.notes or 'None'}\n\n"
                f"Add to your phone calendar: {ics_link}\n"
            )

            recipients = {session.student.email}
            if teacher:
                recipients.add(teacher.email)

            for recipient in recipients:
                send_mail(
                    "Session scheduled - Mtebetiii Seminars and Talks",
                    details,
                    getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@example.com"),
                    [recipient],
                    fail_silently=True,
                )

            messages.success(request, "Session scheduled. A confirmation email has been sent.")
            return redirect("schedule")
    else:
        form = SessionForm()

    if not logged_in_student.is_teacher:
        form.fields.pop("student", None)
        form.fields.pop("student_email", None)
    all_students = None
    if logged_in_student.is_teacher:
        all_students = list(
            Student.objects.filter(is_teacher=False)
            .prefetch_related("topic_selections")
        )
        for s in all_students:
            s.selected_topic_ids_str = ",".join(
                str(sel.topic_id) for sel in s.topic_selections.all()
            )

    context = {
        "form": form,
        "sessions": sessions,
        "is_teacher": logged_in_student.is_teacher,
        "all_students": all_students,
    }
    return render(request, "core/schedule.html", context)


def session_ics(request, session_id):
    """Download a session as .ics. Only the student on the session, or the teacher, may access it."""
    session = get_object_or_404(Session, id=session_id)
    logged_in_student = get_logged_in_student(request)

    allowed = logged_in_student and (
        logged_in_student.id == session.student_id or logged_in_student.is_teacher
    )
    if not allowed:
        messages.error(request, "Please log in to access that calendar file.")
        return redirect("dashboard")

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
    logged_in_student = get_logged_in_student(request)

    allowed = logged_in_student and (
        logged_in_student.id == session.student_id or logged_in_student.is_teacher
    )
    if not allowed:
        messages.error(request, "Please log in to update that session.")
        return redirect("dashboard")

    session.is_completed = not session.is_completed
    session.save()
    return redirect("schedule")


def notes(request):
    """Anyone logged in can view notes. Only the teacher can upload new ones."""
    logged_in_student = get_logged_in_student(request)
    if logged_in_student and logged_in_student.is_teacher:
        all_notes = Note.objects.select_related("owner").all()
    elif logged_in_student:
        all_notes = Note.objects.select_related("owner").filter(owner=logged_in_student)
    else:
        all_notes = Note.objects.none()

    if request.method == "POST":
        if not (logged_in_student and logged_in_student.is_teacher):
            messages.error(request, "Only the teacher can upload notes.")
            return redirect("notes")
        form = NoteForm(request.POST, request.FILES)
        if form.is_valid():
            note = form.save(commit=False)
            note.owner = logged_in_student
            note.save()
            messages.success(request, "Note uploaded.")
            return redirect("notes")
    else:
        form = NoteForm() if (logged_in_student and logged_in_student.is_teacher) else None

    context = {
        "form": form,
        "notes": all_notes,
        "is_teacher": bool(logged_in_student and logged_in_student.is_teacher),
    }
    return render(request, "core/notes.html", context)


def note_attachment(request, note_id):
    """Serve a note's attachment only to logged-in users."""
    logged_in_student = get_logged_in_student(request)
    if not logged_in_student:
        messages.error(request, "Please log in to view that attachment.")
        return redirect("dashboard")

    note = get_object_or_404(Note, id=note_id)
    if not (logged_in_student.is_teacher or note.owner_id == logged_in_student.id):
        messages.error(request, "You do not have permission to view that attachment.")
        return redirect("notes")
    if not note.attachment:
        raise Http404("No attachment on this note.")

    return FileResponse(note.attachment.open("rb"), as_attachment=False, filename=note.attachment.name.split("/")[-1])


def assignments(request):
    """Login required. Teacher can create assignments for any student; others see/manage only their own."""
    logged_in_student = get_logged_in_student(request)
    if not logged_in_student:
        messages.error(request, "Please log in to view assignments.")
        return redirect("dashboard")

    if logged_in_student.is_teacher:
        all_assignments = Assignment.objects.select_related("student", "topic", "session").all()

        if request.method == "POST":
            form = AssignmentForm(request.POST)
            if form.is_valid():
                form.save()
                messages.success(request, "Assignment created.")
                return redirect("assignments")
        else:
            form = AssignmentForm()
    else:
        all_assignments = Assignment.objects.filter(student=logged_in_student).select_related("topic", "session")
        form = None

    context = {
        "assignments": all_assignments,
        "form": form,
        "is_teacher": logged_in_student.is_teacher,
    }
    return render(request, "core/assignments.html", context)


def toggle_assignment_done(request, assignment_id):
    assignment = get_object_or_404(Assignment, id=assignment_id)
    logged_in_student = get_logged_in_student(request)

    allowed = logged_in_student and (
        logged_in_student.id == assignment.student_id or logged_in_student.is_teacher
    )
    if not allowed:
        messages.error(request, "Please log in to update that assignment.")
        return redirect("dashboard")

    assignment.is_done = not assignment.is_done
    assignment.save()
    return redirect("assignments")
