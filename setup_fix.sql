-- Fix script: grant DBMS_CRYPTO, then re-insert all data
-- Run as: sqlplus "/ as sysdba" @setup_fix.sql

-- Grant DBMS_CRYPTO to dscae
GRANT EXECUTE ON SYS.DBMS_CRYPTO TO dscae;
GRANT EXECUTE ON SYS.UTL_I18N TO dscae;

PROMPT Grants applied.

-- Connect as dscae
CONNECT dscae/dscae123@localhost:1521/XE

-- Clean existing data (in case partial inserts)
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM NOTIFICATIONS';
  EXECUTE IMMEDIATE 'DELETE FROM RESPONSES';
  EXECUTE IMMEDIATE 'DELETE FROM SUBMISSIONS';
  EXECUTE IMMEDIATE 'DELETE FROM ACCESS_RULES';
  EXECUTE IMMEDIATE 'DELETE FROM FORM_FIELDS';
  EXECUTE IMMEDIATE 'DELETE FROM FORMS';
  EXECUTE IMMEDIATE 'DELETE FROM USERS';
  COMMIT;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- Reset sequences
BEGIN
  FOR s IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name IN ('SEQ_USER','SEQ_FORM','SEQ_FIELD',
                                    'SEQ_RULE','SEQ_SUB','SEQ_RESP','SEQ_NOTIF'))
  LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/
CREATE SEQUENCE SEQ_USER  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FORM  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FIELD START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RULE  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_SUB   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RESP  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_NOTIF START WITH 1 INCREMENT BY 1 NOCACHE;

PROMPT Inserting users with SHA-256 passwords...

-- Insert users using DBMS_CRYPTO for SHA-256 (matches Python hashlib.sha256)
DECLARE
  FUNCTION sha256(p_str VARCHAR2) RETURN VARCHAR2 IS
    v_raw RAW(32);
  BEGIN
    v_raw := DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(p_str, 'AL32UTF8'), DBMS_CRYPTO.HASH_SH256);
    RETURN LOWER(RAWTOHEX(v_raw));
  END;
BEGIN
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'admin1',   'admin1@mit.edu',   sha256('Admin@123'),   'MCA', 9.5, 'NA',  'admin',   SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'admin2',   'admin2@mit.edu',   sha256('Admin@123'),   'MCA', 9.2, 'NA',  'admin',   SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'pranav',   'pranav@mit.edu',   sha256('Student@123'), 'MCA', 9.1, '4',   'student', SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'sreejesh', 'sreejesh@mit.edu', sha256('Student@123'), 'MCA', 8.7, '4',   'student', SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'alice',    'alice@mit.edu',    sha256('Student@123'), 'CSE', 8.2, '4',   'student', SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'bob',      'bob@mit.edu',      sha256('Student@123'), 'CSE', 6.5, '4',   'student', SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'carol',    'carol@mit.edu',    sha256('Student@123'), 'ECE', 8.9, '2',   'student', SYSDATE);
  INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'dave',     'dave@mit.edu',     sha256('Student@123'), 'MCA', 7.3, '6',   'student', SYSDATE);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Users inserted: 8');
END;
/

-- Verify users exist
SELECT user_id, username, role FROM USERS ORDER BY user_id;

-- Forms (created_by references user_id 1 and 2)
INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL, 1, 'Hackathon Registration 2026',
  'Register for the annual MIT Hackathon. Open to 4th sem MCA with CGPA > 8.0',
  'open', SYSDATE - 2, SYSDATE + 10);

INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL, 1, 'Mid-Sem Feedback Survey',
  'Anonymous feedback for DBS Lab',
  'open', SYSDATE - 1, SYSDATE + 5);

INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL, 2, 'Placement Eligibility Poll',
  'Check eligibility for campus placements',
  'closed', SYSDATE - 20, SYSDATE - 5);

COMMIT;

-- Verify forms
SELECT form_id, title, status FROM FORMS ORDER BY form_id;

-- Form Fields
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'Team Name',        'TEXT',    1, '^[A-Za-z0-9 ]{3,30}$', 1);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'Project Idea',     'TEXT',    1, NULL,                    2);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'Has Laptop',       'BOOLEAN', 1, NULL,                    3);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'T-Shirt Size',     'TEXT',    0, NULL,                    4);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 2, 'Overall Rating',   'NUMERIC', 1, '1-5',  1);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 2, 'Comments',         'TEXT',    0, NULL,   2);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 2, 'Recommend Course', 'BOOLEAN', 1, NULL,   3);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 3, 'Are You Interested', 'BOOLEAN', 1, NULL, 1);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 3, 'Preferred Domain',   'TEXT',    1, NULL, 2);

-- Access Rules
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'branch',   '=',  'MCA');
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'semester', '=',  '4');
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'cgpa',     '>=', '8.0');
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 2, 'semester', '=', '4');
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 3, 'cgpa', '>=', '6.0');

-- Submissions (pranav=3, sreejesh=4, alice=5)
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 1, 3, SYSDATE - 1, 'submitted');
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 1, 4, SYSDATE - 1, 'submitted');
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 2, 3, SYSDATE,     'submitted');
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 2, 5, SYSDATE,     'submitted');

-- Responses
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 1, 'Team Nexus');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 2, 'AI-powered attendance system');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 3, 'YES');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 4, 'L');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 1, 'Team Nexus');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 2, 'AI-powered attendance system');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 3, 'YES');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 4, 'M');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 3, 5, '5');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 3, 6, 'Great lab sessions!');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 3, 7, 'YES');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 4, 5, '4');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 4, 6, 'More practice problems needed');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 4, 7, 'YES');

-- Notifications
INSERT INTO NOTIFICATIONS VALUES (SEQ_NOTIF.NEXTVAL, 3, 1, 'Hackathon Registration is now open for you!', 1, SYSDATE - 2);
INSERT INTO NOTIFICATIONS VALUES (SEQ_NOTIF.NEXTVAL, 4, 1, 'Hackathon Registration is now open for you!', 1, SYSDATE - 2);
INSERT INTO NOTIFICATIONS VALUES (SEQ_NOTIF.NEXTVAL, 6, 1, 'Reminder: Hackathon deadline in 2 days.', 0, SYSDATE + 8);

COMMIT;

PROMPT ============================================
PROMPT Final verification:
PROMPT ============================================
SELECT 'Users: ' || COUNT(*) AS info FROM USERS;
SELECT 'Forms: ' || COUNT(*) AS info FROM FORMS;
SELECT 'Fields: ' || COUNT(*) AS info FROM FORM_FIELDS;
SELECT 'Rules: ' || COUNT(*) AS info FROM ACCESS_RULES;
SELECT 'Submissions: ' || COUNT(*) AS info FROM SUBMISSIONS;
SELECT 'Responses: ' || COUNT(*) AS info FROM RESPONSES;

-- Test eligibility function
SELECT username, fn_is_eligible(user_id, 1) AS hackathon_eligible
FROM USERS WHERE role='student';

PROMPT ============================================
PROMPT ALL DONE! Database is fully populated.
PROMPT ============================================
EXIT;
