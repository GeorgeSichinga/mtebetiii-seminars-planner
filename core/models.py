from django.db import models
from django.utils import timezone
from django.contrib.auth.hashers import make_password, check_password


PROFICIENCY_CHOICES = [
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
    password_hash = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name

    def set_password(self, raw_password):
        self.password_hash = make_password(raw_password)

    def check_password(self, raw_password):
        if not self.password_hash:
            return False
        return check_password(raw_password, self.password_hash)


class Topic(models.Model):
    TRACK_CHOICES = [
        ("stata", "Stata"),
        ("r", "R"),
        ("python", "Python"),
        ("capstone", "Capstone"),
    ]

    title = models.CharField(max_length=200)
    track = models.CharField(max_length=20, choices=TRACK_CHOICES)
    description = models.TextField(blank=True)
    order = models.PositiveIntegerField(default=0, help_text="Order within track.")

    class Meta:
        ordering = ["track", "order", "title"]

    def __str__(self):
        return f"{self.get_track_display()} #{self.order}: {self.title}"


class StudentTopicSelection(models.Model):
    student = models.ForeignKey(
        Student, on_delete=models.CASCADE, related_name="topic_selections"
    )
    topic = models.ForeignKey(
        Topic, on_delete=models.CASCADE, related_name="selections"
    )
    selected_at = models.DateTimeField(auto_now_add=True)
    completed = models.BooleanField(default=False)

    class Meta:
        unique_together = ("student", "topic")
        ordering = ["topic__track", "topic__order"]

    def __str__(self):
        return f"{self.student.name} - {self.topic.title}"


class Session(models.Model):
    student = models.ForeignKey(
        Student, on_delete=models.CASCADE, related_name="sessions"
    )
    topic = models.ForeignKey(
        Topic, on_delete=models.SET_NULL, null=True, blank=True, related_name="sessions"
    )
    scheduled_for = models.DateTimeField()
    notes = models.TextField(blank=True)
    is_completed = models.BooleanField(default=False)
    reminder_sent = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["scheduled_for"]

    def __str__(self):
        return f"Session: {self.student.name} @ {self.scheduled_for:%Y-%m-%d %H:%M}"

    @property
    def is_upcoming(self):
        return not self.is_completed and self.scheduled_for >= timezone.now()


class Assignment(models.Model):
    student = models.ForeignKey(
        Student, on_delete=models.CASCADE, related_name="assignments"
    )
    session = models.ForeignKey(
        Session, on_delete=models.SET_NULL, null=True, blank=True, related_name="assignments"
    )
    topic = models.ForeignKey(
        Topic, on_delete=models.SET_NULL, null=True, blank=True, related_name="assignments"
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    due_date = models.DateField(null=True, blank=True)
    is_done = models.BooleanField(default=False)

    class Meta:
        ordering = ["due_date", "title"]

    def __str__(self):
        return self.title


class Note(models.Model):
    title = models.CharField(max_length=200)
    content = models.TextField(blank=True)
    attachment = models.FileField(upload_to="notes/", blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.title
