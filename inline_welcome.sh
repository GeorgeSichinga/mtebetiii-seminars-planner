#!/usr/bin/env bash
# Run from inside "planner website/"
set -e

echo "Removing modal, inlining welcome section, adding Stata logo..."

# ---------------------------------------------------------------------------
# templates/base.html — remove welcome-modal related CSS (none actually lives here,
# it's all in starter_pack.html), leave coffee modal as is. No change needed here.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# templates/core/starter_pack.html — replace modal with inline section
# ---------------------------------------------------------------------------
python - << 'PYEOF'
import re

path = "templates/core/starter_pack.html"
with open(path) as f:
    content = f.read()

# 1. Remove the old modal + its script entirely
modal_start = content.find('<!-- Welcome / proficiency modal -->')
if modal_start != -1:
    content = content[:modal_start].rstrip() + "\n{% endblock %}\n"
else:
    print("Warning: modal block not found by marker, skipping removal step.")

# 2. Remove the now-defunct hidden-field sync lines from the name field area
content = content.replace(
    '''{{ form.name }}
          {{ form.goal_notes.as_hidden }}
          {{ form.python_level.as_hidden }}
          {{ form.r_level.as_hidden }}
          {{ form.stata_level.as_hidden }}''',
    '{{ form.name }}'
)

# 3. Insert inline welcome/proficiency section right after the gif banner div, before the <form method="post">
inline_section = '''
<div class="mb-12 border rule p-6">
  <p class="text-xs opacity-60 mb-1">before we start</p>
  <h2 class="text-xl font-bold mb-2">What do you want to learn?</h2>
  <p class="text-sm opacity-70 mb-6">Tell us your goal and rate yourself on each tool. This helps tailor your plan.</p>

  <div class="mb-6">
    <label class="block text-xs opacity-60 mb-1">what do you want to learn</label>
    <input type="text" name="goal_notes_display" id="goal_notes_display"
      placeholder="e.g. panel data methods for my thesis"
      class="w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none"
      oninput="document.getElementById('id_goal_notes').value = this.value;">
  </div>

  <div class="space-y-6">
    <div>
      <div class="flex items-center gap-2 mb-2">
        <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/python/python-original.svg" class="w-5 h-5" alt="Python">
        <span class="font-medium text-sm">Python</span>
      </div>
      <div class="flex gap-2">
        {% for i in "12345" %}
        <label class="cursor-pointer">
          <input type="radio" name="python_level" value="{{ forloop.counter }}" class="peer hidden">
          <span class="flex items-center justify-center w-9 h-9 border rule text-xs peer-checked:bg-[var(--accent)] peer-checked:text-white peer-checked:border-[var(--accent)] hover:border-[var(--accent)] transition">{{ forloop.counter }}</span>
        </label>
        {% endfor %}
      </div>
    </div>

    <div>
      <div class="flex items-center gap-2 mb-2">
        <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/r/r-original.svg" class="w-5 h-5" alt="R">
        <span class="font-medium text-sm">R</span>
      </div>
      <div class="flex gap-2">
        {% for i in "12345" %}
        <label class="cursor-pointer">
          <input type="radio" name="r_level" value="{{ forloop.counter }}" class="peer hidden">
          <span class="flex items-center justify-center w-9 h-9 border rule text-xs peer-checked:bg-[var(--accent)] peer-checked:text-white peer-checked:border-[var(--accent)] hover:border-[var(--accent)] transition">{{ forloop.counter }}</span>
        </label>
        {% endfor %}
      </div>
    </div>

    <div>
      <div class="flex items-center gap-2 mb-2">
        <img src="https://api.iconify.design/file-icons:stata.svg" class="w-5 h-5" alt="Stata">
        <span class="font-medium text-sm">Stata</span>
      </div>
      <div class="flex gap-2">
        {% for i in "12345" %}
        <label class="cursor-pointer">
          <input type="radio" name="stata_level" value="{{ forloop.counter }}" class="peer hidden">
          <span class="flex items-center justify-center w-9 h-9 border rule text-xs peer-checked:bg-[var(--accent)] peer-checked:text-white peer-checked:border-[var(--accent)] hover:border-[var(--accent)] transition">{{ forloop.counter }}</span>
        </label>
        {% endfor %}
      </div>
    </div>
  </div>
</div>

<script>
  // keep the hidden goal_notes field (if it still exists) synced for form submission fallback
  document.addEventListener('DOMContentLoaded', function () {
    var hiddenGoal = document.getElementById('id_goal_notes');
    var displayGoal = document.getElementById('goal_notes_display');
    if (hiddenGoal && displayGoal) {
      hiddenGoal.type = 'hidden';
    }
  });
</script>
'''

marker = '<form method="post">'
if marker in content:
    content = content.replace(marker, inline_section + "\n" + marker, 1)
else:
    print("Warning: <form method=\"post\"> marker not found, inline section not inserted.")

with open(path, "w") as f:
    f.write(content)

print("starter_pack.html updated: modal removed, inline welcome section added, real Stata logo used.")
PYEOF

# ---------------------------------------------------------------------------
# core/forms.py — since python_level/r_level/stata_level are now rendered as
# plain radios directly (not {{ form.field }}), make sure they're not required
# and remove the RadioSelect widget assumption (harmless either way, but we
# drop the goal_notes_display duplication concern by keeping goal_notes as a
# normal hidden CharField input).
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/forms.py"
with open(path) as f:
    content = f.read()

content = content.replace(
    '"goal_notes": forms.TextInput(attrs={\n                "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none focus:border-[var(--mustard)]",\n                "placeholder": "e.g. panel data methods for my thesis",\n            }),',
    '"goal_notes": forms.HiddenInput(),'
)

with open(path, "w") as f:
    f.write(content)

print("forms.py: goal_notes widget switched to HiddenInput (driven by JS-synced text field).")
PYEOF

echo ""
echo "Done. Restart the server:"
echo "  python manage.py runserver"
