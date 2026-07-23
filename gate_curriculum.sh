#!/usr/bin/env bash
# Run from inside "planner website/"
set -e

echo "Adding error display and gating curriculum behind login..."

# ---------------------------------------------------------------------------
# core/views.py — auto-login after registration, gate topics behind session
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "core/views.py"
with open(path) as f:
    content = f.read()

old_starter = '''def starter_pack(request):
    """Intake form + topic picker."""
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
        "tracks": tracks,
        "topic_count": topics.count(),
    }
    return render(request, "core/starter_pack.html", context)'''

new_starter = '''def starter_pack(request):
    """Registration for new visitors, or private curriculum picker once logged in."""
    logged_in_student = None
    student_id_in_session = request.session.get("student_id")
    if student_id_in_session:
        logged_in_student = Student.objects.filter(id=student_id_in_session).first()

    topics = Topic.objects.all()
    tracks = {}
    for topic in topics:
        tracks.setdefault(topic.track, []).append(topic)

    if logged_in_student:
        # Logged-in flow: update this student's own topic selections only.
        if request.method == "POST" and "save_topics" in request.POST:
            selected_ids = set(int(i) for i in request.POST.getlist("topics"))
            existing_ids = set(
                StudentTopicSelection.objects.filter(student=logged_in_student)
                .values_list("topic_id", flat=True)
            )
            for topic_id in selected_ids - existing_ids:
                StudentTopicSelection.objects.get_or_create(
                    student=logged_in_student, topic_id=topic_id
                )
            StudentTopicSelection.objects.filter(
                student=logged_in_student
            ).exclude(topic_id__in=selected_ids).delete()
            messages.success(request, "Your curriculum has been updated.")
            return redirect("starter_pack")

        selected_topic_ids = set(
            StudentTopicSelection.objects.filter(student=logged_in_student)
            .values_list("topic_id", flat=True)
        )
        context = {
            "student": logged_in_student,
            "tracks": tracks,
            "topic_count": topics.count(),
            "selected_topic_ids": selected_topic_ids,
        }
        return render(request, "core/starter_pack.html", context)

    # Anonymous flow: registration only, curriculum stays hidden until logged in.
    if request.method == "POST":
        form = StudentIntakeForm(request.POST)
        if form.is_valid():
            student = form.save()
            request.session["student_id"] = student.id
            messages.success(request, f"Welcome, {student.name}. Now pick the topics you want to cover.")
            return redirect("starter_pack")
    else:
        form = StudentIntakeForm()

    context = {
        "student": None,
        "form": form,
        "topic_count": topics.count(),
    }
    return render(request, "core/starter_pack.html", context)'''

assert old_starter in content, "starter_pack() block not found exactly, please check core/views.py manually"
content = content.replace(old_starter, new_starter)

with open(path, "w") as f:
    f.write(content)

print("views.py: starter_pack() now gates curriculum behind login/registration.")
PYEOF

echo ""
echo "Now overwrite templates/core/starter_pack.html with the gated version below."
echo "(printed separately so you can paste it directly)"
