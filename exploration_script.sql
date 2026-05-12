-- ============================================================
-- SCRIPT D'EXPLORATION - GESTION DES CREDITS (MODULE CL)
-- Oracle Flexcube Core Banking
--
-- Objectif : Explorer les tables cles de la BD pour comprendre
--   - le role des tables et colonnes cles
--   - les relations entre les tables
--   - la codification des donnees (statuts, tags, produits)
--
-- Usage :
--   SET SERVEROUTPUT ON SIZE UNLIMITED;
--   @exploration_script.sql
-- ============================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE

    v_sep       CONSTANT VARCHAR2(80) := RPAD('=', 80, '=');
    v_sep2      CONSTANT VARCHAR2(80) := RPAD('-', 80, '-');
    v_count     NUMBER;
    v_count2    NUMBER;

    -- --------------------------------------------------------
    -- SECTION 1 : AMOUNT TAGS DU MODULE CL
    -- --------------------------------------------------------
    CURSOR c_amount_tags IS
        SELECT
            AMOUNT_TAG,
            DESCRIPTION,
            AMOUNT_TAG_TYPE,
            NVL(UNREALISED,       'N') AS UNREALISED,
            NVL(TRACK_RECEIVABLE, 'N') AS TRACK_RCV,
            NVL(TRACK_PAYABLE,    'N') AS TRACK_PAY,
            NVL(INTEREST_ALLOWED, 'N') AS INT_ALLWD,
            NVL(CHARGE_ALLOWED,   'N') AS CHG_ALLWD
        FROM cstb_amount_tag
        WHERE MODULE = 'CL'
        ORDER BY AMOUNT_TAG_TYPE NULLS LAST, AMOUNT_TAG;

    -- --------------------------------------------------------
    -- SECTION 2 : PRODUITS DE CREDIT
    -- --------------------------------------------------------
    CURSOR c_products IS
        SELECT
            PRODUCT_CODE,
            PRODUCT_DESC,
            PRODUCT_CATEGORY,
            PRODUCT_TYPE,
            CONTRACT_TYPE,
            LIQUIDATION_MODE,
            MODULE_CODE,
            RECORD_STAT,
            AUTH_STAT,
            ROLLOVER_ALLOWED,
            OPEN_LINE_LOAN
        FROM cltm_product
        ORDER BY PRODUCT_CATEGORY NULLS LAST, PRODUCT_CODE;

    -- --------------------------------------------------------
    -- SECTION 3 : DOSSIERS DE CREDIT - COMPTES DR/CR PROD
    -- --------------------------------------------------------
    CURSOR c_dr_cr_prod IS
        SELECT
            DR_PROD_AC,
            CR_PROD_AC,
            COUNT(*) AS NB_DOSSIERS
        FROM cltb_account_apps_master
        WHERE DR_PROD_AC IS NOT NULL OR CR_PROD_AC IS NOT NULL
        GROUP BY DR_PROD_AC, CR_PROD_AC
        ORDER BY NB_DOSSIERS DESC
        FETCH FIRST 40 ROWS ONLY;

    CURSOR c_sample_loans IS
        SELECT
            ACCOUNT_NUMBER,
            CUSTOMER_ID,
            PRODUCT_CODE,
            BRANCH_CODE,
            CURRENCY,
            TO_CHAR(BOOK_DATE,     'DD-MON-YYYY') AS BOOK_DATE,
            TO_CHAR(MATURITY_DATE, 'DD-MON-YYYY') AS MATURITY_DATE,
            AMOUNT_FINANCED,
            AMOUNT_DISBURSED,
            ACCOUNT_STATUS,
            DERIVED_STATUS,
            DELINQUENCY_STATUS,
            USER_DEFINED_STATUS,
            DR_PROD_AC,
            CR_PROD_AC
        FROM (
            SELECT a.*
            FROM cltb_account_apps_master a
            ORDER BY BOOK_DATE DESC NULLS LAST
        )
        WHERE ROWNUM <= 5;

    -- --------------------------------------------------------
    -- SECTION 4 : TRANSACTIONS CL DANS ACTB_HISTORY
    -- --------------------------------------------------------
    CURSOR c_amount_tags_hist IS
        SELECT
            AMOUNT_TAG,
            COUNT(*)                                                         AS NB_LIGNES,
            SUM(CASE WHEN DRCR_IND='D' THEN LCY_AMOUNT ELSE 0 END)        AS TOTAL_DEBIT,
            SUM(CASE WHEN DRCR_IND='C' THEN LCY_AMOUNT ELSE 0 END)        AS TOTAL_CREDIT
        FROM actb_history
        WHERE MODULE = 'CL'
        GROUP BY AMOUNT_TAG
        ORDER BY NB_LIGNES DESC;

    CURSOR c_events_hist IS
        SELECT
            EVENT,
            COUNT(*) AS NB_LIGNES
        FROM actb_history
        WHERE MODULE = 'CL'
        GROUP BY EVENT
        ORDER BY NB_LIGNES DESC;

    CURSOR c_trncodes_hist IS
        SELECT
            TRN_CODE,
            COUNT(*) AS NB_LIGNES
        FROM actb_history
        WHERE MODULE = 'CL'
        GROUP BY TRN_CODE
        ORDER BY NB_LIGNES DESC;

    CURSOR c_volume_annuel IS
        SELECT
            TO_CHAR(TRN_DT, 'YYYY')           AS ANNEE,
            COUNT(*)                            AS NB_LIGNES,
            SUM(LCY_AMOUNT)                    AS TOTAL_LCY
        FROM actb_history
        WHERE MODULE = 'CL'
        GROUP BY TO_CHAR(TRN_DT, 'YYYY')
        ORDER BY ANNEE;

    CURSOR c_gl_hist IS
        SELECT *
        FROM (
            SELECT
                h.AC_NO,
                s.AC_GL_DESC,
                s.AC_NATURAL_GL,
                s.GL_CATEGORY,
                s.AC_OR_GL,
                COUNT(*)                                                       AS NB_ECRITURES,
                SUM(CASE WHEN h.DRCR_IND='D' THEN h.LCY_AMOUNT ELSE 0 END)  AS TOTAL_DEBIT,
                SUM(CASE WHEN h.DRCR_IND='C' THEN h.LCY_AMOUNT ELSE 0 END)  AS TOTAL_CREDIT
            FROM actb_history h
            LEFT JOIN sttb_account s ON h.AC_NO = s.AC_GL_NO
            WHERE h.MODULE = 'CL'
            GROUP BY h.AC_NO, s.AC_GL_DESC, s.AC_NATURAL_GL, s.GL_CATEGORY, s.AC_OR_GL
            ORDER BY NB_ECRITURES DESC
        )
        WHERE ROWNUM <= 30;

    CURSOR c_sample_hist IS
        SELECT *
        FROM (
            SELECT
                h.TRN_REF_NO,
                h.AC_NO,
                h.DRCR_IND,
                h.AMOUNT_TAG,
                h.LCY_AMOUNT,
                TO_CHAR(h.TRN_DT, 'DD-MON-YYYY') AS TRN_DT,
                h.RELATED_ACCOUNT,
                h.EVENT,
                h.PRODUCT
            FROM actb_history h
            WHERE h.MODULE = 'CL'
            ORDER BY h.TRN_DT DESC, h.EVENT_SR_NO DESC
        )
        WHERE ROWNUM <= 10;

    -- --------------------------------------------------------
    -- SECTION 5 : ECHEANCIERS DE REMBOURSEMENT
    -- --------------------------------------------------------
    CURSOR c_sch_components IS
        SELECT
            COMPONENT_NAME,
            COUNT(*)               AS NB_ECHEANCES,
            SUM(AMOUNT_DUE)        AS TOTAL_DU,
            SUM(AMOUNT_SETTLED)    AS TOTAL_REGLE,
            SUM(AMOUNT_OVERDUE)    AS TOTAL_IMPAYE,
            SUM(WRITEOFF_AMT)      AS TOTAL_PERTE,
            SUM(SUSP_AMT_DUE)     AS TOTAL_SUSPENDU
        FROM cltb_account_schedules
        GROUP BY COMPONENT_NAME
        ORDER BY TOTAL_DU DESC NULLS LAST;

    CURSOR c_sch_status IS
        SELECT
            SCH_STATUS,
            COUNT(*) AS NB_ECHEANCES
        FROM cltb_account_schedules
        GROUP BY SCH_STATUS
        ORDER BY NB_ECHEANCES DESC;

    CURSOR c_sch_type IS
        SELECT
            SCHEDULE_TYPE,
            COUNT(*) AS NB_ECHEANCES
        FROM cltb_account_schedules
        GROUP BY SCHEDULE_TYPE
        ORDER BY NB_ECHEANCES DESC;

    CURSOR c_sch_sample IS
        SELECT
            ACCOUNT_NUMBER,
            COMPONENT_NAME,
            TO_CHAR(SCHEDULE_DUE_DATE, 'DD-MON-YYYY') AS DUE_DATE,
            AMOUNT_DUE,
            AMOUNT_SETTLED,
            AMOUNT_OVERDUE,
            SCH_STATUS,
            WRITEOFF_AMT,
            SUSP_AMT_DUE
        FROM cltb_account_schedules
        WHERE ACCOUNT_NUMBER = (
            SELECT MIN(S2.ACCOUNT_NUMBER)
            FROM cltb_account_schedules S2
        )
        ORDER BY COMPONENT_NAME, SCHEDULE_DUE_DATE;

    -- --------------------------------------------------------
    -- SECTION 6 : COMPTES GL LIES AUX CREDITS (STTB_ACCOUNT)
    -- --------------------------------------------------------
    CURSOR c_dr_prod_sttb IS
        SELECT
            s.AC_GL_NO,
            s.AC_GL_DESC,
            s.AC_NATURAL_GL,
            s.GL_CATEGORY,
            s.AC_OR_GL,
            s.CUST_NO,
            s.BRANCH_CODE,
            COUNT(a.ACCOUNT_NUMBER) AS NB_DOSSIERS
        FROM sttb_account s
        JOIN cltb_account_apps_master a ON a.DR_PROD_AC = s.AC_GL_NO
        GROUP BY s.AC_GL_NO, s.AC_GL_DESC, s.AC_NATURAL_GL,
                 s.GL_CATEGORY, s.AC_OR_GL, s.CUST_NO, s.BRANCH_CODE
        ORDER BY s.AC_NATURAL_GL NULLS LAST, NB_DOSSIERS DESC;

    CURSOR c_cr_prod_sttb IS
        SELECT
            s.AC_GL_NO,
            s.AC_GL_DESC,
            s.AC_NATURAL_GL,
            s.GL_CATEGORY,
            s.AC_OR_GL,
            s.CUST_NO,
            s.BRANCH_CODE,
            COUNT(a.ACCOUNT_NUMBER) AS NB_DOSSIERS
        FROM sttb_account s
        JOIN cltb_account_apps_master a ON a.CR_PROD_AC = s.AC_GL_NO
        GROUP BY s.AC_GL_NO, s.AC_GL_DESC, s.AC_NATURAL_GL,
                 s.GL_CATEGORY, s.AC_OR_GL, s.CUST_NO, s.BRANCH_CODE
        ORDER BY s.AC_NATURAL_GL NULLS LAST, NB_DOSSIERS DESC;

    CURSOR c_natural_gl_dist IS
        SELECT
            s.AC_NATURAL_GL,
            s.AC_OR_GL,
            s.GL_CATEGORY,
            COUNT(DISTINCT s.AC_GL_NO) AS NB_COMPTES
        FROM sttb_account s
        WHERE s.AC_GL_NO IN (
            SELECT DISTINCT DR_PROD_AC FROM cltb_account_apps_master WHERE DR_PROD_AC IS NOT NULL
            UNION
            SELECT DISTINCT CR_PROD_AC FROM cltb_account_apps_master WHERE CR_PROD_AC IS NOT NULL
        )
        GROUP BY s.AC_NATURAL_GL, s.AC_OR_GL, s.GL_CATEGORY
        ORDER BY s.AC_NATURAL_GL NULLS LAST;

    CURSOR c_provision_accounts IS
        SELECT
            AC_GL_NO,
            AC_GL_DESC,
            AC_NATURAL_GL,
            GL_CATEGORY,
            AC_OR_GL,
            CUST_NO,
            BRANCH_CODE
        FROM sttb_account
        WHERE AC_NATURAL_GL LIKE '39%'
           OR AC_NATURAL_GL LIKE '19%'
        ORDER BY AC_NATURAL_GL, AC_GL_NO;

    CURSOR c_cl_gl_classes IS
        SELECT
            s.AC_NATURAL_GL,
            s.AC_OR_GL,
            s.GL_CATEGORY,
            COUNT(DISTINCT h.AC_NO)                                          AS NB_COMPTES,
            COUNT(*)                                                          AS NB_ECRITURES,
            SUM(CASE WHEN h.DRCR_IND='D' THEN h.LCY_AMOUNT ELSE 0 END)     AS TOTAL_DEBIT,
            SUM(CASE WHEN h.DRCR_IND='C' THEN h.LCY_AMOUNT ELSE 0 END)     AS TOTAL_CREDIT
        FROM actb_history h
        LEFT JOIN sttb_account s ON h.AC_NO = s.AC_GL_NO
        WHERE h.MODULE = 'CL'
        GROUP BY s.AC_NATURAL_GL, s.AC_OR_GL, s.GL_CATEGORY
        ORDER BY s.AC_NATURAL_GL NULLS LAST;

    -- --------------------------------------------------------
    -- SECTION 7 : JOINTURE ILLUSTRATIVE (un dossier complet)
    -- --------------------------------------------------------
    CURSOR c_illustrative IS
        SELECT *
        FROM (
            SELECT
                a.ACCOUNT_NUMBER,
                a.CUSTOMER_ID,
                a.PRODUCT_CODE,
                a.AMOUNT_FINANCED,
                a.ACCOUNT_STATUS,
                h.EVENT,
                h.AMOUNT_TAG,
                h.DRCR_IND,
                h.LCY_AMOUNT,
                TO_CHAR(h.TRN_DT, 'DD-MON-YYYY') AS TRN_DT,
                h.AC_NO,
                s.AC_NATURAL_GL,
                SUBSTR(s.AC_GL_DESC, 1, 40)       AS AC_GL_DESC
            FROM cltb_account_apps_master a
            JOIN actb_history h
                ON  h.RELATED_ACCOUNT = a.ACCOUNT_NUMBER
                AND h.MODULE = 'CL'
            LEFT JOIN sttb_account s ON h.AC_NO = s.AC_GL_NO
            WHERE a.ACCOUNT_NUMBER = (
                SELECT MIN(m.ACCOUNT_NUMBER)
                FROM cltb_account_apps_master m
                WHERE m.ACCOUNT_STATUS = 'A'
                  AND EXISTS (
                      SELECT 1 FROM actb_history hh
                      WHERE hh.RELATED_ACCOUNT = m.ACCOUNT_NUMBER
                        AND hh.MODULE = 'CL'
                  )
            )
            ORDER BY h.TRN_DT, h.EVENT_SR_NO
        )
        WHERE ROWNUM <= 50;

BEGIN

    -- ============================================================
    -- SECTION 1 – AMOUNT TAGS DU MODULE CL (cstb_amount_tag)
    -- ============================================================
    DBMS_OUTPUT.PUT_LINE(v_sep);
    DBMS_OUTPUT.PUT_LINE('SECTION 1 - AMOUNT TAGS MODULE CL (cstb_amount_tag)');
    DBMS_OUTPUT.PUT_LINE(v_sep);

    SELECT COUNT(*) INTO v_count FROM cstb_amount_tag WHERE MODULE = 'CL';
    DBMS_OUTPUT.PUT_LINE('Nombre de tags MODULE=CL : ' || v_count);
    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE(
        RPAD('AMOUNT_TAG',       35) ||
        RPAD('TAG_TYPE',         12) ||
        RPAD('UNREALISED',       11) ||
        RPAD('TRACK_RCV',        10) ||
        RPAD('TRACK_PAY',        10) ||
        'DESCRIPTION'
    );
    DBMS_OUTPUT.PUT_LINE(v_sep2);

    FOR r IN c_amount_tags LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(NVL(r.AMOUNT_TAG,       '-'), 35) ||
            RPAD(NVL(r.AMOUNT_TAG_TYPE,  '-'), 12) ||
            RPAD(NVL(r.UNREALISED,       '-'), 11) ||
            RPAD(NVL(r.TRACK_RCV,        '-'), 10) ||
            RPAD(NVL(r.TRACK_PAY,        '-'), 10) ||
            NVL(SUBSTR(r.DESCRIPTION,1,60), '-')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('Repartition par AMOUNT_TAG_TYPE :');
    FOR r IN (
        SELECT AMOUNT_TAG_TYPE, COUNT(*) AS NB
        FROM cstb_amount_tag WHERE MODULE='CL'
        GROUP BY AMOUNT_TAG_TYPE ORDER BY NB DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.AMOUNT_TAG_TYPE,'-'), 20) || ' : ' || r.NB || ' tag(s)');
    END LOOP;

    -- ============================================================
    -- SECTION 2 – PRODUITS DE CREDIT (cltm_product)
    -- ============================================================
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE(v_sep);
    DBMS_OUTPUT.PUT_LINE('SECTION 2 - PRODUITS DE CREDIT (cltm_product)');
    DBMS_OUTPUT.PUT_LINE(v_sep);

    SELECT COUNT(*) INTO v_count FROM cltm_product;
    DBMS_OUTPUT.PUT_LINE('Nombre total de produits : ' || v_count);
    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE(
        RPAD('PRODUCT_CODE', 14) ||
        RPAD('CATEGORY',     22) ||
        RPAD('TYPE',         10) ||
        RPAD('CONTRACT',     12) ||
        RPAD('LIQD_MODE',    12) ||
        RPAD('STAT',          6) ||
        'DESCRIPTION'
    );
    DBMS_OUTPUT.PUT_LINE(v_sep2);

    FOR r IN c_products LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(NVL(r.PRODUCT_CODE,     '-'), 14) ||
            RPAD(NVL(r.PRODUCT_CATEGORY, '-'), 22) ||
            RPAD(NVL(r.PRODUCT_TYPE,     '-'), 10) ||
            RPAD(NVL(r.CONTRACT_TYPE,    '-'), 12) ||
            RPAD(NVL(r.LIQUIDATION_MODE, '-'), 12) ||
            RPAD(NVL(r.RECORD_STAT,      '-'),  6) ||
            NVL(SUBSTR(r.PRODUCT_DESC,1,45), '-')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('Repartition par PRODUCT_CATEGORY :');
    FOR r IN (
        SELECT PRODUCT_CATEGORY,
               COUNT(*) AS NB_TOTAL,
               COUNT(CASE WHEN RECORD_STAT='O' THEN 1 END) AS NB_ACTIFS
        FROM cltm_product
        GROUP BY PRODUCT_CATEGORY ORDER BY NB_TOTAL DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' || RPAD(NVL(r.PRODUCT_CATEGORY,'-'), 25) ||
            '  total=' || r.NB_TOTAL || '  actifs(O)=' || r.NB_ACTIFS
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('Repartition par LIQUIDATION_MODE :');
    FOR r IN (
        SELECT LIQUIDATION_MODE, COUNT(*) AS NB
        FROM cltm_product GROUP BY LIQUIDATION_MODE ORDER BY NB DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.LIQUIDATION_MODE,'-'), 20) || ' : ' || r.NB);
    END LOOP;

    -- ============================================================
    -- SECTION 3 – DOSSIERS DE CREDIT (cltb_account_apps_master)
    -- ============================================================
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE(v_sep);
    DBMS_OUTPUT.PUT_LINE('SECTION 3 - DOSSIERS DE CREDIT (cltb_account_apps_master)');
    DBMS_OUTPUT.PUT_LINE(v_sep);

    SELECT COUNT(*) INTO v_count FROM cltb_account_apps_master;
    DBMS_OUTPUT.PUT_LINE('Nombre total de dossiers : ' || v_count);

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('3a. Repartition par ACCOUNT_STATUS :');
    FOR r IN (
        SELECT ACCOUNT_STATUS, COUNT(*) AS NB
        FROM cltb_account_apps_master
        GROUP BY ACCOUNT_STATUS ORDER BY NB DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.ACCOUNT_STATUS,'-'), 20) || ' : ' || r.NB);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('3b. Repartition par DERIVED_STATUS :');
    FOR r IN (
        SELECT DERIVED_STATUS, COUNT(*) AS NB
        FROM cltb_account_apps_master
        GROUP BY DERIVED_STATUS ORDER BY NB DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.DERIVED_STATUS,'-'), 25) || ' : ' || r.NB);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('3c. Repartition par DELINQUENCY_STATUS :');
    FOR r IN (
        SELECT DELINQUENCY_STATUS, COUNT(*) AS NB
        FROM cltb_account_apps_master
        GROUP BY DELINQUENCY_STATUS ORDER BY NB DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.DELINQUENCY_STATUS,'-'), 25) || ' : ' || r.NB);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('3d. Repartition par USER_DEFINED_STATUS :');
    FOR r IN (
        SELECT USER_DEFINED_STATUS, COUNT(*) AS NB
        FROM cltb_account_apps_master
        GROUP BY USER_DEFINED_STATUS ORDER BY NB DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.USER_DEFINED_STATUS,'-'), 25) || ' : ' || r.NB);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('3e. Volumes par produit (PRODUCT_CODE / CURRENCY) :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' ||
        RPAD('PRODUCT_CODE',  14) ||
        RPAD('CCY', 6)            ||
        RPAD('NB',  8)            ||
        RPAD('TOTAL_FINANCE',       20) ||
        RPAD('TOTAL_DECAISSE',      20) ||
        RPAD('PREMIER',            14) ||
        'DERNIER'
    );
    FOR r IN (
        SELECT
            PRODUCT_CODE,
            CURRENCY,
            COUNT(*)                                    AS NB,
            SUM(AMOUNT_FINANCED)                        AS TOTAL_FIN,
            SUM(AMOUNT_DISBURSED)                       AS TOTAL_DSB,
            TO_CHAR(MIN(BOOK_DATE), 'DD-MON-YYYY')     AS PREMIER,
            TO_CHAR(MAX(BOOK_DATE), 'DD-MON-YYYY')     AS DERNIER
        FROM cltb_account_apps_master
        GROUP BY PRODUCT_CODE, CURRENCY
        ORDER BY TOTAL_FIN DESC NULLS LAST
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.PRODUCT_CODE,'-'), 14) ||
            RPAD(NVL(r.CURRENCY,    '-'),  6) ||
            RPAD(TO_CHAR(r.NB),            8) ||
            RPAD(TO_CHAR(NVL(r.TOTAL_FIN,0), 'FM999,999,999,990'), 20) ||
            RPAD(TO_CHAR(NVL(r.TOTAL_DSB,0), 'FM999,999,999,990'), 20) ||
            RPAD(NVL(r.PREMIER,'-'), 14) ||
            NVL(r.DERNIER,'-')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('3f. Repartition par BRANCH_CODE :');
    FOR r IN (
        SELECT BRANCH_CODE, COUNT(*) AS NB, SUM(AMOUNT_FINANCED) AS TOTAL
        FROM cltb_account_apps_master
        GROUP BY BRANCH_CODE ORDER BY NB DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' || RPAD(NVL(r.BRANCH_CODE,'-'), 8) ||
            '  dossiers=' || RPAD(TO_CHAR(r.NB), 8) ||
            '  financement=' || TO_CHAR(NVL(r.TOTAL,0), 'FM999,999,999,990')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('3g. DR_PROD_AC / CR_PROD_AC les plus utilises (top 40) :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' || RPAD('DR_PROD_AC', 22) || RPAD('CR_PROD_AC', 22) || 'NB_DOSSIERS'
    );
    FOR r IN c_dr_cr_prod LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.DR_PROD_AC,'-'), 22) ||
            RPAD(NVL(r.CR_PROD_AC,'-'), 22) ||
            r.NB_DOSSIERS
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('3h. Echantillon de 5 dossiers recents :');
    FOR r IN c_sample_loans LOOP
        DBMS_OUTPUT.PUT_LINE('  ---');
        DBMS_OUTPUT.PUT_LINE('  ACCOUNT_NUMBER    : ' || NVL(r.ACCOUNT_NUMBER, '-'));
        DBMS_OUTPUT.PUT_LINE('  CUSTOMER_ID       : ' || NVL(r.CUSTOMER_ID, '-'));
        DBMS_OUTPUT.PUT_LINE('  PRODUCT_CODE      : ' || NVL(r.PRODUCT_CODE, '-'));
        DBMS_OUTPUT.PUT_LINE('  BRANCH / CCY      : ' || NVL(r.BRANCH_CODE,'-') || ' / ' || NVL(r.CURRENCY,'-'));
        DBMS_OUTPUT.PUT_LINE('  BOOK_DATE         : ' || NVL(r.BOOK_DATE, '-'));
        DBMS_OUTPUT.PUT_LINE('  MATURITY_DATE     : ' || NVL(r.MATURITY_DATE, '-'));
        DBMS_OUTPUT.PUT_LINE('  AMOUNT_FINANCED   : ' || TO_CHAR(NVL(r.AMOUNT_FINANCED,0), 'FM999,999,999,990'));
        DBMS_OUTPUT.PUT_LINE('  AMOUNT_DISBURSED  : ' || TO_CHAR(NVL(r.AMOUNT_DISBURSED,0), 'FM999,999,999,990'));
        DBMS_OUTPUT.PUT_LINE('  ACCOUNT_STATUS    : ' || NVL(r.ACCOUNT_STATUS, '-'));
        DBMS_OUTPUT.PUT_LINE('  DERIVED_STATUS    : ' || NVL(r.DERIVED_STATUS, '-'));
        DBMS_OUTPUT.PUT_LINE('  DELINQUENCY_STAT  : ' || NVL(r.DELINQUENCY_STATUS, '-'));
        DBMS_OUTPUT.PUT_LINE('  USER_DEF_STATUS   : ' || NVL(r.USER_DEFINED_STATUS, '-'));
        DBMS_OUTPUT.PUT_LINE('  DR_PROD_AC        : ' || NVL(r.DR_PROD_AC, '-'));
        DBMS_OUTPUT.PUT_LINE('  CR_PROD_AC        : ' || NVL(r.CR_PROD_AC, '-'));
    END LOOP;

    -- ============================================================
    -- SECTION 4 – TRANSACTIONS CL (actb_history MODULE='CL')
    -- ============================================================
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE(v_sep);
    DBMS_OUTPUT.PUT_LINE('SECTION 4 - TRANSACTIONS CL (actb_history WHERE MODULE=''CL'')');
    DBMS_OUTPUT.PUT_LINE(v_sep);

    SELECT COUNT(*) INTO v_count FROM actb_history WHERE MODULE = 'CL';
    DBMS_OUTPUT.PUT_LINE('Nombre total de lignes MODULE=CL : ' || v_count);

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('4a. AMOUNT_TAG utilises (avec volumes debit/credit) :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' ||
        RPAD('AMOUNT_TAG',   35) ||
        RPAD('NB_LIGNES',    12) ||
        RPAD('TOTAL_DEBIT',  22) ||
        'TOTAL_CREDIT'
    );
    FOR r IN c_amount_tags_hist LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.AMOUNT_TAG,'-'), 35) ||
            RPAD(TO_CHAR(r.NB_LIGNES), 12) ||
            RPAD(TO_CHAR(NVL(r.TOTAL_DEBIT,0),  'FM999,999,999,990'), 22) ||
            TO_CHAR(NVL(r.TOTAL_CREDIT,0), 'FM999,999,999,990')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('4b. EVENTS utilises dans MODULE=CL :');
    FOR r IN c_events_hist LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.EVENT,'-'), 20) || ' : ' || r.NB_LIGNES);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('4c. TRN_CODE utilises dans MODULE=CL :');
    FOR r IN c_trncodes_hist LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.TRN_CODE,'-'), 15) || ' : ' || r.NB_LIGNES);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('4d. Volume de transactions CL par annee :');
    DBMS_OUTPUT.PUT_LINE('  ' || RPAD('ANNEE',8) || RPAD('NB_LIGNES',14) || 'TOTAL_LCY');
    FOR r IN c_volume_annuel LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.ANNEE,'-'), 8) ||
            RPAD(TO_CHAR(r.NB_LIGNES), 14) ||
            TO_CHAR(NVL(r.TOTAL_LCY,0), 'FM999,999,999,990')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('4e. Comptes GL (AC_NO) portant des ecritures CL (top 30) :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' ||
        RPAD('AC_NO',        22) ||
        RPAD('AC_NATURAL_GL',15) ||
        RPAD('AC_OR_GL',      9) ||
        RPAD('GL_CATEGORY',  13) ||
        RPAD('NB_ECR',       10) ||
        RPAD('TOTAL_DEBIT',  20) ||
        'TOTAL_CREDIT'
    );
    FOR r IN c_gl_hist LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.AC_NO,       '-'), 22) ||
            RPAD(NVL(r.AC_NATURAL_GL,'-'), 15) ||
            RPAD(NVL(r.AC_OR_GL,    '-'),  9) ||
            RPAD(NVL(r.GL_CATEGORY, '-'), 13) ||
            RPAD(TO_CHAR(r.NB_ECRITURES), 10) ||
            RPAD(TO_CHAR(NVL(r.TOTAL_DEBIT, 0), 'FM999,999,999,990'), 20) ||
            TO_CHAR(NVL(r.TOTAL_CREDIT,0), 'FM999,999,999,990')
        );
        DBMS_OUTPUT.PUT_LINE('     => ' || NVL(SUBSTR(r.AC_GL_DESC,1,60),'-'));
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('4f. Echantillon de 10 transactions CL recentes :');
    FOR r IN c_sample_hist LOOP
        DBMS_OUTPUT.PUT_LINE('  ' ||
            RPAD(NVL(r.TRN_DT,'-'),         14) ||
            RPAD(NVL(r.EVENT,'-'),           15) ||
            RPAD(NVL(r.DRCR_IND,'-'),        4) ||
            RPAD(NVL(r.AMOUNT_TAG,'-'),      30) ||
            RPAD(TO_CHAR(NVL(r.LCY_AMOUNT,0),'FM999,999,999,990'), 22) ||
            RPAD(NVL(r.AC_NO,'-'),           22) ||
            NVL(r.RELATED_ACCOUNT,'-')
        );
    END LOOP;

    -- ============================================================
    -- SECTION 5 – ECHEANCIERS (cltb_account_schedules)
    -- ============================================================
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE(v_sep);
    DBMS_OUTPUT.PUT_LINE('SECTION 5 - ECHEANCIERS DE REMBOURSEMENT (cltb_account_schedules)');
    DBMS_OUTPUT.PUT_LINE(v_sep);

    SELECT COUNT(*) INTO v_count FROM cltb_account_schedules;
    DBMS_OUTPUT.PUT_LINE('Nombre total de lignes : ' || v_count);

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('5a. Composants (COMPONENT_NAME) avec montants cumules :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' ||
        RPAD('COMPONENT_NAME',  28) ||
        RPAD('NB_ECH',           9) ||
        RPAD('TOTAL_DU',        22) ||
        RPAD('TOTAL_REGLE',     22) ||
        RPAD('TOTAL_IMPAYE',    22) ||
        RPAD('TOTAL_PERTE',     22) ||
        'TOTAL_SUSPENDU'
    );
    FOR r IN c_sch_components LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.COMPONENT_NAME,'-'), 28) ||
            RPAD(TO_CHAR(r.NB_ECHEANCES),    9) ||
            RPAD(TO_CHAR(NVL(r.TOTAL_DU,       0),'FM999,999,999,990'), 22) ||
            RPAD(TO_CHAR(NVL(r.TOTAL_REGLE,    0),'FM999,999,999,990'), 22) ||
            RPAD(TO_CHAR(NVL(r.TOTAL_IMPAYE,   0),'FM999,999,999,990'), 22) ||
            RPAD(TO_CHAR(NVL(r.TOTAL_PERTE,    0),'FM999,999,999,990'), 22) ||
            TO_CHAR(NVL(r.TOTAL_SUSPENDU, 0),'FM999,999,999,990')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('5b. Types d''echeance (SCHEDULE_TYPE) :');
    FOR r IN c_sch_type LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.SCHEDULE_TYPE,'-'), 20) || ' : ' || r.NB_ECHEANCES);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('5c. Statuts des echeances (SCH_STATUS) :');
    FOR r IN c_sch_status LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.SCH_STATUS,'-'), 15) || ' : ' || r.NB_ECHEANCES);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('5d. Echantillon : echeancier complet du premier dossier trouve :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' ||
        RPAD('ACCOUNT_NUMBER', 22) ||
        RPAD('COMPONENT_NAME', 25) ||
        RPAD('DUE_DATE',       15) ||
        RPAD('AMOUNT_DUE',     18) ||
        RPAD('AMOUNT_SETTLED', 18) ||
        RPAD('OVERDUE',        18) ||
        RPAD('STATUS',         10) ||
        RPAD('WRITEOFF',       18) ||
        'SUSP_AMT_DUE'
    );
    FOR r IN c_sch_sample LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.ACCOUNT_NUMBER,  '-'), 22) ||
            RPAD(NVL(r.COMPONENT_NAME,  '-'), 25) ||
            RPAD(NVL(r.DUE_DATE,        '-'), 15) ||
            RPAD(TO_CHAR(NVL(r.AMOUNT_DUE,     0),'FM999,999,999,990'), 18) ||
            RPAD(TO_CHAR(NVL(r.AMOUNT_SETTLED, 0),'FM999,999,999,990'), 18) ||
            RPAD(TO_CHAR(NVL(r.AMOUNT_OVERDUE, 0),'FM999,999,999,990'), 18) ||
            RPAD(NVL(r.SCH_STATUS,'-'), 10) ||
            RPAD(TO_CHAR(NVL(r.WRITEOFF_AMT,   0),'FM999,999,999,990'), 18) ||
            TO_CHAR(NVL(r.SUSP_AMT_DUE,0),'FM999,999,999,990')
        );
    END LOOP;

    -- ============================================================
    -- SECTION 6 – COMPTES GL LIES AUX CREDITS (sttb_account)
    -- ============================================================
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE(v_sep);
    DBMS_OUTPUT.PUT_LINE('SECTION 6 - COMPTES GL LIES AUX CREDITS (sttb_account)');
    DBMS_OUTPUT.PUT_LINE(v_sep);

    DBMS_OUTPUT.PUT_LINE('6a. Comptes DR_PROD_AC (compte debit du credit) :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' ||
        RPAD('AC_GL_NO',        25) ||
        RPAD('AC_NATURAL_GL',   15) ||
        RPAD('AC_OR_GL',         9) ||
        RPAD('GL_CATEGORY',     13) ||
        RPAD('BRANCH',           8) ||
        RPAD('NB_DOSSIERS',     12) ||
        'AC_GL_DESC'
    );
    FOR r IN c_dr_prod_sttb LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.AC_GL_NO,       '-'), 25) ||
            RPAD(NVL(r.AC_NATURAL_GL,  '-'), 15) ||
            RPAD(NVL(r.AC_OR_GL,       '-'),  9) ||
            RPAD(NVL(r.GL_CATEGORY,    '-'), 13) ||
            RPAD(NVL(r.BRANCH_CODE,    '-'),  8) ||
            RPAD(TO_CHAR(r.NB_DOSSIERS),     12) ||
            NVL(SUBSTR(r.AC_GL_DESC,1,50),'-')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('6b. Comptes CR_PROD_AC (compte credit du credit) :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' ||
        RPAD('AC_GL_NO',        25) ||
        RPAD('AC_NATURAL_GL',   15) ||
        RPAD('AC_OR_GL',         9) ||
        RPAD('GL_CATEGORY',     13) ||
        RPAD('BRANCH',           8) ||
        RPAD('NB_DOSSIERS',     12) ||
        'AC_GL_DESC'
    );
    FOR r IN c_cr_prod_sttb LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.AC_GL_NO,       '-'), 25) ||
            RPAD(NVL(r.AC_NATURAL_GL,  '-'), 15) ||
            RPAD(NVL(r.AC_OR_GL,       '-'),  9) ||
            RPAD(NVL(r.GL_CATEGORY,    '-'), 13) ||
            RPAD(NVL(r.BRANCH_CODE,    '-'),  8) ||
            RPAD(TO_CHAR(r.NB_DOSSIERS),     12) ||
            NVL(SUBSTR(r.AC_GL_DESC,1,50),'-')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('6c. Classes comptables (AC_NATURAL_GL) des comptes lies aux credits :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' ||
        RPAD('AC_NATURAL_GL', 15) ||
        RPAD('AC_OR_GL',       9) ||
        RPAD('GL_CATEGORY',   13) ||
        'NB_COMPTES'
    );
    FOR r IN c_natural_gl_dist LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.AC_NATURAL_GL,'-'), 15) ||
            RPAD(NVL(r.AC_OR_GL,     '-'),  9) ||
            RPAD(NVL(r.GL_CATEGORY,  '-'), 13) ||
            r.NB_COMPTES
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('6d. Comptes de provisions candidats loan loss pool (classe 39% / 19%) :');
    FOR r IN c_provision_accounts LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.AC_GL_NO,       '-'), 25) ||
            RPAD(NVL(r.AC_NATURAL_GL,  '-'), 15) ||
            RPAD(NVL(r.AC_OR_GL,       '-'),  9) ||
            RPAD(NVL(r.GL_CATEGORY,    '-'), 13) ||
            RPAD(NVL(r.BRANCH_CODE,    '-'),  8) ||
            NVL(SUBSTR(r.AC_GL_DESC,1,50),'-')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('6e. Classes comptables actives dans actb_history MODULE=CL :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' ||
        RPAD('AC_NATURAL_GL', 15) ||
        RPAD('AC_OR_GL',       9) ||
        RPAD('GL_CATEGORY',   13) ||
        RPAD('NB_COMPTES',    12) ||
        RPAD('NB_ECRITURES',  14) ||
        RPAD('TOTAL_DEBIT',   22) ||
        'TOTAL_CREDIT'
    );
    FOR r IN c_cl_gl_classes LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.AC_NATURAL_GL,'-'), 15) ||
            RPAD(NVL(r.AC_OR_GL,     '-'),  9) ||
            RPAD(NVL(r.GL_CATEGORY,  '-'), 13) ||
            RPAD(TO_CHAR(r.NB_COMPTES),    12) ||
            RPAD(TO_CHAR(r.NB_ECRITURES),  14) ||
            RPAD(TO_CHAR(NVL(r.TOTAL_DEBIT, 0),'FM999,999,999,990'), 22) ||
            TO_CHAR(NVL(r.TOTAL_CREDIT,0),'FM999,999,999,990')
        );
    END LOOP;

    -- ============================================================
    -- SECTION 7 – MAPPING DES RELATIONS INTER-TABLES
    -- ============================================================
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE(v_sep);
    DBMS_OUTPUT.PUT_LINE('SECTION 7 - MAPPING DES RELATIONS INTER-TABLES');
    DBMS_OUTPUT.PUT_LINE(v_sep);

    -- 7a. actb_history.RELATED_ACCOUNT <-> cltb_account_apps_master.ACCOUNT_NUMBER
    DBMS_OUTPUT.PUT_LINE('7a. actb_history.RELATED_ACCOUNT <-> cltb_account_apps_master.ACCOUNT_NUMBER');
    SELECT COUNT(DISTINCT RELATED_ACCOUNT) INTO v_count
    FROM actb_history WHERE MODULE='CL' AND RELATED_ACCOUNT IS NOT NULL;

    SELECT COUNT(DISTINCT ACCOUNT_NUMBER) INTO v_count2
    FROM cltb_account_apps_master;

    DBMS_OUTPUT.PUT_LINE(
        '  RELATED_ACCOUNT distincts (module CL) : ' || v_count
    );
    DBMS_OUTPUT.PUT_LINE(
        '  ACCOUNT_NUMBER distincts (master)      : ' || v_count2
    );

    FOR r IN (
        SELECT COUNT(DISTINCT h.RELATED_ACCOUNT) AS MATCHED
        FROM (
            SELECT DISTINCT RELATED_ACCOUNT FROM actb_history
            WHERE MODULE='CL' AND RELATED_ACCOUNT IS NOT NULL
        ) h
        JOIN cltb_account_apps_master a ON h.RELATED_ACCOUNT = a.ACCOUNT_NUMBER
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  MATCHED (jointure reussie)             : ' || r.MATCHED);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('7b. cltb_account_apps_master <-> cltb_account_schedules (ACCOUNT_NUMBER) :');
    FOR r IN (
        SELECT
            COUNT(DISTINCT a.ACCOUNT_NUMBER) AS TOTAL_LOANS,
            COUNT(DISTINCT s.ACCOUNT_NUMBER) AS AVEC_SCHEDULES
        FROM cltb_account_apps_master a
        LEFT JOIN cltb_account_schedules s ON s.ACCOUNT_NUMBER = a.ACCOUNT_NUMBER
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  Total dossiers (master)  : ' || r.TOTAL_LOANS);
        DBMS_OUTPUT.PUT_LINE('  Dossiers avec echeancier : ' || r.AVEC_SCHEDULES);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('7c. cltb_account_apps_master.DR_PROD_AC -> sttb_account.AC_GL_NO :');
    FOR r IN (
        SELECT
            COUNT(DISTINCT a.DR_PROD_AC)                                             AS TOTAL_DR,
            COUNT(DISTINCT CASE WHEN s.AC_GL_NO IS NOT NULL THEN a.DR_PROD_AC END)  AS MATCHED_DR
        FROM (SELECT DISTINCT DR_PROD_AC FROM cltb_account_apps_master WHERE DR_PROD_AC IS NOT NULL) a
        LEFT JOIN sttb_account s ON s.AC_GL_NO = a.DR_PROD_AC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  DR_PROD_AC distincts : ' || r.TOTAL_DR || '  |  Trouves dans sttb_account : ' || r.MATCHED_DR);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('7d. cltb_account_apps_master.CR_PROD_AC -> sttb_account.AC_GL_NO :');
    FOR r IN (
        SELECT
            COUNT(DISTINCT a.CR_PROD_AC)                                             AS TOTAL_CR,
            COUNT(DISTINCT CASE WHEN s.AC_GL_NO IS NOT NULL THEN a.CR_PROD_AC END)  AS MATCHED_CR
        FROM (SELECT DISTINCT CR_PROD_AC FROM cltb_account_apps_master WHERE CR_PROD_AC IS NOT NULL) a
        LEFT JOIN sttb_account s ON s.AC_GL_NO = a.CR_PROD_AC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  CR_PROD_AC distincts : ' || r.TOTAL_CR || '  |  Trouves dans sttb_account : ' || r.MATCHED_CR);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('7e. Dossiers avec historique CL ET echeancier :');
    FOR r IN (
        SELECT
            COUNT(DISTINCT a.ACCOUNT_NUMBER)                                                          AS TOTAL,
            COUNT(DISTINCT CASE WHEN h.RELATED_ACCOUNT IS NOT NULL THEN a.ACCOUNT_NUMBER END)        AS AVEC_HIST,
            COUNT(DISTINCT CASE WHEN s.ACCOUNT_NUMBER  IS NOT NULL THEN a.ACCOUNT_NUMBER END)        AS AVEC_SCH,
            COUNT(DISTINCT CASE WHEN h.RELATED_ACCOUNT IS NOT NULL
                                 AND s.ACCOUNT_NUMBER  IS NOT NULL
                            THEN a.ACCOUNT_NUMBER END)                                               AS AVEC_LES_DEUX
        FROM cltb_account_apps_master a
        LEFT JOIN (SELECT DISTINCT RELATED_ACCOUNT FROM actb_history WHERE MODULE='CL') h
            ON h.RELATED_ACCOUNT = a.ACCOUNT_NUMBER
        LEFT JOIN (SELECT DISTINCT ACCOUNT_NUMBER FROM cltb_account_schedules) s
            ON s.ACCOUNT_NUMBER = a.ACCOUNT_NUMBER
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  Total dossiers master      : ' || r.TOTAL);
        DBMS_OUTPUT.PUT_LINE('  Avec historique CL         : ' || r.AVEC_HIST);
        DBMS_OUTPUT.PUT_LINE('  Avec echeancier            : ' || r.AVEC_SCH);
        DBMS_OUTPUT.PUT_LINE('  Avec historique ET ech.    : ' || r.AVEC_LES_DEUX);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_sep2);
    DBMS_OUTPUT.PUT_LINE('7f. Jointure illustrative : dossier actif + ecritures CL + GL (50 lignes max) :');
    DBMS_OUTPUT.PUT_LINE(
        '  ' ||
        RPAD('ACCOUNT_NUMBER', 22) ||
        RPAD('PRODUCT_CODE',   14) ||
        RPAD('STATUS',         10) ||
        RPAD('TRN_DT',         14) ||
        RPAD('EVENT',          15) ||
        RPAD('DR/CR',           6) ||
        RPAD('AMOUNT_TAG',     30) ||
        RPAD('LCY_AMOUNT',     20) ||
        RPAD('AC_NO',          22) ||
        'NATURAL_GL'
    );
    FOR r IN c_illustrative LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' ||
            RPAD(NVL(r.ACCOUNT_NUMBER, '-'), 22) ||
            RPAD(NVL(r.PRODUCT_CODE,   '-'), 14) ||
            RPAD(NVL(r.ACCOUNT_STATUS, '-'), 10) ||
            RPAD(NVL(r.TRN_DT,         '-'), 14) ||
            RPAD(NVL(r.EVENT,          '-'), 15) ||
            RPAD(NVL(r.DRCR_IND,       '-'),  6) ||
            RPAD(NVL(r.AMOUNT_TAG,     '-'), 30) ||
            RPAD(TO_CHAR(NVL(r.LCY_AMOUNT,0),'FM999,999,999,990'), 20) ||
            RPAD(NVL(r.AC_NO,          '-'), 22) ||
            NVL(r.AC_NATURAL_GL, '-')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE(v_sep);
    DBMS_OUTPUT.PUT_LINE('FIN DU SCRIPT D''EXPLORATION - MODULE CL (CREDITS)');
    DBMS_OUTPUT.PUT_LINE(v_sep);

END;
/
