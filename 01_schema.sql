-- ============================================================
-- D-SCAE: Dynamic Schema Data Collection & Analytics Engine
-- File: 01_schema.sql  |  Oracle SQL*Plus
-- Run as: @01_schema.sql
-- ============================================================

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

-- ============================================================
-- SEQUENCES
-- ============================================================
CREATE SEQUENCE SEQ_USER  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FORM  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FIELD START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RULE  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_SUB   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RESP  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_NOTIF START WITH 1 INCREMENT BY 1 NOCACHE;

-- ============================================================
-- TABLE: USERS
-- ============================================================
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

-- ============================================================
-- TABLE: FORMS
-- ============================================================
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

-- ============================================================
-- TABLE: FORM_FIELDS  (EAV meta-layer)
-- ============================================================
CREATE TABLE FORM_FIELDS (
    field_id        NUMBER          PRIMARY KEY,
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id) ON DELETE CASCADE,
    field_name      VARCHAR2(100)   NOT NULL,
    field_type      VARCHAR2(20)    NOT NULL
                    CHECK (field_type IN ('TEXT','NUMERIC','BOOLEAN','DATE')),
    is_required     NUMBER(1)       DEFAULT 1 CHECK (is_required IN (0,1)),
    validation_rule VARCHAR2(500),   -- Regex / range e.g. "0-10" or "^[A-Z].*"
    display_order   NUMBER          DEFAULT 1,
    CONSTRAINT uq_field UNIQUE (form_id, field_name)
);

-- ============================================================
-- TABLE: ACCESS_RULES  (RBAC predicate engine)
-- ============================================================
CREATE TABLE ACCESS_RULES (
    rule_id         NUMBER          PRIMARY KEY,
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id) ON DELETE CASCADE,
    attribute_name  VARCHAR2(50)    NOT NULL  -- e.g. 'branch', 'cgpa', 'semester'
                    CHECK (attribute_name IN ('branch','cgpa','semester','role')),
    operator        VARCHAR2(10)    NOT NULL
                    CHECK (operator IN ('=','!=','>','<','>=','<=')),
    attribute_value VARCHAR2(100)   NOT NULL
);

-- ============================================================
-- TABLE: SUBMISSIONS
-- ============================================================
CREATE TABLE SUBMISSIONS (
    submission_id   NUMBER          PRIMARY KEY,
    form_id         NUMBER          NOT NULL REFERENCES FORMS(form_id),
    user_id         NUMBER          NOT NULL REFERENCES USERS(user_id),
    submitted_at    DATE            DEFAULT SYSDATE,
    status          VARCHAR2(10)    DEFAULT 'submitted'
                    CHECK (status IN ('submitted','withdrawn')),
    CONSTRAINT uq_submission UNIQUE (form_id, user_id)  -- one submission per user per form
);

-- ============================================================
-- TABLE: RESPONSES  (EAV value store)
-- ============================================================
CREATE TABLE RESPONSES (
    response_id     NUMBER          PRIMARY KEY,
    submission_id   NUMBER          NOT NULL REFERENCES SUBMISSIONS(submission_id) ON DELETE CASCADE,
    field_id        NUMBER          NOT NULL REFERENCES FORM_FIELDS(field_id),
    response_value  CLOB,
    CONSTRAINT uq_response UNIQUE (submission_id, field_id)
);

-- ============================================================
-- TABLE: NOTIFICATIONS
-- ============================================================
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
