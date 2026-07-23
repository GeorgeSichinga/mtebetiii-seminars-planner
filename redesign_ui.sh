#!/usr/bin/env bash
# Run from inside "planner website/"
set -e

echo "Redesigning UI and fixing nav gif..."

# ---------------------------------------------------------------------------
# templates/base.html
# ---------------------------------------------------------------------------
cat > templates/base.html << 'EOF'
{% load static %}
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{% block title %}Mtebetiii Seminars and Talks{% endblock %}</title>
<script src="https://cdn.tailwindcss.com"></script>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Source+Serif+4:wght@400;600;700&family=IBM+Plex+Mono:wght@400;500&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  :root {
    --ink: #1c2430;
    --paper: #f6f4ef;
    --rule: #d8d3c4;
    --mustard: #b6862c;
    --track-capstone: #6b4a8a;
    --track-python: #2f6f5e;
    --track-r: #2f5c8a;
    --track-stata: #8a3f2f;
  }
  body { font-family: 'Inter', sans-serif; background-color: var(--paper); color: var(--ink); }
  .font-serif-custom { font-family: 'Source Serif 4', serif; }
  .font-mono-custom { font-family: 'IBM Plex Mono', monospace; }
  .rule { border-color: var(--rule); }
  .track-tag { font-family: 'IBM Plex Mono', monospace; font-size: 0.7rem; letter-spacing: 0.05em; }
</style>
</head>
<body>
<header class="border-b-2 rule">
  <div class="max-w-4xl mx-auto px-4 py-5 flex items-end justify-between">
    <a href="{% url 'starter_pack' %}" class="flex items-center gap-3">
      <img src="{% static 'img/welcome.gif' %}" alt="" class="w-10 h-10 rounded-sm object-cover border rule">
      <span class="font-serif-custom text-2xl font-semibold tracking-tight">Mtebetiii Seminars and Talks</span>
    </a>
  </div>
  <div class="max-w-4xl mx-auto px-4 pb-3 flex gap-6 text-sm font-mono-custom">
    <a href="{% url 'starter_pack' %}" class="hover:text-[var(--mustard)]">starter_pack</a>
    <a href="{% url 'dashboard' %}" class="hover:text-[var(--mustard)]">dashboard</a>
    <a href="{% url 'schedule' %}" class="hover:text-[var(--mustard)]">schedule</a>
  </div>
</header>

<main class="max-w-4xl mx-auto px-4 py-10">
  {% if messages %}
    {% for message in messages %}
      <div class="mb-6 px-4 py-2 border-l-4 border-[var(--mustard)] bg-white text-sm">
        {{ message }}
      </div>
    {% endfor %}
  {% endif %}
  {% block content %}{% endblock %}
</main>

<footer class="border-t-2 rule mt-16">
  <div class="max-w-4xl mx-auto px-4 py-8 flex items-center justify-between text-sm">
    <p class="font-mono-custom text-gray-500">&copy; {% now "Y" %} Mtebetiii Seminars and Talks</p>
    <button onclick="document.getElementById('coffee-modal').classList.remove('hidden')"
      class="border border-[var(--mustard)] text-[var(--mustard)] hover:bg-[var(--mustard)] hover:text-white transition px-4 py-2 text-xs font-mono-custom">
      buy_me_a_coffee()
    </button>
  </div>
</footer>

<div id="coffee-modal" class="hidden fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4">
  <div class="bg-[var(--paper)] border-2 rule max-w-md w-full p-6 relative">
    <button onclick="document.getElementById('coffee-modal').classList.add('hidden')"
      class="absolute top-3 right-3 text-gray-500 hover:text-black font-mono-custom">[x]</button>
    <h3 class="font-serif-custom text-lg font-semibold mb-1">Support this project</h3>
    <p class="text-sm text-gray-600 mb-5">If this planner has been useful, a contribution through any of these is appreciated.</p>

    <div class="space-y-3">
      <div class="flex items-center gap-3 border rule p-3 bg-white">
        <img src="{% static 'img/nbm.jpg' %}" alt="National Bank" class="w-9 h-9 object-contain">
        <div class="text-sm">
          <p class="font-medium">National Bank of Malawi</p>
          <p class="text-gray-600 font-mono-custom text-xs">Acc: 1006192927 &middot; George Sichinga</p>
        </div>
      </div>
      <div class="flex items-center gap-3 border rule p-3 bg-white">
        <img src="{% static 'img/airtelmoney.png' %}" alt="Airtel Money" class="w-9 h-9 object-contain">
        <div class="text-sm">
          <p class="font-medium">Airtel Money</p>
          <p class="text-gray-600 font-mono-custom text-xs">+265 997 079 810</p>
        </div>
      </div>
      <div class="flex items-center gap-3 border rule p-3 bg-white">
        <img src="{% static 'img/mpamba.jpeg' %}" alt="TNM Mpamba" class="w-9 h-9 object-contain">
        <div class="text-sm">
          <p class="font-medium">TNM Mpamba</p>
          <p class="text-gray-600 font-mono-custom text-xs">+265 883 873 380</p>
        </div>
      </div>
    </div>
  </div>
</div>
</body>
</html>
EOF

# ---------------------------------------------------------------------------
# templates/core/starter_pack.html
# ---------------------------------------------------------------------------
cat > templates/core/starter_pack.html << 'EOF'
{% extends "base.html" %}
{% load static %}
{% block title %}Starter Pack{% endblock %}
{% block content %}

<div class="mb-10">
  <p class="font-mono-custom text-xs text-gray-500 mb-1">welcome</p>
  <h1 class="font-serif-custom text-3xl font-semibold mb-2">Build your learning plan</h1>
  <p class="text-sm text-gray-600 max-w-xl">Enter your details, choose the topics you want to cover across Stata, R, Python, and the Capstone track, and this becomes your personal curriculum on the dashboard.</p>
</div>

<div class="grid md:grid-cols-5 gap-10">
  <div class="md:col-span-3">
    <form method="post">
      {% csrf_token %}
      <div class="space-y-4 mb-10 pb-8 border-b rule">
        <div>
          <label class="block font-mono-custom text-xs text-gray-500 mb-1">name</label>
          {{ form.name }}
        </div>
        <div>
          <label class="block font-mono-custom text-xs text-gray-500 mb-1">email</label>
          {{ form.email }}
        </div>
        <div>
          <label class="block font-mono-custom text-xs text-gray-500 mb-1">background / goals</label>
          {{ form.background_notes }}
        </div>
      </div>

      <div class="flex items-baseline justify-between mb-6">
        <h2 class="font-serif-custom text-xl font-semibold">Curriculum</h2>
        <span class="font-mono-custom text-xs text-gray-500">{{ topic_count }} topics</span>
      </div>

      {% for track, topics in tracks.items %}
        <div class="mb-8">
          <p class="track-tag uppercase mb-3 pb-1 border-b" style="border-color:
            {% if track == 'capstone' %}var(--track-capstone)
            {% elif track == 'python' %}var(--track-python)
            {% elif track == 'r' %}var(--track-r)
            {% else %}var(--track-stata){% endif %};
            color:
            {% if track == 'capstone' %}var(--track-capstone)
            {% elif track == 'python' %}var(--track-python)
            {% elif track == 'r' %}var(--track-r)
            {% else %}var(--track-stata){% endif %};">
            {{ track }}
          </p>
          {% for topic in topics %}
            <label class="flex items-start gap-3 mb-3 text-sm cursor-pointer group">
              <input type="checkbox" name="topics" value="{{ topic.id }}" class="mt-1 accent-[var(--mustard)]">
              <span>
                <span class="font-medium group-hover:text-[var(--mustard)]">{{ topic.title }}</span>
                <span class="block text-gray-500 text-xs mt-0.5">{{ topic.description }}</span>
              </span>
            </label>
          {% endfor %}
        </div>
      {% endfor %}

      <button type="submit" class="bg-[var(--ink)] text-white px-6 py-3 text-sm font-mono-custom hover:bg-black transition">
        save_and_start_plan()
      </button>
    </form>
  </div>

  <div class="md:col-span-2">
    <p class="font-mono-custom text-xs text-gray-500 mb-3">enrolled students &middot; {{ students.count }}</p>
    {% if students %}
      <ul class="space-y-3">
        {% for s in students %}
          <li class="border-b rule pb-3">
            <a href="{% url 'dashboard' student_id=s.id %}" class="text-sm hover:text-[var(--mustard)]">
              <span class="font-medium">{{ s.name }}</span>
              <span class="block text-xs text-gray-500 font-mono-custom">{{ s.email }}</span>
            </a>
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
# core/forms.py — restyle widgets to match new UI (plain underline inputs)
# ---------------------------------------------------------------------------
python3 - << 'PYEOF'
import re
path = "core/forms.py"
with open(path) as f:
    content = f.read()

field_class = "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none focus:border-[var(--mustard)]"

content = content.replace(
    '"class": "w-full border border-gray-300 rounded-md px-3 py-2",\n                "placeholder": "Full Name",',
    f'"class": "{field_class}",\n                "placeholder": "Full Name",'
)
content = content.replace(
    '"class": "w-full border border-gray-300 rounded-md px-3 py-2",\n                "placeholder": "Email Address",',
    f'"class": "{field_class}",\n                "placeholder": "Email Address",'
)
content = content.replace(
    '"class": "w-full border border-gray-300 rounded-md px-3 py-2",\n                "rows": 4,\n                "placeholder": "Background / Learning Goals",',
    f'"class": "{field_class}",\n                "rows": 3,\n                "placeholder": "Background / Learning Goals",'
)
content = content.replace(
    'forms.Select(attrs={"class": "w-full border border-gray-300 rounded-md px-3 py-2"})',
    f'forms.Select(attrs={{"class": "{field_class}"}})'
)
content = content.replace(
    'attrs={"type": "datetime-local", "class": "w-full border border-gray-300 rounded-md px-3 py-2"}',
    f'attrs={{"type": "datetime-local", "class": "{field_class}"}}'
)
content = content.replace(
    'forms.Textarea(attrs={"class": "w-full border border-gray-300 rounded-md px-3 py-2", "rows": 3})',
    f'forms.Textarea(attrs={{"class": "{field_class}", "rows": 3}})'
)

with open(path, "w") as f:
    f.write(content)

print("forms.py restyled.")
PYEOF

echo ""
echo "Done. Restart the server:"
echo "  python manage.py runserver"
