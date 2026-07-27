# Generated manually to add ownership to notes.

from django.db import migrations, models


def backfill_note_owner(apps, schema_editor):
    Student = apps.get_model('core', 'Student')
    Note = apps.get_model('core', 'Note')

    owner = Student.objects.filter(is_teacher=True).order_by('id').first()
    if owner is None:
        owner = Student.objects.order_by('id').first()

    if owner is None:
        return

    Note.objects.filter(owner__isnull=True).update(owner=owner)


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0006_student_is_teacher'),
    ]

    operations = [
        migrations.AddField(
            model_name='note',
            name='owner',
            field=models.ForeignKey(null=True, blank=True, on_delete=models.CASCADE, related_name='notes', to='core.student'),
        ),
        migrations.RunPython(backfill_note_owner, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='note',
            name='owner',
            field=models.ForeignKey(on_delete=models.CASCADE, related_name='notes', to='core.student'),
        ),
    ]