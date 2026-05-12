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
