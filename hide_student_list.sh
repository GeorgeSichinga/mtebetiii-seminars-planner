#!/usr/bin/env bash
# Run from inside "planner website/"
set -e

echo "Removing public student list/count..."

# ---------------------------------------------------------------------------
# templates/core/starter_pack.html — remove enrolled students panel
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "templates/core/starter_pack.html"
with open(path) as f:
    content = f.read()

old_block = '''  <div class="md:col-span-2">
    <p class="text-xs opacity-60 mb-3">enrolled students &middot; {{ students.count }}</p>
    {% if students %}
      <ul class="space-y-3">
        {% for s in students %}
          <li class="border-b rule pb-3">
            <a href="{% url 'dashboard' student_id=s.id %}" class="text-sm hover:accent">
              <span class="font-medium">{{ s.name }}</span>
              <span class="block text-xs opacity-60">{{ s.email }}</span>
            </a>
          </li>
        {% endfor %}
      </ul>
    {% else %}
      <p class="text-sm opacity-60">No students registered yet.</p>
    {% endif %}
  </div>'''

if old_block in content:
    content = content.replace(old_block, "")
    # collapse the now-single-column layout: form no longer needs md:col-span-3 split
    content = content.replace('<div class="md:col-span-3">', '<div>')
    content = content.replace('<div class="grid md:grid-cols-5 gap-10">', '<div>')
    with open(path, "w") as f:
        f.write(content)
    print("starter_pack.html: public student list removed.")
else:
    print("Warning: enrolled students block not found by exact match, please check starter_pack.html manually.")
PYEOF

# ---------------------------------------------------------------------------
# templates/core/dashboard.html — remove full student dropdown (was exposing everyone's name)
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "templates/core/dashboard.html"
with open(path) as f:
    content = f.read()

old_block = '''<div class="mb-8">
  <label class="text-xs opacity-60 block mb-1">viewing student</label>
  <select onchange="window.location = '/dashboard/' + this.value + '/'"
    class="border rule bg-transparent px-2 py-1.5 text-sm">
    {% for s in students %}
      <option value="{{ s.id }}" {% if student and s.id == student.id %}selected{% endif %}>{{ s.name }}</option>
    {% endfor %}
  </select>
</div>'''

new_block = '''<div class="mb-8">
  <p class="text-xs opacity-60">Enter the link you were given, or the email you registered with, to view your dashboard.</p>
  <form method="get" action="{% url 'dashboard_lookup' %}" class="flex gap-2 mt-2">
    <input type="email" name="email" placeholder="your registered email"
      class="border rule bg-transparent px-3 py-2 text-sm flex-1 focus:outline-none focus:border-[var(--accent)]" required>
    <button type="submit" class="bg-[var(--accent)] text-white px-4 py-2 text-sm hover:opacity-90 transition">view</button>
  </form>
</div>'''

if old_block in content:
    content = content.replace(old_block, new_block)
    with open(path, "w") as f:
        f.write(content)
    print("dashboard.html: public student dropdown replaced with email lookup.")
else:
    print("Warning: student dropdown block not found by exact match, please check dashboard.html manually.")
PYEOF

# ---------------------------------------------------------------------------
# core/views.py — stop passing full student list to templates, add dashboard_lookup view
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/views.py"
with open(path) as f:
    content = f.read()

# starter_pack(): stop sending the full students queryset to the template
old_sp = '''def starter_pack(request):
    """Intake form + topic picker."""
    students = Student.objects.all()
    topics = Topic.objects.all()'''
new_sp = '''def starter_pack(request):
    """Intake form + topic picker."""
    topics = Topic.objects.all()'''
if old_sp in content:
    content = content.replace(old_sp, new_sp)

content = content.replace(
    '''    context = {
        "form": form,
        "students": students,
        "tracks": tracks,
        "topic_count": topics.count(),
    }
    return render(request, "core/starter_pack.html", context)''',
    '''    context = {
        "form": form,
        "tracks": tracks,
        "topic_count": topics.count(),
    }
    return render(request, "core/starter_pack.html", context)'''
)

# dashboard(): stop passing the full students list too
old_dash = '''def dashboard(request, student_id=None):
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
    return render(request, "core/dashboard.html", context)'''

new_dash = '''def dashboard(request, student_id=None):
    student = None
    selections = []
    assignments = []

    if student_id:
        student = get_object_or_404(Student, id=student_id)

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


def dashboard_lookup(request):
    email = request.GET.get("email", "").strip()
    if email:
        student = Student.objects.filter(email__iexact=email).first()
        if student:
            return redirect("dashboard", student_id=student.id)
        messages.error(request, "No student found with that email.")
    return redirect("dashboard")'''

assert old_dash in content, "dashboard() block not found exactly, please check core/views.py manually"
content = content.replace(old_dash, new_dash)

with open(path, "w") as f:
    f.write(content)

print("views.py: student lists no longer exposed publicly, dashboard_lookup() added.")
PYEOF

# ---------------------------------------------------------------------------
# core/urls.py — add dashboard_lookup route
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/urls.py"
with open(path) as f:
    content = f.read()

if 'name="dashboard_lookup"' not in content:
    content = content.replace(
        'path("dashboard/<int:student_id>/", views.dashboard, name="dashboard"),',
        'path("dashboard/<int:student_id>/", views.dashboard, name="dashboard"),\n    path("dashboard/lookup/", views.dashboard_lookup, name="dashboard_lookup"),'
    )
    with open(path, "w") as f:
        f.write(content)
    print("urls.py: dashboard_lookup route added.")
else:
    print("urls.py: dashboard_lookup route already present, skipped.")
PYEOF

echo ""
echo "Done. Restart the server:"
echo "  python manage.py runserver"
echo ""
echo "You can still see the full student list, count, and every detail at:"
echo "  /admin/  (log in with your superuser account)"
