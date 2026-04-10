"""
D-SCAE Flask Backend  |  app.py
Install: pip install flask oracledb
Run:     python app.py

If Oracle DB is unreachable, the app auto-starts in DEMO mode
with in-memory sample data so you can explore the full UI.
"""

from flask import Flask, render_template, request, redirect, url_for, session, jsonify, flash
import hashlib
import os
from functools import wraps
from datetime import datetime, timedelta

app = Flask(__name__)
app.secret_key = os.urandom(24)

# ── Oracle connection ──────────────────────────────────────────────────────────
DB_HOST    = os.environ.get("DB_HOST", "localhost")
DB_PORT    = os.environ.get("DB_PORT", "1521")
DB_SERVICE = os.environ.get("DB_SERVICE", "XE")
DB_USER    = os.environ.get("DB_USER", "dscae")
DB_PASS    = os.environ.get("DB_PASS", "dscae123")

DEMO_MODE = False  # will be set True if Oracle is unreachable

# Try importing oracledb
try:
    import oracledb as cx_Oracle
    DB_DSN = cx_Oracle.makedsn(DB_HOST, int(DB_PORT), service_name=DB_SERVICE)
except ImportError:
    cx_Oracle = None
    DB_DSN = None
    DEMO_MODE = True

# ── Demo data ──────────────────────────────────────────────────────────────────
def hash_pw(pw):
    return hashlib.sha256(pw.encode()).hexdigest()

def _build_demo_data():
    now = datetime.now()
    users = [
        {'user_id': 1, 'username': 'admin1',   'email': 'admin1@mit.edu',   'password_hash': hash_pw('Admin@123'),   'branch': 'ADMIN', 'cgpa': 10.0, 'semester': 'NA',  'role': 'admin',   'created_at': now},
        {'user_id': 2, 'username': 'admin2',   'email': 'admin2@mit.edu',   'password_hash': hash_pw('Admin@123'),   'branch': 'MCA',   'cgpa': 9.2,  'semester': 'NA',  'role': 'admin',   'created_at': now},
        {'user_id': 3, 'username': 'pranav',   'email': 'pranav@mit.edu',   'password_hash': hash_pw('Student@123'), 'branch': 'MCA',   'cgpa': 9.1,  'semester': '4',   'role': 'student', 'created_at': now},
        {'user_id': 4, 'username': 'sreejesh', 'email': 'sreejesh@mit.edu', 'password_hash': hash_pw('Student@123'), 'branch': 'MCA',   'cgpa': 8.7,  'semester': '4',   'role': 'student', 'created_at': now},
        {'user_id': 5, 'username': 'alice',    'email': 'alice@mit.edu',    'password_hash': hash_pw('Student@123'), 'branch': 'CSE',   'cgpa': 8.2,  'semester': '4',   'role': 'student', 'created_at': now},
        {'user_id': 6, 'username': 'bob',      'email': 'bob@mit.edu',      'password_hash': hash_pw('Student@123'), 'branch': 'CSE',   'cgpa': 6.5,  'semester': '4',   'role': 'student', 'created_at': now},
        {'user_id': 7, 'username': 'carol',    'email': 'carol@mit.edu',    'password_hash': hash_pw('Student@123'), 'branch': 'ECE',   'cgpa': 8.9,  'semester': '2',   'role': 'student', 'created_at': now},
        {'user_id': 8, 'username': 'dave',     'email': 'dave@mit.edu',     'password_hash': hash_pw('Student@123'), 'branch': 'MCA',   'cgpa': 7.3,  'semester': '6',   'role': 'student', 'created_at': now},
    ]
    forms = [
        {'form_id': 1, 'created_by': 1, 'title': 'Hackathon Registration 2026',    'description': 'Register for the annual MIT Hackathon. Open to 4th sem MCA with CGPA > 8.0',  'status': 'open',   'start_date': now - timedelta(days=2), 'end_date': now + timedelta(days=10)},
        {'form_id': 2, 'created_by': 1, 'title': 'Mid-Sem Feedback Survey',        'description': 'Anonymous feedback for DBS Lab',                                               'status': 'open',   'start_date': now - timedelta(days=1), 'end_date': now + timedelta(days=5)},
        {'form_id': 3, 'created_by': 2, 'title': 'Placement Eligibility Poll',     'description': 'Check eligibility for campus placements',                                      'status': 'closed', 'start_date': now - timedelta(days=20),'end_date': now - timedelta(days=5)},
    ]
    fields = [
        {'field_id': 1, 'form_id': 1, 'field_name': 'Team Name',        'field_type': 'TEXT',    'is_required': 1, 'validation_rule': '^[A-Za-z0-9 ]{3,30}$', 'display_order': 1},
        {'field_id': 2, 'form_id': 1, 'field_name': 'Project Idea',     'field_type': 'TEXT',    'is_required': 1, 'validation_rule': None,                    'display_order': 2},
        {'field_id': 3, 'form_id': 1, 'field_name': 'Has Laptop',       'field_type': 'BOOLEAN', 'is_required': 1, 'validation_rule': None,                    'display_order': 3},
        {'field_id': 4, 'form_id': 1, 'field_name': 'T-Shirt Size',     'field_type': 'TEXT',    'is_required': 0, 'validation_rule': None,                    'display_order': 4},
        {'field_id': 5, 'form_id': 2, 'field_name': 'Overall Rating',   'field_type': 'NUMERIC','is_required': 1, 'validation_rule': '1-5',                   'display_order': 1},
        {'field_id': 6, 'form_id': 2, 'field_name': 'Comments',         'field_type': 'TEXT',    'is_required': 0, 'validation_rule': None,                    'display_order': 2},
        {'field_id': 7, 'form_id': 2, 'field_name': 'Recommend Course', 'field_type': 'BOOLEAN', 'is_required': 1, 'validation_rule': None,                    'display_order': 3},
        {'field_id': 8, 'form_id': 3, 'field_name': 'Are You Interested','field_type': 'BOOLEAN','is_required': 1, 'validation_rule': None,                    'display_order': 1},
        {'field_id': 9, 'form_id': 3, 'field_name': 'Preferred Domain',  'field_type': 'TEXT',   'is_required': 1, 'validation_rule': None,                    'display_order': 2},
    ]
    rules = [
        {'rule_id': 1, 'form_id': 1, 'attribute_name': 'branch',   'operator': '=',  'attribute_value': 'MCA'},
        {'rule_id': 2, 'form_id': 1, 'attribute_name': 'semester', 'operator': '=',  'attribute_value': '4'},
        {'rule_id': 3, 'form_id': 1, 'attribute_name': 'cgpa',     'operator': '>=', 'attribute_value': '8.0'},
        {'rule_id': 4, 'form_id': 2, 'attribute_name': 'semester', 'operator': '=',  'attribute_value': '4'},
        {'rule_id': 5, 'form_id': 3, 'attribute_name': 'cgpa',     'operator': '>=', 'attribute_value': '6.0'},
    ]
    submissions = [
        {'submission_id': 1, 'form_id': 1, 'user_id': 3, 'submitted_at': now - timedelta(days=5), 'status': 'submitted'},
        {'submission_id': 2, 'form_id': 1, 'user_id': 4, 'submitted_at': now - timedelta(days=3), 'status': 'submitted'},
        {'submission_id': 3, 'form_id': 2, 'user_id': 3, 'submitted_at': now - timedelta(days=4), 'status': 'submitted'},
        {'submission_id': 4, 'form_id': 2, 'user_id': 5, 'submitted_at': now - timedelta(days=2), 'status': 'submitted'},
        {'submission_id': 5, 'form_id': 2, 'user_id': 4, 'submitted_at': now - timedelta(days=1), 'status': 'submitted'},
        {'submission_id': 6, 'form_id': 2, 'user_id': 6, 'submitted_at': now,                      'status': 'submitted'},
        {'submission_id': 7, 'form_id': 3, 'user_id': 3, 'submitted_at': now - timedelta(days=18),'status': 'submitted'},
        {'submission_id': 8, 'form_id': 3, 'user_id': 7, 'submitted_at': now - timedelta(days=15),'status': 'submitted'},
        {'submission_id': 9, 'form_id': 3, 'user_id': 8, 'submitted_at': now - timedelta(days=12),'status': 'submitted'},
    ]
    responses = [
        # Form 1 (Hackathon) – Submission 1 (pranav)
        {'response_id': 1, 'submission_id': 1, 'field_id': 1, 'response_value': 'Team Nexus'},
        {'response_id': 2, 'submission_id': 1, 'field_id': 2, 'response_value': 'AI-powered attendance system'},
        {'response_id': 3, 'submission_id': 1, 'field_id': 3, 'response_value': 'YES'},
        {'response_id': 4, 'submission_id': 1, 'field_id': 4, 'response_value': 'L'},
        # Form 1 (Hackathon) – Submission 2 (sreejesh)
        {'response_id': 5, 'submission_id': 2, 'field_id': 1, 'response_value': 'Code Crusaders'},
        {'response_id': 6, 'submission_id': 2, 'field_id': 2, 'response_value': 'Blockchain-based voting platform'},
        {'response_id': 7, 'submission_id': 2, 'field_id': 3, 'response_value': 'YES'},
        {'response_id': 8, 'submission_id': 2, 'field_id': 4, 'response_value': 'M'},
        # Form 2 (Feedback) – Submission 3 (pranav)
        {'response_id': 9,  'submission_id': 3, 'field_id': 5, 'response_value': '5'},
        {'response_id': 10, 'submission_id': 3, 'field_id': 6, 'response_value': 'Great lab sessions!'},
        {'response_id': 11, 'submission_id': 3, 'field_id': 7, 'response_value': 'YES'},
        # Form 2 (Feedback) – Submission 4 (alice)
        {'response_id': 12, 'submission_id': 4, 'field_id': 5, 'response_value': '4'},
        {'response_id': 13, 'submission_id': 4, 'field_id': 6, 'response_value': 'More practice problems needed'},
        {'response_id': 14, 'submission_id': 4, 'field_id': 7, 'response_value': 'YES'},
        # Form 2 (Feedback) – Submission 5 (sreejesh)
        {'response_id': 15, 'submission_id': 5, 'field_id': 5, 'response_value': '3'},
        {'response_id': 16, 'submission_id': 5, 'field_id': 6, 'response_value': 'Average experience'},
        {'response_id': 17, 'submission_id': 5, 'field_id': 7, 'response_value': 'NO'},
        # Form 2 (Feedback) – Submission 6 (bob)
        {'response_id': 18, 'submission_id': 6, 'field_id': 5, 'response_value': '2'},
        {'response_id': 19, 'submission_id': 6, 'field_id': 6, 'response_value': 'Difficult to follow'},
        {'response_id': 20, 'submission_id': 6, 'field_id': 7, 'response_value': 'NO'},
        # Form 3 (Placement) – Submission 7 (pranav)
        {'response_id': 21, 'submission_id': 7, 'field_id': 8, 'response_value': 'YES'},
        {'response_id': 22, 'submission_id': 7, 'field_id': 9, 'response_value': 'Full Stack Development'},
        # Form 3 (Placement) – Submission 8 (carol)
        {'response_id': 23, 'submission_id': 8, 'field_id': 8, 'response_value': 'YES'},
        {'response_id': 24, 'submission_id': 8, 'field_id': 9, 'response_value': 'Data Science'},
        # Form 3 (Placement) – Submission 9 (dave)
        {'response_id': 25, 'submission_id': 9, 'field_id': 8, 'response_value': 'NO'},
        {'response_id': 26, 'submission_id': 9, 'field_id': 9, 'response_value': 'Cloud Computing'},
    ]
    return {'users': users, 'forms': forms, 'fields': fields, 'rules': rules,
            'submissions': submissions, 'responses': responses,
            '_next_user': 9, '_next_form': 4, '_next_field': 10, '_next_rule': 6,
            '_next_sub': 10, '_next_resp': 27}

DEMO_DB = None  # populated at startup if needed

def _demo_eligible(user_id, form_id):
    """Check eligibility against demo rules."""
    user = next((u for u in DEMO_DB['users'] if u['user_id'] == user_id), None)
    if not user: return 'NOT ELIGIBLE'
    rules = [r for r in DEMO_DB['rules'] if r['form_id'] == form_id]
    for rule in rules:
        attr = rule['attribute_name']
        op   = rule['operator']
        val  = rule['attribute_value']
        if attr == 'branch':
            if op == '=' and user.get('branch') != val: return 'NOT ELIGIBLE'
        elif attr == 'semester':
            if op == '=' and user.get('semester') != val: return 'NOT ELIGIBLE'
        elif attr == 'cgpa':
            try:
                thr = float(val)
                uc  = float(user.get('cgpa', 0))
                if op == '>=' and uc < thr: return 'NOT ELIGIBLE'
                if op == '>'  and uc <= thr: return 'NOT ELIGIBLE'
            except ValueError:
                return 'NOT ELIGIBLE'
    return 'ELIGIBLE'

# ── Real Oracle helpers ────────────────────────────────────────────────────────
def get_conn():
    return cx_Oracle.connect(user=DB_USER, password=DB_PASS, dsn=DB_DSN)

def query(sql, params=None, fetchall=True):
    with get_conn() as conn:
        # Force CLOBs to be returned as strings so we don't need the connection during template rendering
        def output_type_handler(cursor, metadata):
            if metadata.type_code is cx_Oracle.DB_TYPE_CLOB:
                return cursor.var(cx_Oracle.DB_TYPE_LONG, arraysize=cursor.arraysize)
            if metadata.type_code is cx_Oracle.DB_TYPE_BLOB:
                return cursor.var(cx_Oracle.DB_TYPE_LONG_RAW, arraysize=cursor.arraysize)
        conn.outputtypehandler = output_type_handler
        cur = conn.cursor()
        cur.execute(sql, params or {})
        cols = [d[0].lower() for d in cur.description]
        rows = cur.fetchall() if fetchall else cur.fetchone()
        if fetchall:
            return [dict(zip(cols, r)) for r in rows]
        return dict(zip(cols, rows)) if rows else None

def execute(sql, params=None):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(sql, params or {})
        conn.commit()

# ── Auth helpers ───────────────────────────────────────────────────────────────
def seed_users_if_requested():
    """
    Optional one-time seeding helper.
    Controlled via env var: DSCAE_SEED_USERS=1
    Inserts users only if username doesn't already exist.
    """
    if os.getenv("DSCAE_SEED_USERS") != "1":
        return

    # Seed admin
    admin = query("SELECT user_id FROM USERS WHERE username=:u", {'u': 'admin1'}, fetchall=False)
    if not admin:
        execute(
            """INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,:un,:em,:pw,:br,:cg,:sem,'admin',SYSDATE)""",
            {
                'un': 'admin1',
                'em': 'admin1@example.com',
                'pw': hash_pw('Admin@123'),
                'br': 'ADMIN',
                'cg': 10.0,
                'sem': 'NA'
            }
        )

    # Seed a demo student
    student = query("SELECT user_id FROM USERS WHERE username=:u", {'u': 'student1'}, fetchall=False)
    if not student:
        execute(
            """INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,:un,:em,:pw,:br,:cg,:sem,'student',SYSDATE)""",
            {
                'un': 'student1',
                'em': 'student1@example.com',
                'pw': hash_pw('Student@123'),
                'br': 'CSE',
                'cg': 8.5,
                'sem': '6'
            }
        )

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated

def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if session.get('role') != 'admin':
            flash("Admin access required.", "danger")
            return redirect(url_for('dashboard'))
        return f(*args, **kwargs)
    return decorated

# ── Routes ─────────────────────────────────────────────────────────────────────

@app.route('/')
def index():
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        uname = request.form['username']
        pw    = hash_pw(request.form['password'])
        if DEMO_MODE:
            user = next((u for u in DEMO_DB['users'] if u['username'] == uname and u['password_hash'] == pw), None)
        else:
            try:
                user = query(
                    "SELECT * FROM USERS WHERE username=:u AND password_hash=:p",
                    {'u': uname, 'p': pw}, fetchall=False
                )
            except Exception as e:
                flash(f"DB Error: {e}", "danger")
                user = None
        if user:
            session['user_id']  = user['user_id']
            session['username'] = user['username']
            session['role']     = user['role']
            return redirect(url_for('dashboard'))
        flash("Invalid credentials.", "danger")
    return render_template('login.html', demo_mode=DEMO_MODE)

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        if DEMO_MODE:
            DEMO_DB['users'].append({
                'user_id':       DEMO_DB['_next_user'],
                'username':      request.form['username'],
                'email':         request.form['email'],
                'password_hash': hash_pw(request.form['password']),
                'branch':        request.form['branch'],
                'cgpa':          float(request.form['cgpa']),
                'semester':      request.form['semester'],
                'role':          'student',
                'created_at':    datetime.now()
            })
            DEMO_DB['_next_user'] += 1
            flash("Account created! Please login.", "success")
            return redirect(url_for('login'))
        else:
            try:
                execute(
                    """INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,:un,:em,:pw,:br,:cg,:sem,'student',SYSDATE)""",
                    {
                        'un':  request.form['username'],
                        'em':  request.form['email'],
                        'pw':  hash_pw(request.form['password']),
                        'br':  request.form['branch'],
                        'cg':  float(request.form['cgpa']),
                        'sem': request.form['semester']
                    }
                )
                flash("Account created! Please login.", "success")
                return redirect(url_for('login'))
            except Exception as e:
                flash(f"Registration Error: {e}", "danger")
    return render_template('register.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    if DEMO_MODE:
        if session['role'] == 'admin':
            forms = sorted(DEMO_DB['forms'], key=lambda f: f['form_id'], reverse=True)
        else:
            now = datetime.now()
            forms = []
            for f in DEMO_DB['forms']:
                if f['status'] == 'open' and f['end_date'] >= now:
                    fc = dict(f)
                    fc['eligible'] = _demo_eligible(session['user_id'], f['form_id'])
                    forms.append(fc)
    else:
        if session['role'] == 'admin':
            forms = query("SELECT * FROM FORMS ORDER BY form_id DESC")
        else:
            forms = query("""
                SELECT f.*, fn_is_eligible(:p_user_id, f.form_id) AS eligible
                FROM   FORMS f
                WHERE  f.status = 'open' AND f.end_date >= SYSDATE
            """, {'p_user_id': session['user_id']})
    return render_template('dashboard.html', forms=forms)

# ── Forms (admin only) ─────────────────────────────────────────────────────────

@app.route('/forms/new', methods=['GET', 'POST'])
@login_required
@admin_required
def create_form():
    if request.method == 'POST':
        if DEMO_MODE:
            fid = DEMO_DB['_next_form']
            DEMO_DB['_next_form'] += 1
            DEMO_DB['forms'].append({
                'form_id': fid, 'created_by': session['user_id'],
                'title': request.form['title'], 'description': request.form['description'],
                'status': 'open',
                'start_date': datetime.strptime(request.form['start_date'], '%Y-%m-%d'),
                'end_date':   datetime.strptime(request.form['end_date'], '%Y-%m-%d'),
            })
            return redirect(url_for('edit_form_fields', form_id=fid))
        else:
            execute("""
                INSERT INTO FORMS (form_id,created_by,title,description,status,start_date,end_date)
                VALUES (SEQ_FORM.NEXTVAL,:cb,:t,:d,'open',TO_DATE(:sd,'YYYY-MM-DD'),TO_DATE(:ed,'YYYY-MM-DD'))
            """, {
                'cb': session['user_id'],
                't':  request.form['title'],
                'd':  request.form['description'],
                'sd': request.form['start_date'],
                'ed': request.form['end_date']
            })
            form = query("SELECT MAX(form_id) AS fid FROM FORMS", fetchall=False)
            return redirect(url_for('edit_form_fields', form_id=form['fid']))
    return render_template('form_create.html')

@app.route('/forms/<int:form_id>/fields', methods=['GET', 'POST'])
@login_required
@admin_required
def edit_form_fields(form_id):
    if request.method == 'POST':
        if DEMO_MODE:
            fld_id = DEMO_DB['_next_field']
            DEMO_DB['_next_field'] += 1
            DEMO_DB['fields'].append({
                'field_id': fld_id, 'form_id': form_id,
                'field_name': request.form['field_name'],
                'field_type': request.form['field_type'],
                'is_required': 1 if request.form.get('is_required') else 0,
                'validation_rule': request.form.get('validation_rule') or None,
                'display_order': int(request.form.get('display_order', 1))
            })
        else:
            execute("""
                INSERT INTO FORM_FIELDS (field_id,form_id,field_name,field_type,is_required,validation_rule,display_order)
                VALUES (SEQ_FIELD.NEXTVAL,:fid,:fn,:ft,:req,:vr,:ord)
            """, {
                'fid': form_id, 'fn': request.form['field_name'],
                'ft':  request.form['field_type'],
                'req': 1 if request.form.get('is_required') else 0,
                'vr':  request.form.get('validation_rule') or None,
                'ord': request.form.get('display_order', 1)
            })
    if DEMO_MODE:
        fields = sorted([f for f in DEMO_DB['fields'] if f['form_id'] == form_id], key=lambda f: f['display_order'])
    else:
        fields = query("SELECT * FROM FORM_FIELDS WHERE form_id=:fid ORDER BY display_order", {'fid': form_id})
    return render_template('form_fields.html', form_id=form_id, fields=fields)

@app.route('/forms/<int:form_id>/rules', methods=['GET', 'POST'])
@login_required
@admin_required
def edit_form_rules(form_id):
    if request.method == 'POST':
        if DEMO_MODE:
            rid = DEMO_DB['_next_rule']
            DEMO_DB['_next_rule'] += 1
            DEMO_DB['rules'].append({
                'rule_id': rid, 'form_id': form_id,
                'attribute_name': request.form['attribute_name'],
                'operator': request.form['operator'],
                'attribute_value': request.form['attribute_value']
            })
        else:
            execute("""
                INSERT INTO ACCESS_RULES (rule_id,form_id,attribute_name,operator,attribute_value)
                VALUES (SEQ_RULE.NEXTVAL,:fid,:an,:op,:av)
            """, {
                'fid': form_id,
                'an':  request.form['attribute_name'],
                'op':  request.form['operator'],
                'av':  request.form['attribute_value']
            })
    if DEMO_MODE:
        rules = [r for r in DEMO_DB['rules'] if r['form_id'] == form_id]
    else:
        rules = query("SELECT * FROM ACCESS_RULES WHERE form_id=:fid", {'fid': form_id})
    return render_template('form_rules.html', form_id=form_id, rules=rules)

# ── Submissions (students) ─────────────────────────────────────────────────────

@app.route('/forms/<int:form_id>/submit', methods=['GET', 'POST'])
@login_required
def submit_form(form_id):
    uid = session['user_id']
    if DEMO_MODE:
        elig = _demo_eligible(uid, form_id)
        if elig != 'ELIGIBLE':
            flash("You are not eligible for this form.", "danger")
            return redirect(url_for('dashboard'))
        fields = sorted([f for f in DEMO_DB['fields'] if f['form_id'] == form_id], key=lambda f: f['display_order'])
        form = next((f for f in DEMO_DB['forms'] if f['form_id'] == form_id), None)
        if request.method == 'POST':
            # Check for duplicate submission
            already = any(s for s in DEMO_DB['submissions'] if s['form_id'] == form_id and s['user_id'] == uid)
            if already:
                flash("You have already submitted this form.", "danger")
                return redirect(url_for('dashboard'))
            sid = DEMO_DB['_next_sub']; DEMO_DB['_next_sub'] += 1
            DEMO_DB['submissions'].append({
                'submission_id': sid, 'form_id': form_id, 'user_id': uid,
                'submitted_at': datetime.now(), 'status': 'submitted'
            })
            for f in fields:
                rid = DEMO_DB['_next_resp']; DEMO_DB['_next_resp'] += 1
                DEMO_DB['responses'].append({
                    'response_id': rid, 'submission_id': sid,
                    'field_id': f['field_id'],
                    'response_value': request.form.get(f'field_{f["field_id"]}', '')
                })
            flash(f"Submitted successfully! (ID: {sid})", "success")
            return redirect(url_for('dashboard'))
    else:
        eligible = query(
            "SELECT fn_is_eligible(:p_user_id,:p_form_id) AS e FROM DUAL",
            {'p_user_id': uid, 'p_form_id': form_id}, fetchall=False
        )
        if not eligible or eligible['e'] != 'ELIGIBLE':
            flash("You are not eligible for this form.", "danger")
            return redirect(url_for('dashboard'))
        fields = query("SELECT * FROM FORM_FIELDS WHERE form_id=:p_form_id ORDER BY display_order", {'p_form_id': form_id})
        form = query("SELECT * FROM FORMS WHERE form_id=:p_form_id", {'p_form_id': form_id}, fetchall=False)
        if request.method == 'POST':
            try:
                with get_conn() as conn:
                    # Force CLOB handler for this connection too
                    def output_type_handler(cursor, metadata):
                        if metadata.type_code is cx_Oracle.DB_TYPE_CLOB:
                            return cursor.var(cx_Oracle.DB_TYPE_LONG, arraysize=cursor.arraysize)
                    conn.outputtypehandler = output_type_handler
                    cur = conn.cursor()

                    # Check for duplicate submission
                    cur.execute("SELECT COUNT(*) AS c FROM SUBMISSIONS WHERE form_id=:f AND user_id=:u",
                                {'f': form_id, 'u': uid})
                    if cur.fetchone()[0] > 0:
                        flash("You have already submitted this form.", "danger")
                        return redirect(url_for('dashboard'))

                    # Get next submission ID
                    cur.execute("SELECT SEQ_SUB.NEXTVAL FROM DUAL")
                    sub_id = int(cur.fetchone()[0])

                    # Insert submission
                    cur.execute("""INSERT INTO SUBMISSIONS (submission_id, form_id, user_id, submitted_at, status)
                                   VALUES (:sid, :fid, :uid_val, SYSDATE, 'submitted')""",
                                {'sid': sub_id, 'fid': form_id, 'uid_val': uid})

                    # Insert each response
                    for f in fields:
                        val = request.form.get(f'field_{f["field_id"]}', '')
                        cur.execute("SELECT SEQ_RESP.NEXTVAL FROM DUAL")
                        resp_id = int(cur.fetchone()[0])
                        cur.execute("""INSERT INTO RESPONSES (response_id, submission_id, field_id, response_value)
                                       VALUES (:rid, :sid, :fld, :val)""",
                                    {'rid': resp_id, 'sid': sub_id, 'fld': f['field_id'], 'val': val})

                    conn.commit()
                    flash(f"Submitted successfully! (ID: {sub_id})", "success")
                    return redirect(url_for('dashboard'))
            except cx_Oracle.DatabaseError as e:
                flash(str(e), "danger")

    return render_template('form_submit.html', form_id=form_id, form=form, fields=fields)

# ── Analytics ─────────────────────────────────────────────────────────────────

@app.route('/analytics/<int:form_id>')
@login_required
@admin_required
def analytics(form_id):
    if DEMO_MODE:
        form = next((f for f in DEMO_DB['forms'] if f['form_id'] == form_id), None)
        form_fields = sorted([f for f in DEMO_DB['fields'] if f['form_id'] == form_id], key=lambda f: f['display_order'])
        form_subs   = [s for s in DEMO_DB['submissions'] if s['form_id'] == form_id]
        sub_ids     = {s['submission_id'] for s in form_subs}
        num_submissions = len(form_subs)
        stats = []
        for ff in form_fields:
            resps = [r for r in DEMO_DB['responses'] if r['field_id'] == ff['field_id'] and r['submission_id'] in sub_ids]
            total = len(resps)
            avg_val = None
            min_val = None
            max_val = None
            if ff['field_type'] == 'NUMERIC' and resps:
                try:
                    vals = [float(r['response_value']) for r in resps if r['response_value']]
                    if vals:
                        avg_val = round(sum(vals) / len(vals), 2)
                        min_val = min(vals)
                        max_val = max(vals)
                except ValueError:
                    pass
            yes_c = sum(1 for r in resps if str(r['response_value']).upper() == 'YES')
            no_c  = sum(1 for r in resps if str(r['response_value']).upper() == 'NO')
            # Count distinct values
            distinct_vals = len(set(r['response_value'] for r in resps if r['response_value']))
            # Fill rate: how many answered vs total submissions
            fill_rate = round((total / num_submissions * 100), 1) if num_submissions > 0 else 0
            # Value distribution (top 5)
            val_counts = {}
            for r in resps:
                v = str(r['response_value']).strip()
                if v:
                    val_counts[v] = val_counts.get(v, 0) + 1
            top_values = sorted(val_counts.items(), key=lambda x: -x[1])[:5]
            stats.append({
                'field_name': ff['field_name'], 'field_type': ff['field_type'],
                'total': total, 'avg_val': avg_val, 'min_val': min_val, 'max_val': max_val,
                'yes_count': yes_c, 'no_count': no_c,
                'distinct_count': distinct_vals, 'fill_rate': fill_rate,
                'top_values': top_values
            })
        total_students = sum(1 for u in DEMO_DB['users'] if u['role'] == 'student')
        submitted = len(set(s['user_id'] for s in form_subs))
        participation = {'submitted': submitted, 'total': total_students}
        # Timeline data: submissions per day
        timeline = {}
        for s in form_subs:
            day = s['submitted_at'].strftime('%d %b')
            timeline[day] = timeline.get(day, 0) + 1
        timeline_labels = list(timeline.keys())
        timeline_values = list(timeline.values())
    else:
        form = query("SELECT * FROM FORMS WHERE form_id=:p_form_id", {'p_form_id': form_id}, fetchall=False)
        stats = query("""
            SELECT ff.field_name, ff.field_type,
                   COUNT(r.response_id) AS total,
                   ROUND(AVG(CASE WHEN ff.field_type='NUMERIC' THEN TO_NUMBER(TO_CHAR(r.response_value)) END),2) AS avg_val,
                   MIN(CASE WHEN ff.field_type='NUMERIC' THEN TO_NUMBER(TO_CHAR(r.response_value)) END) AS min_val,
                   MAX(CASE WHEN ff.field_type='NUMERIC' THEN TO_NUMBER(TO_CHAR(r.response_value)) END) AS max_val,
                   SUM(CASE WHEN UPPER(TO_CHAR(r.response_value))='YES' THEN 1 ELSE 0 END) AS yes_count,
                   SUM(CASE WHEN UPPER(TO_CHAR(r.response_value))='NO'  THEN 1 ELSE 0 END) AS no_count,
                   COUNT(DISTINCT TO_CHAR(r.response_value)) AS distinct_count
            FROM   FORM_FIELDS ff
            LEFT   JOIN RESPONSES r   ON r.field_id = ff.field_id
            LEFT   JOIN SUBMISSIONS s ON s.submission_id = r.submission_id
            WHERE  ff.form_id = :p_form_id
            GROUP  BY ff.field_id, ff.field_name, ff.field_type
        """, {'p_form_id': form_id})
        # Add fill_rate and top_values for each stat
        sub_count_row = query("SELECT COUNT(*) AS c FROM SUBMISSIONS WHERE form_id=:p_form_id",
                              {'p_form_id': form_id}, fetchall=False)
        num_subs = sub_count_row['c'] if sub_count_row else 0
        for s in stats:
            s['fill_rate'] = round((s['total'] / num_subs * 100), 1) if num_subs > 0 else 0
            s['top_values'] = []  # Could be queried but kept simple for Oracle mode
        sub_count = query("SELECT COUNT(DISTINCT user_id) AS submitted FROM SUBMISSIONS WHERE form_id=:p_form_id",
                          {'p_form_id': form_id}, fetchall=False)
        total_students = query("SELECT COUNT(*) AS total FROM USERS WHERE role='student'", fetchall=False)
        participation = {
            'submitted': sub_count['submitted'] if sub_count else 0,
            'total': total_students['total'] if total_students else 0
        }
        # Timeline from DB
        timeline_rows = query("""
            SELECT TO_CHAR(submitted_at, 'DD Mon') AS day, COUNT(*) AS cnt
            FROM SUBMISSIONS WHERE form_id=:p_form_id
            GROUP BY TO_CHAR(submitted_at, 'DD Mon'), TRUNC(submitted_at)
            ORDER BY TRUNC(submitted_at)
        """, {'p_form_id': form_id})
        timeline_labels = [r['day'] for r in timeline_rows] if timeline_rows else []
        timeline_values = [r['cnt'] for r in timeline_rows] if timeline_rows else []
    return render_template('analytics.html', form=form, stats=stats, participation=participation,
                           timeline_labels=timeline_labels, timeline_values=timeline_values)

# ── API endpoint for dashboard refresh ────────────────────────────────────────
@app.route('/api/forms')
@login_required
def api_forms():
    if DEMO_MODE:
        return jsonify([{'form_id': f['form_id'], 'title': f['title'], 'status': f['status'],
                         'end_date': str(f['end_date'])} for f in DEMO_DB['forms'] if f['status']=='open'])
    forms = query("SELECT form_id, title, status, end_date FROM FORMS WHERE status='open'")
    return jsonify(forms)

if __name__ == '__main__':
    # Try Oracle, fall back to demo
    if not DEMO_MODE:
        try:
            conn = cx_Oracle.connect(user=DB_USER, password=DB_PASS, dsn=DB_DSN)
            conn.close()
            print("[OK] Connected to Oracle DB successfully.")
            seed_users_if_requested()
        except Exception as e:
            print(f"[WARN] Oracle unavailable ({e}). Starting in DEMO mode.")
            DEMO_MODE = True
            DEMO_DB = _build_demo_data()
    else:
        DEMO_DB = _build_demo_data()
        print("[INFO] Starting in DEMO mode (no Oracle driver).")

    app.run(debug=True, port=5000)
