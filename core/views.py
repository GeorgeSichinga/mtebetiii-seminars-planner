from django.shortcuts import render, redirect, get_object_or_404
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
        if form.is_valid():
            form.save()
            messages.success(request, "Session scheduled.")
            return redirect("schedule")
    else:
        form = SessionForm()

    context = {
        "form": form,
        "sessions": sessions,
    }
    return render(request, "core/schedule.html", context)


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
