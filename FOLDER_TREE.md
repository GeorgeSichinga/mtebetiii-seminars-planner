# Project Folder Tree

```text
planner website/
|-- manage.py
|-- db.sqlite3
|-- requirements.txt
|-- Project structure.txt
|-- PROJECT_SUMMARY.md
|-- core/
|   |-- __init__.py
|   |-- admin.py
|   |-- forms.py
|   |-- models.py
|   |-- url.py [legacy / stray]
|   |-- urls.py
|   |-- views.py
|   |-- management/
|   |   |-- __init__.py
|   |   |-- commands/
|   |   |   |-- __init__.py
|   |   |   |-- seed_topics.py
|   |   |   `-- send_reminders.py
|   |-- migrations/
|   |   |-- __init__.py
|   |   `-- 0001_initial.py
|   `-- templates/
|       `-- core/
|           `-- home.html
|-- data_notebook/
|   |-- __init__.py
|   |-- settings.py
|   |-- urls.py
|   `-- wsgi.py
`-- templates/
    |-- base.html
    `-- core/
        |-- dashboard.html
        |-- schedule.html
        `-- starter_pack.html
```

## What each area contains

- `manage.py`: Django entry point for commands and server startup.
- `data_notebook/`: Project configuration package.
- `core/`: Main app code, models, forms, views, admin, migrations, and commands.
- `templates/`: Shared and page-level templates used by the active app flow.
- `db.sqlite3`: Local development database.
- `requirements.txt`: Python dependencies.
- `Project structure.txt`: Original target tree/reference.
- `PROJECT_SUMMARY.md`: High-level handoff summary.

## Notes

- `core/url.py` looks like an older or accidental routing file. The active router is `core/urls.py`.
- Generated folders such as `__pycache__/` and the virtual environment are intentionally omitted from this tree.