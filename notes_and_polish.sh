#!/usr/bin/env bash
# Run from inside "planner website/"
set -e

echo "Applying footer fix, Notes feature, hero rewrite, gif banner, responsive tweaks..."

mkdir -p static/img
mv "dumb-stupid.gif" static/img/learn-together.gif 2>/dev/null || echo "Note: dumb-stupid.gif not found at repo root, move manually into static/img/learn-together.gif"

# ---------------------------------------------------------------------------
# core/models.py — add Note model
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/models.py"
with open(path) as f:
    content = f.read()

addition = '''

class Note(models.Model):
    title = models.CharField(max_length=200)
    content = models.TextField(blank=True)
    attachment = models.FileField(upload_to="notes/", blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.title
'''

if "class Note(models.Model):" not in content:
    content = content.rstrip() + "\n" + addition
    with open(path, "w") as f:
        f.write(content)
    print("models.py: Note model added.")
else:
    print("models.py: Note model already present, skipped.")
PYEOF

# ---------------------------------------------------------------------------
# core/forms.py — NoteForm
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/forms.py"
with open(path) as f:
    content = f.read()

content = content.replace(
    "from .models import Student, Session, Topic",
    "from .models import Student, Session, Topic, Note"
)

addition = '''

class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ["title", "content", "attachment"]
        widgets = {
            "title": forms.TextInput(attrs={
                "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none",
                "placeholder": "Note title",
            }),
            "content": forms.Textarea(attrs={
                "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none",
                "rows": 5,
                "placeholder": "Write your note here...",
            }),
        }
'''

if "class NoteForm" not in content:
    content = content.rstrip() + "\n" + addition
    with open(path, "w") as f:
        f.write(content)
    print("forms.py: NoteForm added.")
else:
    print("forms.py: NoteForm already present, skipped.")
PYEOF

# ---------------------------------------------------------------------------
# core/admin.py — register Note
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/admin.py"
with open(path) as f:
    content = f.read()

content = content.replace(
    "from .models import Student, Topic, StudentTopicSelection, Session, Assignment",
    "from .models import Student, Topic, StudentTopicSelection, Session, Assignment, Note"
)

addition = '''

@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ("title", "created_at")
'''

if "class NoteAdmin" not in content:
    content = content.rstrip() + "\n" + addition
    with open(path, "w") as f:
        f.write(content)
    print("admin.py: Note registered.")
else:
    print("admin.py: NoteAdmin already present, skipped.")
PYEOF

# ---------------------------------------------------------------------------
# core/views.py — notes list + upload view
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/views.py"
with open(path) as f:
    content = f.read()

content = content.replace(
    "from .forms import StudentIntakeForm, SessionForm",
    "from .forms import StudentIntakeForm, SessionForm, NoteForm"
)
content = content.replace(
    "from .models import Student, Topic, StudentTopicSelection, Session, Assignment",
    "from .models import Student, Topic, StudentTopicSelection, Session, Assignment, Note"
)

addition = '''

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
'''

if "def notes(request):" not in content:
    content = content.rstrip() + "\n" + addition
    with open(path, "w") as f:
        f.write(content)
    print("views.py: notes view added.")
else:
    print("views.py: notes view already present, skipped.")
PYEOF

# ---------------------------------------------------------------------------
# core/urls.py — notes route
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/urls.py"
with open(path) as f:
    content = f.read()

if 'name="notes"' not in content:
    content = content.replace(
        'path("schedule/", views.schedule, name="schedule"),',
        'path("schedule/", views.schedule, name="schedule"),\n    path("notes/", views.notes, name="notes"),'
    )
    with open(path, "w") as f:
        f.write(content)
    print("urls.py: notes route added.")
else:
    print("urls.py: notes route already present, skipped.")
PYEOF

# ---------------------------------------------------------------------------
# templates/core/notes.html — new template
# ---------------------------------------------------------------------------
cat > templates/core/notes.html << 'EOF'
{% extends "base.html" %}
{% block title %}Notes{% endblock %}
{% block nav_notes %}accent{% endblock %}
{% block content %}

<h1 class="text-xl font-bold mb-6">Notes</h1>

<div class="grid md:grid-cols-2 gap-10">
  <div>
    <form method="post" enctype="multipart/form-data" class="space-y-4">
      {% csrf_token %}
      {{ form.title }}
      {{ form.content }}
      <div>
        <label class="block text-xs opacity-60 mb-1">attachment (optional)</label>
        {{ form.attachment }}
      </div>
      <button type="submit" class="bg-[var(--accent)] text-white px-5 py-2.5 text-sm hover:opacity-90 transition">
        upload_note()
      </button>
    </form>
  </div>

  <div>
    <p class="text-xs opacity-60 mb-3">{{ notes|length }} note(s)</p>
    <ul class="space-y-5">
      {% for note in notes %}
        <li class="border-b rule pb-4">
          <p class="font-bold">{{ note.title }}</p>
          <p class="text-xs opacity-60 mb-2">{{ note.created_at|date:"d M Y, H:i" }}</p>
          {% if note.content %}<p class="text-sm mb-2 leading-relaxed">{{ note.content }}</p>{% endif %}
          {% if note.attachment %}
            <a href="{{ note.attachment.url }}" target="_blank" class="text-xs underline">view attachment</a>
          {% endif %}
        </li>
      {% empty %}
        <li class="opacity-60 text-sm">No notes yet.</li>
      {% endfor %}
    </ul>
  </div>
</div>
{% endblock %}
EOF

# ---------------------------------------------------------------------------
# templates/base.html — fix footer spacing, add Notes nav link, responsive tweaks
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "templates/base.html"
with open(path) as f:
    content = f.read()

# Add Notes to nav
old_nav = '''<nav class="max-w-2xl mx-auto px-4 pb-6 flex gap-5 text-sm border-b rule">
  <a href="{% url 'starter_pack' %}" class="nav-link pb-3 {% block nav_starter %}{% endblock %}">Starter Pack</a>
  <a href="{% url 'dashboard' %}" class="nav-link pb-3 {% block nav_dashboard %}{% endblock %}">Dashboard</a>
  <a href="{% url 'schedule' %}" class="nav-link pb-3 {% block nav_schedule %}{% endblock %}">Schedule</a>
</nav>'''

new_nav = '''<nav class="max-w-2xl mx-auto px-4 pb-6 flex flex-wrap gap-4 sm:gap-5 text-sm border-b rule">
  <a href="{% url 'starter_pack' %}" class="nav-link pb-3 {% block nav_starter %}{% endblock %}">Starter Pack</a>
  <a href="{% url 'dashboard' %}" class="nav-link pb-3 {% block nav_dashboard %}{% endblock %}">Dashboard</a>
  <a href="{% url 'schedule' %}" class="nav-link pb-3 {% block nav_schedule %}{% endblock %}">Schedule</a>
  <a href="{% url 'notes' %}" class="nav-link pb-3 {% block nav_notes %}{% endblock %}">Notes</a>
</nav>'''

assert old_nav in content, "nav block not found"
content = content.replace(old_nav, new_nav)

# Fix footer: stack on small screens, proper gaps, no overlap
old_footer = '''<footer class="max-w-2xl mx-auto px-4 py-8 border-t rule mt-10 flex items-center justify-between text-xs">
  <p>&copy; {% now "Y" %} George Sichinga. Mtebetiii Seminars and Talks</p>
  <div class="flex items-center gap-4">
    <a href="https://github.com/GeorgeSichinga" target="_blank" rel="noopener" class="flex items-center gap-1 nav-link">
      <svg viewBox="0 0 16 16" width="16" height="16" fill="currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38
        0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07
        -1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44
        1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>
      github.com/GeorgeSichinga
    </a>
    <button onclick="document.getElementById('coffee-modal').classList.remove('hidden')"
      class="flex items-center gap-1 nav-link">
      <img src="{% static 'img/coffee.webp' %}" alt="" class="w-4 h-4">
      buy me a coffee
    </button>
  </div>
</footer>'''

new_footer = '''<footer class="max-w-2xl mx-auto px-4 py-10 border-t rule mt-10 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 text-xs">
  <p class="opacity-80">&copy; {% now "Y" %} George Sichinga. Mtebetiii Seminars and Talks</p>
  <div class="flex flex-wrap items-center gap-x-6 gap-y-3">
    <a href="https://github.com/GeorgeSichinga" target="_blank" rel="noopener" class="flex items-center gap-2 nav-link">
      <svg viewBox="0 0 16 16" width="16" height="16" fill="currentColor" class="shrink-0"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38
        0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07
        -1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44
        1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>
      <span class="whitespace-nowrap">github.com/GeorgeSichinga</span>
    </a>
    <button onclick="document.getElementById('coffee-modal').classList.remove('hidden')"
      class="flex items-center gap-2 nav-link">
      <img src="{% static 'img/coffee.webp' %}" alt="" class="w-4 h-4 shrink-0">
      <span class="whitespace-nowrap">buy me a coffee</span>
    </button>
  </div>
</footer>'''

assert old_footer in content, "footer block not found"
content = content.replace(old_footer, new_footer)

# Responsive header: wrap on very small screens
content = content.replace(
    '<header class="max-w-2xl mx-auto px-4 pt-8 pb-4 flex items-center justify-between">',
    '<header class="max-w-2xl mx-auto px-4 pt-8 pb-4 flex flex-wrap items-center justify-between gap-3">'
)

with open(path, "w") as f:
    f.write(content)

print("base.html updated: footer spacing fixed, Notes nav link added, responsive tweaks applied.")
PYEOF

# ---------------------------------------------------------------------------
# templates/core/starter_pack.html — rewritten hero + gif banner
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "templates/core/starter_pack.html"
with open(path) as f:
    content = f.read()

old_hero = '''<div class="mb-12">
  <h1 class="text-2xl font-bold mb-4">Hello World!</h1>
  <p class="mb-3 leading-relaxed opacity-90">
    Hi, I'm George Sichinga's applied data analysis learning planner. This is a
    self-paced curriculum tool covering Stata, R, Python, and a Capstone track,
    built for postgraduate econometrics and data science coursework. Pick the
    topics you want to cover below, rate your proficiency, and it becomes your
    personal syllabus on the dashboard.
  </p>
  <p class="mb-6 opacity-70 text-xs">
    If you want to know more about how this was built, click the GitHub icon in the footer below.
  </p>
</div>'''

new_hero = '''<div class="mb-10">
  <h1 class="text-2xl font-bold mb-4">Hello World!</h1>
  <p class="mb-3 leading-relaxed opacity-90">
    Hi, I'm George Sichinga. I teach applied data analysis and econometrics to
    clients and students who want to actually use Stata, R, and Python on their
    own research, not just watch a tutorial. This site is where that teaching
    happens: pick the topics you want covered below, tell me your current
    comfort level with each tool, and I'll shape sessions and a syllabus
    around exactly where you are.
  </p>
</div>

<div class="mb-12 border rule p-6 flex flex-col sm:flex-row items-center gap-6">
  <img src="{% static 'img/learn-together.gif' %}" alt="Let's learn together" class="w-28 h-28 sm:w-32 sm:h-32 rounded-sm object-cover border rule shrink-0">
  <p class="text-sm leading-relaxed opacity-90">
    Let's learn together. Bring your dataset, your thesis question, or just
    your curiosity, and we'll work through it step by step, one method at a
    time.
  </p>
</div>'''

assert old_hero in content, "hero block not found, check starter_pack.html manually"
content = content.replace(old_hero, new_hero)

with open(path, "w") as f:
    f.write(content)

print("starter_pack.html: hero rewritten, gif banner added.")
PYEOF

echo ""
echo "-------------------------------------------------------------"
echo "MANUAL STEP (settings.py) - needed for file uploads (Notes):"
echo "-------------------------------------------------------------"
echo "Add near the bottom of data_notebook/settings.py:"
echo "  MEDIA_URL = '/media/'"
echo "  MEDIA_ROOT = BASE_DIR / 'media'"
echo ""
echo "And in data_notebook/urls.py, add at the bottom (below urlpatterns):"
echo "  from django.conf import settings"
echo "  from django.conf.urls.static import static"
echo "  urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)"
echo "-------------------------------------------------------------"
echo "THEN RUN:"
echo "  python manage.py makemigrations core"
echo "  python manage.py migrate"
echo "  python manage.py runserver"
echo "-------------------------------------------------------------"
