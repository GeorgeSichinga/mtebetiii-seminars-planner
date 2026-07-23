# Project Summary

This project is a Django-based learning planner for an applied data analysis or econometrics curriculum. It helps a student submit an intake form, choose topics from several tracks, review a dashboard of selected topics and assignments, and schedule teaching sessions. The design uses a notebook-style interface with Tailwind CSS and a custom serif/sans-serif typography pairing.

## What the app does

- Collects a student profile and background notes through a starter form.
- Lets the student pick topics from Stata, R, Python, and Capstone tracks.
- Creates a personalized curriculum by saving selected topics for that student.
- Shows a dashboard with progress, selected syllabus topics, and assignments.
- Provides a session planner for creating and reviewing scheduled sessions.
- Supports email reminders for upcoming sessions.
- Includes a seed command to populate the default topic catalogue.

## Main data model

- `Student`: stores the learner’s name, email, and background notes.
- `Topic`: stores syllabus items grouped by track and ordered within each track.
- `StudentTopicSelection`: records which topics a student selected.
- `Session`: stores planned teaching sessions, notes, completion status, and reminder state.
- `Assignment`: stores student tasks linked to a session when needed.

## Core file roles

- `models.py`: defines the database schema.
- `forms.py`: defines the intake and session forms.
- `views.py`: handles the starter pack, dashboard, and schedule pages.
- `admin.py`: registers the models in Django admin.
- `data_notebook_urls.py`: routes the app and admin URLs.
- `base.html`: shared layout, styling, and navigation shell.
- `starter_pack.html`: intake page where topics are chosen.
- `dashboard.html`: student progress and assignment overview.
- `schedule.html`: session planning and timeline view.
- `seed_topics.py`: management command that seeds the topic catalogue.
- `send_reminders.py`: management command that emails session reminders.

## Project shape

The checked-in structure suggests the intended app layout is a Django project named `data_notebook` with a `core` app, templates under `templates/`, and management commands under `core/management/commands/`. Some files currently appear at the repository root, so the tree in `Project structure.txt` looks like the intended final organization.

## Short handoff

If another model needs to continue working on this project, the key idea is: this is a student-facing curriculum planner that converts an intake form and topic selections into a personalized dashboard and session workflow.