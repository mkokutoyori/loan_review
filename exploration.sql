SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    v_count   NUMBER;
    v_sep     VARCHAR2(120) := RPAD('=', 120, '=');
    v_min_dt  DATE;
    v_max_dt  DATE;
    v_min_vdt DATE;
    v_max_vdt DATE;

    PROCEDURE print_section(p_title VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(v_sep);
        DBMS_OUTPUT.PUT_LINE('>>> ' || p_title);
        DBMS_OUTPUT.PUT_LINE(v_sep);
    END;

    PROCEDURE print_sub(p_title VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('--- ' || p_title || ' ---');
    END;

    PROCEDURE print_kv(p_label VARCHAR2, p_value VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(p_label, 45, '.') || ' ' || NVL(p_value, 'NULL / NON RENSEIGNE'));
    END;

    PROCEDURE print_line(p_text VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('  ' || p_text);
    END;

BEGIN

    print_section('1. VOLUMETRIE GENERALE ET PERIMETRE MODULE CL');

    print_sub('1.1 Comptage des tables cles');
    FOR t IN (
        SELECT table_name FROM (
            SELECT 'CLTM_PRODUCT'             AS table_name, 1 AS ord FROM DUAL UNION ALL
            SELECT 'CLTB_ACCOUNT_APPS_MASTER',           2 FROM DUAL UNION ALL
            SELECT 'CLTB_ACCOUNT_SCHEDULES',             3 FROM DUAL UNION ALL
            SELECT 'CSTB_AMOUNT_TAG',                    4 FROM DUAL UNION ALL
            SELECT 'STTB_ACCOUNT',                       5 FROM DUAL UNION ALL
            SELECT 'ACTB_HISTORY',                       6 FROM DUAL
        ) ORDER BY ord
    ) LOOP
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || t.table_name INTO v_count;
        print_kv(t.table_name, TO_CHAR(v_count) || ' lignes');
    END LOOP;

    SELECT COUNT(*) INTO v_count FROM actb_history WHERE module = 'CL';
    print_kv('ACTB_HISTORY (module=CL)', TO_CHAR(v_count) || ' lignes');

    print_sub('1.2 Repartition des modules dans ACTB_HISTORY');
    FOR r IN (
        SELECT module, COUNT(*) AS nb
        FROM   actb_history
        GROUP  BY module
        ORDER  BY nb DESC
    ) LOOP
        print_kv('Module ' || NVL(r.module,'<NULL>'), TO_CHAR(r.nb) || ' lignes');
    END LOOP;

    print_sub('1.3 Branches actives sur module CL');
    FOR r IN (
        SELECT ac_branch,
               COUNT(*)            AS nb_entries,
               COUNT(DISTINCT ac_no) AS nb_accounts
        FROM   actb_history
        WHERE  module = 'CL'
        GROUP  BY ac_branch
        ORDER  BY nb_entries DESC
    ) LOOP
        print_line(RPAD('BR ' || r.ac_branch, 12) ||
                   ' entries=' || RPAD(TO_CHAR(r.nb_entries), 12) ||
                   ' distinct_ac=' || r.nb_accounts);
    END LOOP;

    print_sub('1.4 Plage de dates ACTB_HISTORY (module CL)');
    SELECT MIN(trn_dt), MAX(trn_dt), MIN(value_dt), MAX(value_dt)
      INTO v_min_dt, v_max_dt, v_min_vdt, v_max_vdt
      FROM actb_history
     WHERE module = 'CL';
    print_kv('Premiere date trn',   TO_CHAR(v_min_dt,'YYYY-MM-DD'));
    print_kv('Derniere date trn',   TO_CHAR(v_max_dt,'YYYY-MM-DD'));
    print_kv('Premiere value_dt',   TO_CHAR(v_min_vdt,'YYYY-MM-DD'));
    print_kv('Derniere value_dt',   TO_CHAR(v_max_vdt,'YYYY-MM-DD'));

END;
/
