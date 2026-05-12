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

    print_section('2. CLTM_PRODUCT (catalogue produits credit)');

    print_sub('2.1 Repartition par product_category');
    FOR r IN (
        SELECT product_category, COUNT(*) AS nb
        FROM   cltm_product
        GROUP  BY product_category
        ORDER  BY nb DESC
    ) LOOP
        print_kv('Category ' || NVL(r.product_category,'<NULL>'), TO_CHAR(r.nb) || ' produits');
    END LOOP;

    print_sub('2.2 Repartition module_code / product_type / contract_type');
    FOR r IN (
        SELECT module_code, product_type, contract_type, COUNT(*) AS nb
        FROM   cltm_product
        GROUP  BY module_code, product_type, contract_type
        ORDER  BY module_code, nb DESC
    ) LOOP
        print_line(RPAD('module='||NVL(r.module_code,'-'),15) ||
                   RPAD('type='||NVL(r.product_type,'-'),15) ||
                   RPAD('contract='||NVL(r.contract_type,'-'),20) ||
                   'nb=' || r.nb);
    END LOOP;

    print_sub('2.3 Liste des produits autorises');
    FOR r IN (
        SELECT product_code, product_desc, product_category, product_type,
               contract_type, module_code, product_end_date, record_stat, auth_stat
        FROM   cltm_product
        WHERE  auth_stat = 'A'
        ORDER  BY product_category, product_code
    ) LOOP
        print_line(RPAD(r.product_code,12) ||
                   RPAD(SUBSTR(r.product_desc,1,40),42) ||
                   RPAD('cat='||NVL(r.product_category,'-'),12) ||
                   RPAD('type='||NVL(r.product_type,'-'),12) ||
                   RPAD('contract='||NVL(r.contract_type,'-'),18) ||
                   RPAD('module='||NVL(r.module_code,'-'),12) ||
                   'end='||TO_CHAR(r.product_end_date,'YYYY-MM-DD'));
    END LOOP;

    print_sub('2.4 Flags produits (revolving / packing / lease / IC / projet)');
    FOR r IN (
        SELECT product_code, revolving_type, open_line_loan, packing_credit,
               lease_type, cl_against_bill, ic_product, project_account,
               fa_product, limits_product
        FROM   cltm_product
        WHERE  auth_stat = 'A'
        ORDER  BY product_code
    ) LOOP
        print_line(RPAD(r.product_code,12) ||
                   RPAD('rev='||NVL(r.revolving_type,'-'),10) ||
                   RPAD('openline='||NVL(r.open_line_loan,'-'),12) ||
                   RPAD('packing='||NVL(r.packing_credit,'-'),12) ||
                   RPAD('lease='||NVL(r.lease_type,'-'),12) ||
                   RPAD('bill='||NVL(r.cl_against_bill,'-'),10) ||
                   RPAD('ic='||NVL(r.ic_product,'-'),8) ||
                   RPAD('proj='||NVL(r.project_account,'-'),10) ||
                   RPAD('fa='||NVL(r.fa_product,'-'),8) ||
                   'limits='||NVL(r.limits_product,'-'));
    END LOOP;

    print_section('3. CLTB_ACCOUNT_APPS_MASTER (contrats de credit)');

    print_sub('3.1 Repartition account_status / auth_stat');
    FOR r IN (
        SELECT account_status, auth_stat, COUNT(*) AS nb
        FROM   cltb_account_apps_master
        GROUP  BY account_status, auth_stat
        ORDER  BY nb DESC
    ) LOOP
        print_line(RPAD('account_status='||NVL(r.account_status,'-'),25) ||
                   RPAD('auth_stat='||NVL(r.auth_stat,'-'),18) ||
                   'nb=' || r.nb);
    END LOOP;

    print_sub('3.2 Repartition par user_defined_status (axe NPL)');
    FOR r IN (
        SELECT user_defined_status,
               COUNT(*)             AS nb,
               SUM(amount_financed) AS sum_fin,
               SUM(amount_disbursed) AS sum_dsb
        FROM   cltb_account_apps_master
        GROUP  BY user_defined_status
        ORDER  BY nb DESC
    ) LOOP
        print_line(RPAD('uds='||NVL(r.user_defined_status,'<NULL>'),25) ||
                   'nb=' || RPAD(TO_CHAR(r.nb),10) ||
                   'fin=' || RPAD(TO_CHAR(NVL(r.sum_fin,0),'FM999999999990.00'),20) ||
                   'dsb=' || TO_CHAR(NVL(r.sum_dsb,0),'FM999999999990.00'));
    END LOOP;

    print_sub('3.3 Repartition branche / produit / categorie');
    FOR r IN (
        SELECT branch_code, product_code, product_category,
               COUNT(*) AS nb,
               SUM(amount_financed) AS sum_fin
        FROM   cltb_account_apps_master
        GROUP  BY branch_code, product_code, product_category
        ORDER  BY branch_code, nb DESC
    ) LOOP
        print_line(RPAD('BR='||r.branch_code,8) ||
                   RPAD('prod='||r.product_code,15) ||
                   RPAD('cat='||NVL(r.product_category,'-'),12) ||
                   'nb=' || RPAD(TO_CHAR(r.nb),8) ||
                   'fin=' || TO_CHAR(NVL(r.sum_fin,0),'FM999999999990.00'));
    END LOOP;

    print_sub('3.4 Repartition module_code / devise');
    FOR r IN (
        SELECT module_code, currency,
               COUNT(*) AS nb,
               SUM(amount_financed) AS sum_fin,
               SUM(amount_disbursed) AS sum_dsb
        FROM   cltb_account_apps_master
        GROUP  BY module_code, currency
        ORDER  BY nb DESC
    ) LOOP
        print_line(RPAD('module='||NVL(r.module_code,'-'),12) ||
                   RPAD('ccy='||NVL(r.currency,'-'),10) ||
                   'nb=' || RPAD(TO_CHAR(r.nb),8) ||
                   'fin=' || RPAD(TO_CHAR(NVL(r.sum_fin,0),'FM999999999990.00'),20) ||
                   'dsb=' || TO_CHAR(NVL(r.sum_dsb,0),'FM999999999990.00'));
    END LOOP;

    print_sub('3.5 Echantillon : 10 derniers contrats authentifies');
    FOR r IN (
        SELECT *
          FROM (SELECT account_number, branch_code, customer_id, product_code,
                       currency, amount_financed, amount_disbursed,
                       value_date, maturity_date,
                       account_status, user_defined_status,
                       dr_prod_ac, cr_prod_ac
                  FROM cltb_account_apps_master
                 WHERE auth_stat = 'A'
                 ORDER BY book_date DESC NULLS LAST)
         WHERE ROWNUM <= 10
    ) LOOP
        print_line(RPAD(r.account_number,18) ||
                   RPAD('BR='||r.branch_code,8) ||
                   RPAD('cust='||NVL(r.customer_id,'-'),14) ||
                   RPAD('prod='||r.product_code,12) ||
                   RPAD('ccy='||r.currency,8) ||
                   RPAD('fin='||TO_CHAR(NVL(r.amount_financed,0),'FM999999999990.00'),20) ||
                   RPAD('vd='||TO_CHAR(r.value_date,'YYYY-MM-DD'),16) ||
                   RPAD('uds='||NVL(r.user_defined_status,'-'),12) ||
                   RPAD('dr='||NVL(r.dr_prod_ac,'-'),20) ||
                   'cr='||NVL(r.cr_prod_ac,'-'));
    END LOOP;

    print_sub('3.6 Couverture des comptes de reglement DR_PROD_AC / CR_PROD_AC');
    SELECT COUNT(*) INTO v_count FROM cltb_account_apps_master;
    print_kv('Total contrats', TO_CHAR(v_count));
    SELECT COUNT(DISTINCT dr_prod_ac) INTO v_count FROM cltb_account_apps_master;
    print_kv('DR_PROD_AC distincts', TO_CHAR(v_count));
    SELECT COUNT(dr_prod_ac) INTO v_count FROM cltb_account_apps_master;
    print_kv('DR_PROD_AC renseignes', TO_CHAR(v_count));
    SELECT COUNT(DISTINCT cr_prod_ac) INTO v_count FROM cltb_account_apps_master;
    print_kv('CR_PROD_AC distincts', TO_CHAR(v_count));
    SELECT COUNT(cr_prod_ac) INTO v_count FROM cltb_account_apps_master;
    print_kv('CR_PROD_AC renseignes', TO_CHAR(v_count));

    print_section('4. CSTB_AMOUNT_TAG (dictionnaire des balises module CL)');

    print_sub('4.1 Nombre de balises par module');
    FOR r IN (
        SELECT module, COUNT(*) AS nb
        FROM   cstb_amount_tag
        GROUP  BY module
        ORDER  BY nb DESC
    ) LOOP
        print_kv('Module ' || NVL(r.module,'<NULL>'), TO_CHAR(r.nb) || ' balises');
    END LOOP;

    print_sub('4.2 Toutes les balises module CL');
    FOR r IN (
        SELECT amount_tag, description, amount_tag_type,
               interest_allowed, charge_allowed, commission_allowed, tax_allowed,
               unrealised, track_receivable, track_payable,
               offset_amount_tag, user_defined
        FROM   cstb_amount_tag
        WHERE  module = 'CL'
        ORDER  BY amount_tag
    ) LOOP
        print_line(RPAD(r.amount_tag,25) ||
                   RPAD(SUBSTR(NVL(r.description,'-'),1,45),47) ||
                   RPAD('type='||NVL(r.amount_tag_type,'-'),10) ||
                   RPAD('int='||NVL(r.interest_allowed,'-'),8) ||
                   RPAD('chg='||NVL(r.charge_allowed,'-'),8) ||
                   RPAD('unrl='||NVL(r.unrealised,'-'),9) ||
                   RPAD('trkrcv='||NVL(r.track_receivable,'-'),11) ||
                   RPAD('trkpay='||NVL(r.track_payable,'-'),11) ||
                   RPAD('offset='||NVL(r.offset_amount_tag,'-'),20) ||
                   'usr='||NVL(r.user_defined,'-'));
    END LOOP;

    print_sub('4.3 Balises CL candidates loss-pool / provision / suspense');
    FOR r IN (
        SELECT amount_tag, description, amount_tag_type, unrealised,
               track_receivable, track_payable
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
        ORDER  BY amount_tag
    ) LOOP
        print_line(RPAD(r.amount_tag,25) ||
                   RPAD(SUBSTR(NVL(r.description,'-'),1,55),57) ||
                   RPAD('type='||NVL(r.amount_tag_type,'-'),10) ||
                   RPAD('unrl='||NVL(r.unrealised,'-'),9) ||
                   RPAD('trkrcv='||NVL(r.track_receivable,'-'),11) ||
                   'trkpay='||NVL(r.track_payable,'-'));
    END LOOP;

    print_section('5. ACTB_HISTORY (ecritures comptables module CL)');

    print_sub('5.1 Evenements distincts module CL');
    FOR r IN (
        SELECT event,
               COUNT(*) AS nb_entries,
               COUNT(DISTINCT trn_ref_no) AS nb_contracts
        FROM   actb_history
        WHERE  module = 'CL'
        GROUP  BY event
        ORDER  BY nb_entries DESC
    ) LOOP
        print_line(RPAD('event='||NVL(r.event,'-'),15) ||
                   'entries=' || RPAD(TO_CHAR(r.nb_entries),12) ||
                   'contracts=' || r.nb_contracts);
    END LOOP;

    print_sub('5.2 Balises (amount_tag) utilisees module CL');
    FOR r IN (
        SELECT amount_tag,
               COUNT(*) AS nb_entries,
               SUM(CASE WHEN drcr_ind = 'D' THEN lcy_amount ELSE 0 END) AS sum_dr,
               SUM(CASE WHEN drcr_ind = 'C' THEN lcy_amount ELSE 0 END) AS sum_cr
        FROM   actb_history
        WHERE  module = 'CL'
        GROUP  BY amount_tag
        ORDER  BY nb_entries DESC
    ) LOOP
        print_line(RPAD('tag='||NVL(r.amount_tag,'-'),28) ||
                   'nb=' || RPAD(TO_CHAR(r.nb_entries),10) ||
                   'sumDR=' || RPAD(TO_CHAR(NVL(r.sum_dr,0),'FM999999999990.00'),22) ||
                   'sumCR=' || TO_CHAR(NVL(r.sum_cr,0),'FM999999999990.00'));
    END LOOP;

    print_sub('5.3 Top 50 combinaisons event x amount_tag x DR/CR');
    FOR r IN (
        SELECT *
          FROM (SELECT event, amount_tag, drcr_ind,
                       COUNT(*)        AS nb,
                       SUM(lcy_amount) AS sum_lcy
                  FROM actb_history
                 WHERE module = 'CL'
                 GROUP BY event, amount_tag, drcr_ind
                 ORDER BY COUNT(*) DESC)
         WHERE ROWNUM <= 50
    ) LOOP
        print_line(RPAD('event='||r.event,15) ||
                   RPAD('tag='||r.amount_tag,28) ||
                   RPAD('drcr='||r.drcr_ind,8) ||
                   'nb=' || RPAD(TO_CHAR(r.nb),10) ||
                   'sumLCY=' || TO_CHAR(NVL(r.sum_lcy,0),'FM999999999990.00'));
    END LOOP;

    print_sub('5.4 Codes de transaction (trn_code) module CL');
    FOR r IN (
        SELECT trn_code, COUNT(*) AS nb
        FROM   actb_history
        WHERE  module = 'CL'
        GROUP  BY trn_code
        ORDER  BY nb DESC
    ) LOOP
        print_kv('trn_code ' || NVL(r.trn_code,'-'), TO_CHAR(r.nb));
    END LOOP;

    print_sub('5.5 Produits utilises dans les ecritures CL');
    FOR r IN (
        SELECT product, COUNT(*) AS nb_entries,
               COUNT(DISTINCT ac_no) AS nb_accounts
        FROM   actb_history
        WHERE  module = 'CL'
        GROUP  BY product
        ORDER  BY nb_entries DESC
    ) LOOP
        print_line(RPAD('product='||NVL(r.product,'-'),18) ||
                   'entries=' || RPAD(TO_CHAR(r.nb_entries),12) ||
                   'distinct_ac=' || r.nb_accounts);
    END LOOP;

    print_sub('5.6 Echantillon des 15 dernieres ecritures CL');
    FOR r IN (
        SELECT *
          FROM (SELECT trn_ref_no, event, event_sr_no, ac_branch, ac_no, ac_ccy,
                       drcr_ind, trn_code, amount_tag,
                       fcy_amount, lcy_amount,
                       related_account, related_reference,
                       trn_dt, value_dt, product
                  FROM actb_history
                 WHERE module = 'CL'
                 ORDER BY trn_dt DESC, entry_seq_no DESC)
         WHERE ROWNUM <= 15
    ) LOOP
        print_line(RPAD(r.trn_ref_no,18) ||
                   RPAD('ev='||r.event,12) ||
                   RPAD('sr='||TO_CHAR(r.event_sr_no),8) ||
                   RPAD('br='||r.ac_branch,7) ||
                   RPAD('ac='||r.ac_no,18) ||
                   RPAD('ccy='||r.ac_ccy,8) ||
                   RPAD('dc='||r.drcr_ind,6) ||
                   RPAD('tag='||r.amount_tag,18) ||
                   RPAD('lcy='||TO_CHAR(NVL(r.lcy_amount,0),'FM999999999990.00'),20) ||
                   RPAD('trn_dt='||TO_CHAR(r.trn_dt,'YYYY-MM-DD'),18) ||
                   'prod='||NVL(r.product,'-'));
    END LOOP;

    print_sub('5.7 Top 30 ac_no les plus mouvementes par CL');
    FOR r IN (
        SELECT *
          FROM (SELECT ac_no,
                       COUNT(*) AS nb_entries,
                       SUM(CASE WHEN drcr_ind='D' THEN lcy_amount ELSE 0 END) AS sum_dr,
                       SUM(CASE WHEN drcr_ind='C' THEN lcy_amount ELSE 0 END) AS sum_cr
                  FROM actb_history
                 WHERE module = 'CL'
                 GROUP BY ac_no
                 ORDER BY COUNT(*) DESC)
         WHERE ROWNUM <= 30
    ) LOOP
        print_line(RPAD('ac='||r.ac_no,22) ||
                   'nb=' || RPAD(TO_CHAR(r.nb_entries),10) ||
                   'sumDR=' || RPAD(TO_CHAR(NVL(r.sum_dr,0),'FM999999999990.00'),22) ||
                   'sumCR=' || TO_CHAR(NVL(r.sum_cr,0),'FM999999999990.00'));
    END LOOP;

    print_section('6. CLTB_ACCOUNT_SCHEDULES (echeanciers de credit)');

    print_sub('6.1 Component_name distincts');
    FOR r IN (
        SELECT component_name,
               COUNT(*) AS nb_lines,
               COUNT(DISTINCT account_number) AS nb_accounts
        FROM   cltb_account_schedules
        GROUP  BY component_name
        ORDER  BY nb_lines DESC
    ) LOOP
        print_line(RPAD('comp='||NVL(r.component_name,'-'),22) ||
                   'lines=' || RPAD(TO_CHAR(r.nb_lines),12) ||
                   'accounts=' || r.nb_accounts);
    END LOOP;

    print_sub('6.2 Schedule_type distincts');
    FOR r IN (
        SELECT schedule_type, COUNT(*) AS nb
        FROM   cltb_account_schedules
        GROUP  BY schedule_type
        ORDER  BY nb DESC
    ) LOOP
        print_kv('schedule_type ' || NVL(r.schedule_type,'-'), TO_CHAR(r.nb));
    END LOOP;

    print_sub('6.3 Repartition schedule_flag / sch_status');
    FOR r IN (
        SELECT schedule_flag, sch_status, COUNT(*) AS nb
        FROM   cltb_account_schedules
        GROUP  BY schedule_flag, sch_status
        ORDER  BY nb DESC
    ) LOOP
        print_line(RPAD('flag='||NVL(r.schedule_flag,'-'),12) ||
                   RPAD('sch_status='||NVL(r.sch_status,'-'),18) ||
                   'nb=' || r.nb);
    END LOOP;

    print_sub('6.4 Overdue snapshot par composant (amount_overdue > 0)');
    FOR r IN (
        SELECT component_name,
               COUNT(*) AS nb_lines,
               COUNT(DISTINCT account_number) AS nb_accounts,
               SUM(amount_overdue) AS sum_overdue,
               SUM(amount_due)     AS sum_due,
               SUM(amount_settled) AS sum_settled
        FROM   cltb_account_schedules
        WHERE  amount_overdue > 0
        GROUP  BY component_name
        ORDER  BY SUM(amount_overdue) DESC NULLS LAST
    ) LOOP
        print_line(RPAD('comp='||NVL(r.component_name,'-'),22) ||
                   'lines=' || RPAD(TO_CHAR(r.nb_lines),10) ||
                   'acc=' || RPAD(TO_CHAR(r.nb_accounts),10) ||
                   'overdue=' || RPAD(TO_CHAR(NVL(r.sum_overdue,0),'FM999999999990.00'),22) ||
                   'due=' || RPAD(TO_CHAR(NVL(r.sum_due,0),'FM999999999990.00'),22) ||
                   'settled=' || TO_CHAR(NVL(r.sum_settled,0),'FM999999999990.00'));
    END LOOP;

    print_sub('6.5 Aging des impayes (DPD buckets)');
    FOR r IN (
        SELECT CASE
                 WHEN TRUNC(SYSDATE) - schedule_due_date <= 30  THEN '1-30'
                 WHEN TRUNC(SYSDATE) - schedule_due_date <= 60  THEN '31-60'
                 WHEN TRUNC(SYSDATE) - schedule_due_date <= 90  THEN '61-90'
                 WHEN TRUNC(SYSDATE) - schedule_due_date <= 180 THEN '91-180'
                 WHEN TRUNC(SYSDATE) - schedule_due_date <= 365 THEN '181-365'
                 ELSE '>365'
               END AS bucket,
               COUNT(*) AS nb_lines,
               COUNT(DISTINCT account_number) AS nb_accounts,
               SUM(amount_overdue) AS sum_overdue
        FROM   cltb_account_schedules
        WHERE  amount_overdue > 0
          AND  schedule_due_date < TRUNC(SYSDATE)
        GROUP  BY CASE
                    WHEN TRUNC(SYSDATE) - schedule_due_date <= 30  THEN '1-30'
                    WHEN TRUNC(SYSDATE) - schedule_due_date <= 60  THEN '31-60'
                    WHEN TRUNC(SYSDATE) - schedule_due_date <= 90  THEN '61-90'
                    WHEN TRUNC(SYSDATE) - schedule_due_date <= 180 THEN '91-180'
                    WHEN TRUNC(SYSDATE) - schedule_due_date <= 365 THEN '181-365'
                    ELSE '>365'
                  END
        ORDER  BY 1
    ) LOOP
        print_line(RPAD('bucket='||r.bucket,15) ||
                   'lines=' || RPAD(TO_CHAR(r.nb_lines),10) ||
                   'acc=' || RPAD(TO_CHAR(r.nb_accounts),10) ||
                   'overdue=' || TO_CHAR(NVL(r.sum_overdue,0),'FM999999999990.00'));
    END LOOP;

    print_sub('6.6 Suspense et write-off au niveau echeance');
    FOR r IN (
        SELECT component_name,
               SUM(susp_amt_due)     AS sum_susp_due,
               SUM(susp_amt_settled) AS sum_susp_set,
               SUM(susp_amt_lcy)     AS sum_susp_lcy,
               SUM(writeoff_amt)     AS sum_wro,
               SUM(amount_waived)    AS sum_wai
        FROM   cltb_account_schedules
        GROUP  BY component_name
        ORDER  BY SUM(susp_amt_due) DESC NULLS LAST
    ) LOOP
        print_line(RPAD('comp='||NVL(r.component_name,'-'),22) ||
                   'susp_due=' || RPAD(TO_CHAR(NVL(r.sum_susp_due,0),'FM999999999990.00'),22) ||
                   'susp_set=' || RPAD(TO_CHAR(NVL(r.sum_susp_set,0),'FM999999999990.00'),22) ||
                   'susp_lcy=' || RPAD(TO_CHAR(NVL(r.sum_susp_lcy,0),'FM999999999990.00'),22) ||
                   'wro=' || RPAD(TO_CHAR(NVL(r.sum_wro,0),'FM999999999990.00'),20) ||
                   'wai=' || TO_CHAR(NVL(r.sum_wai,0),'FM999999999990.00'));
    END LOOP;

END;
/
