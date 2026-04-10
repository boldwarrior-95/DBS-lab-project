-- Complete reset: drop user, recreate with all grants, insert everything in PL/SQL
-- Run as: sqlplus "/ as sysdba" @setup_final.sql

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET FEEDBACK OFF

-- Drop and recreate user
BEGIN
  EXECUTE IMMEDIATE 'DROP USER dscae CASCADE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

ALTER SESSION SET "_ORACLE_SCRIPT"=true;

CREATE USER dscae IDENTIFIED BY dscae123
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CONNECT, RESOURCE, CREATE SESSION, CREATE TABLE,
      CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER,
      CREATE VIEW, CREATE TYPE TO dscae;
GRANT EXECUTE ON SYS.DBMS_CRYPTO TO dscae;
GRANT EXECUTE ON SYS.UTL_I18N TO dscae;

PROMPT [1/6] User DSCAE created with all grants.

-- Now connect as dscae
CONNECT dscae/dscae123@localhost:1521/XE
SET SERVEROUTPUT ON SIZE UNLIMITED

-- Create all objects and insert data in one big PL/SQL block
-- so nothing can go wrong with ordering

-- Step 1: Sequences
CREATE SEQUENCE SEQ_USER  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FORM  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FIELD START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RULE  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_SUB   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RESP  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_NOTIF START WITH 1 INCREMENT BY 1 NOCACHE;

PROMPT [2/6] Sequences created.

-- Step 2: Tables (no triggers yet so inserts work cleanly)
CREATE TABLE USERS (
    user_id       NUMBER          PRIMARY KEY,
    username      VARCHAR2(50)    NOT NULL UNIQUE,
    email         VARCHAR2(100)   NOT NULL UNIQUE,
    password_hash VARCHAR2(255)   NOT NULL,
    branch        VARCHAR2(50),
    cgpa          NUMBER(3,1)     CHECK (cgpa BETWEEN 0 AND 10),
    semester      VARCHAR2(10),
    role          VARCHAR2(10)    DEFAULT 'student' CHECK (role IN ('admin','student')),
    created_at    DATE            DEFAULT SYSDATE
);

CREATE TABLE FORMS (
    form_id       NUMBER          PRIMARY KEY,
    created_by    NUMBER          NOT NULL REFERENCES USERS(user_id),
    title         VARCHAR2(200)   NOT NULL,
    description   CLOB,
    status        VARCHAR2(10)    DEFAULT 'draft' CHECK (status IN ('draft','open','closed')),
    start_date    DATE            NOT NULL,
    end_date      DATE            NOT NULL,
    CONSTRAINT chk_form_dates CHECK (end_date > start_date)
);

CREATE TABLE FORM_FIELDS (
    field_id        NUMBER          PRIMARY KEY,
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id) ON DELETE CASCADE,
    field_name      VARCHAR2(100)   NOT NULL,
    field_type      VARCHAR2(20)    NOT NULL CHECK (field_type IN ('TEXT','NUMERIC','BOOLEAN','DATE')),
    is_required     NUMBER(1)       DEFAULT 1 CHECK (is_required IN (0,1)),
    validation_rule VARCHAR2(500),
    display_order   NUMBER          DEFAULT 1,
    CONSTRAINT uq_field UNIQUE (form_id, field_name)
);

CREATE TABLE ACCESS_RULES (
    rule_id         NUMBER          PRIMARY KEY,
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id) ON DELETE CASCADE,
    attribute_name  VARCHAR2(50)    NOT NULL CHECK (attribute_name IN ('branch','cgpa','semester','role')),
    operator        VARCHAR2(10)    NOT NULL CHECK (operator IN ('=','!=','>','<','>=','<=')),
    attribute_value VARCHAR2(100)   NOT NULL
);

CREATE TABLE SUBMISSIONS (
    submission_id   NUMBER          PRIMARY KEY,
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id),
    user_id         NUMBER          NOT NULL REFERENCES USERS(user_id),
    submitted_at    DATE            DEFAULT SYSDATE,
    status          VARCHAR2(10)    DEFAULT 'submitted' CHECK (status IN ('submitted','withdrawn')),
    CONSTRAINT uq_submission UNIQUE (form_id, user_id)
);

CREATE TABLE RESPONSES (
    response_id     NUMBER          PRIMARY KEY,
    submission_id   NUMBER          NOT NULL REFERENCES SUBMISSIONS(submission_id) ON DELETE CASCADE,
    field_id        NUMBER          NOT NULL REFERENCES FORM_FIELDS(field_id),
    response_value  CLOB,
    CONSTRAINT uq_response UNIQUE (submission_id, field_id)
);

CREATE TABLE NOTIFICATIONS (
    notif_id        NUMBER          PRIMARY KEY,
    user_id         NUMBER          NOT NULL REFERENCES USERS(user_id),
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id),
    message         VARCHAR2(1000),
    is_sent         NUMBER(1)       DEFAULT 0 CHECK (is_sent IN (0,1)),
    scheduled_at    DATE            DEFAULT SYSDATE
);

PROMPT [3/6] Tables created.

-- Step 3: Insert ALL sample data in one PL/SQL block
DECLARE
  FUNCTION sha256(p_str VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(p_str, 'AL32UTF8'), DBMS_CRYPTO.HASH_SH256)));
  END;
  v_admin_pw  VARCHAR2(255);
  v_student_pw VARCHAR2(255);
BEGIN
  v_admin_pw  := sha256('Admin@123');
  v_student_pw := sha256('Student@123');

  -- Users
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,'admin1','admin1@mit.edu',v_admin_pw,'MCA',9.5,'NA','admin',SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,'admin2','admin2@mit.edu',v_admin_pw,'MCA',9.2,'NA','admin',SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,'pranav','pranav@mit.edu',v_student_pw,'MCA',9.1,'4','student',SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,'sreejesh','sreejesh@mit.edu',v_student_pw,'MCA',8.7,'4','student',SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,'alice','alice@mit.edu',v_student_pw,'CSE',8.2,'4','student',SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,'bob','bob@mit.edu',v_student_pw,'CSE',6.5,'4','student',SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,'carol','carol@mit.edu',v_student_pw,'ECE',8.9,'2','student',SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL,'dave','dave@mit.edu',v_student_pw,'MCA',7.3,'6','student',SYSDATE);
  DBMS_OUTPUT.PUT_LINE('Inserted 8 users');

  -- Forms
  INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL,1,'Hackathon Registration 2026','Register for the annual MIT Hackathon. Open to 4th sem MCA with CGPA > 8.0','open',SYSDATE-2,SYSDATE+10);
  INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL,1,'Mid-Sem Feedback Survey','Anonymous feedback for DBS Lab','open',SYSDATE-1,SYSDATE+5);
  INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL,2,'Placement Eligibility Poll','Check eligibility for campus placements','closed',SYSDATE-20,SYSDATE-5);
  DBMS_OUTPUT.PUT_LINE('Inserted 3 forms');

  -- Form Fields
  INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL,1,'Team Name','TEXT',1,'^[A-Za-z0-9 ]{3,30}$',1);
  INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL,1,'Project Idea','TEXT',1,NULL,2);
  INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL,1,'Has Laptop','BOOLEAN',1,NULL,3);
  INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL,1,'T-Shirt Size','TEXT',0,NULL,4);
  INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL,2,'Overall Rating','NUMERIC',1,'1-5',1);
  INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL,2,'Comments','TEXT',0,NULL,2);
  INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL,2,'Recommend Course','BOOLEAN',1,NULL,3);
  INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL,3,'Are You Interested','BOOLEAN',1,NULL,1);
  INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL,3,'Preferred Domain','TEXT',1,NULL,2);
  DBMS_OUTPUT.PUT_LINE('Inserted 9 fields');

  -- Access Rules
  INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL,1,'branch','=','MCA');
  INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL,1,'semester','=','4');
  INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL,1,'cgpa','>=','8.0');
  INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL,2,'semester','=','4');
  INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL,3,'cgpa','>=','6.0');
  DBMS_OUTPUT.PUT_LINE('Inserted 5 rules');

  -- Submissions
  INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL,1,3,SYSDATE-1,'submitted');
  INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL,1,4,SYSDATE-1,'submitted');
  INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL,2,3,SYSDATE,'submitted');
  INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL,2,5,SYSDATE,'submitted');
  DBMS_OUTPUT.PUT_LINE('Inserted 4 submissions');

  -- Responses
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,1,1,'Team Nexus');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,1,2,'AI-powered attendance system');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,1,3,'YES');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,1,4,'L');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,2,1,'Team Nexus');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,2,2,'AI-powered attendance system');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,2,3,'YES');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,2,4,'M');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,3,5,'5');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,3,6,'Great lab sessions!');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,3,7,'YES');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,4,5,'4');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,4,6,'More practice problems needed');
  INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,4,7,'YES');
  DBMS_OUTPUT.PUT_LINE('Inserted 14 responses');

  -- Notifications
  INSERT INTO NOTIFICATIONS VALUES (SEQ_NOTIF.NEXTVAL,3,1,'Hackathon Registration is now open for you!',1,SYSDATE-2);
  INSERT INTO NOTIFICATIONS VALUES (SEQ_NOTIF.NEXTVAL,4,1,'Hackathon Registration is now open for you!',1,SYSDATE-2);
  INSERT INTO NOTIFICATIONS VALUES (SEQ_NOTIF.NEXTVAL,6,1,'Reminder: Hackathon deadline in 2 days.',0,SYSDATE+8);
  DBMS_OUTPUT.PUT_LINE('Inserted 3 notifications');

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('ALL DATA COMMITTED SUCCESSFULLY');
END;
/

PROMPT [4/6] Sample data inserted.

-- Step 4: PL/SQL Function
CREATE OR REPLACE FUNCTION fn_is_eligible (
    p_user_id IN NUMBER, p_form_id IN NUMBER
) RETURN VARCHAR2 AS
    v_branch USERS.branch%TYPE; v_cgpa USERS.cgpa%TYPE; v_semester USERS.semester%TYPE; v_passes NUMBER;
BEGIN
    SELECT branch,cgpa,semester INTO v_branch,v_cgpa,v_semester FROM USERS WHERE user_id=p_user_id;
    FOR rule IN (SELECT * FROM ACCESS_RULES WHERE form_id=p_form_id) LOOP
        v_passes := 0;
        IF rule.attribute_name='branch' AND rule.operator='=' AND v_branch=rule.attribute_value THEN v_passes:=1;
        ELSIF rule.attribute_name='semester' AND rule.operator='=' AND v_semester=rule.attribute_value THEN v_passes:=1;
        ELSIF rule.attribute_name='cgpa' THEN
            IF rule.operator='>=' AND v_cgpa>=TO_NUMBER(rule.attribute_value) THEN v_passes:=1;
            ELSIF rule.operator='>' AND v_cgpa>TO_NUMBER(rule.attribute_value) THEN v_passes:=1;
            END IF;
        END IF;
        IF v_passes=0 THEN RETURN 'NOT ELIGIBLE'; END IF;
    END LOOP;
    RETURN 'ELIGIBLE';
END fn_is_eligible;
/

-- Step 5: Stored Procedure
CREATE OR REPLACE PROCEDURE sp_submit_form (
    p_form_id IN NUMBER, p_user_id IN NUMBER,
    p_field_ids IN SYS.ODCINUMBERLIST, p_values IN SYS.ODCIVARCHAR2LIST,
    p_sub_id OUT NUMBER
) AS
    v_status VARCHAR2(10); v_end_date DATE; v_dup NUMBER;
    v_branch USERS.branch%TYPE; v_cgpa USERS.cgpa%TYPE; v_semester USERS.semester%TYPE; v_passes NUMBER;
BEGIN
    SELECT status,end_date INTO v_status,v_end_date FROM FORMS WHERE form_id=p_form_id;
    IF v_status!='open' THEN RAISE_APPLICATION_ERROR(-20001,'Form is not open.'); END IF;
    IF v_end_date<SYSDATE THEN RAISE_APPLICATION_ERROR(-20002,'Deadline passed.'); END IF;
    SELECT COUNT(*) INTO v_dup FROM SUBMISSIONS WHERE form_id=p_form_id AND user_id=p_user_id;
    IF v_dup>0 THEN RAISE_APPLICATION_ERROR(-20003,'Already submitted.'); END IF;
    SELECT branch,cgpa,semester INTO v_branch,v_cgpa,v_semester FROM USERS WHERE user_id=p_user_id;
    FOR rule IN (SELECT * FROM ACCESS_RULES WHERE form_id=p_form_id) LOOP
        v_passes:=0;
        IF rule.attribute_name='branch' THEN IF rule.operator='=' AND v_branch=rule.attribute_value THEN v_passes:=1; END IF;
        ELSIF rule.attribute_name='semester' THEN IF rule.operator='=' AND v_semester=rule.attribute_value THEN v_passes:=1; END IF;
        ELSIF rule.attribute_name='cgpa' THEN
            IF rule.operator='>=' AND v_cgpa>=TO_NUMBER(rule.attribute_value) THEN v_passes:=1;
            ELSIF rule.operator='>' AND v_cgpa>TO_NUMBER(rule.attribute_value) THEN v_passes:=1;
            ELSIF rule.operator='<=' AND v_cgpa<=TO_NUMBER(rule.attribute_value) THEN v_passes:=1;
            ELSIF rule.operator='=' AND v_cgpa=TO_NUMBER(rule.attribute_value) THEN v_passes:=1;
            END IF;
        END IF;
        IF v_passes=0 THEN RAISE_APPLICATION_ERROR(-20004,'Not eligible.'); END IF;
    END LOOP;
    p_sub_id := SEQ_SUB.NEXTVAL;
    INSERT INTO SUBMISSIONS VALUES (p_sub_id,p_form_id,p_user_id,SYSDATE,'submitted');
    FOR i IN 1..p_field_ids.COUNT LOOP
        INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL,p_sub_id,p_field_ids(i),p_values(i));
    END LOOP;
    COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
END sp_submit_form;
/

PROMPT [5/6] PL/SQL function and procedure created.

-- Step 6: Triggers (created AFTER data is populated)
CREATE OR REPLACE TRIGGER trg_auto_close_form
BEFORE INSERT OR UPDATE ON SUBMISSIONS FOR EACH ROW
DECLARE v_end DATE; v_st VARCHAR2(10);
BEGIN
    SELECT end_date,status INTO v_end,v_st FROM FORMS WHERE form_id=:NEW.form_id;
    IF SYSDATE>v_end THEN UPDATE FORMS SET status='closed' WHERE form_id=:NEW.form_id;
        RAISE_APPLICATION_ERROR(-20010,'Deadline passed. Form closed.'); END IF;
END trg_auto_close_form;
/

CREATE OR REPLACE TRIGGER trg_no_duplicate_submission
BEFORE INSERT ON SUBMISSIONS FOR EACH ROW
DECLARE v_c NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_c FROM SUBMISSIONS WHERE form_id=:NEW.form_id AND user_id=:NEW.user_id;
    IF v_c>0 THEN RAISE_APPLICATION_ERROR(-20011,'Duplicate submission.'); END IF;
END trg_no_duplicate_submission;
/

CREATE OR REPLACE TRIGGER trg_form_create_notifications
AFTER INSERT ON FORMS FOR EACH ROW
DECLARE CURSOR c IS SELECT user_id FROM USERS WHERE role='student';
BEGIN
    FOR u IN c LOOP
        INSERT INTO NOTIFICATIONS VALUES(SEQ_NOTIF.NEXTVAL,u.user_id,:NEW.form_id,
            'New form "'||:NEW.title||'" available. Deadline: '||TO_CHAR(:NEW.end_date,'DD-MON-YYYY'),0,SYSDATE);
    END LOOP;
END trg_form_create_notifications;
/

PROMPT [6/6] Triggers created.

SET FEEDBACK ON
PROMPT ============================================
PROMPT VERIFICATION:
PROMPT ============================================
SELECT 'Users: '||COUNT(*) info FROM USERS;
SELECT 'Forms: '||COUNT(*) info FROM FORMS;
SELECT 'Fields: '||COUNT(*) info FROM FORM_FIELDS;
SELECT 'Rules: '||COUNT(*) info FROM ACCESS_RULES;
SELECT 'Submissions: '||COUNT(*) info FROM SUBMISSIONS;
SELECT 'Responses: '||COUNT(*) info FROM RESPONSES;

SELECT username, fn_is_eligible(user_id,1) AS hackathon FROM USERS WHERE role='student';

PROMPT ============================================
PROMPT DATABASE FULLY SET UP!
PROMPT Credentials: admin1/Admin@123, pranav/Student@123
PROMPT ============================================
EXIT;
