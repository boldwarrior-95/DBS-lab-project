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

CREATE OR REPLACE TRIGGER trg_form_create_notifications
AFTER INSERT ON FORMS
FOR EACH ROW
DECLARE
    CURSOR student_users IS
        SELECT u.user_id FROM USERS u WHERE u.role = 'student';
BEGIN
    FOR u IN student_users LOOP
        INSERT INTO NOTIFICATIONS (notif_id, user_id, form_id, message, is_sent, scheduled_at)
        VALUES (SEQ_NOTIF.NEXTVAL, u.user_id, :NEW.form_id,
                'A new form "' || :NEW.title || '" is available. Deadline: ' ||
                TO_CHAR(:NEW.end_date, 'DD-MON-YYYY'),
                0, SYSDATE);
    END LOOP;
END trg_form_create_notifications;
/
