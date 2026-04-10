-- ============================================================
-- D-SCAE: Sample Data
-- File: 02_sample_data.sql  |  Oracle SQL*Plus
-- Run as: @02_sample_data.sql
-- ============================================================

-- USERS (2 admins, 6 students)
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'admin1',   'admin1@mit.edu',   'hashed_pw_1', 'MCA', 9.5, 'NA',  'admin',   SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'admin2',   'admin2@mit.edu',   'hashed_pw_2', 'MCA', 9.2, 'NA',  'admin',   SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'pranav',   'pranav@mit.edu',   'hashed_pw_3', 'MCA', 9.1, '4',   'student', SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'sreejesh',  'sreejesh@mit.edu', 'hashed_pw_4', 'MCA', 8.7, '4',   'student', SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'alice',    'alice@mit.edu',    'hashed_pw_5', 'CSE', 8.2, '4',   'student', SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'bob',      'bob@mit.edu',      'hashed_pw_6', 'CSE', 6.5, '4',   'student', SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'carol',    'carol@mit.edu',    'hashed_pw_7', 'ECE', 8.9, '2',   'student', SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'dave',     'dave@mit.edu',     'hashed_pw_8', 'MCA', 7.3, '6',   'student', SYSDATE);

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

-- ACCESS_RULES for Form 1 (MCA students, sem=4, cgpa>8)
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'branch',   '=',  'MCA');
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'semester', '=',  '4');
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'cgpa',     '>=', '8.0');

-- ACCESS_RULES for Form 2 (all 4th sem students)
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 2, 'semester', '=', '4');

-- ACCESS_RULES for Form 3 (CGPA >= 6.0)
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 3, 'cgpa', '>=', '6.0');

-- SUBMISSIONS (pranav & sreejesh submit to hackathon; alice submits to feedback)
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
