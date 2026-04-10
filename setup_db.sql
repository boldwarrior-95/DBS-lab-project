-- Setup script for D-SCAE Oracle user and schema
-- Run as: sqlplus "/ as sysdba" @setup_db.sql

-- 1. Create user dscae
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM all_users WHERE username = 'DSCAE';
  IF v_count > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER dscae CASCADE';
    DBMS_OUTPUT.PUT_LINE('Dropped existing DSCAE user.');
  END IF;
END;
/

ALTER SESSION SET "_ORACLE_SCRIPT"=true;
CREATE USER dscae IDENTIFIED BY dscae123
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CONNECT, RESOURCE TO dscae;
GRANT CREATE SESSION TO dscae;
GRANT CREATE TABLE TO dscae;
GRANT CREATE SEQUENCE TO dscae;
GRANT CREATE PROCEDURE TO dscae;
GRANT CREATE TRIGGER TO dscae;
GRANT CREATE VIEW TO dscae;
GRANT CREATE TYPE TO dscae;

PROMPT ============================================
PROMPT User DSCAE created successfully.
PROMPT ============================================

-- 2. Connect as dscae and run schema
CONNECT dscae/dscae123@localhost:1521/XE

-- Drop tables if re-running (reverse dependency order)
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('NOTIFICATIONS','RESPONSES','SUBMISSIONS',
                                 'ACCESS_RULES','FORM_FIELDS','FORMS','USERS'))
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
END;
/

-- Drop sequences
BEGIN
  FOR s IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name IN ('SEQ_USER','SEQ_FORM','SEQ_FIELD',
                                    'SEQ_RULE','SEQ_SUB','SEQ_RESP','SEQ_NOTIF'))
  LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/

-- SEQUENCES
CREATE SEQUENCE SEQ_USER  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FORM  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FIELD START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RULE  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_SUB   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RESP  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_NOTIF START WITH 1 INCREMENT BY 1 NOCACHE;

-- TABLE: USERS
CREATE TABLE USERS (
    user_id       NUMBER          PRIMARY KEY,
    username      VARCHAR2(50)    NOT NULL UNIQUE,
    email         VARCHAR2(100)   NOT NULL UNIQUE,
    password_hash VARCHAR2(255)   NOT NULL,
    branch        VARCHAR2(50),
    cgpa          NUMBER(3,1)     CHECK (cgpa BETWEEN 0 AND 10),
    semester      VARCHAR2(10),
    role          VARCHAR2(10)    DEFAULT 'student'
                                  CHECK (role IN ('admin','student')),
    created_at    DATE            DEFAULT SYSDATE
);

-- TABLE: FORMS
CREATE TABLE FORMS (
    form_id       NUMBER          PRIMARY KEY,
    created_by    NUMBER          NOT NULL REFERENCES USERS(user_id),
    title         VARCHAR2(200)   NOT NULL,
    description   CLOB,
    status        VARCHAR2(10)    DEFAULT 'draft'
                                  CHECK (status IN ('draft','open','closed')),
    start_date    DATE            NOT NULL,
    end_date      DATE            NOT NULL,
    CONSTRAINT chk_form_dates CHECK (end_date > start_date)
);

-- TABLE: FORM_FIELDS
CREATE TABLE FORM_FIELDS (
    field_id        NUMBER          PRIMARY KEY,
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id) ON DELETE CASCADE,
    field_name      VARCHAR2(100)   NOT NULL,
    field_type      VARCHAR2(20)    NOT NULL
                    CHECK (field_type IN ('TEXT','NUMERIC','BOOLEAN','DATE')),
    is_required     NUMBER(1)       DEFAULT 1 CHECK (is_required IN (0,1)),
    validation_rule VARCHAR2(500),
    display_order   NUMBER          DEFAULT 1,
    CONSTRAINT uq_field UNIQUE (form_id, field_name)
);

-- TABLE: ACCESS_RULES
CREATE TABLE ACCESS_RULES (
    rule_id         NUMBER          PRIMARY KEY,
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id) ON DELETE CASCADE,
    attribute_name  VARCHAR2(50)    NOT NULL
                    CHECK (attribute_name IN ('branch','cgpa','semester','role')),
    operator        VARCHAR2(10)    NOT NULL
                    CHECK (operator IN ('=','!=','>','<','>=','<=')),
    attribute_value VARCHAR2(100)   NOT NULL
);

-- TABLE: SUBMISSIONS
CREATE TABLE SUBMISSIONS (
    submission_id   NUMBER          PRIMARY KEY,
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id),
    user_id         NUMBER          NOT NULL REFERENCES USERS(user_id),
    submitted_at    DATE            DEFAULT SYSDATE,
    status          VARCHAR2(10)    DEFAULT 'submitted'
                    CHECK (status IN ('submitted','withdrawn')),
    CONSTRAINT uq_submission UNIQUE (form_id, user_id)
);

-- TABLE: RESPONSES
CREATE TABLE RESPONSES (
    response_id     NUMBER          PRIMARY KEY,
    submission_id   NUMBER          NOT NULL REFERENCES SUBMISSIONS(submission_id) ON DELETE CASCADE,
    field_id        NUMBER          NOT NULL REFERENCES FORM_FIELDS(field_id),
    response_value  CLOB,
    CONSTRAINT uq_response UNIQUE (submission_id, field_id)
);

-- TABLE: NOTIFICATIONS
CREATE TABLE NOTIFICATIONS (
    notif_id        NUMBER          PRIMARY KEY,
    user_id         NUMBER          NOT NULL REFERENCES USERS(user_id),
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id),
    message         VARCHAR2(1000),
    is_sent         NUMBER(1)       DEFAULT 0 CHECK (is_sent IN (0,1)),
    scheduled_at    DATE            DEFAULT SYSDATE
);

COMMIT;
PROMPT Schema created successfully.

PROMPT ============================================
PROMPT Inserting sample data...
PROMPT ============================================

-- USERS (2 admins, 6 students) -- using SHA256 hashed passwords
-- admin1/Admin@123  => 5b722b307fce6c0f6e45440c3ba0ea8c26a0cf64a8b1e04ac7f70f26cb80db93
-- Student@123       => 52dac72a3023e77f30e8e9a3e1805345ff13c0827a50e601f07b365e7f98eb20

-- We'll use PL/SQL to hash properly
DECLARE
  FUNCTION sha256(p_str VARCHAR2) RETURN VARCHAR2 IS
    v_raw RAW(32);
  BEGIN
    v_raw := DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(p_str, 'AL32UTF8'), DBMS_CRYPTO.HASH_SH256);
    RETURN LOWER(RAWTOHEX(v_raw));
  END;
BEGIN
  -- Admin users
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'admin1',   'admin1@mit.edu',   sha256('Admin@123'),   'MCA', 9.5, 'NA',  'admin',   SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'admin2',   'admin2@mit.edu',   sha256('Admin@123'),   'MCA', 9.2, 'NA',  'admin',   SYSDATE);
  -- Student users
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'pranav',   'pranav@mit.edu',   sha256('Student@123'), 'MCA', 9.1, '4',   'student', SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'sreejesh', 'sreejesh@mit.edu', sha256('Student@123'), 'MCA', 8.7, '4',   'student', SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'alice',    'alice@mit.edu',    sha256('Student@123'), 'CSE', 8.2, '4',   'student', SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'bob',      'bob@mit.edu',      sha256('Student@123'), 'CSE', 6.5, '4',   'student', SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'carol',    'carol@mit.edu',    sha256('Student@123'), 'ECE', 8.9, '2',   'student', SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'dave',     'dave@mit.edu',     sha256('Student@123'), 'MCA', 7.3, '6',   'student', SYSDATE);
  COMMIT;
END;
/

-- FORMS
INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL, 1, 'Hackathon Registration 2026',
  'Register for the annual MIT Hackathon. Open to 4th sem MCA with CGPA > 8.0',
  'open', SYSDATE - 2, SYSDATE + 10);

INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL, 1, 'Mid-Sem Feedback Survey',
  'Anonymous feedback for DBS Lab',
  'open', SYSDATE - 1, SYSDATE + 5);

INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL, 2, 'Placement Eligibility Poll',
  'Check eligibility for campus placements',
  'closed', SYSDATE - 20, SYSDATE - 5);

-- FORM_FIELDS for Form 1 (Hackathon)
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'Team Name',        'TEXT',    1, '^[A-Za-z0-9 ]{3,30}$', 1);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'Project Idea',     'TEXT',    1, NULL,                    2);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'Has Laptop',       'BOOLEAN', 1, NULL,                    3);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'T-Shirt Size',     'TEXT',    0, NULL,                    4);

-- FORM_FIELDS for Form 2 (Feedback)
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 2, 'Overall Rating',   'NUMERIC', 1, '1-5',  1);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 2, 'Comments',         'TEXT',    0, NULL,   2);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 2, 'Recommend Course', 'BOOLEAN', 1, NULL,   3);

-- FORM_FIELDS for Form 3 (Placement)
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 3, 'Are You Interested', 'BOOLEAN', 1, NULL, 1);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 3, 'Preferred Domain',   'TEXT',    1, NULL, 2);

-- ACCESS_RULES for Form 1 (MCA students, sem=4, cgpa>=8)
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'branch',   '=',  'MCA');
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'semester', '=',  '4');
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'cgpa',     '>=', '8.0');

-- ACCESS_RULES for Form 2 (all 4th sem students)
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 2, 'semester', '=', '4');

-- ACCESS_RULES for Form 3 (CGPA >= 6.0)
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 3, 'cgpa', '>=', '6.0');

-- SUBMISSIONS
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 1, 3, SYSDATE - 1, 'submitted');
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 1, 4, SYSDATE - 1, 'submitted');
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 2, 3, SYSDATE,     'submitted');
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 2, 5, SYSDATE,     'submitted');

-- RESPONSES for Submission 1 (pranav -> hackathon)
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 1, 'Team Nexus');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 2, 'AI-powered attendance system');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 3, 'YES');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 4, 'L');

-- RESPONSES for Submission 2 (sreejesh -> hackathon)
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 1, 'Team Nexus');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 2, 'AI-powered attendance system');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 3, 'YES');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 4, 'M');

-- RESPONSES for Submission 3 (pranav -> feedback)
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 3, 5, '5');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 3, 6, 'Great lab sessions!');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 3, 7, 'YES');

-- RESPONSES for Submission 4 (alice -> feedback)
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 4, 5, '4');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 4, 6, 'More practice problems needed');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 4, 7, 'YES');

-- NOTIFICATIONS
INSERT INTO NOTIFICATIONS VALUES (SEQ_NOTIF.NEXTVAL, 3, 1, 'Hackathon Registration is now open for you!', 1, SYSDATE - 2);
INSERT INTO NOTIFICATIONS VALUES (SEQ_NOTIF.NEXTVAL, 4, 1, 'Hackathon Registration is now open for you!', 1, SYSDATE - 2);
INSERT INTO NOTIFICATIONS VALUES (SEQ_NOTIF.NEXTVAL, 6, 1, 'Reminder: Hackathon deadline in 2 days.', 0, SYSDATE + 8);

COMMIT;
PROMPT Sample data inserted successfully.

PROMPT ============================================
PROMPT Creating PL/SQL objects...
PROMPT ============================================

-- FUNCTION: Check User Eligibility
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

-- STORED PROCEDURE: Submit a Form
CREATE OR REPLACE PROCEDURE sp_submit_form (
    p_form_id    IN  NUMBER,
    p_user_id    IN  NUMBER,
    p_field_ids  IN  SYS.ODCINUMBERLIST,
    p_values     IN  SYS.ODCIVARCHAR2LIST,
    p_sub_id     OUT NUMBER
) AS
    v_status      VARCHAR2(10);
    v_end_date    DATE;
    v_dup         NUMBER;
    v_branch      USERS.branch%TYPE;
    v_cgpa        USERS.cgpa%TYPE;
    v_semester    USERS.semester%TYPE;
    v_passes_rule NUMBER;
BEGIN
    SELECT status, end_date INTO v_status, v_end_date
    FROM   FORMS WHERE form_id = p_form_id;
    IF v_status != 'open' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Form is not open for submissions.');
    END IF;
    IF v_end_date < SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20002, 'Submission deadline has passed.');
    END IF;

    SELECT COUNT(*) INTO v_dup FROM SUBMISSIONS
    WHERE  form_id = p_form_id AND user_id = p_user_id;
    IF v_dup > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'User has already submitted this form.');
    END IF;

    SELECT branch, cgpa, semester INTO v_branch, v_cgpa, v_semester
    FROM   USERS WHERE user_id = p_user_id;

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

    p_sub_id := SEQ_SUB.NEXTVAL;
    INSERT INTO SUBMISSIONS (submission_id, form_id, user_id, submitted_at, status)
    VALUES (p_sub_id, p_form_id, p_user_id, SYSDATE, 'submitted');

    FOR i IN 1 .. p_field_ids.COUNT LOOP
        INSERT INTO RESPONSES (response_id, submission_id, field_id, response_value)
        VALUES (SEQ_RESP.NEXTVAL, p_sub_id, p_field_ids(i), p_values(i));
    END LOOP;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_submit_form;
/

-- TRIGGER: Auto-close expired forms
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
        UPDATE FORMS SET status = 'closed' WHERE form_id = :NEW.form_id;
        RAISE_APPLICATION_ERROR(-20010, 'Form deadline has passed. Form is now closed.');
    END IF;
END trg_auto_close_form;
/

-- TRIGGER: Prevent duplicate submissions
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

-- TRIGGER: Auto-generate notifications on new form
CREATE OR REPLACE TRIGGER trg_form_create_notifications
AFTER INSERT ON FORMS
FOR EACH ROW
DECLARE
    CURSOR eligible_users IS
        SELECT u.user_id FROM USERS u WHERE u.role = 'student';
BEGIN
    FOR u IN eligible_users LOOP
        INSERT INTO NOTIFICATIONS (notif_id, user_id, form_id, message, is_sent, scheduled_at)
        VALUES (SEQ_NOTIF.NEXTVAL, u.user_id, :NEW.form_id,
                'A new form "' || :NEW.title || '" is available. Deadline: ' ||
                TO_CHAR(:NEW.end_date, 'DD-MON-YYYY'),
                0, SYSDATE);
    END LOOP;
END trg_form_create_notifications;
/

-- Verify
PROMPT ============================================
PROMPT Verifying setup...
PROMPT ============================================
SELECT 'Users: ' || COUNT(*) AS info FROM USERS;
SELECT 'Forms: ' || COUNT(*) AS info FROM FORMS;
SELECT 'Fields: ' || COUNT(*) AS info FROM FORM_FIELDS;
SELECT 'Rules: ' || COUNT(*) AS info FROM ACCESS_RULES;
SELECT 'Submissions: ' || COUNT(*) AS info FROM SUBMISSIONS;
SELECT 'Responses: ' || COUNT(*) AS info FROM RESPONSES;

PROMPT ============================================
PROMPT D-SCAE database setup complete!
PROMPT Login credentials:
PROMPT   admin1 / Admin@123
PROMPT   pranav / Student@123
PROMPT ============================================
EXIT;
