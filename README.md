# D-SCAE — Dynamic Schema Collection & Analytics Engine

Flask + Oracle Database mini-project. Admins build dynamic forms with custom
fields, eligibility rules, and per-question analytics; students see only the
forms they're eligible for and submit responses through a typed UI.

## Stack

- **Backend:** Python 3.12, Flask, `python-oracledb` (thin mode, no Instant Client)
- **Database:** Oracle Database 23 Free (via `gvenzl/oracle-free`)
- **Frontend:** Server-side Jinja templates + Chart.js
- **Deploy:** docker-compose, two services (`db`, `web`)

## Quick start

You need Docker Desktop (or any Docker engine) and `docker compose`.

```bash
cp .env.example .env       # tweak passwords if you like
docker compose up --build
```

First boot pulls the Oracle image (~1.4 GB) and waits ~60-90 s for the DB to
finish initialising — the schema, PL/SQL objects, and seed data load
automatically. Subsequent boots are seconds.

Open http://localhost:5050 (or whatever `PORT` you set in `.env`) and sign in
with the seeded credentials below.

## Test credentials

| Role    | Username | Password      |
|---------|----------|---------------|
| Admin   | admin1   | `Admin@123`   |
| Admin   | admin2   | `Admin@123`   |
| Student | pranav   | `Student@123` |
| Student | sreejesh | `Student@123` |
| Student | alice    | `Student@123` |
| Student | bob      | `Student@123` |
| Student | carol    | `Student@123` |
| Student | dave     | `Student@123` |

`pranav` is MCA / sem 4 / CGPA 9.1 — eligible for the seeded Hackathon form.
`bob` is CSE / sem 4 / CGPA 6.5 — useful for testing the ineligibility path.

## Repo layout

```
.
├── app.py                  # Flask routes
├── db.py                   # Oracle connection pool + query helpers
├── auth.py                 # Password hashing + login/admin decorators
├── requirements.txt
├── Dockerfile              # Flask app image
├── docker-compose.yml      # db + web services
├── .env.example
├── docker/
│   └── init.sh             # Bootstraps schema as APP_USER on first DB start
├── sql/
│   ├── 01_schema.sql       # Tables, sequences, constraints
│   ├── 02_plsql.sql        # Procedures, functions, triggers
│   └── 03_seed.sql         # Demo users (with real SHA-256 hashes), forms, fields, rules, sample submissions
├── templates/              # Jinja templates
└── static/css/             # Stylesheet
```

## Schema highlights

Six tables (`USERS`, `FORMS`, `FORM_FIELDS`, `ACCESS_RULES`, `SUBMISSIONS`,
`RESPONSES`) plus a `NOTIFICATIONS` table populated by trigger.

PL/SQL objects in `sql/02_plsql.sql`:

- `fn_is_eligible(user_id, form_id)` — evaluates all access rules for a form
  and returns `'ELIGIBLE'` / `'NOT ELIGIBLE'`. Called from the dashboard query
  and from the submit guard.
- `sp_submit_form(...)` — atomic submission procedure (rule check + dup check
  + insert). The Flask app inlines the same logic in Python so it works
  without arrays of bind variables, but the procedure is here for the rubric.
- `fn_form_analytics(form_id)` — ref-cursor function that returns per-field
  aggregates.
- `trg_auto_close_form` — closes a form when its `end_date` is reached.
- `trg_no_duplicate_submission` — second-line defence against double submits.
- `trg_form_create_notifications` — fans out a NOTIFICATIONS row to every
  student when a new form is created.

## Local dev (without Docker)

If you have an Oracle instance running already:

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export $(grep -v '^#' .env | xargs)   # or set them by hand
flask --app app run
```

Load the schema once with:

```bash
sqlplus "${DB_USER}/${DB_PASSWORD}@//${DB_HOST}:${DB_PORT}/${DB_SERVICE}" \
  @sql/01_schema.sql @sql/02_plsql.sql @sql/03_seed.sql
```

## Useful commands

```bash
docker compose logs -f web              # Flask logs
docker compose logs -f db               # Oracle bring-up logs
# Open a SQL*Plus shell as the app user (env vars expand inside the container).
docker compose exec db bash -c 'sqlplus "$APP_USER/$APP_USER_PASSWORD@//localhost:1521/$DB_SERVICE"'
docker compose down                     # stop, keep data
docker compose down -v                  # stop and wipe the DB volume (re-runs init.sh next boot)
```
