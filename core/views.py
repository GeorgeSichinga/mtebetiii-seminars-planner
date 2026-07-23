from datetime import timedelta

from django.shortcuts import render, redirect, get_object_or_404
from django.http import HttpResponse
from django.utils import timezone
from django.contrib import messages
from django.db.models import Prefetch

from .forms import StudentIntakeForm, SessionForm, NoteForm
from .models import Student, Topic, StudentTopicSelection, Session, Assignment, Note


def starter_pack(request):
    """Intake form + topic picker."""
    students = Student.objects.all()
    topics = Topic.objects.all()
    tracks = {}
    for topic in topics:
        tracks.setdefault(topic.track, []).append(topic)

    if request.method == "POST":
        form = StudentIntakeForm(request.POST)
        selected_ids = request.POST.getlist("topics")
        if form.is_valid():
            student = form.save()
            for topic_id in selected_ids:
                StudentTopicSelection.objects.get_or_create(
                    student=student, topic_id=topic_id
                )
            messages.success(request, f"Plan created for {student.name}.")
            return redirect("dashboard", student_id=student.id)
    else:
        form = StudentIntakeForm()

    context = {
        "form": form,
        "students": students,
        "tracks": tracks,
        "topic_count": topics.count(),
    }
    return render(request, "core/starter_pack.html", context)


def dashboard(request, student_id=None):
    students = Student.objects.all()
    student = None
    selections = []
    assignments = []

    if student_id:
        student = get_object_or_404(Student, id=student_id)
    elif students.exists():
        student = students.first()

    if student:
        selections = (
            StudentTopicSelection.objects.filter(student=student)
            .select_related("topic")
        )
        assignments = Assignment.objects.filter(student=student)

    context = {
        "students": students,
        "student": student,
        "selections": selections,
        "assignments": assignments,
    }
    return render(request, "core/dashboard.html", context)


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
    """Download a single session as an .ics calendar file."""
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
