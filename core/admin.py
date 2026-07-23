from django.contrib import admin
from .models import Student, Topic, StudentTopicSelection, Session, Assignment, Note


@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display = ("name", "email", "created_at")
    search_fields = ("name", "email")


@admin.register(Topic)
class TopicAdmin(admin.ModelAdmin):
    list_display = ("title", "track", "order")
    list_filter = ("track",)
    ordering = ("track", "order")


@admin.register(StudentTopicSelection)
class StudentTopicSelectionAdmin(admin.ModelAdmin):
    list_display = ("student", "topic", "completed", "selected_at")
    list_filter = ("completed", "topic__track")


@admin.register(Session)
class SessionAdmin(admin.ModelAdmin):
    list_display = ("student", "topic", "scheduled_for", "is_completed", "reminder_sent")
    list_filter = ("is_completed", "reminder_sent")


@admin.register(Assignment)
class AssignmentAdmin(admin.ModelAdmin):
    list_display = ("title", "student", "due_date", "is_done")
    list_filter = ("is_done",)


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ("title", "created_at")
