#!/usr/bin/env bash
# Run from inside "planner website/"
set -e

echo "Adding magic-link login for student dashboards..."

# ---------------------------------------------------------------------------
# core/views.py — replace email-lookup with magic-link request + verify + session gating
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/views.py"
with open(path) as f:
    content = f.read()

# Add imports needed for signing + email
if "from django.core.signing import" not in content:
    content = content.replace(
        "from django.utils import timezone",
        "from django.utils import timezone\nfrom django.core.signing import TimestampSigner, BadSignature, SignatureExpired\nfrom django.core.mail import send_mail\nfrom django.conf import settings\nfrom django.urls import reverse"
    )

old_dash = '''def dashboard(request, student_id=None):
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

new_dash = '''SIGNER = TimestampSigner(salt="mtebetiii-dashboard-login")
MAGIC_LINK_MAX_AGE = 60 * 15  # 15 minutes


def dashboard(request, student_id=None):
    student = None
    selections = []
    assignments = []

    if student_id:
        candidate = get_object_or_404(Student, id=student_id)
        if request.session.get("student_id") == candidate.id:
            student = candidate
        else:
            messages.error(request, "Please log in to view that dashboard.")
            return redirect("dashboard")

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


def request_magic_link(request):
    email = request.POST.get("email", "").strip()
    if not email:
        messages.error(request, "Please enter your registered email.")
        return redirect("dashboard")

    student = Student.objects.filter(email__iexact=email).first()
    if not student:
        messages.error(request, "No student found with that email. Register on the Starter Pack page first.")
        return redirect("dashboard")

    token = SIGNER.sign(str(student.id))
    link = request.build_absolute_uri(reverse("dashboard_login", args=[token]))

    send_mail(
        "Your dashboard login link",
        f"Hi {student.name},\\n\\nClick this link to view your dashboard "
        f"(valid for 15 minutes):\\n\\n{link}\\n",
        getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@example.com"),
        [student.email],
        fail_silently=False,
    )

    messages.success(request, "A login link has been sent to your email. Check your inbox.")
    return redirect("dashboard")


def dashboard_login(request, token):
    try:
        student_id = int(SIGNER.unsign(token, max_age=MAGIC_LINK_MAX_AGE))
    except SignatureExpired:
        messages.error(request, "That login link has expired. Please request a new one.")
        return redirect("dashboard")
    except BadSignature:
        messages.error(request, "That login link is invalid.")
        return redirect("dashboard")

    student = get_object_or_404(Student, id=student_id)
    request.session["student_id"] = student.id
    messages.success(request, f"Welcome back, {student.name}.")
    return redirect("dashboard", student_id=student.id)


def dashboard_logout(request):
    request.session.pop("student_id", None)
    messages.success(request, "Logged out.")
    return redirect("dashboard")'''

assert old_dash in content, "dashboard()/dashboard_lookup() block not found exactly, please check core/views.py manually"
content = content.replace(old_dash, new_dash)

with open(path, "w") as f:
    f.write(content)

print("views.py: magic-link login flow added, dashboard now session-gated.")
PYEOF

# ---------------------------------------------------------------------------
# core/urls.py — add magic-link routes, remove old lookup route
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/urls.py"
with open(path) as f:
    content = f.read()

content = content.replace(
    'path("dashboard/lookup/", views.dashboard_lookup, name="dashboard_lookup"),\n    ',
    ''
)

if 'name="request_magic_link"' not in content:
    content = content.replace(
        'path("dashboard/<int:student_id>/", views.dashboard, name="dashboard"),',
        '''path("dashboard/<int:student_id>/", views.dashboard, name="dashboard"),
    path("dashboard/login/request/", views.request_magic_link, name="request_magic_link"),
    path("dashboard/login/<str:token>/", views.dashboard_login, name="dashboard_login"),
    path("dashboard/logout/", views.dashboard_logout, name="dashboard_logout"),'''
    )
    with open(path, "w") as f:
        f.write(content)
    print("urls.py: magic-link routes added.")
else:
    print("urls.py: magic-link routes already present, skipped.")
PYEOF

# ---------------------------------------------------------------------------
# templates/core/dashboard.html — login form when logged out, logout link when in
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "templates/core/dashboard.html"
with open(path) as f:
    content = f.read()

old_block = '''<div class="mb-8">
  <p class="text-xs opacity-60">Enter the link you were given, or the email you registered with, to view your dashboard.</p>
  <form method="get" action="{% url 'dashboard_lookup' %}" class="flex gap-2 mt-2">
    <input type="email" name="email" placeholder="your registered email"
      class="border rule bg-transparent px-3 py-2 text-sm flex-1 focus:outline-none focus:border-[var(--accent)]" required>
    <button type="submit" class="bg-[var(--accent)] text-white px-4 py-2 text-sm hover:opacity-90 transition">view</button>
  </form>
</div>'''

new_block = '''{% if not student %}
<div class="mb-8">
  <p class="text-xs opacity-60 mb-2">Enter the email you registered with and we'll email you a login link (valid 15 minutes).</p>
  <form method="post" action="{% url 'request_magic_link' %}" class="flex gap-2">
    {% csrf_token %}
    <input type="email" name="email" placeholder="your registered email"
      class="border rule bg-transparent px-3 py-2 text-sm flex-1 focus:outline-none focus:border-[var(--accent)]" required>
    <button type="submit" class="bg-[var(--accent)] text-white px-4 py-2 text-sm hover:opacity-90 transition">send login link</button>
  </form>
</div>
{% else %}
<div class="mb-8 flex justify-end">
  <a href="{% url 'dashboard_logout' %}" class="text-xs underline opacity-70 hover:accent">log out</a>
</div>
{% endif %}'''

if old_block in content:
    content = content.replace(old_block, new_block)
else:
    # in case an earlier version of dashboard.html still has the raw student loop/select, patch by inserting right after the h1
    content = content.replace(
        '<h1 class="text-xl font-bold mb-6">Dashboard</h1>',
        '<h1 class="text-xl font-bold mb-6">Dashboard</h1>\n\n' + new_block
    )

with open(path, "w") as f:
    f.write(content)

print("dashboard.html: magic-link request form / logout link added.")
PYEOF

echo ""
echo "-------------------------------------------------------------"
echo "IMPORTANT: settings.py must have a working EMAIL_BACKEND for links to send."
echo "For local testing, console backend is fine (prints the email/link to your terminal):"
echo "  EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'"
echo "For production on Render, you'll want a real SMTP provider (e.g. SendGrid, Mailgun)"
echo "configured via env vars, since Render does not provide outbound SMTP itself."
echo "-------------------------------------------------------------"
echo "Done. Restart the server:"
echo "  python manage.py runserver"
echo ""
echo "Test flow: go to /dashboard/, enter your registered email, check your terminal"
echo "(console backend prints the email including the magic link), copy/paste that"
echo "link into your browser to log in."
