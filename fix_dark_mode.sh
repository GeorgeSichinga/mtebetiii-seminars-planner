#!/usr/bin/env bash
# Run from inside "planner website/"
set -e

echo "Fixing dark-mode contrast issues..."

# ---------------------------------------------------------------------------
# templates/base.html — make coffee modal dark-mode aware
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "templates/base.html"
with open(path) as f:
    content = f.read()

content = content.replace(
    '''<div id="coffee-modal" class="hidden fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4">
  <div class="bg-[var(--bg)] border rule max-w-md w-full p-6 relative text-sm">''',
    '''<div id="coffee-modal" class="hidden fixed inset-0 bg-black/60 flex items-center justify-center z-50 px-4">
  <div class="bg-white dark:bg-[#1e1f27] border rule max-w-md w-full p-6 relative text-sm text-[var(--ink)] dark:text-[var(--ink-dark)]">'''
)

# card rows inside modal: force readable border/bg per theme
content = content.replace(
    '<div class="flex items-center gap-3 border rule p-3">',
    '<div class="flex items-center gap-3 border rule p-3 bg-black/[0.02] dark:bg-white/[0.03]">'
)

with open(path, "w") as f:
    f.write(content)

print("base.html: coffee modal now theme-aware.")
PYEOF

# ---------------------------------------------------------------------------
# templates/core/schedule.html — full Cactus-style rewrite (dark-mode aware)
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
    <form method="post" class="space-y-4">
      {% csrf_token %}
      <div>
        <label class="block text-xs opacity-60 mb-1">student</label>
        {{ form.student }}
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
        <li class="flex items-center justify-between border-b rule pb-4">
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
        </li>
      {% empty %}
        <li class="opacity-60 text-sm">No sessions scheduled yet.</li>
      {% endfor %}
    </ul>
  </div>
</div>
{% endblock %}
EOF
echo "schedule.html rewritten with theme-aware styling."

# ---------------------------------------------------------------------------
# templates/core/dashboard.html — full Cactus-style rewrite (dark-mode aware)
# ---------------------------------------------------------------------------
cat > templates/core/dashboard.html << 'EOF'
{% extends "base.html" %}
{% block title %}Dashboard{% endblock %}
{% block nav_dashboard %}accent{% endblock %}
{% block content %}

<h1 class="text-xl font-bold mb-6">Dashboard</h1>

<div class="mb-8">
  <label class="text-xs opacity-60 block mb-1">viewing student</label>
  <select onchange="window.location = '/dashboard/' + this.value + '/'"
    class="border rule bg-transparent px-2 py-1.5 text-sm">
    {% for s in students %}
      <option value="{{ s.id }}" {% if student and s.id == student.id %}selected{% endif %}>{{ s.name }}</option>
    {% endfor %}
  </select>
</div>

{% if student %}
  <div class="border-b rule pb-6 mb-8">
    <h2 class="text-lg font-bold">{{ student.name }}</h2>
    <p class="opacity-60 text-xs mt-1">{{ student.email }}</p>
    {% if student.background_notes %}
      <p class="text-sm mt-3 leading-relaxed">{{ student.background_notes }}</p>
    {% endif %}
  </div>

  <div class="grid md:grid-cols-2 gap-10">
    <div>
      <h3 class="font-bold mb-4">Selected Topics ({{ selections|length }})</h3>
      <ul class="space-y-3 text-sm">
        {% for sel in selections %}
          <li class="flex items-center justify-between border-b rule pb-3">
            <span>{{ sel.topic.title }}</span>
            <span class="text-xs px-2 py-0.5 border rule {% if sel.completed %}bg-[var(--accent)] text-white border-[var(--accent)]{% else %}opacity-60{% endif %}">
              {% if sel.completed %}done{% else %}pending{% endif %}
            </span>
          </li>
        {% empty %}
          <li class="opacity-60">No topics selected yet.</li>
        {% endfor %}
      </ul>
    </div>

    <div>
      <h3 class="font-bold mb-4">Assignments ({{ assignments|length }})</h3>
      <ul class="space-y-3 text-sm">
        {% for a in assignments %}
          <li class="flex items-center justify-between border-b rule pb-3">
            <span>{{ a.title }}</span>
            <span class="opacity-60 text-xs">{{ a.due_date|default:"no due date" }}</span>
          </li>
        {% empty %}
          <li class="opacity-60">No assignments yet.</li>
        {% endfor %}
      </ul>
    </div>
  </div>
{% else %}
  <p class="opacity-70 text-sm">No students registered yet. <a href="{% url 'starter_pack' %}" class="underline">Create one</a>.</p>
{% endif %}
{% endblock %}
EOF
echo "dashboard.html rewritten with theme-aware styling."

# ---------------------------------------------------------------------------
# core/forms.py — restyle Session/Student form widgets for dark-mode legibility
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/forms.py"
with open(path) as f:
    content = f.read()

field_class = "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]"

# Replace any lingering old-style widget classes (rounded-md border-gray etc.) across the whole file
content = content.replace(
    "w-full border border-gray-300 rounded-md px-3 py-2",
    field_class,
)
content = content.replace(
    "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none",
    field_class,
)
content = content.replace(
    'attrs={"type": "datetime-local", "class": "' + field_class + '"}',
    'attrs={"type": "datetime-local", "class": "' + field_class + '"}',
)

with open(path, "w") as f:
    f.write(content)

print("forms.py: widget classes normalized for dark-mode legibility.")
PYEOF

echo ""
echo "Done. Restart the server:"
echo "  python manage.py runserver"
