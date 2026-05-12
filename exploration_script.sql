-- =============================================================================
-- SCRIPT D'EXPLORATION - REVUE DES CREDITS BANCAIRES (MODULE CL)
-- =============================================================================
-- Objectif : Explorer la structure des donnees de credit dans Flexcube pour
--            comprendre comment sont gerees les informations liees aux prets,
--            avant de rediger le script final d'analyse pour le rapport ED.
--
-- Tables principales : actb_history (MODULE='CL'), cltb_account_apps_master,
--                      sttb_account, cstb_amount_tag, cltb_account_schedules,
--                      cltm_product
--
-- NOTE : Executer avec SET SERVEROUTPUT ON si utilise en mode PL/SQL.
--        Ce script est un fichier SQL*Plus : executer en une seule fois via :
--        @exploration_script.sql  (dans SQL*Plus / SQLcl)
-- =============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET FEEDBACK ON
SET ECHO OFF
SET TRIM ON
SET WRAP OFF
SET COLSEP ' | '

COLUMN amount_tag        FORMAT A35
COLUMN description       FORMAT A60
COLUMN amount_tag_type   FORMAT A5
COLUMN unrealised        FORMAT A12
COLUMN track_receivable  FORMAT A16
COLUMN track_payable     FORMAT A13
COLUMN charge_allowed    FORMAT A15
COLUMN interest_allowed  FORMAT A16

-- =============================================================================
-- SECTION 1 : TAGS DE MONTANT DU MODULE CL (CSTB_AMOUNT_TAG)
-- =============================================================================
-- Objectif : Identifier tous les tags comptables utilises dans le module CL :
--   - principal, interets, commissions, penalites, provisions, etc.
--   - comprendre si les montants sont realises ou non, suivis en receivable/payable
-- =============================================================================

PROMPT
PROMPT =============================================================================
PROMPT SECTION 1 : CSTB_AMOUNT_TAG - TAGS DU MODULE CL
PROMPT =============================================================================
PROMPT

PROMPT --- 1a. Liste complete des AMOUNT_TAG pour MODULE = 'CL' ---
PROMPT

SELECT
    at.amount_tag,
    at.description,
    at.amount_tag_type,
    at.unrealised,
    at.track_receivable,
    at.track_payable,
    at.charge_allowed,
    at.interest_allowed
FROM cstb_amount_tag at
WHERE at.module = 'CL'
ORDER BY at.amount_tag;

PROMPT
PROMPT --- 1b. Repartition par TYPE de tag (AMOUNT_TAG_TYPE) ---
PROMPT

SELECT
    at.amount_tag_type,
    COUNT(*)        nb_tags
FROM cstb_amount_tag at
WHERE at.module = 'CL'
GROUP BY at.amount_tag_type
ORDER BY nb_tags DESC;

PROMPT
PROMPT --- 1c. Tags lies aux receivables / payables ---
PROMPT

SELECT
    at.amount_tag,
    at.description,
    at.track_receivable,
    at.track_payable
FROM cstb_amount_tag at
WHERE at.module = 'CL'
  AND (at.track_receivable = 'Y' OR at.track_payable = 'Y')
ORDER BY at.amount_tag;


-- =============================================================================
-- SECTION 2 : PRODUITS DE CREDIT (CLTM_PRODUCT)
-- =============================================================================
-- Objectif : Lister tous les produits de credit avec leurs caracteristiques
--   cles pour identifier les product programs et DCPs concernes par la revue.
-- =============================================================================

PROMPT
PROMPT =============================================================================
PROMPT SECTION 2 : CLTM_PRODUCT - PRODUITS DE CREDIT
PROMPT =============================================================================
PROMPT

COLUMN product_code      FORMAT A15
COLUMN product_desc      FORMAT A45
COLUMN product_category  FORMAT A20
COLUMN product_type      FORMAT A15
COLUMN contract_type     FORMAT A15
COLUMN liquidation_mode  FORMAT A18
COLUMN module_code       FORMAT A12
COLUMN record_stat       FORMAT A12
COLUMN auth_stat         FORMAT A10

PROMPT --- 2a. Liste de tous les produits de credit ---
PROMPT

SELECT
    p.product_code,
    p.product_desc,
    p.product_category,
    p.product_type,
    p.contract_type,
    p.liquidation_mode,
    p.module_code,
    p.record_stat,
    p.auth_stat
FROM cltm_product p
ORDER BY p.product_category, p.product_code;

PROMPT
PROMPT --- 2b. Produits actifs (RECORD_STAT = 'O') ---
PROMPT

SELECT
    p.product_code,
    p.product_desc,
    p.product_category,
    p.product_type,
    p.contract_type,
    p.liquidation_mode
FROM cltm_product p
WHERE p.record_stat = 'O'
ORDER BY p.product_category, p.product_code;

PROMPT
PROMPT --- 2c. Repartition par categorie et type de produit ---
PROMPT

SELECT
    p.product_category,
    p.product_type,
    COUNT(*)   nb_produits
FROM cltm_product p
GROUP BY p.product_category, p.product_type
ORDER BY nb_produits DESC;

PROMPT
PROMPT --- 2d. Categories de produits distinctes ---
PROMPT

SELECT DISTINCT
    pc.product_category,
    pc.product_type
FROM cltm_product_category pc
ORDER BY pc.product_category;


-- =============================================================================
-- SECTION 3 : VUE D'ENSEMBLE DES DOSSIERS DE CREDIT (CLTB_ACCOUNT_APPS_MASTER)
-- =============================================================================
-- Objectif : Comprendre le volume et la repartition des dossiers de credit :
--   - statuts (actif, liquide, NPL, en souffrance...)
--   - produits utilises et montants finances / decaisses
--   - comptes rattaches (dr_prod_ac / cr_prod_ac)
--   - structure des champs cles
-- =============================================================================

PROMPT
PROMPT =============================================================================
PROMPT SECTION 3 : CLTB_ACCOUNT_APPS_MASTER - DOSSIERS DE CREDIT
PROMPT =============================================================================
PROMPT

COLUMN account_status     FORMAT A16
COLUMN derived_status     FORMAT A20
COLUMN delinquency_status FORMAT A20
COLUMN user_def_status    FORMAT A25
COLUMN product_code       FORMAT A15
COLUMN nb_dossiers        FORMAT 999,999,990
COLUMN total_finance      FORMAT 999,999,999,990
COLUMN total_decaisse     FORMAT 999,999,999,990
COLUMN premier_credit     FORMAT A13
COLUMN dernier_credit     FORMAT A13

PROMPT --- 3a. Repartition par ACCOUNT_STATUS ---
PROMPT

SELECT
    a.account_status,
    COUNT(*)             nb_dossiers
FROM cltb_account_apps_master a
GROUP BY a.account_status
ORDER BY nb_dossiers DESC;

PROMPT
PROMPT --- 3b. Repartition par DERIVED_STATUS ---
PROMPT

SELECT
    a.derived_status,
    COUNT(*)             nb_dossiers
FROM cltb_account_apps_master a
GROUP BY a.derived_status
ORDER BY nb_dossiers DESC;

PROMPT
PROMPT --- 3c. Repartition par DELINQUENCY_STATUS ---
PROMPT

SELECT
    a.delinquency_status,
    COUNT(*)             nb_dossiers
FROM cltb_account_apps_master a
GROUP BY a.delinquency_status
ORDER BY nb_dossiers DESC;

PROMPT
PROMPT --- 3d. Repartition par USER_DEFINED_STATUS ---
PROMPT

SELECT
    a.user_defined_status,
    COUNT(*)             nb_dossiers
FROM cltb_account_apps_master a
GROUP BY a.user_defined_status
ORDER BY nb_dossiers DESC;

PROMPT
PROMPT --- 3e. Volumes par produit (montants finances et decaisses) ---
PROMPT

SELECT
    a.product_code,
    a.currency,
    COUNT(*)                                    nb_dossiers,
    SUM(a.amount_financed)                      total_finance,
    SUM(a.amount_disbursed)                     total_decaisse,
    TO_CHAR(MIN(a.book_date), 'DD-MON-YYYY')   premier_credit,
    TO_CHAR(MAX(a.book_date), 'DD-MON-YYYY')   dernier_credit
FROM cltb_account_apps_master a
GROUP BY a.product_code, a.currency
ORDER BY total_finance DESC;

PROMPT
PROMPT --- 3f. Repartition par BRANCH_CODE ---
PROMPT

SELECT
    a.branch_code,
    COUNT(*)             nb_dossiers,
    SUM(a.amount_financed) total_finance
FROM cltb_account_apps_master a
GROUP BY a.branch_code
ORDER BY nb_dossiers DESC;

PROMPT
PROMPT --- 3g. Comptes DR_PROD_AC et CR_PROD_AC distincts utilises ---
PROMPT

COLUMN dr_prod_ac FORMAT A20
COLUMN cr_prod_ac FORMAT A20

SELECT
    a.dr_prod_ac,
    a.cr_prod_ac,
    COUNT(*) nb_dossiers
FROM cltb_account_apps_master a
WHERE a.dr_prod_ac IS NOT NULL OR a.cr_prod_ac IS NOT NULL
GROUP BY a.dr_prod_ac, a.cr_prod_ac
ORDER BY nb_dossiers DESC;

PROMPT
PROMPT --- 3h. Echantillon de 5 dossiers recents (colonnes cles) ---
PROMPT

COLUMN account_number         FORMAT A20
COLUMN customer_id            FORMAT A15
COLUMN primary_applicant_name FORMAT A35
COLUMN branch_code            FORMAT A12
COLUMN currency               FORMAT A5
COLUMN amount_financed        FORMAT 999,999,999,990
COLUMN amount_disbursed       FORMAT 999,999,999,990

SELECT *
FROM (
    SELECT
        a.account_number,
        a.customer_id,
        a.primary_applicant_name,
        a.product_code,
        a.branch_code,
        a.currency,
        a.book_date,
        a.maturity_date,
        a.amount_financed,
        a.amount_disbursed,
        a.account_status,
        a.derived_status,
        a.delinquency_status,
        a.dr_prod_ac,
        a.cr_prod_ac
    FROM cltb_account_apps_master a
    ORDER BY a.book_date DESC
)
WHERE ROWNUM <= 5;


-- =============================================================================
-- SECTION 4 : TRANSACTIONS DE CREDIT DANS ACTB_HISTORY (MODULE = 'CL')
-- =============================================================================
-- Objectif : Comprendre comment les operations de credit sont enregistrees :
--   - quels AMOUNT_TAG sont utilises (principal, interets, provisions...)
--   - quels EVENTs sont declenchés (DSBR, LIQD, ACCR, STCH...)
--   - les TRN_CODE utilises
--   - les comptes GL (AC_NO) qui portent les ecritures CL
--   - le volume de transactions dans le temps
-- =============================================================================

PROMPT
PROMPT =============================================================================
PROMPT SECTION 4 : ACTB_HISTORY - TRANSACTIONS MODULE CL
PROMPT =============================================================================
PROMPT

COLUMN amount_tag    FORMAT A35
COLUMN nb_lignes     FORMAT 999,999,990
COLUMN total_debit   FORMAT 999,999,999,990
COLUMN total_credit  FORMAT 999,999,999,990
COLUMN event         FORMAT A15
COLUMN trn_code      FORMAT A15
COLUMN annee         FORMAT A6

PROMPT --- 4a. AMOUNT_TAG utilises dans le module CL (avec volumes) ---
PROMPT

SELECT
    h.amount_tag,
    COUNT(*)                                                          nb_lignes,
    SUM(CASE WHEN h.drcr_ind = 'D' THEN h.lcy_amount ELSE 0 END)   total_debit,
    SUM(CASE WHEN h.drcr_ind = 'C' THEN h.lcy_amount ELSE 0 END)   total_credit
FROM actb_history h
WHERE h.module = 'CL'
GROUP BY h.amount_tag
ORDER BY nb_lignes DESC;

PROMPT
PROMPT --- 4b. EVENTS utilises dans le module CL ---
PROMPT

SELECT
    h.event,
    COUNT(*)   nb_lignes
FROM actb_history h
WHERE h.module = 'CL'
GROUP BY h.event
ORDER BY nb_lignes DESC;

PROMPT
PROMPT --- 4c. TRN_CODE utilises dans le module CL ---
PROMPT

SELECT
    h.trn_code,
    COUNT(*)   nb_lignes
FROM actb_history h
WHERE h.module = 'CL'
GROUP BY h.trn_code
ORDER BY nb_lignes DESC;

PROMPT
PROMPT --- 4d. Volume de transactions CL par annee ---
PROMPT

SELECT
    TO_CHAR(h.trn_dt, 'YYYY')   annee,
    COUNT(*)                     nb_lignes,
    SUM(h.lcy_amount)            total_montant_lcy
FROM actb_history h
WHERE h.module = 'CL'
GROUP BY TO_CHAR(h.trn_dt, 'YYYY')
ORDER BY annee;

PROMPT
PROMPT --- 4e. Comptes GL (AC_NO) portant des ecritures CL (top 30) ---
PROMPT    (jointure avec sttb_account pour identifier la classe comptable)
PROMPT

COLUMN ac_no          FORMAT A20
COLUMN ac_gl_desc     FORMAT A45
COLUMN ac_natural_gl  FORMAT A14
COLUMN gl_category    FORMAT A12
COLUMN ac_or_gl       FORMAT A8

SELECT *
FROM (
    SELECT
        h.ac_no,
        s.ac_gl_desc,
        s.ac_natural_gl,
        s.gl_category,
        s.ac_or_gl,
        COUNT(*)                                                          nb_ecritures,
        SUM(CASE WHEN h.drcr_ind = 'D' THEN h.lcy_amount ELSE 0 END)   total_debit,
        SUM(CASE WHEN h.drcr_ind = 'C' THEN h.lcy_amount ELSE 0 END)   total_credit
    FROM actb_history h
    LEFT JOIN sttb_account s ON h.ac_no = s.ac_gl_no
    WHERE h.module = 'CL'
    GROUP BY h.ac_no, s.ac_gl_desc, s.ac_natural_gl, s.gl_category, s.ac_or_gl
    ORDER BY nb_ecritures DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT --- 4f. Echantillon de 10 transactions CL recentes ---
PROMPT

COLUMN trn_ref_no       FORMAT A30
COLUMN related_account  FORMAT A20
COLUMN lcy_amount       FORMAT 999,999,999,990
COLUMN trn_dt           FORMAT A13

SELECT *
FROM (
    SELECT
        h.trn_ref_no,
        h.ac_no,
        h.drcr_ind,
        h.amount_tag,
        h.lcy_amount,
        TO_CHAR(h.trn_dt, 'DD-MON-YYYY')   trn_dt,
        h.related_account,
        h.event,
        h.module,
        h.product
    FROM actb_history h
    WHERE h.module = 'CL'
    ORDER BY h.trn_dt DESC, h.event_sr_no DESC
)
WHERE ROWNUM <= 10;
