#!/usr/bin/env bash
# Run this from inside "planner website/" (same folder as manage.py)
# Renames the site to "Mtebetiii Seminars and Talks", adds a welcome gif,
# and adds a Buy Me a Coffee section with your payment details/logos.

set -e

echo "Setting up static files folder..."
mkdir -p static/img

# Move the media files into static/img (adjust names if yours differ)
mv "tom-&-jerry-pizarron.gif" static/img/welcome.gif 2>/dev/null || echo "Note: gif not found at repo root, move it manually into static/img/welcome.gif"
mv "airtelmoney.png" static/img/airtelmoney.png 2>/dev/null || echo "Note: airtelmoney.png not found, move manually"
mv "NBM.jpg" static/img/nbm.jpg 2>/dev/null || echo "Note: NBM.jpg not found, move manually"
mv "Mpamba.jpeg" static/img/mpamba.jpeg 2>/dev/null || echo "Note: Mpamba.jpeg not found, move manually"

echo "Static files placed in static/img/"

# ---------------------------------------------------------------------------
# templates/base.html — rename site + add Buy Me a Coffee modal
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
<link href="https://fonts.googleapis.com/css2?family=Source+Serif+4:wght@400;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  body { font-family: 'Inter', sans-serif; background-color: #faf9f6; }
  .font-serif-custom { font-family: 'Source Serif 4', serif; }
</style>
</head>
<body class="text-gray-900">
<nav class="bg-white border-b border-gray-200">
  <div class="max-w-5xl mx-auto px-4 py-4 flex items-center justify-between">
    <a href="{% url 'starter_pack' %}" class="font-serif-custom text-xl font-semibold">📚 Mtebetiii Seminars and Talks</a>
    <div class="space-x-4 text-sm flex items-center">
      <a href="{% url 'starter_pack' %}" class="hover:underline">Starter Pack</a>
      <a href="{% url 'dashboard' %}" class="hover:underline">Dashboard</a>
      <a href="{% url 'schedule' %}" class="hover:underline">Schedule</a>
      <button onclick="document.getElementById('coffee-modal').classList.remove('hidden')"
        class="bg-amber-500 hover:bg-amber-600 text-white text-xs font-semibold px-3 py-2 rounded-md">
        ☕ Buy Me a Coffee
      </button>
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

<!-- Buy Me a Coffee Modal -->
<div id="coffee-modal" class="hidden fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4">
  <div class="bg-white rounded-lg max-w-md w-full p-6 relative">
    <button onclick="document.getElementById('coffee-modal').classList.add('hidden')"
      class="absolute top-3 right-3 text-gray-400 hover:text-gray-700">✕</button>
    <h3 class="font-serif-custom text-lg font-semibold mb-1">Support This Project ☕</h3>
    <p class="text-sm text-gray-500 mb-4">If this planner has been useful, you can send a token of appreciation through any of the options below.</p>

    <div class="space-y-4">
      <div class="flex items-center gap-3 border border-gray-200 rounded-md p-3">
        <img src="{% static 'img/nbm.jpg' %}" alt="National Bank" class="w-10 h-10 object-contain rounded">
        <div class="text-sm">
          <p class="font-medium">National Bank of Malawi</p>
          <p class="text-gray-600">Account: 1006192927</p>
          <p class="text-gray-600">Name: George Sichinga</p>
        </div>
      </div>

      <div class="flex items-center gap-3 border border-gray-200 rounded-md p-3">
        <img src="{% static 'img/airtelmoney.png' %}" alt="Airtel Money" class="w-10 h-10 object-contain rounded">
        <div class="text-sm">
          <p class="font-medium">Airtel Money</p>
          <p class="text-gray-600">+265 997 079 810</p>
        </div>
      </div>

      <div class="flex items-center gap-3 border border-gray-200 rounded-md p-3">
        <img src="{% static 'img/mpamba.jpeg' %}" alt="TNM Mpamba" class="w-10 h-10 object-contain rounded">
        <div class="text-sm">
          <p class="font-medium">TNM Mpamba</p>
          <p class="text-gray-600">+265 883 873 380</p>
        </div>
      </div>
    </div>
  </div>
</div>
</body>
</html>
EOF

# ---------------------------------------------------------------------------
# templates/core/starter_pack.html — add welcome banner with gif
# ---------------------------------------------------------------------------
python3 - << 'PYEOF'
import re

path = "templates/core/starter_pack.html"
with open(path) as f:
    content = f.read()

banner = '''{% extends "base.html" %}
{% load static %}
{% block title %}Starter Pack{% endblock %}
{% block content %}
<div class="bg-white rounded-lg border border-gray-200 p-6 mb-8 flex items-center gap-6">
  <img src="{% static 'img/welcome.gif' %}" alt="Welcome" class="w-24 h-24 rounded-md object-cover">
  <div>
    <h1 class="font-serif-custom text-xl font-semibold mb-1">Welcome to Mtebetiii Seminars and Talks 👋</h1>
    <p class="text-sm text-gray-600">Let's build your personalised data analysis learning plan. Pick your topics below and get started.</p>
  </div>
</div>
'''

content = content.replace(
    '{% extends "base.html" %}\n{% block title %}Starter Pack{% endblock %}\n{% block content %}\n',
    banner
)

with open(path, "w") as f:
    f.write(content)

print("starter_pack.html updated with welcome banner.")
PYEOF

echo ""
echo "-------------------------------------------------------------"
echo "MANUAL STEP (settings.py) - do this once if not already set:"
echo "-------------------------------------------------------------"
echo "Make sure data_notebook/settings.py has:"
echo "  STATIC_URL = 'static/'"
echo "  STATICFILES_DIRS = [BASE_DIR / 'static']"
echo "-------------------------------------------------------------"
echo "Done. Restart the dev server (Ctrl+C then rerun):"
echo "  python manage.py runserver"
echo "-------------------------------------------------------------"
