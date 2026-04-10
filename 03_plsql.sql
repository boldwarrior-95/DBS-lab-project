-- ============================================================
-- D-SCAE: PL/SQL Business Logic
-- File: 03_plsql.sql  |  Oracle SQL*Plus
-- Run as: @03_plsql.sql
-- ============================================================

-- ============================================================
-- SECTION 1: BASIC QUERIES (for demo)
-- ============================================================

-- 1a. List all open forms
SELECT form_id, title, start_date, end_date, status
FROM   FORMS
WHERE  status = 'open'
ORDER  BY end_date;

-- 1b. List all students with CGPA > 8
SELECT username, branch, cgpa, semester
FROM   USERS
WHERE  role = 'student' AND cgpa > 8
ORDER  BY cgpa DESC;

-- 1c. Count submissions per form
SELECT f.title, COUNT(s.submission_id) AS total_submissions
FROM   FORMS f LEFT JOIN SUBMISSIONS s ON f.form_id = s.form_id
GROUP  BY f.title
ORDER  BY total_submissions DESC;

-- 1d. View all responses for a submission
SELECT ff.field_name, r.response_value
FROM   RESPONSES r
JOIN   FORM_FIELDS ff ON r.field_id = ff.field_id
WHERE  r.submission_id = 1;

-- ============================================================
-- SECTION 2: COMPLEX QUERIES
-- ============================================================

-- 2a. Eligible users for a specific form (RBAC check)
--     Shows users who satisfy ALL access rules for form_id = 1
SELECT u.user_id, u.username, u.branch, u.cgpa, u.semester
FROM   USERS u
WHERE  u.role = 'student'
  AND  NOT EXISTS (
         SELECT 1 FROM ACCESS_RULES ar
         WHERE  ar.form_id = 1
           AND  NOT (
             (ar.attribute_name = 'branch'   AND ar.operator = '='  AND u.branch   = ar.attribute_value) OR
             (ar.attribute_name = 'semester' AND ar.operator = '='  AND u.semester = ar.attribute_value) OR
             (ar.attribute_name = 'cgpa'     AND ar.operator = '>=' AND u.cgpa    >= TO_NUMBER(ar.attribute_value)) OR
             (ar.attribute_name = 'cgpa'     AND ar.operator = '>'  AND u.cgpa    >  TO_NUMBER(ar.attribute_value))
           )
       );

-- 2b. Users eligible but NOT yet submitted (for reminder notifications)
SELECT u.user_id, u.username, u.email
FROM   USERS u
WHERE  u.role = 'student'
  AND  NOT EXISTS (SELECT 1 FROM SUBMISSIONS s WHERE s.user_id = u.user_id AND s.form_id = 1)
  AND  NOT EXISTS (
         SELECT 1 FROM ACCESS_RULES ar
         WHERE  ar.form_id = 1
           AND  NOT (
             (ar.attribute_name = 'branch'   AND ar.operator = '='  AND u.branch   = ar.attribute_value) OR
             (ar.attribute_name = 'semester' AND ar.operator = '='  AND u.semester = ar.attribute_value) OR
             (ar.attribute_name = 'cgpa'     AND ar.operator = '>=' AND u.cgpa    >= TO_NUMBER(ar.attribute_value))
           )
       );

-- 2c. Participation rate per form (analytics)
SELECT f.title,
       COUNT(DISTINCT s.user_id)                             AS submitted,
       (SELECT COUNT(*) FROM USERS WHERE role = 'student')   AS total_students,
       ROUND(COUNT(DISTINCT s.user_id) * 100.0 /
             NULLIF((SELECT COUNT(*) FROM USERS WHERE role='student'),0), 1) AS pct
FROM   FORMS f
LEFT   JOIN SUBMISSIONS s ON f.form_id = s.form_id AND s.status = 'submitted'
GROUP  BY f.form_id, f.title;

-- 2d. Average numeric response per field (analytics engine)
SELECT ff.field_name,
       ROUND(AVG(TO_NUMBER(r.response_value)), 2) AS average_score,
       MIN(TO_NUMBER(r.response_value))           AS min_score,
       MAX(TO_NUMBER(r.response_value))           AS max_score,
       COUNT(*)                                   AS responses
FROM   RESPONSES r
JOIN   FORM_FIELDS ff ON r.field_id = ff.field_id
WHERE  ff.field_type = 'NUMERIC'
GROUP  BY ff.field_id, ff.field_name;

-- 2e. Full submission report with user details (JOIN across 4 tables)
SELECT u.username, f.title AS form_title,
       ff.field_name, r.response_value, s.submitted_at
FROM   SUBMISSIONS s
JOIN   USERS       u  ON s.user_id = u.user_id
JOIN   FORMS       f  ON s.form_id = f.form_id
JOIN   RESPONSES   r  ON r.submission_id = s.submission_id
JOIN   FORM_FIELDS ff ON ff.field_id = r.field_id
ORDER  BY s.submission_id, ff.display_order;

-- ============================================================
-- SECTION 3: STORED PROCEDURE — Submit a Form
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_submit_form (
    p_form_id    IN  NUMBER,
    p_user_id    IN  NUMBER,
    p_field_ids  IN  SYS.ODCINUMBERLIST,   -- array of field IDs
    p_values     IN  SYS.ODCIVARCHAR2LIST, -- matching values
    p_sub_id     OUT NUMBER
) AS
    v_status      VARCHAR2(10);
    v_end_date    DATE;
    v_eligible    NUMBER := 1;
    v_dup         NUMBER;
    v_branch      USERS.branch%TYPE;
    v_cgpa        USERS.cgpa%TYPE;
    v_semester    USERS.semester%TYPE;
    v_attr_val    VARCHAR2(100);
    v_passes_rule NUMBER;
BEGIN
    -- Check form is open and not expired
    SELECT status, end_date INTO v_status, v_end_date
    FROM   FORMS WHERE form_id = p_form_id;

    IF v_status != 'open' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Form is not open for submissions.');
    END IF;
    IF v_end_date < SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20002, 'Submission deadline has passed.');
    END IF;

    -- Check for duplicate submission
    SELECT COUNT(*) INTO v_dup FROM SUBMISSIONS
    WHERE  form_id = p_form_id AND user_id = p_user_id;
    IF v_dup > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'User has already submitted this form.');
    END IF;

    -- Fetch user attributes for RBAC check
    SELECT branch, cgpa, semester INTO v_branch, v_cgpa, v_semester
    FROM   USERS WHERE user_id = p_user_id;

    -- Evaluate each access rule (all rules must pass — AND logic)
    FOR rule IN (SELECT * FROM ACCESS_RULES WHERE form_id = p_form_id) LOOP
        v_passes_rule := 0;
        IF rule.attribute_name = 'branch' THEN
            IF rule.operator = '=' AND v_branch = rule.attribute_value THEN v_passes_rule := 1; END IF;
        ELSIF rule.attribute_name = 'semester' THEN
            IF rule.operator = '=' AND v_semester = rule.attribute_value THEN v_passes_rule := 1; END IF;
        ELSIF rule.attribute_name = 'cgpa' THEN
            IF    rule.operator = '>=' AND v_cgpa >= TO_NUMBER(rule.attribute_value) THEN v_passes_rule := 1;
            ELSIF rule.operator = '>'  AND v_cgpa >  TO_NUMBER(rule.attribute_value) THEN v_passes_rule := 1;
            ELSIF rule.operator = '<=' AND v_cgpa <= TO_NUMBER(rule.attribute_value) THEN v_passes_rule := 1;
            ELSIF rule.operator = '='  AND v_cgpa =  TO_NUMBER(rule.attribute_value) THEN v_passes_rule := 1;
            END IF;
        END IF;
        IF v_passes_rule = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'User is not eligible to submit this form.');
        END IF;
    END LOOP;

    -- Insert submission
    p_sub_id := SEQ_SUB.NEXTVAL;
    INSERT INTO SUBMISSIONS (submission_id, form_id, user_id, submitted_at, status)
    VALUES (p_sub_id, p_form_id, p_user_id, SYSDATE, 'submitted');

    -- Insert responses
    FOR i IN 1 .. p_field_ids.COUNT LOOP
        INSERT INTO RESPONSES (response_id, submission_id, field_id, response_value)
        VALUES (SEQ_RESP.NEXTVAL, p_sub_id, p_field_ids(i), p_values(i));
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Submission ' || p_sub_id || ' recorded successfully.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_submit_form;
/

-- ============================================================
-- SECTION 4: FUNCTION — Check User Eligibility
-- ============================================================
CREATE OR REPLACE FUNCTION fn_is_eligible (
    p_user_id IN NUMBER,
    p_form_id IN NUMBER
) RETURN VARCHAR2 AS
    v_branch    USERS.branch%TYPE;
    v_cgpa      USERS.cgpa%TYPE;
    v_semester  USERS.semester%TYPE;
    v_passes    NUMBER;
BEGIN
    SELECT branch, cgpa, semester INTO v_branch, v_cgpa, v_semester
    FROM   USERS WHERE user_id = p_user_id;

    FOR rule IN (SELECT * FROM ACCESS_RULES WHERE form_id = p_form_id) LOOP
        v_passes := 0;
        IF rule.attribute_name = 'branch' AND rule.operator = '=' AND v_branch = rule.attribute_value THEN
            v_passes := 1;
        ELSIF rule.attribute_name = 'semester' AND rule.operator = '=' AND v_semester = rule.attribute_value THEN
            v_passes := 1;
        ELSIF rule.attribute_name = 'cgpa' THEN
            IF    rule.operator = '>=' AND v_cgpa >= TO_NUMBER(rule.attribute_value) THEN v_passes := 1;
            ELSIF rule.operator = '>'  AND v_cgpa >  TO_NUMBER(rule.attribute_value) THEN v_passes := 1;
            END IF;
        END IF;
        IF v_passes = 0 THEN RETURN 'NOT ELIGIBLE'; END IF;
    END LOOP;
    RETURN 'ELIGIBLE';
END fn_is_eligible;
/

-- Test the function
SELECT username, fn_is_eligible(user_id, 1) AS eligibility_form1
FROM   USERS WHERE role = 'student';

-- ============================================================
-- SECTION 5: FUNCTION — Get Analytics for a Form
-- ============================================================
CREATE OR REPLACE FUNCTION fn_form_analytics (
    p_form_id IN NUMBER
) RETURN SYS_REFCURSOR AS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        SELECT ff.field_name,
               ff.field_type,
               COUNT(r.response_id)                              AS total_responses,
               CASE WHEN ff.field_type = 'NUMERIC'
                    THEN TO_CHAR(ROUND(AVG(TO_NUMBER(r.response_value)),2))
                    ELSE 'N/A' END                               AS avg_value,
               CASE WHEN ff.field_type = 'BOOLEAN'
                    THEN TO_CHAR(SUM(CASE WHEN UPPER(r.response_value)='YES' THEN 1 ELSE 0 END))
                         || ' YES / '
                         || TO_CHAR(SUM(CASE WHEN UPPER(r.response_value)='NO'  THEN 1 ELSE 0 END))
                         || ' NO'
                    ELSE 'N/A' END                               AS bool_distribution
        FROM   FORM_FIELDS ff
        LEFT   JOIN RESPONSES   r  ON r.field_id = ff.field_id
        LEFT   JOIN SUBMISSIONS s  ON s.submission_id = r.submission_id AND s.form_id = p_form_id
        WHERE  ff.form_id = p_form_id
        GROUP  BY ff.field_id, ff.field_name, ff.field_type;
    RETURN v_cursor;
END fn_form_analytics;
/

-- ============================================================
-- SECTION 6: TRIGGER — Auto-close expired forms
-- ============================================================
CREATE OR REPLACE TRIGGER trg_auto_close_form
BEFORE INSERT OR UPDATE ON SUBMISSIONS
FOR EACH ROW
DECLARE
    v_end_date  DATE;
    v_status    VARCHAR2(10);
BEGIN
    SELECT end_date, status INTO v_end_date, v_status
    FROM   FORMS WHERE form_id = :NEW.form_id;

    IF SYSDATE > v_end_date THEN
        -- Auto-close the form
        UPDATE FORMS SET status = 'closed' WHERE form_id = :NEW.form_id;
        RAISE_APPLICATION_ERROR(-20010, 'Form deadline has passed. Form is now closed.');
    END IF;
END trg_auto_close_form;
/

-- ============================================================
-- SECTION 7: TRIGGER — Prevent duplicate submissions
-- ============================================================
CREATE OR REPLACE TRIGGER trg_no_duplicate_submission
BEFORE INSERT ON SUBMISSIONS
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM   SUBMISSIONS
    WHERE  form_id = :NEW.form_id AND user_id = :NEW.user_id;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Duplicate submission detected for user ' || :NEW.user_id || ' on form ' || :NEW.form_id);
    END IF;
END trg_no_duplicate_submission;
/

-- ============================================================
-- SECTION 8: TRIGGER — Auto-generate reminder notifications
--            when a new form is created
-- ============================================================
CREATE OR REPLACE TRIGGER trg_form_create_notifications
AFTER INSERT ON FORMS
FOR EACH ROW
DECLARE
    CURSOR eligible_users IS
        SELECT u.user_id FROM USERS u WHERE u.role = 'student';
BEGIN
    -- We queue a notification for all students (eligibility is filtered at runtime)
    FOR u IN eligible_users LOOP
        INSERT INTO NOTIFICATIONS (notif_id, user_id, form_id, message, is_sent, scheduled_at)
        VALUES (SEQ_NOTIF.NEXTVAL, u.user_id, :NEW.form_id,
                'A new form "' || :NEW.title || '" is available. Deadline: ' ||
                TO_CHAR(:NEW.end_date, 'DD-MON-YYYY'),
                0, SYSDATE);
    END LOOP;
END trg_form_create_notifications;
/

PROMPT PL/SQL objects compiled successfully.
SHOW ERRORS
