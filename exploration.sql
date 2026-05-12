SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 300
SET PAGESIZE 200
SET TRIMSPOOL ON
SET FEEDBACK OFF
SET VERIFY OFF
SET ECHO OFF
SPOOL exploration_report.log

PROMPT ============================================================
PROMPT SECTION 1 - GLOBAL COUNTS AND MODULE SCOPE
PROMPT ============================================================

PROMPT --- 1.1 Row counts of key tables ---
SELECT 'CLTM_PRODUCT'            AS table_name, COUNT(*) AS row_count FROM cltm_product
UNION ALL SELECT 'CLTB_ACCOUNT_APPS_MASTER',  COUNT(*) FROM cltb_account_apps_master
UNION ALL SELECT 'CLTB_ACCOUNT_SCHEDULES',    COUNT(*) FROM cltb_account_schedules
UNION ALL SELECT 'CSTB_AMOUNT_TAG',           COUNT(*) FROM cstb_amount_tag
UNION ALL SELECT 'STTB_ACCOUNT',              COUNT(*) FROM sttb_account
UNION ALL SELECT 'ACTB_HISTORY',              COUNT(*) FROM actb_history
UNION ALL SELECT 'ACTB_HISTORY_CL_ONLY',      COUNT(*) FROM actb_history WHERE module = 'CL';

PROMPT --- 1.2 Distinct modules present in ACTB_HISTORY (sanity check) ---
SELECT module, COUNT(*) AS nb_lines
FROM   actb_history
GROUP  BY module
ORDER  BY nb_lines DESC;

PROMPT --- 1.3 Branches having CL activity ---
SELECT ac_branch, COUNT(*) AS nb_entries, COUNT(DISTINCT ac_no) AS nb_accounts
FROM   actb_history
WHERE  module = 'CL'
GROUP  BY ac_branch
ORDER  BY nb_entries DESC;

PROMPT --- 1.4 ACTB_HISTORY date range for module CL ---
SELECT MIN(trn_dt) AS first_trn_dt,
       MAX(trn_dt) AS last_trn_dt,
       MIN(value_dt) AS first_value_dt,
       MAX(value_dt) AS last_value_dt
FROM   actb_history
WHERE  module = 'CL';

PROMPT ============================================================
PROMPT SECTION 2 - CLTM_PRODUCT (loan products definitions)
PROMPT ============================================================

PROMPT --- 2.1 Distinct product categories ---
SELECT product_category, COUNT(*) AS nb_products
FROM   cltm_product
GROUP  BY product_category
ORDER  BY nb_products DESC;

PROMPT --- 2.2 Distinct product types / contract types / module ---
SELECT module_code, product_type, contract_type, COUNT(*) AS nb_products
FROM   cltm_product
GROUP  BY module_code, product_type, contract_type
ORDER  BY module_code, nb_products DESC;

PROMPT --- 2.3 Product master list (authorized, not closed) ---
SELECT product_code,
       product_desc,
       product_category,
       product_type,
       contract_type,
       module_code,
       product_end_date,
       record_stat,
       auth_stat
FROM   cltm_product
WHERE  auth_stat = 'A'
ORDER  BY product_category, product_code;

PROMPT --- 2.4 Product key flags (revolving, packing credit, lease, etc.) ---
SELECT product_code,
       revolving_type,
       open_line_loan,
       packing_credit,
       lease_type,
       cl_against_bill,
       ic_product,
       project_account,
       fa_product,
       limits_product
FROM   cltm_product
WHERE  auth_stat = 'A'
ORDER  BY product_code;

PROMPT ============================================================
PROMPT SECTION 3 - CLTB_ACCOUNT_APPS_MASTER (loan contracts)
PROMPT ============================================================

PROMPT --- 3.1 Distribution by account_status / auth_stat ---
SELECT account_status, auth_stat, COUNT(*) AS nb
FROM   cltb_account_apps_master
GROUP  BY account_status, auth_stat
ORDER  BY nb DESC;

PROMPT --- 3.2 Distribution by user_defined_status (NPL classification axis) ---
SELECT user_defined_status, COUNT(*) AS nb,
       SUM(amount_financed)  AS sum_financed,
       SUM(amount_disbursed) AS sum_disbursed
FROM   cltb_account_apps_master
GROUP  BY user_defined_status
ORDER  BY nb DESC;

PROMPT --- 3.3 Loans by product / category / branch ---
SELECT branch_code, product_code, product_category, COUNT(*) AS nb_loans,
       SUM(amount_financed) AS sum_financed
FROM   cltb_account_apps_master
GROUP  BY branch_code, product_code, product_category
ORDER  BY branch_code, nb_loans DESC;

PROMPT --- 3.4 Loans by currency and module ---
SELECT module_code, currency, COUNT(*) AS nb_loans,
       SUM(amount_financed)  AS sum_financed,
       SUM(amount_disbursed) AS sum_disbursed
FROM   cltb_account_apps_master
GROUP  BY module_code, currency
ORDER  BY nb_loans DESC;

PROMPT --- 3.5 Sample loans (10 most recent disbursed) ---
SELECT *
FROM   (SELECT account_number, branch_code, customer_id, product_code, product_category,
               currency, amount_financed, amount_disbursed, value_date, maturity_date,
               account_status, user_defined_status, dr_prod_ac, cr_prod_ac, alt_acc_no
        FROM   cltb_account_apps_master
        WHERE  auth_stat = 'A'
        ORDER  BY book_date DESC NULLS LAST)
WHERE  ROWNUM <= 10;

PROMPT --- 3.6 Distinct DR_PROD_AC / CR_PROD_AC patterns (settlement GL/customer account) ---
SELECT 'DR_PROD_AC' AS side, COUNT(DISTINCT dr_prod_ac) AS nb_distinct,
       COUNT(*) AS nb_loans, COUNT(dr_prod_ac) AS nb_filled
FROM   cltb_account_apps_master
UNION ALL
SELECT 'CR_PROD_AC', COUNT(DISTINCT cr_prod_ac), COUNT(*), COUNT(cr_prod_ac)
FROM   cltb_account_apps_master;
