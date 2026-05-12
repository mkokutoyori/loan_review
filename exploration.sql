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

PROMPT ============================================================
PROMPT SECTION 4 - CSTB_AMOUNT_TAG (module CL amount tag dictionary)
PROMPT ============================================================

PROMPT --- 4.1 Number of tags by module ---
SELECT module, COUNT(*) AS nb_tags
FROM   cstb_amount_tag
GROUP  BY module
ORDER  BY nb_tags DESC;

PROMPT --- 4.2 All CL amount tags with their nature ---
SELECT amount_tag,
       description,
       amount_tag_type,
       interest_allowed,
       charge_allowed,
       commission_allowed,
       tax_allowed,
       unrealised,
       track_receivable,
       track_payable,
       offset_amount_tag,
       user_defined
FROM   cstb_amount_tag
WHERE  module = 'CL'
ORDER  BY amount_tag;

PROMPT --- 4.3 CL tags that are unrealised / income suspense related (loss-pool candidates) ---
SELECT amount_tag, description, amount_tag_type, unrealised,
       track_receivable, track_payable
FROM   cstb_amount_tag
WHERE  module = 'CL'
  AND  (UPPER(description) LIKE '%LOSS%'
        OR UPPER(description) LIKE '%PROVIS%'
        OR UPPER(description) LIKE '%WRITE%OFF%'
        OR UPPER(description) LIKE '%SUSPEND%'
        OR UPPER(description) LIKE '%SUSP%'
        OR UPPER(description) LIKE '%POOL%'
        OR UPPER(description) LIKE '%IMPAIR%'
        OR UPPER(description) LIKE '%NPL%'
        OR UPPER(amount_tag) LIKE '%LOSS%'
        OR UPPER(amount_tag) LIKE '%PROV%'
        OR UPPER(amount_tag) LIKE '%WROFF%'
        OR UPPER(amount_tag) LIKE '%SUSP%'
        OR UPPER(amount_tag) LIKE '%POOL%')
ORDER  BY amount_tag;

PROMPT ============================================================
PROMPT SECTION 5 - ACTB_HISTORY (module CL accounting entries)
PROMPT ============================================================

PROMPT --- 5.1 Distinct events used in CL ---
SELECT event, COUNT(*) AS nb_entries, COUNT(DISTINCT trn_ref_no) AS nb_contracts
FROM   actb_history
WHERE  module = 'CL'
GROUP  BY event
ORDER  BY nb_entries DESC;

PROMPT --- 5.2 Distinct amount_tag used in CL ---
SELECT amount_tag, COUNT(*) AS nb_entries,
       SUM(CASE WHEN drcr_ind = 'D' THEN lcy_amount ELSE 0 END) AS sum_dr_lcy,
       SUM(CASE WHEN drcr_ind = 'C' THEN lcy_amount ELSE 0 END) AS sum_cr_lcy
FROM   actb_history
WHERE  module = 'CL'
GROUP  BY amount_tag
ORDER  BY nb_entries DESC;

PROMPT --- 5.3 Event x amount_tag matrix (top combinations) ---
SELECT event, amount_tag, drcr_ind, COUNT(*) AS nb,
       SUM(lcy_amount) AS sum_lcy
FROM   actb_history
WHERE  module = 'CL'
GROUP  BY event, amount_tag, drcr_ind
ORDER  BY nb DESC FETCH FIRST 50 ROWS ONLY;

PROMPT --- 5.4 Distinct trn_code in CL ---
SELECT trn_code, COUNT(*) AS nb_entries
FROM   actb_history
WHERE  module = 'CL'
GROUP  BY trn_code
ORDER  BY nb_entries DESC;

PROMPT --- 5.5 Distinct products used through CL entries ---
SELECT product, COUNT(*) AS nb_entries, COUNT(DISTINCT ac_no) AS nb_accounts
FROM   actb_history
WHERE  module = 'CL'
GROUP  BY product
ORDER  BY nb_entries DESC;

PROMPT --- 5.6 Sample CL entries (last 15 by trn_dt) ---
SELECT *
FROM   (SELECT trn_ref_no, event, event_sr_no, ac_branch, ac_no, ac_ccy,
               drcr_ind, trn_code, amount_tag, fcy_amount, lcy_amount,
               related_account, related_reference, trn_dt, value_dt, product
        FROM   actb_history
        WHERE  module = 'CL'
        ORDER  BY trn_dt DESC, entry_seq_no DESC)
WHERE  ROWNUM <= 15;

PROMPT --- 5.7 GL accounts (ac_no) most hit by CL entries ---
SELECT ac_no, COUNT(*) AS nb_entries,
       SUM(CASE WHEN drcr_ind = 'D' THEN lcy_amount ELSE 0 END) AS sum_dr_lcy,
       SUM(CASE WHEN drcr_ind = 'C' THEN lcy_amount ELSE 0 END) AS sum_cr_lcy
FROM   actb_history
WHERE  module = 'CL'
GROUP  BY ac_no
ORDER  BY nb_entries DESC FETCH FIRST 30 ROWS ONLY;

PROMPT ============================================================
PROMPT SECTION 6 - CLTB_ACCOUNT_SCHEDULES (loan repayment schedules)
PROMPT ============================================================

PROMPT --- 6.1 Distinct component_name (MAIN_INT, PRINCIPAL, etc.) ---
SELECT component_name, COUNT(*) AS nb_lines,
       COUNT(DISTINCT account_number) AS nb_accounts
FROM   cltb_account_schedules
GROUP  BY component_name
ORDER  BY nb_lines DESC;

PROMPT --- 6.2 Distinct schedule_type ---
SELECT schedule_type, COUNT(*) AS nb_lines
FROM   cltb_account_schedules
GROUP  BY schedule_type
ORDER  BY nb_lines DESC;

PROMPT --- 6.3 Distinct schedule_flag / sch_status ---
SELECT schedule_flag, sch_status, COUNT(*) AS nb_lines
FROM   cltb_account_schedules
GROUP  BY schedule_flag, sch_status
ORDER  BY nb_lines DESC;

PROMPT --- 6.4 Overdue snapshot by component (positive amount_overdue) ---
SELECT component_name,
       COUNT(*)                       AS nb_overdue_lines,
       COUNT(DISTINCT account_number) AS nb_accounts_overdue,
       SUM(amount_overdue)            AS sum_overdue,
       SUM(amount_due)                AS sum_due,
       SUM(amount_settled)            AS sum_settled
FROM   cltb_account_schedules
WHERE  amount_overdue > 0
GROUP  BY component_name
ORDER  BY sum_overdue DESC NULLS LAST;

PROMPT --- 6.5 Aging of overdue (days past due) ---
SELECT CASE
         WHEN TRUNC(SYSDATE) - schedule_due_date <= 30  THEN '1-30'
         WHEN TRUNC(SYSDATE) - schedule_due_date <= 60  THEN '31-60'
         WHEN TRUNC(SYSDATE) - schedule_due_date <= 90  THEN '61-90'
         WHEN TRUNC(SYSDATE) - schedule_due_date <= 180 THEN '91-180'
         WHEN TRUNC(SYSDATE) - schedule_due_date <= 365 THEN '181-365'
         ELSE '>365'
       END AS bucket,
       COUNT(*)                       AS nb_lines,
       COUNT(DISTINCT account_number) AS nb_accounts,
       SUM(amount_overdue)            AS sum_overdue
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
ORDER  BY 1;

PROMPT --- 6.6 Suspense and write-off amounts at schedule level ---
SELECT component_name,
       SUM(susp_amt_due)     AS sum_susp_amt_due,
       SUM(susp_amt_settled) AS sum_susp_amt_settled,
       SUM(susp_amt_lcy)     AS sum_susp_amt_lcy,
       SUM(writeoff_amt)     AS sum_writeoff,
       SUM(amount_waived)    AS sum_waived
FROM   cltb_account_schedules
GROUP  BY component_name
ORDER  BY sum_susp_amt_due DESC NULLS LAST;

PROMPT ============================================================
PROMPT SECTION 7 - STTB_ACCOUNT (GL / customer accounts)
PROMPT ============================================================

PROMPT --- 7.1 Distribution AC_OR_GL ---
SELECT ac_or_gl, COUNT(*) AS nb
FROM   sttb_account
GROUP  BY ac_or_gl
ORDER  BY ac_or_gl;

PROMPT --- 7.2 Distribution GL_ACLASS_TYPE / GL_CATEGORY ---
SELECT gl_aclass_type, gl_category, COUNT(*) AS nb
FROM   sttb_account
WHERE  ac_or_gl = 'G'
GROUP  BY gl_aclass_type, gl_category
ORDER  BY nb DESC;

PROMPT --- 7.3 AC_CLASS distribution ---
SELECT ac_class, COUNT(*) AS nb
FROM   sttb_account
GROUP  BY ac_class
ORDER  BY nb DESC;

PROMPT --- 7.4 GLs whose description suggests loan loss pool / provisioning ---
SELECT ac_gl_no, branch_code, ac_gl_ccy, ac_gl_desc, ac_class,
       gl_aclass_type, gl_category, ac_natural_gl, auth_stat
FROM   sttb_account
WHERE  ac_or_gl = 'G'
  AND  (UPPER(ac_gl_desc) LIKE '%LOSS%POOL%'
        OR UPPER(ac_gl_desc) LIKE '%POOL%'
        OR UPPER(ac_gl_desc) LIKE '%PROVIS%'
        OR UPPER(ac_gl_desc) LIKE '%IMPAIR%'
        OR UPPER(ac_gl_desc) LIKE '%WRITE%OFF%'
        OR UPPER(ac_gl_desc) LIKE '%DOUBTFUL%'
        OR UPPER(ac_gl_desc) LIKE '%NPL%'
        OR UPPER(ac_gl_desc) LIKE '%LOAN%LOSS%')
ORDER  BY branch_code, ac_gl_no;

PROMPT --- 7.5 GLs related to loans (loan principal, interest receivable etc.) ---
SELECT ac_gl_no, branch_code, ac_gl_ccy, ac_gl_desc, ac_class, ac_natural_gl
FROM   sttb_account
WHERE  ac_or_gl = 'G'
  AND  (UPPER(ac_gl_desc) LIKE '%LOAN%'
        OR UPPER(ac_gl_desc) LIKE '%ADVANCE%'
        OR UPPER(ac_gl_desc) LIKE '%CREDIT%')
ORDER  BY branch_code, ac_gl_no FETCH FIRST 50 ROWS ONLY;

PROMPT --- 7.6 Status flags on GL (blocked / frozen / dormant) ---
SELECT gl_stat_blocked, ac_stat_frozen, ac_stat_dormant, COUNT(*) AS nb
FROM   sttb_account
WHERE  ac_or_gl = 'G'
GROUP  BY gl_stat_blocked, ac_stat_frozen, ac_stat_dormant
ORDER  BY nb DESC;

PROMPT ============================================================
PROMPT SECTION 8 - CROSS-TABLE RELATIONSHIPS
PROMPT ============================================================

PROMPT --- 8.1 Loan -> Product join coverage ---
SELECT COUNT(*) AS total_loans,
       SUM(CASE WHEN p.product_code IS NOT NULL THEN 1 ELSE 0 END) AS matched_product,
       SUM(CASE WHEN p.product_code IS NULL     THEN 1 ELSE 0 END) AS unmatched_product
FROM   cltb_account_apps_master m
LEFT   JOIN cltm_product p ON p.product_code = m.product_code;

PROMPT --- 8.2 ACTB_HISTORY (CL) -> CLTB_ACCOUNT_APPS_MASTER join via trn_ref_no ---
SELECT COUNT(*)                                                     AS nb_cl_entries,
       COUNT(DISTINCT h.trn_ref_no)                                  AS nb_cl_contracts,
       SUM(CASE WHEN m.account_number IS NOT NULL THEN 1 ELSE 0 END) AS entries_with_loan_match,
       SUM(CASE WHEN m.account_number IS NULL     THEN 1 ELSE 0 END) AS entries_without_loan_match
FROM   actb_history h
LEFT   JOIN cltb_account_apps_master m ON m.account_number = h.trn_ref_no
WHERE  h.module = 'CL';

PROMPT --- 8.3 ACTB_HISTORY (CL) ac_no resolution against STTB_ACCOUNT ---
SELECT SUM(CASE WHEN s.ac_or_gl = 'G' THEN 1 ELSE 0 END) AS hits_on_gl,
       SUM(CASE WHEN s.ac_or_gl = 'A' THEN 1 ELSE 0 END) AS hits_on_customer_ac,
       SUM(CASE WHEN s.ac_or_gl IS NULL THEN 1 ELSE 0 END) AS unmatched
FROM   actb_history h
LEFT   JOIN sttb_account s ON s.ac_gl_no = h.ac_no AND s.branch_code = h.ac_branch
WHERE  h.module = 'CL';

PROMPT --- 8.4 CLTB_ACCOUNT_SCHEDULES -> CLTB_ACCOUNT_APPS_MASTER join ---
SELECT COUNT(*) AS nb_schedule_lines,
       COUNT(DISTINCT s.account_number) AS nb_distinct_accounts,
       SUM(CASE WHEN m.account_number IS NULL THEN 1 ELSE 0 END) AS schedule_lines_without_master
FROM   cltb_account_schedules s
LEFT   JOIN cltb_account_apps_master m ON m.account_number = s.account_number;

PROMPT --- 8.5 Customer account behind a loan via CR_PROD_AC / DR_PROD_AC ---
SELECT COUNT(*) AS total_loans,
       SUM(CASE WHEN cr_s.ac_or_gl = 'A' THEN 1 ELSE 0 END) AS cr_prod_is_customer,
       SUM(CASE WHEN cr_s.ac_or_gl = 'G' THEN 1 ELSE 0 END) AS cr_prod_is_gl,
       SUM(CASE WHEN dr_s.ac_or_gl = 'A' THEN 1 ELSE 0 END) AS dr_prod_is_customer,
       SUM(CASE WHEN dr_s.ac_or_gl = 'G' THEN 1 ELSE 0 END) AS dr_prod_is_gl
FROM   cltb_account_apps_master m
LEFT   JOIN sttb_account cr_s ON cr_s.ac_gl_no = m.cr_prod_ac AND cr_s.branch_code = m.cr_acc_brn
LEFT   JOIN sttb_account dr_s ON dr_s.ac_gl_no = m.dr_prod_ac AND dr_s.branch_code = m.dr_acc_brn;

PROMPT --- 8.6 Tagged amount_tag from ACTB_HISTORY also defined in CSTB_AMOUNT_TAG ---
SELECT COUNT(DISTINCT h.amount_tag) AS distinct_tags_in_history,
       SUM(CASE WHEN t.amount_tag IS NULL THEN 1 ELSE 0 END) AS tags_not_in_dictionary
FROM  (SELECT DISTINCT amount_tag FROM actb_history WHERE module = 'CL') h
LEFT   JOIN cstb_amount_tag t ON t.module = 'CL' AND t.amount_tag = h.amount_tag;

PROMPT --- 8.7 End-to-end sample : last 5 CL loans with their product + main GLs + schedule summary ---
SELECT m.account_number,
       m.branch_code,
       m.product_code,
       p.product_desc,
       p.product_category,
       m.currency,
       m.amount_financed,
       m.amount_disbursed,
       m.value_date,
       m.maturity_date,
       m.user_defined_status,
       m.cr_prod_ac,
       cr_s.ac_gl_desc AS cr_prod_ac_desc,
       m.dr_prod_ac,
       dr_s.ac_gl_desc AS dr_prod_ac_desc,
       (SELECT SUM(amount_overdue) FROM cltb_account_schedules s WHERE s.account_number = m.account_number) AS total_overdue
FROM   cltb_account_apps_master m
LEFT   JOIN cltm_product p   ON p.product_code = m.product_code
LEFT   JOIN sttb_account cr_s ON cr_s.ac_gl_no = m.cr_prod_ac AND cr_s.branch_code = m.cr_acc_brn
LEFT   JOIN sttb_account dr_s ON dr_s.ac_gl_no = m.dr_prod_ac AND dr_s.branch_code = m.dr_acc_brn
WHERE  m.auth_stat = 'A'
ORDER  BY m.book_date DESC NULLS LAST
FETCH  FIRST 5 ROWS ONLY;

SPOOL OFF
SET FEEDBACK ON
