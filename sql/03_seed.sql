-- Demo data. Password hashes are bcrypt of the documented credentials
-- (Admin@123 for admins, Student@123 for students). Each row has its own
-- salt so the hashes look different even when the plaintext matches.

INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'admin1',   'admin1@mit.edu',   '$2b$12$Ko.h3iev6hBG1VcTqVmLNeyTVvkS28aLOiZQu40uhW7vcRO9Y6csW', 'ADMIN', 10.0, 'NA', 'admin',   SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'admin2',   'admin2@mit.edu',   '$2b$12$tv9vt4QVNEoW0FzBgzqnqutiEI5427oNawQ/VtvUdtPRWce4XPGIS', 'MCA',   9.2,  'NA', 'admin',   SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'pranav',   'pranav@mit.edu',   '$2b$12$VZIa9DolupXpOd5Kea4mPO0MRfegnZS4qVm39N8efw92gdnQcACka', 'MCA',   9.1,  '4',  'student', SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'sreejesh', 'sreejesh@mit.edu', '$2b$12$Q9E20G0q.iif5jR6bMZ3TeebTqHf/OGD9KLNpWApXOvlbw/SlZj1e', 'MCA',   8.7,  '4',  'student', SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'alice',    'alice@mit.edu',    '$2b$12$4rso3NxLlYIEPN6/SPemPu2nxCr.O1IZnU9N9605eikZTxq.nyweG', 'CSE',   8.2,  '4',  'student', SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'bob',      'bob@mit.edu',      '$2b$12$IzCnrU/5CZpZoTScNX6QMuj2fOHsp4f/mi3wGm6pW.qWfVG/AbVfe', 'CSE',   6.5,  '4',  'student', SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'carol',    'carol@mit.edu',    '$2b$12$pX2aUerYWMXjeZ1r7BaojO/85Hq8kWGqk3x/PxNgH8CTkF6BcWdI2', 'ECE',   8.9,  '2',  'student', SYSDATE);
INSERT INTO USERS VALUES (SEQ_USER.NEXTVAL, 'dave',     'dave@mit.edu',     '$2b$12$hTMVbQDKe3n../8QKnc8zekNaAwX9ViJa5ADjP4ZyYi8t3I2whl5K', 'MCA',   7.3,  '6',  'student', SYSDATE);

INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL, 1, 'Hackathon Registration 2026',
  'Register for the annual MIT Hackathon. Open to 4th sem MCA with CGPA > 8.0',
  'open', SYSDATE - 2, SYSDATE + 10);

INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL, 1, 'Mid-Sem Feedback Survey',
  'Anonymous feedback for DBS Lab',
  'open', SYSDATE - 1, SYSDATE + 5);

INSERT INTO FORMS VALUES (SEQ_FORM.NEXTVAL, 2, 'Placement Eligibility Poll',
  'Check eligibility for campus placements',
  'closed', SYSDATE - 20, SYSDATE - 5);

INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'Team Name',        'TEXT',    1, '^[A-Za-z0-9 ]{3,30}$', 1);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'Project Idea',     'TEXT',    1, NULL,                    2);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'Has Laptop',       'BOOLEAN', 1, NULL,                    3);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 1, 'T-Shirt Size',     'TEXT',    0, NULL,                    4);

INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 2, 'Overall Rating',   'NUMERIC', 1, '1-5',  1);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 2, 'Comments',         'TEXT',    0, NULL,   2);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 2, 'Recommend Course', 'BOOLEAN', 1, NULL,   3);

INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 3, 'Are You Interested', 'BOOLEAN', 1, NULL, 1);
INSERT INTO FORM_FIELDS VALUES (SEQ_FIELD.NEXTVAL, 3, 'Preferred Domain',   'TEXT',    1, NULL, 2);

INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'branch',   '=',  'MCA');
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'semester', '=',  '4');
INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 1, 'cgpa',     '>=', '8.0');

INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 2, 'semester', '=', '4');

INSERT INTO ACCESS_RULES VALUES (SEQ_RULE.NEXTVAL, 3, 'cgpa', '>=', '6.0');

INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 1, 3, SYSDATE - 1, 'submitted');
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 1, 4, SYSDATE - 1, 'submitted');
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 2, 3, SYSDATE,     'submitted');
INSERT INTO SUBMISSIONS VALUES (SEQ_SUB.NEXTVAL, 2, 5, SYSDATE,     'submitted');

INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 1, 'Team Nexus');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 2, 'AI-powered attendance system');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 3, 'YES');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 1, 4, 'L');

INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 1, 'Code Crusaders');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 2, 'Blockchain-based voting platform');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 3, 'YES');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 2, 4, 'M');

INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 3, 5, '5');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 3, 6, 'Great lab sessions!');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 3, 7, 'YES');

INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 4, 5, '4');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 4, 6, 'More practice problems needed');
INSERT INTO RESPONSES VALUES (SEQ_RESP.NEXTVAL, 4, 7, 'YES');

COMMIT;
