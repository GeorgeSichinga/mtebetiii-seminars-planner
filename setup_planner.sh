#!/usr/bin/env bash
# Run this from inside "planner website/" (same folder as manage.py)
# It writes/overwrites: core/models.py, core/forms.py, core/views.py, core/urls.py,
# core/admin.py, core/management/commands/*.py, templates/*.html, data_notebook/urls.py
# It does NOT touch settings.py or db.sqlite3 automatically — see printed instructions at the end.

set -e

echo "Scaffolding Data Notebook Planner..."

mkdir -p core/management/commands
mkdir -p core/templates/core
mkdir -p templates/core

# Remove stray legacy file if present
if [ -f "core/url.py" ]; then
  echo "Removing stray core/url.py (legacy duplicate of core/urls.py)"
  rm core/url.py
fi

# ---------------------------------------------------------------------------
# core/models.py
# ---------------------------------------------------------------------------
cat > core/models.py << 'EOF'
from django.db import models
from django.utils import timezone


class Student(models.Model):
    name = models.CharField(max_length=150)
    email = models.EmailField(unique=True)
    background_notes = models.TextField(
        blank=True,
        help_text="Background, prior experience, and learning goals."
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class Topic(models.Model):
    TRACK_CHOICES = [
        ("stata", "Stata"),
        ("r", "R"),
        ("python", "Python"),
        ("capstone", "Capstone"),
    ]

    title = models.CharField(max_length=200)
    track = models.CharField(max_length=20, choices=TRACK_CHOICES)
    description = models.TextField(blank=True)
    order = models.PositiveIntegerField(default=0, help_text="Order within track.")

    class Meta:
        ordering = ["track", "order", "title"]

    def __str__(self):
        return f"{self.get_track_display()} #{self.order}: {self.title}"


class StudentTopicSelection(models.Model):
    student = models.ForeignKey(
        Student, on_delete=models.CASCADE, related_name="topic_selections"
    )
    topic = models.ForeignKey(
        Topic, on_delete=models.CASCADE, related_name="selections"
    )
    selected_at = models.DateTimeField(auto_now_add=True)
    completed = models.BooleanField(default=False)

    class Meta:
        unique_together = ("student", "topic")
        ordering = ["topic__track", "topic__order"]

    def __str__(self):
        return f"{self.student.name} - {self.topic.title}"


class Session(models.Model):
    student = models.ForeignKey(
        Student, on_delete=models.CASCADE, related_name="sessions"
    )
    topic = models.ForeignKey(
        Topic, on_delete=models.SET_NULL, null=True, blank=True, related_name="sessions"
    )
    scheduled_for = models.DateTimeField()
    notes = models.TextField(blank=True)
    is_completed = models.BooleanField(default=False)
    reminder_sent = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["scheduled_for"]

    def __str__(self):
        return f"Session: {self.student.name} @ {self.scheduled_for:%Y-%m-%d %H:%M}"

    @property
    def is_upcoming(self):
        return not self.is_completed and self.scheduled_for >= timezone.now()


class Assignment(models.Model):
    student = models.ForeignKey(
        Student, on_delete=models.CASCADE, related_name="assignments"
    )
    session = models.ForeignKey(
        Session, on_delete=models.SET_NULL, null=True, blank=True, related_name="assignments"
    )
    topic = models.ForeignKey(
        Topic, on_delete=models.SET_NULL, null=True, blank=True, related_name="assignments"
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    due_date = models.DateField(null=True, blank=True)
    is_done = models.BooleanField(default=False)

    class Meta:
        ordering = ["due_date", "title"]

    def __str__(self):
        return self.title
EOF

# ---------------------------------------------------------------------------
# core/forms.py
# ---------------------------------------------------------------------------
cat > core/forms.py << 'EOF'
from django import forms
from .models import Student, Session, Topic


class StudentIntakeForm(forms.ModelForm):
    class Meta:
        model = Student
        fields = ["name", "email", "background_notes"]
        widgets = {
            "name": forms.TextInput(attrs={
                "class": "w-full border border-gray-300 rounded-md px-3 py-2",
                "placeholder": "Full Name",
            }),
            "email": forms.EmailInput(attrs={
                "class": "w-full border border-gray-300 rounded-md px-3 py-2",
                "placeholder": "Email Address",
            }),
            "background_notes": forms.Textarea(attrs={
                "class": "w-full border border-gray-300 rounded-md px-3 py-2",
                "rows": 4,
                "placeholder": "Background / Learning Goals",
            }),
        }


class TopicSelectionForm(forms.Form):
    topics = forms.ModelMultipleChoiceField(
        queryset=Topic.objects.all(),
        widget=forms.CheckboxSelectMultiple,
        required=False,
    )


class SessionForm(forms.ModelForm):
    class Meta:
        model = Session
        fields = ["student", "topic", "scheduled_for", "notes"]
        widgets = {
            "student": forms.Select(attrs={"class": "w-full border border-gray-300 rounded-md px-3 py-2"}),
            "topic": forms.Select(attrs={"class": "w-full border border-gray-300 rounded-md px-3 py-2"}),
            "scheduled_for": forms.DateTimeInput(
                attrs={"type": "datetime-local", "class": "w-full border border-gray-300 rounded-md px-3 py-2"}
            ),
            "notes": forms.Textarea(attrs={"class": "w-full border border-gray-300 rounded-md px-3 py-2", "rows": 3}),
        }
EOF

# ---------------------------------------------------------------------------
# core/admin.py
# ---------------------------------------------------------------------------
cat > core/admin.py << 'EOF'
from django.contrib import admin
from .models import Student, Topic, StudentTopicSelection, Session, Assignment


@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display = ("name", "email", "created_at")
    search_fields = ("name", "email")


@admin.register(Topic)
class TopicAdmin(admin.ModelAdmin):
    list_display = ("title", "track", "order")
    list_filter = ("track",)
    ordering = ("track", "order")


@admin.register(StudentTopicSelection)
class StudentTopicSelectionAdmin(admin.ModelAdmin):
    list_display = ("student", "topic", "completed", "selected_at")
    list_filter = ("completed", "topic__track")


@admin.register(Session)
class SessionAdmin(admin.ModelAdmin):
    list_display = ("student", "topic", "scheduled_for", "is_completed", "reminder_sent")
    list_filter = ("is_completed", "reminder_sent")


@admin.register(Assignment)
class AssignmentAdmin(admin.ModelAdmin):
    list_display = ("title", "student", "due_date", "is_done")
    list_filter = ("is_done",)
EOF

# ---------------------------------------------------------------------------
# core/views.py
# ---------------------------------------------------------------------------
cat > core/views.py << 'EOF'
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.db.models import Prefetch

from .forms import StudentIntakeForm, SessionForm
from .models import Student, Topic, StudentTopicSelection, Session, Assignment


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
EOF

# ---------------------------------------------------------------------------
# core/urls.py
# ---------------------------------------------------------------------------
cat > core/urls.py << 'EOF'
from django.urls import path
from . import views

urlpatterns = [
    path("", views.starter_pack, name="starter_pack"),
    path("dashboard/", views.dashboard, name="dashboard"),
    path("dashboard/<int:student_id>/", views.dashboard, name="dashboard"),
    path("schedule/", views.schedule, name="schedule"),
    path("schedule/<int:session_id>/toggle/", views.toggle_session_complete, name="toggle_session_complete"),
]
EOF

# ---------------------------------------------------------------------------
# data_notebook/urls.py
# ---------------------------------------------------------------------------
cat > data_notebook/urls.py << 'EOF'
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path("admin/", admin.site.urls),
    path("", include("core.urls")),
]
EOF

# ---------------------------------------------------------------------------
# core/management/commands/seed_topics.py
# ---------------------------------------------------------------------------
cat > core/management/commands/seed_topics.py << 'EOF'
from django.core.management.base import BaseCommand
from core.models import Topic

TOPICS = [
    ("capstone", 1, "Research Question & Data Strategy",
     "Defining empirical strategies and data collection methodology."),
    ("capstone", 2, "Final Applied Mini-Project",
     "Executing an end-to-end data analysis workflow in chosen tool."),

    ("python", 1, "Python for Data Analysis (Pandas/NumPy)",
     "Series, DataFrames, indexing, and array computations."),
    ("python", 2, "Data Cleaning & Exploratory Analysis",
     "Handling missing data, grouping, aggregations, and transforming columns."),
    ("python", 3, "Visualization (Matplotlib/Seaborn)",
     "Designing informative charts and spatial/trend visualizations."),
    ("python", 4, "Intro to Scikit-Learn",
     "Supervised learning pipelines for regression and classification."),
    ("python", 5, "Geospatial & Remote Sensing Workflows",
     "Working with spatial data vectors and environmental datasets."),

    ("r", 1, "R & Tidyverse Foundations",
     "RStudio orientation, vectors, data frames, and dplyr wrangling."),
    ("r", 2, "Data Visualization with ggplot2",
     "Building layered publication-quality charts and economic plots."),
    ("r", 3, "Linear Regression & Model Diagnostics",
     "Fitting lm() models, diagnostic plots, and heteroskedasticity corrections."),
    ("r", 4, "Reproducible Research with R Markdown",
     "Dynamic document generation combining code, outputs, and text."),
    ("r", 5, "Intro to Machine Learning in R",
     "Basic decision trees and classification models."),

    ("stata", 1, "Data Management Basics",
     "Importing, cleaning, merging, reshaping, and labeling variables."),
    ("stata", 2, "Descriptive Statistics & Tabulation",
     "Summary tables, cross-tabulations, and data exploration."),
    ("stata", 3, "OLS Regression Fundamentals",
     "Running linear regressions, interpreting coefficients, and robust standard errors."),
    ("stata", 4, "Panel Data Setup & Pooled OLS",
     "Structuring panel data using xtset and baseline panel models."),
    ("stata", 5, "Fixed Effects vs. Random Effects",
     "Implementing xtreg, FE vs RE specification, and Hausman testing."),
    ("stata", 6, "Instrumental Variables (2SLS)",
     "Addressing endogeneity with ivregress and diagnostic tests."),
    ("stata", 7, "Publication-Ready Tables",
     "Exporting formatted regression and summary tables using esttab/outreg2."),
]


class Command(BaseCommand):
    help = "Seeds the default topic catalogue (Stata, R, Python, Capstone tracks)."

    def handle(self, *args, **options):
        created_count = 0
        for track, order, title, description in TOPICS:
            _, created = Topic.objects.get_or_create(
                track=track,
                order=order,
                title=title,
                defaults={"description": description},
            )
            if created:
                created_count += 1
        self.stdout.write(self.style.SUCCESS(
            f"Seeded topics. {created_count} new topic(s) created, "
            f"{len(TOPICS) - created_count} already existed."
        ))
EOF

# ---------------------------------------------------------------------------
# core/management/commands/send_reminders.py
# ---------------------------------------------------------------------------
cat > core/management/commands/send_reminders.py << 'EOF'
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone

from core.models import Session


class Command(BaseCommand):
    help = "Sends email reminders for sessions scheduled in the next 24 hours."

    def add_arguments(self, parser):
        parser.add_argument(
            "--hours-ahead",
            type=int,
            default=24,
            help="How many hours ahead to look for upcoming sessions (default: 24).",
        )

    def handle(self, *args, **options):
        hours_ahead = options["hours_ahead"]
        now = timezone.now()
        window_end = now + timedelta(hours=hours_ahead)

        sessions = Session.objects.filter(
            scheduled_for__gte=now,
            scheduled_for__lte=window_end,
            reminder_sent=False,
            is_completed=False,
        ).select_related("student", "topic")

        sent_count = 0
        for session in sessions:
            subject = "Upcoming Session Reminder"
            topic_line = f" on {session.topic.title}" if session.topic else ""
            message = (
                f"Hi {session.student.name},\n\n"
                f"This is a reminder of your upcoming session{topic_line}, "
                f"scheduled for {session.scheduled_for:%Y-%m-%d %H:%M}.\n\n"
                f"Notes: {session.notes or 'None'}\n"
            )
            send_mail(
                subject,
                message,
                getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@example.com"),
                [session.student.email],
                fail_silently=False,
            )
            session.reminder_sent = True
            session.save(update_fields=["reminder_sent"])
            sent_count += 1

        self.stdout.write(self.style.SUCCESS(f"Sent {sent_count} reminder(s)."))
EOF

# ---------------------------------------------------------------------------
# templates/base.html
# ---------------------------------------------------------------------------
cat > templates/base.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{% block title %}Data Notebook Planner{% endblock %}</title>
<script src="https://cdn.tailwindcss.com"></script>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Source+Serif+4:wght@400;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  body { font-family: 'Inter', sans-serif; background-color: #faf9f6; }
  .font-serif-custom { font-family: 'Source Serif 4', serif; }
</style>
</head>
<body class="text-gray-900">
<nav class="bg-white border-b border-gray-200">
  <div class="max-w-5xl mx-auto px-4 py-4 flex items-center justify-between">
    <a href="{% url 'starter_pack' %}" class="font-serif-custom text-xl font-semibold">📚 Data Notebook Planner</a>
    <div class="space-x-4 text-sm">
      <a href="{% url 'starter_pack' %}" class="hover:underline">Starter Pack</a>
      <a href="{% url 'dashboard' %}" class="hover:underline">Dashboard</a>
      <a href="{% url 'schedule' %}" class="hover:underline">Schedule</a>
    </div>
  </div>
</nav>

<main class="max-w-5xl mx-auto px-4 py-8">
  {% if messages %}
    {% for message in messages %}
      <div class="mb-4 px-4 py-2 rounded-md bg-green-50 border border-green-200 text-green-800 text-sm">
        {{ message }}
      </div>
    {% endfor %}
  {% endif %}
  {% block content %}{% endblock %}
</main>
</body>
</html>
EOF

# ---------------------------------------------------------------------------
# templates/core/starter_pack.html
# ---------------------------------------------------------------------------
cat > templates/core/starter_pack.html << 'EOF'
{% extends "base.html" %}
{% block title %}Starter Pack{% endblock %}
{% block content %}
<div class="grid md:grid-cols-2 gap-8">
  <div class="bg-white rounded-lg border border-gray-200 p-6">
    <h2 class="font-serif-custom text-lg font-semibold mb-4">Create Student Planner</h2>
    <form method="post">
      {% csrf_token %}
      <div class="space-y-3 mb-4">
        {{ form.name.label_tag }} {{ form.name }}
        {{ form.email.label_tag }} {{ form.email }}
        {{ form.background_notes.label_tag }} {{ form.background_notes }}
      </div>

      <h3 class="font-serif-custom font-semibold mb-2">Course Curriculum &amp; Topics</h3>
      <p class="text-sm text-gray-500 mb-3">{{ topic_count }} Topics Loaded</p>

      {% for track, topics in tracks.items %}
        <div class="mb-4">
          <p class="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2">{{ track }}</p>
          {% for topic in topics %}
            <label class="flex items-start gap-2 mb-2 text-sm">
              <input type="checkbox" name="topics" value="{{ topic.id }}" class="mt-1">
              <span>
                <span class="font-medium">#{{ topic.order }} {{ topic.title }}</span>
                <span class="block text-gray-500">{{ topic.description }}</span>
              </span>
            </label>
          {% endfor %}
        </div>
      {% endfor %}

      <button type="submit" class="bg-gray-900 text-white px-4 py-2 rounded-md text-sm">
        Save &amp; Start Plan
      </button>
    </form>
  </div>

  <div class="bg-white rounded-lg border border-gray-200 p-6">
    <h2 class="font-serif-custom text-lg font-semibold mb-4">Enrolled Students ({{ students.count }})</h2>
    {% if students %}
      <ul class="space-y-2">
        {% for s in students %}
          <li>
            <a href="{% url 'dashboard' student_id=s.id %}" class="text-sm hover:underline">{{ s.name }} &mdash; {{ s.email }}</a>
          </li>
        {% endfor %}
      </ul>
    {% else %}
      <p class="text-sm text-gray-500">No students registered yet.</p>
    {% endif %}
  </div>
</div>
{% endblock %}
EOF

# ---------------------------------------------------------------------------
# templates/core/dashboard.html
# ---------------------------------------------------------------------------
cat > templates/core/dashboard.html << 'EOF'
{% extends "base.html" %}
{% block title %}Dashboard{% endblock %}
{% block content %}
<div class="mb-6">
  <label class="text-sm text-gray-500">Viewing student:</label>
  <select onchange="window.location = '/dashboard/' + this.value + '/'" class="border border-gray-300 rounded-md px-2 py-1 text-sm">
    {% for s in students %}
      <option value="{{ s.id }}" {% if student and s.id == student.id %}selected{% endif %}>{{ s.name }}</option>
    {% endfor %}
  </select>
</div>

{% if student %}
  <div class="bg-white rounded-lg border border-gray-200 p-6 mb-6">
    <h2 class="font-serif-custom text-lg font-semibold">{{ student.name }}</h2>
    <p class="text-sm text-gray-500">{{ student.email }}</p>
    {% if student.background_notes %}
      <p class="text-sm mt-2">{{ student.background_notes }}</p>
    {% endif %}
  </div>

  <div class="grid md:grid-cols-2 gap-6">
    <div class="bg-white rounded-lg border border-gray-200 p-6">
      <h3 class="font-serif-custom font-semibold mb-3">Selected Topics ({{ selections|length }})</h3>
      <ul class="space-y-2 text-sm">
        {% for sel in selections %}
          <li class="flex items-center justify-between">
            <span>{{ sel.topic.title }}</span>
            <span class="text-xs px-2 py-0.5 rounded-full {% if sel.completed %}bg-green-100 text-green-700{% else %}bg-gray-100 text-gray-500{% endif %}">
              {% if sel.completed %}Done{% else %}Pending{% endif %}
            </span>
          </li>
        {% empty %}
          <li class="text-gray-500">No topics selected yet.</li>
        {% endfor %}
      </ul>
    </div>

    <div class="bg-white rounded-lg border border-gray-200 p-6">
      <h3 class="font-serif-custom font-semibold mb-3">Assignments ({{ assignments|length }})</h3>
      <ul class="space-y-2 text-sm">
        {% for a in assignments %}
          <li class="flex items-center justify-between">
            <span>{{ a.title }}</span>
            <span class="text-xs text-gray-500">{{ a.due_date|default:"No due date" }}</span>
          </li>
        {% empty %}
          <li class="text-gray-500">No assignments yet.</li>
        {% endfor %}
      </ul>
    </div>
  </div>
{% else %}
  <p class="text-gray-500">No students registered yet. <a href="{% url 'starter_pack' %}" class="underline">Create one</a>.</p>
{% endif %}
{% endblock %}
EOF

# ---------------------------------------------------------------------------
# templates/core/schedule.html
# ---------------------------------------------------------------------------
cat > templates/core/schedule.html << 'EOF'
{% extends "base.html" %}
{% block title %}Schedule{% endblock %}
{% block content %}
<div class="grid md:grid-cols-2 gap-8">
  <div class="bg-white rounded-lg border border-gray-200 p-6">
    <h2 class="font-serif-custom text-lg font-semibold mb-4">Plan a Session</h2>
    <form method="post" class="space-y-3">
      {% csrf_token %}
      {{ form.student.label_tag }} {{ form.student }}
      {{ form.topic.label_tag }} {{ form.topic }}
      {{ form.scheduled_for.label_tag }} {{ form.scheduled_for }}
      {{ form.notes.label_tag }} {{ form.notes }}
      <button type="submit" class="bg-gray-900 text-white px-4 py-2 rounded-md text-sm">Schedule Session</button>
    </form>
  </div>

  <div class="bg-white rounded-lg border border-gray-200 p-6">
    <h2 class="font-serif-custom text-lg font-semibold mb-4">Upcoming &amp; Past Sessions</h2>
    <ul class="space-y-3 text-sm">
      {% for session in sessions %}
        <li class="flex items-center justify-between border-b border-gray-100 pb-2">
          <div>
            <p class="font-medium">{{ session.student.name }}{% if session.topic %} &mdash; {{ session.topic.title }}{% endif %}</p>
            <p class="text-gray-500">{{ session.scheduled_for }}</p>
          </div>
          <form method="post" action="{% url 'toggle_session_complete' session.id %}">
            {% csrf_token %}
            <button type="submit" class="text-xs px-2 py-1 rounded-full {% if session.is_completed %}bg-green-100 text-green-700{% else %}bg-gray-100 text-gray-600{% endif %}">
              {% if session.is_completed %}Completed{% else %}Mark Done{% endif %}
            </button>
          </form>
        </li>
      {% empty %}
        <li class="text-gray-500">No sessions scheduled yet.</li>
      {% endfor %}
    </ul>
  </div>
</div>
{% endblock %}
EOF

echo ""
echo "Done. Files written."
echo ""
echo "-------------------------------------------------------------"
echo "MANUAL STEPS (settings.py) - do these once:"
echo "-------------------------------------------------------------"
echo "1. In data_notebook/settings.py, make sure INSTALLED_APPS includes 'core',"
echo "   and TEMPLATES[0]['DIRS'] includes BASE_DIR / 'templates'."
echo "2. For email (send_reminders command), add for local dev:"
echo "     EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'"
echo "     DEFAULT_FROM_EMAIL = 'planner@example.com'"
echo "-------------------------------------------------------------"
echo "THEN RUN:"
echo "  python manage.py makemigrations core"
echo "  python manage.py migrate"
echo "  python manage.py seed_topics"
echo "  python manage.py runserver"
echo "-------------------------------------------------------------"