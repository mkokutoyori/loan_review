SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    PROCEDURE print_sub(p_title VARCHAR2) IS BEGIN
        DBMS_OUTPUT.PUT_LINE(''); DBMS_OUTPUT.PUT_LINE('--- ' || p_title || ' ---');
    END;
    PROCEDURE print_line(p_text VARCHAR2) IS BEGIN
        DBMS_OUTPUT.PUT_LINE('  ' || p_text);
    END;
BEGIN
    print_sub('C1. Balises CL candidates loss-pool / provision / suspense (dedoublonne)');
    FOR r IN (
        SELECT amount_tag,
               MIN(description)      AS description,
               MIN(amount_tag_type)  AS amount_tag_type,
               MIN(unrealised)       AS unrealised
        FROM   cstb_amount_tag
        WHERE  module = 'CL'
          AND (UPPER(description) LIKE '%LOSS%'
               OR UPPER(description) LIKE '%PROVIS%'
               OR UPPER(description) LIKE '%WRITE%OFF%'
               OR UPPER(description) LIKE '%SUSPEND%'
               OR UPPER(description) LIKE '%SUSP%'
               OR UPPER(description) LIKE '%POOL%'
               OR UPPER(description) LIKE '%IMPAIR%'
               OR UPPER(description) LIKE '%NPL%'
               OR UPPER(amount_tag)  LIKE '%LOSS%'
               OR UPPER(amount_tag)  LIKE '%PROV%'
               OR UPPER(amount_tag)  LIKE '%WROFF%'
               OR UPPER(amount_tag)  LIKE '%SUSP%'
               OR UPPER(amount_tag)  LIKE '%POOL%')
        GROUP  BY amount_tag
        ORDER  BY amount_tag
    ) LOOP
        print_line(RPAD(r.amount_tag,22) ||
                   RPAD(SUBSTR(NVL(r.description,'-'),1,55),57) ||
                   RPAD('t='||NVL(r.amount_tag_type,'-'),6) ||
                   'unr='||NVL(r.unrealised,'-'));
    END LOOP;
END;
/

DECLARE
    PROCEDURE print_sub(p_title VARCHAR2) IS BEGIN
        DBMS_OUTPUT.PUT_LINE(''); DBMS_OUTPUT.PUT_LINE('--- ' || p_title || ' ---');
    END;
    PROCEDURE print_line(p_text VARCHAR2) IS BEGIN
        DBMS_OUTPUT.PUT_LINE('  ' || p_text);
    END;
BEGIN
    print_sub('C2. GLs mouvementes par module CL avec leur description (top 80 par volume)');
    FOR r IN (
        SELECT * FROM (
            SELECT h.ac_no, h.ac_branch, s.ac_gl_desc, s.ac_class, s.ac_natural_gl,
                   COUNT(*) AS nb_entries,
                   SUM(CASE WHEN h.drcr_ind='D' THEN h.lcy_amount ELSE 0 END) AS sum_dr,
                   SUM(CASE WHEN h.drcr_ind='C' THEN h.lcy_amount ELSE 0 END) AS sum_cr
            FROM   actb_history h
            LEFT   JOIN sttb_account s ON s.ac_gl_no = h.ac_no AND s.branch_code = h.ac_branch
            WHERE  h.module = 'CL'
              AND  s.ac_or_gl = 'G'
            GROUP  BY h.ac_no, h.ac_branch, s.ac_gl_desc, s.ac_class, s.ac_natural_gl
            ORDER  BY COUNT(*) DESC
        ) WHERE ROWNUM <= 80
    ) LOOP
        print_line(RPAD(r.ac_no,16) ||
                   RPAD('br='||r.ac_branch,7) ||
                   RPAD(SUBSTR(NVL(r.ac_gl_desc,'-'),1,50),52) ||
                   RPAD('cl='||NVL(r.ac_class,'-'),10) ||
                   RPAD('nat='||NVL(r.ac_natural_gl,'-'),14) ||
                   'nb=' || RPAD(TO_CHAR(r.nb_entries),8) ||
                   'CR=' || RPAD(TO_CHAR(NVL(r.sum_cr,0),'FM999999999990.00'),20) ||
                   'DR=' || TO_CHAR(NVL(r.sum_dr,0),'FM999999999990.00'));
    END LOOP;
END;
/

DECLARE
    PROCEDURE print_sub(p_title VARCHAR2) IS BEGIN
        DBMS_OUTPUT.PUT_LINE(''); DBMS_OUTPUT.PUT_LINE('--- ' || p_title || ' ---');
    END;
    PROCEDURE print_line(p_text VARCHAR2) IS BEGIN
        DBMS_OUTPUT.PUT_LINE('  ' || p_text);
    END;
BEGIN
    print_sub('C3. Combinaisons amount_tag x GL pour les tags suspect-loss (top 100)');
    FOR r IN (
        SELECT * FROM (
            SELECT h.amount_tag, h.event, h.ac_no, s.ac_gl_desc, s.ac_class,
                   h.drcr_ind,
                   COUNT(*) AS nb,
                   SUM(h.lcy_amount) AS sum_lcy
            FROM   actb_history h
            LEFT   JOIN sttb_account s ON s.ac_gl_no = h.ac_no AND s.branch_code = h.ac_branch
            WHERE  h.module = 'CL'
              AND (UPPER(h.amount_tag) LIKE '%LOSS%'
                   OR UPPER(h.amount_tag) LIKE '%PROV%'
                   OR UPPER(h.amount_tag) LIKE '%POOL%'
                   OR UPPER(h.amount_tag) LIKE '%SUSP%'
                   OR UPPER(h.amount_tag) LIKE '%WROFF%'
                   OR UPPER(h.amount_tag) LIKE '%IMPAIR%')
            GROUP  BY h.amount_tag, h.event, h.ac_no, s.ac_gl_desc, s.ac_class, h.drcr_ind
            ORDER  BY COUNT(*) DESC
        ) WHERE ROWNUM <= 100
    ) LOOP
        print_line(RPAD('tag='||r.amount_tag,22) ||
                   RPAD('ev='||r.event,12) ||
                   RPAD('ac='||r.ac_no,16) ||
                   RPAD(SUBSTR(NVL(r.ac_gl_desc,'-'),1,40),42) ||
                   RPAD('cl='||NVL(r.ac_class,'-'),10) ||
                   RPAD('dc='||r.drcr_ind,6) ||
                   'nb=' || RPAD(TO_CHAR(r.nb),8) ||
                   'lcy=' || TO_CHAR(NVL(r.sum_lcy,0),'FM999999999990.00'));
    END LOOP;
END;
/

DECLARE
    PROCEDURE print_sub(p_title VARCHAR2) IS BEGIN
        DBMS_OUTPUT.PUT_LINE(''); DBMS_OUTPUT.PUT_LINE('--- ' || p_title || ' ---');
    END;
    PROCEDURE print_line(p_text VARCHAR2) IS BEGIN
        DBMS_OUTPUT.PUT_LINE('  ' || p_text);
    END;
BEGIN
    print_sub('C4. Echantillons par user_defined_status (1 contrat par valeur, max 20)');
    FOR r IN (
        SELECT * FROM (
            SELECT user_defined_status, account_number, product_code,
                   amount_financed, amount_disbursed, currency, value_date,
                   ROW_NUMBER() OVER (PARTITION BY user_defined_status ORDER BY book_date DESC) AS rn
            FROM   cltb_account_apps_master
            WHERE  auth_stat = 'A'
        ) WHERE rn = 1 AND ROWNUM <= 20
    ) LOOP
        print_line(RPAD('uds='||NVL(r.user_defined_status,'<NULL>'),18) ||
                   RPAD('ac='||r.account_number,18) ||
                   RPAD('prod='||r.product_code,12) ||
                   RPAD('ccy='||r.currency,8) ||
                   RPAD('fin='||TO_CHAR(NVL(r.amount_financed,0),'FM999999999990.00'),20) ||
                   'vd='||TO_CHAR(r.value_date,'YYYY-MM-DD'));
    END LOOP;
END;
/

DECLARE
    PROCEDURE print_sub(p_title VARCHAR2) IS BEGIN
        DBMS_OUTPUT.PUT_LINE(''); DBMS_OUTPUT.PUT_LINE('--- ' || p_title || ' ---');
    END;
    PROCEDURE print_line(p_text VARCHAR2) IS BEGIN
        DBMS_OUTPUT.PUT_LINE('  ' || p_text);
    END;
BEGIN
    print_sub('C5. Encours et impayes par user_defined_status (couplage master x schedules)');
    FOR r IN (
        SELECT m.user_defined_status,
               COUNT(DISTINCT m.account_number) AS nb_loans,
               SUM(m.amount_disbursed)          AS sum_disbursed,
               SUM(NVL(s.amount_due,0) - NVL(s.amount_settled,0)) AS outstanding_principal_int,
               SUM(NVL(s.amount_overdue,0))     AS sum_overdue,
               SUM(NVL(s.susp_amt_due,0))       AS sum_susp_due
        FROM   cltb_account_apps_master m
        LEFT   JOIN cltb_account_schedules s ON s.account_number = m.account_number
        WHERE  m.auth_stat = 'A'
        GROUP  BY m.user_defined_status
        ORDER  BY SUM(m.amount_disbursed) DESC NULLS LAST
    ) LOOP
        print_line(RPAD('uds='||NVL(r.user_defined_status,'<NULL>'),18) ||
                   'nb=' || RPAD(TO_CHAR(r.nb_loans),8) ||
                   'dsb=' || RPAD(TO_CHAR(NVL(r.sum_disbursed,0),'FM999999999990.00'),20) ||
                   'outst=' || RPAD(TO_CHAR(NVL(r.outstanding_principal_int,0),'FM999999999990.00'),22) ||
                   'overd=' || RPAD(TO_CHAR(NVL(r.sum_overdue,0),'FM999999999990.00'),22) ||
                   'susp=' || TO_CHAR(NVL(r.sum_susp_due,0),'FM999999999990.00'));
    END LOOP;
END;
/
