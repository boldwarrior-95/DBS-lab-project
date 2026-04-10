"""
D-SCAE — Dynamic Schema Collection & Analytics Engine.
Flask app backed by Oracle Database. Connects via the env vars in .env.example.
"""

import logging
import os
import oracledb
from flask import (
    Flask, abort, flash, jsonify, redirect, render_template,
    request, session, url_for,
)

from db import query, execute, insert_returning, get_conn, init_pool
from auth import hash_pw, verify_pw, login_required, admin_required

log = logging.getLogger("dscae")
logging.basicConfig(level=logging.INFO)

app = Flask(__name__)
try:
    app.secret_key = os.environ["FLASK_SECRET_KEY"]
except KeyError as exc:
    raise RuntimeError(
        "FLASK_SECRET_KEY env var is required (sessions break across gunicorn workers without it)."
    ) from exc

init_pool()


def _get_form_or_404(form_id: int) -> dict:
    form = query("SELECT * FROM FORMS WHERE form_id = :f", {"f": form_id}, one=True)
    if not form:
        abort(404)
    return form


@app.route("/")
def index():
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        user = query(
            "SELECT * FROM USERS WHERE username = :u",
            {"u": request.form["username"]},
            one=True,
        )
        if user and verify_pw(request.form["password"], user["password_hash"]):
            session["user_id"]  = user["user_id"]
            session["username"] = user["username"]
            session["role"]     = user["role"]
            return redirect(url_for("dashboard"))
        flash("Invalid credentials.", "danger")
    return render_template("login.html")


@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        try:
            execute(
                """INSERT INTO USERS
                   VALUES (SEQ_USER.NEXTVAL, :un, :em, :pw, :br, :cg, :sem, 'student', SYSDATE)""",
                {
                    "un":  request.form["username"],
                    "em":  request.form["email"],
                    "pw":  hash_pw(request.form["password"]),
                    "br":  request.form["branch"],
                    "cg":  float(request.form["cgpa"]),
                    "sem": request.form["semester"],
                },
            )
            flash("Account created! Please login.", "success")
            return redirect(url_for("login"))
        except oracledb.DatabaseError as e:
            log.warning("registration failed: %s", e)
            flash("Could not create account — username or email may already be in use.", "danger")
    return render_template("register.html")


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/dashboard")
@login_required
def dashboard():
    if session["role"] == "admin":
        forms = query("SELECT * FROM FORMS ORDER BY form_id DESC")
    else:
        forms = query(
            """SELECT f.*, fn_is_eligible(:p_user_id, f.form_id) AS eligible
               FROM   FORMS f
               WHERE  f.status = 'open' AND f.end_date >= SYSDATE""",
            {"p_user_id": session["user_id"]},
        )
    return render_template("dashboard.html", forms=forms)


@app.route("/forms/new", methods=["GET", "POST"])
@login_required
@admin_required
def create_form():
    if request.method == "POST":
        new_id = insert_returning(
            """INSERT INTO FORMS (form_id, created_by, title, description, status, start_date, end_date)
               VALUES (SEQ_FORM.NEXTVAL, :cb, :t, :d, 'open',
                       TO_DATE(:sd, 'YYYY-MM-DD'), TO_DATE(:ed, 'YYYY-MM-DD'))
               RETURNING form_id INTO :new_id""",
            {
                "cb": session["user_id"],
                "t":  request.form["title"],
                "d":  request.form["description"],
                "sd": request.form["start_date"],
                "ed": request.form["end_date"],
            },
        )
        return redirect(url_for("edit_form_fields", form_id=new_id))
    return render_template("form_create.html")


@app.route("/forms/<int:form_id>/fields", methods=["GET", "POST"])
@login_required
@admin_required
def edit_form_fields(form_id):
    _get_form_or_404(form_id)
    if request.method == "POST":
        execute(
            """INSERT INTO FORM_FIELDS (field_id, form_id, field_name, field_type,
                                        is_required, validation_rule, display_order)
               VALUES (SEQ_FIELD.NEXTVAL, :fid, :fn, :ft, :req, :vr, :ord)""",
            {
                "fid": form_id,
                "fn":  request.form["field_name"],
                "ft":  request.form["field_type"],
                "req": 1 if request.form.get("is_required") else 0,
                "vr":  request.form.get("validation_rule") or None,
                "ord": int(request.form.get("display_order", 1)),
            },
        )
    fields = query(
        "SELECT * FROM FORM_FIELDS WHERE form_id = :fid ORDER BY display_order",
        {"fid": form_id},
    )
    return render_template("form_fields.html", form_id=form_id, fields=fields)


@app.route("/forms/<int:form_id>/rules", methods=["GET", "POST"])
@login_required
@admin_required
def edit_form_rules(form_id):
    _get_form_or_404(form_id)
    if request.method == "POST":
        execute(
            """INSERT INTO ACCESS_RULES (rule_id, form_id, attribute_name, operator, attribute_value)
               VALUES (SEQ_RULE.NEXTVAL, :fid, :an, :op, :av)""",
            {
                "fid": form_id,
                "an":  request.form["attribute_name"],
                "op":  request.form["operator"],
                "av":  request.form["attribute_value"],
            },
        )
    rules = query("SELECT * FROM ACCESS_RULES WHERE form_id = :fid", {"fid": form_id})
    return render_template("form_rules.html", form_id=form_id, rules=rules)


@app.route("/forms/<int:form_id>/submit", methods=["GET", "POST"])
@login_required
def submit_form(form_id):
    uid  = session["user_id"]
    form = _get_form_or_404(form_id)

    eligible = query(
        "SELECT fn_is_eligible(:u, :f) AS e FROM DUAL",
        {"u": uid, "f": form_id}, one=True,
    )
    if not eligible or eligible["e"] != "ELIGIBLE":
        flash("You are not eligible for this form.", "danger")
        return redirect(url_for("dashboard"))

    fields = query(
        "SELECT * FROM FORM_FIELDS WHERE form_id = :f ORDER BY display_order",
        {"f": form_id},
    )

    if request.method == "POST":
        try:
            with get_conn() as conn:
                cur = conn.cursor()

                cur.execute(
                    "SELECT COUNT(*) FROM SUBMISSIONS WHERE form_id = :f AND user_id = :u",
                    {"f": form_id, "u": uid},
                )
                if cur.fetchone()[0] > 0:
                    flash("You have already submitted this form.", "danger")
                    return redirect(url_for("dashboard"))

                sub_id_var = cur.var(oracledb.NUMBER)
                cur.execute(
                    """INSERT INTO SUBMISSIONS (submission_id, form_id, user_id, submitted_at, status)
                       VALUES (SEQ_SUB.NEXTVAL, :f, :u, SYSDATE, 'submitted')
                       RETURNING submission_id INTO :sid""",
                    {"f": form_id, "u": uid, "sid": sub_id_var},
                )
                sub_id_raw = sub_id_var.getvalue()
                sub_id = int(sub_id_raw[0] if isinstance(sub_id_raw, list) else sub_id_raw)

                for f in fields:
                    cur.execute(
                        """INSERT INTO RESPONSES (response_id, submission_id, field_id, response_value)
                           VALUES (SEQ_RESP.NEXTVAL, :sid, :fld, :val)""",
                        {
                            "sid": sub_id,
                            "fld": f["field_id"],
                            "val": request.form.get(f"field_{f['field_id']}", ""),
                        },
                    )
                conn.commit()
                flash(f"Submitted successfully! (ID: {sub_id})", "success")
                return redirect(url_for("dashboard"))
        except oracledb.DatabaseError as e:
            log.warning("submission failed for user=%s form=%s: %s", uid, form_id, e)
            flash("Submission failed. Please try again.", "danger")

    return render_template("form_submit.html", form_id=form_id, form=form, fields=fields)


@app.route("/analytics/<int:form_id>")
@login_required
@admin_required
def analytics(form_id):
    form = _get_form_or_404(form_id)

    stats = query(
        """SELECT ff.field_name, ff.field_type,
                  COUNT(r.response_id) AS total,
                  ROUND(AVG(CASE WHEN ff.field_type='NUMERIC' THEN TO_NUMBER(TO_CHAR(r.response_value)) END), 2) AS avg_val,
                  MIN(CASE WHEN ff.field_type='NUMERIC' THEN TO_NUMBER(TO_CHAR(r.response_value)) END) AS min_val,
                  MAX(CASE WHEN ff.field_type='NUMERIC' THEN TO_NUMBER(TO_CHAR(r.response_value)) END) AS max_val,
                  SUM(CASE WHEN UPPER(TO_CHAR(r.response_value))='YES' THEN 1 ELSE 0 END) AS yes_count,
                  SUM(CASE WHEN UPPER(TO_CHAR(r.response_value))='NO'  THEN 1 ELSE 0 END) AS no_count,
                  COUNT(DISTINCT TO_CHAR(r.response_value)) AS distinct_count
           FROM   FORM_FIELDS ff
           LEFT   JOIN RESPONSES   r ON r.field_id = ff.field_id
           LEFT   JOIN SUBMISSIONS s ON s.submission_id = r.submission_id
           WHERE  ff.form_id = :f
           GROUP  BY ff.field_id, ff.field_name, ff.field_type
           ORDER  BY ff.field_id""",
        {"f": form_id},
    )

    sub_count = query(
        "SELECT COUNT(*) AS c FROM SUBMISSIONS WHERE form_id = :f",
        {"f": form_id}, one=True,
    )
    num_subs = sub_count["c"] if sub_count else 0
    for s in stats:
        s["fill_rate"]  = round((s["total"] / num_subs * 100), 1) if num_subs else 0
        s["top_values"] = []

    distinct = query(
        "SELECT COUNT(DISTINCT user_id) AS submitted FROM SUBMISSIONS WHERE form_id = :f",
        {"f": form_id}, one=True,
    )
    total_students = query(
        "SELECT COUNT(*) AS total FROM USERS WHERE role = 'student'", one=True,
    )
    participation = {
        "submitted": distinct["submitted"] if distinct else 0,
        "total":     total_students["total"] if total_students else 0,
    }

    timeline_rows = query(
        """SELECT TO_CHAR(submitted_at, 'DD Mon') AS day, COUNT(*) AS cnt
           FROM   SUBMISSIONS WHERE form_id = :f
           GROUP  BY TO_CHAR(submitted_at, 'DD Mon'), TRUNC(submitted_at)
           ORDER  BY TRUNC(submitted_at)""",
        {"f": form_id},
    )
    timeline_labels = [r["day"] for r in timeline_rows]
    timeline_values = [r["cnt"] for r in timeline_rows]

    return render_template(
        "analytics.html",
        form=form, stats=stats, participation=participation,
        timeline_labels=timeline_labels, timeline_values=timeline_values,
    )


@app.route("/api/forms")
@login_required
def api_forms():
    forms = query(
        "SELECT form_id, title, status, end_date FROM FORMS WHERE status = 'open'"
    )
    return jsonify(forms)


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", "5000")),
        debug=os.environ.get("FLASK_DEBUG") == "1",
    )
