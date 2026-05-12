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
