from django import forms
from .models import Student, Session, Topic, Note, Assignment


class StudentIntakeForm(forms.ModelForm):
    password = forms.CharField(
        min_length=6,
        widget=forms.PasswordInput(attrs={
            "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none",
            "placeholder": "Create a password (min 6 characters)",
        }),
    )

    class Meta:
        model = Student
        fields = ["name", "email", "background_notes", "goal_notes", "python_level", "r_level", "stata_level"]
        widgets = {
            "name": forms.TextInput(attrs={
                "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none",
                "placeholder": "Full Name",
            }),
            "email": forms.EmailInput(attrs={
                "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none",
                "placeholder": "Email Address",
            }),
            "background_notes": forms.Textarea(attrs={
                "class": "w-full border-0 border-b rule bg-transparent px-1 py-2 text-sm focus:outline-none",
                "rows": 3,
                "placeholder": "Background / Learning Goals",
            }),
            "goal_notes": forms.HiddenInput(),
            "python_level": forms.RadioSelect,
            "r_level": forms.RadioSelect,
            "stata_level": forms.RadioSelect,
        }

    def save(self, commit=True):
        student = super().save(commit=False)
        student.set_password(self.cleaned_data["password"])
        if commit:
            student.save()
        return student


class TopicSelectionForm(forms.Form):
    topics = forms.ModelMultipleChoiceField(
        queryset=Topic.objects.all(),
        widget=forms.CheckboxSelectMultiple,
        required=False,
    )


class SessionForm(forms.ModelForm):
    student_email = forms.EmailField(
        required=False,
        widget=forms.EmailInput(attrs={
            "class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]",
            "placeholder": "the email you registered with",
        }),
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["student"].required = False
        self.fields["student"].empty_label = "Select a student"
        self.fields["topic"].empty_label = "Select a topic"

    class Meta:
        model = Session
        fields = ["student", "topic", "scheduled_for", "notes"]
        widgets = {
            "student": forms.Select(attrs={"class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]"}),
            "topic": forms.Select(attrs={"class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]"}),
            "scheduled_for": forms.DateTimeInput(
                attrs={"type": "datetime-local", "class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]"}
            ),
            "notes": forms.Textarea(attrs={"class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]", "rows": 3}),
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


class AssignmentForm(forms.ModelForm):
    class Meta:
        model = Assignment
        fields = ["student", "topic", "session", "title", "description", "due_date"]
        widgets = {
            "student": forms.Select(attrs={"class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]"}),
            "topic": forms.Select(attrs={"class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]"}),
            "session": forms.Select(attrs={"class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]"}),
            "title": forms.TextInput(attrs={"class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]", "placeholder": "Assignment title"}),
            "description": forms.Textarea(attrs={"class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]", "rows": 3}),
            "due_date": forms.DateInput(attrs={"type": "date", "class": "w-full border rule bg-transparent px-3 py-2 text-sm focus:outline-none focus:border-[var(--accent)]"}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["topic"].required = False
        self.fields["session"].required = False
        self.fields["topic"].empty_label = "None"
        self.fields["session"].empty_label = "None"
