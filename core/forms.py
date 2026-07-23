from django import forms
from .models import Student, Session, Topic, Note


class StudentIntakeForm(forms.ModelForm):
    class Meta:
        model = Student
        fields = [
            "name", "email", "background_notes",
            "goal_notes", "python_level", "r_level", "stata_level",
        ]
        widgets = {
            "name": forms.TextInput(attrs={
                "class": "w-full border border-gray-300 rounded-md px-3 py-2",
                "placeholder": "Full Name",
            }),
            "email": forms.EmailInput(attrs={
                "class": "w-full border border-gray-300 rounded-md px-3 py-2",
                "placeholder": "Email Address",
            }),
            "background_notes": forms.Textarea(attrs={
                "class": "w-full border border-gray-300 rounded-md px-3 py-2",
                "rows": 4,
                "placeholder": "Background / Learning Goals",
            }),
            "goal_notes": forms.TextInput(attrs={
                "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none focus:border-[var(--mustard)]",
                "placeholder": "e.g. panel data methods for my thesis",
            }),
            "python_level": forms.RadioSelect,
            "r_level": forms.RadioSelect,
            "stata_level": forms.RadioSelect,
        }


class TopicSelectionForm(forms.Form):
    topics = forms.ModelMultipleChoiceField(
        queryset=Topic.objects.all(),
        widget=forms.CheckboxSelectMultiple,
        required=False,
    )


class SessionForm(forms.ModelForm):
    class Meta:
        model = Session
        fields = ["student", "topic", "scheduled_for", "notes"]
        widgets = {
            "student": forms.Select(attrs={"class": "w-full border border-gray-300 rounded-md px-3 py-2"}),
            "topic": forms.Select(attrs={"class": "w-full border border-gray-300 rounded-md px-3 py-2"}),
            "scheduled_for": forms.DateTimeInput(
                attrs={"type": "datetime-local", "class": "w-full border border-gray-300 rounded-md px-3 py-2"}
            ),
            "notes": forms.Textarea(attrs={"class": "w-full border border-gray-300 rounded-md px-3 py-2", "rows": 3}),
        }


class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ["title", "content", "attachment"]
        widgets = {
            "title": forms.TextInput(attrs={
                "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none",
                "placeholder": "Note title",
            }),
            "content": forms.Textarea(attrs={
                "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none",
                "rows": 5,
                "placeholder": "Write your note here...",
            }),
        }
