#!/usr/bin/env bash
# Run from inside "planner website/"
set -e

echo "Fixing select fields, adding role toggle, adding calendar export..."

# ---------------------------------------------------------------------------
# core/forms.py — nicer empty labels for student/topic dropdowns, add student_email field
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/forms.py"
with open(path) as f:
    content = f.read()

old = '''class SessionForm(forms.ModelForm):
    class Meta:
        model = Session
        fields = ["student", "topic", "scheduled_for", "notes"]'''

new = '''class SessionForm(forms.ModelForm):
    student_email = forms.EmailField(
        required=False,
        widget=forms.EmailInput(attrs={
            "class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]",
            "placeholder": "the email you registered with",
        }),
    )

    class Meta:
        model = Session
        fields = ["student", "topic", "scheduled_for", "notes"]'''

assert old in content
content = content.replace(old, new)

# give student/topic ModelChoiceFields friendlier empty labels via __init__
old_init_marker = "class SessionForm(forms.ModelForm):"
if "def __init__(self, *args, **kwargs):" not in content.split(old_init_marker, 1)[1].split("class Meta")[0]:
    # inject an __init__ right after the student_email field, before class Meta
    content = content.replace(
        '    class Meta:\n        model = Session\n        fields = ["student", "topic", "scheduled_for", "notes"]',
        '''    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["student"].required = False
        self.fields["student"].empty_label = "Select a student"
        self.fields["topic"].empty_label = "Select a topic"

    class Meta:
        model = Session
        fields = ["student", "topic", "scheduled_for", "notes"]'''
    )

with open(path, "w") as f:
    f.write(content)

print("forms.py: student_email field added, empty labels fixed, student made optional at form level.")
PYEOF

# ---------------------------------------------------------------------------
# core/views.py — handle student/teacher submission, add ics export view
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/views.py"
with open(path) as f:
    content = f.read()

# Add imports needed for ics generation
content = content.replace(
    "from django.shortcuts import render, redirect, get_object_or_404",
    "from django.shortcuts import render, redirect, get_object_or_404\nfrom django.http import HttpResponse"
)

old_schedule = '''def schedule(request):
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
    return render(request, "core/schedule.html", context)'''

new_schedule = '''def schedule(request):
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
    description = (session.notes or "").replace("\\n", "\\\\n").replace(",", "\\\\,")

    ics_content = (
        "BEGIN:VCALENDAR\\r\\n"
        "VERSION:2.0\\r\\n"
        "PRODID:-//Mtebetiii Seminars and Talks//EN\\r\\n"
        "BEGIN:VEVENT\\r\\n"
        f"UID:session-{session.id}@mtebetiii-seminars\\r\\n"
        f"DTSTAMP:{fmt(timezone.now())}\\r\\n"
        f"DTSTART:{fmt(start)}\\r\\n"
        f"DTEND:{fmt(end)}\\r\\n"
        f"SUMMARY:{summary}\\r\\n"
        f"DESCRIPTION:{description}\\r\\n"
        "END:VEVENT\\r\\n"
        "END:VCALENDAR\\r\\n"
    )

    response = HttpResponse(ics_content, content_type="text/calendar")
    response["Content-Disposition"] = f'attachment; filename="session-{session.id}.ics"'
    return response'''

assert old_schedule in content
content = content.replace(old_schedule, new_schedule)

# add needed imports for timedelta / timezone
if "from datetime import timedelta" not in content:
    content = content.replace(
        "from django.shortcuts import render, redirect, get_object_or_404\nfrom django.http import HttpResponse",
        "from datetime import timedelta\n\nfrom django.shortcuts import render, redirect, get_object_or_404\nfrom django.http import HttpResponse\nfrom django.utils import timezone"
    )

with open(path, "w") as f:
    f.write(content)

print("views.py: schedule() updated for role handling, session_ics() view added.")
PYEOF

# ---------------------------------------------------------------------------
# core/urls.py — add ics route
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/urls.py"
with open(path) as f:
    content = f.read()

if 'name="session_ics"' not in content:
    content = content.replace(
        'path("schedule/<int:session_id>/toggle/", views.toggle_session_complete, name="toggle_session_complete"),',
        'path("schedule/<int:session_id>/toggle/", views.toggle_session_complete, name="toggle_session_complete"),\n    path("schedule/<int:session_id>/calendar.ics", views.session_ics, name="session_ics"),'
    )
    with open(path, "w") as f:
        f.write(content)
    print("urls.py: session_ics route added.")
else:
    print("urls.py: session_ics route already present, skipped.")
PYEOF

# ---------------------------------------------------------------------------
# templates/core/schedule.html — role toggle + calendar links
# ---------------------------------------------------------------------------
cat > templates/core/schedule.html << 'EOF'
{% extends "base.html" %}
{% block title %}Schedule{% endblock %}
{% block nav_schedule %}accent{% endblock %}
{% block content %}

<h1 class="text-xl font-bold mb-8">Schedule</h1>

<div class="grid md:grid-cols-2 gap-10">
  <div>
    <h2 class="text-lg font-bold mb-4">Plan a Session</h2>

    <div class="mb-5">
      <label class="block text-xs opacity-60 mb-1">I am a</label>
      <select id="role-select" onchange="toggleRole()"
        class="w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]">
        <option value="teacher">Teacher (George)</option>
        <option value="student">Student</option>
      </select>
    </div>

    <form method="post" class="space-y-4">
      {% csrf_token %}
      <input type="hidden" name="role" id="role-hidden" value="teacher">

      <div id="teacher-field">
        <label class="block text-xs opacity-60 mb-1">student</label>
        {{ form.student }}
      </div>

      <div id="student-field" class="hidden">
        <label class="block text-xs opacity-60 mb-1">your registered email</label>
        {{ form.student_email }}
      </div>

      <div>
        <label class="block text-xs opacity-60 mb-1">topic</label>
        {{ form.topic }}
      </div>
      <div>
        <label class="block text-xs opacity-60 mb-1">scheduled for</label>
        {{ form.scheduled_for }}
      </div>
      <div>
        <label class="block text-xs opacity-60 mb-1">notes</label>
        {{ form.notes }}
      </div>
      <button type="submit" class="bg-[var(--accent)] text-white px-5 py-2.5 text-sm hover:opacity-90 transition">
        schedule_session()
      </button>
    </form>
  </div>

  <div>
    <h2 class="text-lg font-bold mb-4">Upcoming &amp; Past Sessions</h2>
    <ul class="space-y-4">
      {% for session in sessions %}
        <li class="border-b rule pb-4">
          <div class="flex items-center justify-between mb-2">
            <div>
              <p class="font-medium">{{ session.student.name }}{% if session.topic %} &mdash; {{ session.topic.title }}{% endif %}</p>
              <p class="opacity-60 text-xs mt-1">{{ session.scheduled_for }}</p>
            </div>
            <form method="post" action="{% url 'toggle_session_complete' session.id %}">
              {% csrf_token %}
              <button type="submit" class="text-xs px-3 py-1.5 border rule {% if session.is_completed %}bg-[var(--accent)] text-white border-[var(--accent)]{% else %}hover:border-[var(--accent)]{% endif %} transition">
                {% if session.is_completed %}completed{% else %}mark done{% endif %}
              </button>
            </form>
          </div>
          <a href="{% url 'session_ics' session.id %}" class="text-xs underline opacity-80 hover:accent">
            add to calendar (.ics)
          </a>
        </li>
      {% empty %}
        <li class="opacity-60 text-sm">No sessions scheduled yet.</li>
      {% endfor %}
    </ul>
  </div>
</div>

<script>
  function toggleRole() {
    const role = document.getElementById('role-select').value;
    document.getElementById('role-hidden').value = role;
    document.getElementById('teacher-field').classList.toggle('hidden', role === 'student');
    document.getElementById('student-field').classList.toggle('hidden', role === 'teacher');
  }
</script>
{% endblock %}
EOF

echo ""
echo "Done. Restart the server:"
echo "  python manage.py runserver"
echo ""
echo "Reminder: your existing 'send_reminders' management command already emails"
echo "students ahead of their sessions. To run it periodically for real, you can"
echo "set up a Render Cron Job later that runs: python manage.py send_reminders"
