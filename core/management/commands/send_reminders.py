from datetime import timedelta

from django.core.management.base import BaseCommand
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone

from core.models import Session


class Command(BaseCommand):
    help = "Sends email reminders for sessions scheduled in the next 24 hours."

    def add_arguments(self, parser):
        parser.add_argument(
            "--hours-ahead",
            type=int,
            default=24,
            help="How many hours ahead to look for upcoming sessions (default: 24).",
        )

    def handle(self, *args, **options):
        hours_ahead = options["hours_ahead"]
        now = timezone.now()
        window_end = now + timedelta(hours=hours_ahead)

        sessions = Session.objects.filter(
            scheduled_for__gte=now,
            scheduled_for__lte=window_end,
            reminder_sent=False,
            is_completed=False,
        ).select_related("student", "topic")

        sent_count = 0
        for session in sessions:
            subject = "Upcoming Session Reminder"
            topic_line = f" on {session.topic.title}" if session.topic else ""
            message = (
                f"Hi {session.student.name},\n\n"
                f"This is a reminder of your upcoming session{topic_line}, "
                f"scheduled for {session.scheduled_for:%Y-%m-%d %H:%M}.\n\n"
                f"Notes: {session.notes or 'None'}\n"
            )
            send_mail(
                subject,
                message,
                getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@example.com"),
                [session.student.email],
                fail_silently=False,
            )
            session.reminder_sent = True
            session.save(update_fields=["reminder_sent"])
            sent_count += 1

        self.stdout.write(self.style.SUCCESS(f"Sent {sent_count} reminder(s)."))
