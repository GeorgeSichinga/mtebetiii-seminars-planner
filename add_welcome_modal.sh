#!/usr/bin/env bash
# Run from inside "planner website/"
set -e

echo "Copying coffee icon into static..."
mkdir -p static/img
mv "buy-me-coffee-icon.webp" static/img/coffee.webp 2>/dev/null || echo "Note: buy-me-coffee-icon.webp not found at repo root, move it manually into static/img/coffee.webp"

# ---------------------------------------------------------------------------
# core/models.py — add proficiency fields to Student
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/models.py"
with open(path) as f:
    content = f.read()

old = '''class Student(models.Model):
    name = models.CharField(max_length=150)
    email = models.EmailField(unique=True)
    background_notes = models.TextField(
        blank=True,
        help_text="Background, prior experience, and learning goals."
    )
    created_at = models.DateTimeField(auto_now_add=True)'''

new = '''PROFICIENCY_CHOICES = [
    (1, "1 - New to it"),
    (2, "2 - Basic exposure"),
    (3, "3 - Comfortable"),
    (4, "4 - Confident"),
    (5, "5 - Advanced"),
]


class Student(models.Model):
    name = models.CharField(max_length=150)
    email = models.EmailField(unique=True)
    background_notes = models.TextField(
        blank=True,
        help_text="Background, prior experience, and learning goals."
    )
    goal_notes = models.CharField(
        max_length=255, blank=True,
        help_text="What the student wants to learn."
    )
    python_level = models.PositiveSmallIntegerField(
        choices=PROFICIENCY_CHOICES, null=True, blank=True
    )
    r_level = models.PositiveSmallIntegerField(
        choices=PROFICIENCY_CHOICES, null=True, blank=True
    )
    stata_level = models.PositiveSmallIntegerField(
        choices=PROFICIENCY_CHOICES, null=True, blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True)'''

assert old in content, "Student model block not found, please check core/models.py manually"
content = content.replace(old, new)

with open(path, "w") as f:
    f.write(content)

print("models.py updated with proficiency fields.")
PYEOF

# ---------------------------------------------------------------------------
# core/forms.py — add new fields to StudentIntakeForm
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/forms.py"
with open(path) as f:
    content = f.read()

old = '''class StudentIntakeForm(forms.ModelForm):
    class Meta:
        model = Student
        fields = ["name", "email", "background_notes"]'''

new = '''class StudentIntakeForm(forms.ModelForm):
    class Meta:
        model = Student
        fields = [
            "name", "email", "background_notes",
            "goal_notes", "python_level", "r_level", "stata_level",
        ]'''

assert old in content, "StudentIntakeForm Meta block not found, please check core/forms.py manually"
content = content.replace(old, new)

# add widgets for the new fields, right before the closing widgets dict end
marker = '"placeholder": "Background / Learning Goals",\n            }),\n        }'
new_widgets = '''"placeholder": "Background / Learning Goals",
            }),
            "goal_notes": forms.TextInput(attrs={
                "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none focus:border-[var(--mustard)]",
                "placeholder": "e.g. panel data methods for my thesis",
            }),
            "python_level": forms.RadioSelect,
            "r_level": forms.RadioSelect,
            "stata_level": forms.RadioSelect,
        }'''

assert marker in content, "Widgets marker not found, please check core/forms.py manually"
content = content.replace(marker, new_widgets)

with open(path, "w") as f:
    f.write(content)

print("forms.py updated with proficiency fields.")
PYEOF

# ---------------------------------------------------------------------------
# templates/base.html — bigger gif, coffee icon in footer button
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "templates/base.html"
with open(path) as f:
    content = f.read()

content = content.replace(
    '<img src="{% static \'img/welcome.gif\' %}" alt="" class="w-10 h-10 rounded-sm object-cover border rule">',
    '<img src="{% static \'img/welcome.gif\' %}" alt="" class="w-20 h-20 rounded-sm object-cover border rule">'
)

content = content.replace(
    '''<button onclick="document.getElementById('coffee-modal').classList.remove('hidden')"
      class="border border-[var(--mustard)] text-[var(--mustard)] hover:bg-[var(--mustard)] hover:text-white transition px-4 py-2 text-xs font-mono-custom">
      buy_me_a_coffee()
    </button>''',
    '''<button onclick="document.getElementById('coffee-modal').classList.remove('hidden')"
      class="flex items-center gap-2 border border-[var(--mustard)] text-[var(--mustard)] hover:bg-[var(--mustard)] hover:text-white transition px-4 py-2 text-xs font-mono-custom">
      <img src="{% static 'img/coffee.webp' %}" alt="" class="w-4 h-4">
      buy_me_a_coffee()
    </button>'''
)

with open(path, "w") as f:
    f.write(content)

print("base.html updated: bigger gif + coffee icon.")
PYEOF

# ---------------------------------------------------------------------------
# templates/core/starter_pack.html — welcome proficiency modal (auto-shows once per session)
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "templates/core/starter_pack.html"
with open(path) as f:
    content = f.read()

# Give the hidden main-form fields ids so JS can sync values from the modal
content = content.replace(
    '<label class="block font-mono-custom text-xs text-gray-500 mb-1">name</label>\n          {{ form.name }}',
    '<label class="block font-mono-custom text-xs text-gray-500 mb-1">name</label>\n          {{ form.name }}\n          {{ form.goal_notes.as_hidden }}\n          {{ form.python_level.as_hidden }}\n          {{ form.r_level.as_hidden }}\n          {{ form.stata_level.as_hidden }}'
)

modal_html = '''
<!-- Welcome / proficiency modal -->
<div id="welcome-modal" class="hidden fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4">
  <div class="bg-[var(--paper)] border-2 rule max-w-lg w-full p-6 relative max-h-[90vh] overflow-y-auto">
    <button onclick="closeWelcomeModal()" class="absolute top-3 right-3 text-gray-500 hover:text-black font-mono-custom">[x]</button>
    <p class="font-mono-custom text-xs text-gray-500 mb-1">before we start</p>
    <h3 class="font-serif-custom text-xl font-semibold mb-1">What do you want to learn?</h3>
    <p class="text-sm text-gray-600 mb-5">Tell us your goal and rate yourself on each tool. This helps tailor your plan.</p>

    <label class="block font-mono-custom text-xs text-gray-500 mb-1">what do you want to learn</label>
    <input id="modal-goal" type="text" placeholder="e.g. panel data methods for my thesis"
      class="w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm mb-6 focus:outline-none focus:border-[var(--mustard)]">

    <div class="space-y-5 mb-6">
      <div>
        <div class="flex items-center gap-2 mb-2">
          <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/python/python-original.svg" class="w-5 h-5" alt="Python">
          <span class="font-medium text-sm">Python</span>
        </div>
        <div class="flex gap-2" data-scale="modal-python">
          {% for i in "12345" %}
          <button type="button" onclick="setLevel('modal-python', {{ forloop.counter }})"
            class="level-btn w-9 h-9 border rule text-xs font-mono-custom hover:bg-[var(--mustard)] hover:text-white transition">{{ forloop.counter }}</button>
          {% endfor %}
        </div>
      </div>

      <div>
        <div class="flex items-center gap-2 mb-2">
          <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/r/r-original.svg" class="w-5 h-5" alt="R">
          <span class="font-medium text-sm">R</span>
        </div>
        <div class="flex gap-2" data-scale="modal-r">
          {% for i in "12345" %}
          <button type="button" onclick="setLevel('modal-r', {{ forloop.counter }})"
            class="level-btn w-9 h-9 border rule text-xs font-mono-custom hover:bg-[var(--mustard)] hover:text-white transition">{{ forloop.counter }}</button>
          {% endfor %}
        </div>
      </div>

      <div>
        <div class="flex items-center gap-2 mb-2">
          <span class="w-5 h-5 flex items-center justify-center bg-[var(--track-stata)] text-white text-[9px] font-mono-custom rounded-sm">S</span>
          <span class="font-medium text-sm">Stata</span>
        </div>
        <div class="flex gap-2" data-scale="modal-stata">
          {% for i in "12345" %}
          <button type="button" onclick="setLevel('modal-stata', {{ forloop.counter }})"
            class="level-btn w-9 h-9 border rule text-xs font-mono-custom hover:bg-[var(--mustard)] hover:text-white transition">{{ forloop.counter }}</button>
          {% endfor %}
        </div>
      </div>
    </div>

    <button onclick="saveWelcomeModal()" class="bg-[var(--ink)] text-white px-5 py-2.5 text-sm font-mono-custom hover:bg-black transition">
      save_and_continue()
    </button>
    <p class="text-xs text-gray-500 mt-3">This fills into the form below. You can still edit it before saving your plan.</p>
  </div>
</div>

<script>
  const levels = { "modal-python": null, "modal-r": null, "modal-stata": null };

  function setLevel(key, value) {
    levels[key] = value;
    document.querySelectorAll('[data-scale="' + key + '"] .level-btn').forEach((btn, idx) => {
      btn.classList.toggle('bg-[var(--mustard)]', idx + 1 === value);
      btn.classList.toggle('text-white', idx + 1 === value);
    });
  }

  function saveWelcomeModal() {
    const goal = document.getElementById('modal-goal').value;
    document.getElementById('id_goal_notes').value = goal;
    if (levels["modal-python"]) document.getElementById('id_python_level').value = levels["modal-python"];
    if (levels["modal-r"]) document.getElementById('id_r_level').value = levels["modal-r"];
    if (levels["modal-stata"]) document.getElementById('id_stata_level').value = levels["modal-stata"];
    closeWelcomeModal();
  }

  function closeWelcomeModal() {
    document.getElementById('welcome-modal').classList.add('hidden');
    sessionStorage.setItem('welcomeModalShown', '1');
  }

  document.addEventListener('DOMContentLoaded', () => {
    if (!sessionStorage.getItem('welcomeModalShown')) {
      document.getElementById('welcome-modal').classList.remove('hidden');
    }
  });
</script>
'''

content = content.rstrip()
if content.endswith("{% endblock %}"):
    content = content[: -len("{% endblock %}")] + modal_html + "\n{% endblock %}"

with open(path, "w") as f:
    f.write(content)

print("starter_pack.html updated with welcome modal.")
PYEOF

echo ""
echo "-------------------------------------------------------------"
echo "Now run:"
echo "  python manage.py makemigrations core"
echo "  python manage.py migrate"
echo "  python manage.py runserver"
echo "-------------------------------------------------------------"