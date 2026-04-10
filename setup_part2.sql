-- PART 2: Run as dscae user — schema, data, PL/SQL
-- setup_part2.sql
-- Run as: sqlplus dscae/dscae123@localhost:1521/XE @setup_part2.sql

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON

-- Sequences
CREATE SEQUENCE SEQ_USER  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FORM  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FIELD START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RULE  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_SUB   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RESP  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_NOTIF START WITH 1 INCREMENT BY 1 NOCACHE;

PROMPT === Sequences OK ===

-- Tables
CREATE TABLE USERS (
    user_id       NUMBER PRIMARY KEY,
    username      VARCHAR2(50) NOT NULL UNIQUE,
    email         VARCHAR2(100) NOT NULL UNIQUE,
    password_hash VARCHAR2(255) NOT NULL,
    branch        VARCHAR2(50),
    cgpa          NUMBER(3,1) CHECK (cgpa BETWEEN 0 AND 10),
    semester      VARCHAR2(10),
    role          VARCHAR2(10) DEFAULT 'student' CHECK (role IN ('admin','student')),
    created_at    DATE DEFAULT SYSDATE
);

CREATE TABLE FORMS (
    form_id     NUMBER PRIMARY KEY,
    created_by  NUMBER NOT NULL REFERENCES USERS(user_id),
    title       VARCHAR2(200) NOT NULL,
    description CLOB,
    status      VARCHAR2(10) DEFAULT 'draft' CHECK (status IN ('draft','open','closed')),
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    CONSTRAINT chk_form_dates CHECK (end_date > start_date)
);

CREATE TABLE FORM_FIELDS (
    field_id      NUMBER PRIMARY KEY,
    form_id       NUMBER NOT NULL REFERENCES FORMS(form_id) ON DELETE CASCADE,
    field_name    VARCHAR2(100) NOT NULL,
    field_type    VARCHAR2(20) NOT NULL CHECK (field_type IN ('TEXT','NUMERIC','BOOLEAN','DATE')),
    is_required   NUMBER(1) DEFAULT 1 CHECK (is_required IN (0,1)),
    validation_rule VARCHAR2(500),
    display_order NUMBER DEFAULT 1,
    CONSTRAINT uq_field UNIQUE (form_id, field_name)
);

CREATE TABLE ACCESS_RULES (
    rule_id         NUMBER PRIMARY KEY,
    form_id         NUMBER NOT NULL REFERENCES FORMS(form_id) ON DELETE CASCADE,
    attribute_name  VARCHAR2(50) NOT NULL CHECK (attribute_name IN ('branch','cgpa','semester','role')),
    operator        VARCHAR2(10) NOT NULL CHECK (operator IN ('=','!=','>','<','>=','<=')),
    attribute_value VARCHAR2(100) NOT NULL
);

CREATE TABLE SUBMISSIONS (
    submission_id NUMBER PRIMARY KEY,
    form_id       NUMBER NOT NULL REFERENCES FORMS(form_id),
    user_id       NUMBER NOT NULL REFERENCES USERS(user_id),
    submitted_at  DATE DEFAULT SYSDATE,
    status        VARCHAR2(10) DEFAULT 'submitted' CHECK (status IN ('submitted','withdrawn')),
    CONSTRAINT uq_submission UNIQUE (form_id, user_id)
);

CREATE TABLE RESPONSES (
    response_id   NUMBER PRIMARY KEY,
    submission_id NUMBER NOT NULL REFERENCES SUBMISSIONS(submission_id) ON DELETE CASCADE,
    field_id      NUMBER NOT NULL REFERENCES FORM_FIELDS(field_id),
    response_value CLOB,
    CONSTRAINT uq_response UNIQUE (submission_id, field_id)
);

CREATE TABLE NOTIFICATIONS (
    notif_id   NUMBER PRIMARY KEY,
    user_id    NUMBER NOT NULL REFERENCES USERS(user_id),
    form_id    NUMBER NOT NULL REFERENCES FORMS(form_id),
    message    VARCHAR2(1000),
    is_sent    NUMBER(1) DEFAULT 0 CHECK (is_sent IN (0,1)),
    scheduled_at DATE DEFAULT SYSDATE
);

PROMPT === Tables OK ===

-- Insert data (all in PL/SQL so it's transactional)
DECLARE
    v_apw VARCHAR2(255);
    v_spw VARCHAR2(255);
BEGIN
    v_apw := LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW('Admin@123','AL32UTF8'), DBMS_CRYPTO.HASH_SH256)));
    v_spw := LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW('Student@123','AL32UTF8'), DBMS_CRYPTO.HASH_SH256)));

    DBMS_OUTPUT.PUT_LINE('Admin hash: ' || v_apw);
    DBMS_OUTPUT.PUT_LINE('Student hash: ' || v_spw);

    -- Users
    INSERT INTO USERS VALUES(SEQ_USER.NEXTVAL,'admin1','admin1@mit.edu',v_apw,'MCA',9.5,'NA','admin',SYSDATE);
    INSERT INTO USERS VALUES(SEQ_USER.NEXTVAL,'admin2','admin2@mit.edu',v_apw,'MCA',9.2,'NA','admin',SYSDATE);
    INSERT INTO USERS VALUES(SEQ_USER.NEXTVAL,'pranav','pranav@mit.edu',v_spw,'MCA',9.1,'4','student',SYSDATE);
    INSERT INTO USERS VALUES(SEQ_USER.NEXTVAL,'sreejesh','sreejesh@mit.edu',v_spw,'MCA',8.7,'4','student',SYSDATE);
    INSERT INTO USERS VALUES(SEQ_USER.NEXTVAL,'alice','alice@mit.edu',v_spw,'CSE',8.2,'4','student',SYSDATE);
    INSERT INTO USERS VALUES(SEQ_USER.NEXTVAL,'bob','bob@mit.edu',v_spw,'CSE',6.5,'4','student',SYSDATE);
    INSERT INTO USERS VALUES(SEQ_USER.NEXTVAL,'carol','carol@mit.edu',v_spw,'ECE',8.9,'2','student',SYSDATE);
    INSERT INTO USERS VALUES(SEQ_USER.NEXTVAL,'dave','dave@mit.edu',v_spw,'MCA',7.3,'6','student',SYSDATE);

    -- Forms
    INSERT INTO FORMS VALUES(SEQ_FORM.NEXTVAL,1,'Hackathon Registration 2026','Register for the annual MIT Hackathon. Open to 4th sem MCA with CGPA > 8.0','open',SYSDATE-2,SYSDATE+10);
    INSERT INTO FORMS VALUES(SEQ_FORM.NEXTVAL,1,'Mid-Sem Feedback Survey','Anonymous feedback for DBS Lab','open',SYSDATE-1,SYSDATE+5);
    INSERT INTO FORMS VALUES(SEQ_FORM.NEXTVAL,2,'Placement Eligibility Poll','Check eligibility for campus placements','closed',SYSDATE-20,SYSDATE-5);

    -- Form Fields
    INSERT INTO FORM_FIELDS VALUES(SEQ_FIELD.NEXTVAL,1,'Team Name','TEXT',1,'^[A-Za-z0-9 ]{3,30}$',1);
    INSERT INTO FORM_FIELDS VALUES(SEQ_FIELD.NEXTVAL,1,'Project Idea','TEXT',1,NULL,2);
    INSERT INTO FORM_FIELDS VALUES(SEQ_FIELD.NEXTVAL,1,'Has Laptop','BOOLEAN',1,NULL,3);
    INSERT INTO FORM_FIELDS VALUES(SEQ_FIELD.NEXTVAL,1,'T-Shirt Size','TEXT',0,NULL,4);
    INSERT INTO FORM_FIELDS VALUES(SEQ_FIELD.NEXTVAL,2,'Overall Rating','NUMERIC',1,'1-5',1);
    INSERT INTO FORM_FIELDS VALUES(SEQ_FIELD.NEXTVAL,2,'Comments','TEXT',0,NULL,2);
    INSERT INTO FORM_FIELDS VALUES(SEQ_FIELD.NEXTVAL,2,'Recommend Course','BOOLEAN',1,NULL,3);
    INSERT INTO FORM_FIELDS VALUES(SEQ_FIELD.NEXTVAL,3,'Are You Interested','BOOLEAN',1,NULL,1);
    INSERT INTO FORM_FIELDS VALUES(SEQ_FIELD.NEXTVAL,3,'Preferred Domain','TEXT',1,NULL,2);

    -- Access Rules
    INSERT INTO ACCESS_RULES VALUES(SEQ_RULE.NEXTVAL,1,'branch','=','MCA');
    INSERT INTO ACCESS_RULES VALUES(SEQ_RULE.NEXTVAL,1,'semester','=','4');
    INSERT INTO ACCESS_RULES VALUES(SEQ_RULE.NEXTVAL,1,'cgpa','>=','8.0');
    INSERT INTO ACCESS_RULES VALUES(SEQ_RULE.NEXTVAL,2,'semester','=','4');
    INSERT INTO ACCESS_RULES VALUES(SEQ_RULE.NEXTVAL,3,'cgpa','>=','6.0');

    -- Submissions
    INSERT INTO SUBMISSIONS VALUES(SEQ_SUB.NEXTVAL,1,3,SYSDATE-1,'submitted');
    INSERT INTO SUBMISSIONS VALUES(SEQ_SUB.NEXTVAL,1,4,SYSDATE-1,'submitted');
    INSERT INTO SUBMISSIONS VALUES(SEQ_SUB.NEXTVAL,2,3,SYSDATE,'submitted');
    INSERT INTO SUBMISSIONS VALUES(SEQ_SUB.NEXTVAL,2,5,SYSDATE,'submitted');

    -- Responses
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,1,1,'Team Nexus');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,1,2,'AI-powered attendance system');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,1,3,'YES');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,1,4,'L');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,2,1,'Team Nexus');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,2,2,'AI-powered attendance system');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,2,3,'YES');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,2,4,'M');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,3,5,'5');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,3,6,'Great lab sessions!');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,3,7,'YES');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,4,5,'4');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,4,6,'More practice problems needed');
    INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,4,7,'YES');

    -- Notifications
    INSERT INTO NOTIFICATIONS VALUES(SEQ_NOTIF.NEXTVAL,3,1,'Hackathon Registration is now open!',1,SYSDATE-2);
    INSERT INTO NOTIFICATIONS VALUES(SEQ_NOTIF.NEXTVAL,4,1,'Hackathon Registration is now open!',1,SYSDATE-2);
    INSERT INTO NOTIFICATIONS VALUES(SEQ_NOTIF.NEXTVAL,6,1,'Reminder: Hackathon deadline in 2 days.',0,SYSDATE+8);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('ALL DATA INSERTED SUCCESSFULLY');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/

PROMPT === Data OK ===

-- PL/SQL: fn_is_eligible
CREATE OR REPLACE FUNCTION fn_is_eligible(p_uid NUMBER, p_fid NUMBER) RETURN VARCHAR2 AS
    v_br USERS.branch%TYPE; v_cg USERS.cgpa%TYPE; v_sm USERS.semester%TYPE; v_p NUMBER;
BEGIN
    SELECT branch,cgpa,semester INTO v_br,v_cg,v_sm FROM USERS WHERE user_id=p_uid;
    FOR r IN (SELECT * FROM ACCESS_RULES WHERE form_id=p_fid) LOOP
        v_p:=0;
        IF r.attribute_name='branch' AND r.operator='=' AND v_br=r.attribute_value THEN v_p:=1;
        ELSIF r.attribute_name='semester' AND r.operator='=' AND v_sm=r.attribute_value THEN v_p:=1;
        ELSIF r.attribute_name='cgpa' THEN
            IF r.operator='>=' AND v_cg>=TO_NUMBER(r.attribute_value) THEN v_p:=1;
            ELSIF r.operator='>' AND v_cg>TO_NUMBER(r.attribute_value) THEN v_p:=1;
            END IF;
        END IF;
        IF v_p=0 THEN RETURN 'NOT ELIGIBLE'; END IF;
    END LOOP;
    RETURN 'ELIGIBLE';
END fn_is_eligible;
/

-- PL/SQL: sp_submit_form
CREATE OR REPLACE PROCEDURE sp_submit_form(
    p_fid IN NUMBER, p_uid IN NUMBER,
    p_flds IN SYS.ODCINUMBERLIST, p_vals IN SYS.ODCIVARCHAR2LIST,
    p_sid OUT NUMBER
) AS
    v_st VARCHAR2(10); v_ed DATE; v_d NUMBER;
    v_br USERS.branch%TYPE; v_cg USERS.cgpa%TYPE; v_sm USERS.semester%TYPE; v_p NUMBER;
BEGIN
    SELECT status,end_date INTO v_st,v_ed FROM FORMS WHERE form_id=p_fid;
    IF v_st!='open' THEN RAISE_APPLICATION_ERROR(-20001,'Form not open.'); END IF;
    IF v_ed<SYSDATE THEN RAISE_APPLICATION_ERROR(-20002,'Deadline passed.'); END IF;
    SELECT COUNT(*) INTO v_d FROM SUBMISSIONS WHERE form_id=p_fid AND user_id=p_uid;
    IF v_d>0 THEN RAISE_APPLICATION_ERROR(-20003,'Already submitted.'); END IF;
    SELECT branch,cgpa,semester INTO v_br,v_cg,v_sm FROM USERS WHERE user_id=p_uid;
    FOR r IN (SELECT * FROM ACCESS_RULES WHERE form_id=p_fid) LOOP
        v_p:=0;
        IF r.attribute_name='branch' THEN IF r.operator='=' AND v_br=r.attribute_value THEN v_p:=1; END IF;
        ELSIF r.attribute_name='semester' THEN IF r.operator='=' AND v_sm=r.attribute_value THEN v_p:=1; END IF;
        ELSIF r.attribute_name='cgpa' THEN
            IF r.operator='>=' AND v_cg>=TO_NUMBER(r.attribute_value) THEN v_p:=1;
            ELSIF r.operator='>' AND v_cg>TO_NUMBER(r.attribute_value) THEN v_p:=1;
            END IF;
        END IF;
        IF v_p=0 THEN RAISE_APPLICATION_ERROR(-20004,'Not eligible.'); END IF;
    END LOOP;
    p_sid := SEQ_SUB.NEXTVAL;
    INSERT INTO SUBMISSIONS VALUES(p_sid,p_fid,p_uid,SYSDATE,'submitted');
    FOR i IN 1..p_flds.COUNT LOOP
        INSERT INTO RESPONSES VALUES(SEQ_RESP.NEXTVAL,p_sid,p_flds(i),p_vals(i));
    END LOOP;
    COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
END sp_submit_form;
/

PROMPT === PL/SQL OK ===

-- Triggers
CREATE OR REPLACE TRIGGER trg_auto_close_form
BEFORE INSERT OR UPDATE ON SUBMISSIONS FOR EACH ROW
DECLARE v_ed DATE; v_st VARCHAR2(10);
BEGIN
    SELECT end_date,status INTO v_ed,v_st FROM FORMS WHERE form_id=:NEW.form_id;
    IF SYSDATE>v_ed THEN UPDATE FORMS SET status='closed' WHERE form_id=:NEW.form_id;
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
            'New form "'||:NEW.title||'" available.',0,SYSDATE);
    END LOOP;
END trg_form_create_notifications;
/

PROMPT === Triggers OK ===

-- Verification
PROMPT ============================================
SELECT 'Users: '||COUNT(*) AS info FROM USERS;
SELECT 'Forms: '||COUNT(*) AS info FROM FORMS;
SELECT 'Fields: '||COUNT(*) AS info FROM FORM_FIELDS;
SELECT 'Rules: '||COUNT(*) AS info FROM ACCESS_RULES;
SELECT 'Submissions: '||COUNT(*) AS info FROM SUBMISSIONS;
SELECT 'Responses: '||COUNT(*) AS info FROM RESPONSES;
SELECT 'Notifications: '||COUNT(*) AS info FROM NOTIFICATIONS;

SELECT username, role, branch, cgpa, semester FROM USERS ORDER BY user_id;
SELECT username, fn_is_eligible(user_id,1) AS hackathon_eligible FROM USERS WHERE role='student';

PROMPT ============================================
PROMPT DONE! Flask app should now connect at dscae/dscae123
PROMPT ============================================
EXIT;
