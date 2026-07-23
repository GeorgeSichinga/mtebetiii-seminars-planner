#!/usr/bin/env bash
# Run from inside "planner website/"
set -e

echo "Prepping project for deployment..."

# ---------------------------------------------------------------------------
# .gitignore
# ---------------------------------------------------------------------------
cat > .gitignore << 'EOF'
venv/
__pycache__/
*.pyc
db.sqlite3
.env
media/
staticfiles/
.vscode/
EOF
echo ".gitignore created."

# ---------------------------------------------------------------------------
# Procfile for Render/Heroku-style deploys
# ---------------------------------------------------------------------------
cat > Procfile << 'EOF'
web: gunicorn data_notebook.wsgi --log-file -
EOF
echo "Procfile created."

# ---------------------------------------------------------------------------
# build.sh — Render build command
# ---------------------------------------------------------------------------
cat > build.sh << 'EOF'
#!/usr/bin/env bash
set -o errexit

pip install -r requirements.txt

python manage.py collectstatic --no-input
python manage.py migrate
EOF
chmod +x build.sh
echo "build.sh created."

# ---------------------------------------------------------------------------
# Ensure gunicorn + whitenoise + psycopg2-binary are in requirements.txt
# ---------------------------------------------------------------------------
python - << 'PYEOF'
path = "requirements.txt"
with open(path) as f:
    content = f.read()

needed = ["gunicorn", "whitenoise", "psycopg2-binary", "dj-database-url", "python-decouple"]
lines = content.splitlines()
existing_lower = [l.split("==")[0].strip().lower() for l in lines if l.strip()]

added = []
for pkg in needed:
    if pkg.lower() not in existing_lower:
        lines.append(pkg)
        added.append(pkg)

with open(path, "w") as f:
    f.write("\n".join(lines) + "\n")

if added:
    print(f"requirements.txt: added {', '.join(added)}")
else:
    print("requirements.txt: all required packages already present.")
PYEOF

echo ""
echo "-------------------------------------------------------------"
echo "MANUAL STEP: settings.py changes for production"
echo "-------------------------------------------------------------"
echo "Open data_notebook/settings.py and make sure it has these (add/adjust as needed):"
echo ""
cat << 'EOF'
import os

DEBUG = config('DEBUG', default=False, cast=bool)

ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='127.0.0.1,localhost').split(',')

# Static files (add whitenoise)
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',   # add this line right after SecurityMiddleware
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Database (Render provides DATABASE_URL automatically)
DATABASES = {
    'default': dj_database_url.config(
        default=config('DATABASE_URL', default=f'sqlite:///{BASE_DIR / "db.sqlite3"}')
    )
}
EOF
echo "-------------------------------------------------------------"
echo "Also add near the top of settings.py if not present:"
echo "  import dj_database_url"
echo "-------------------------------------------------------------"
