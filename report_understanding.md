# Rapport de compréhension — Gestion des crédits dans le système

Source : data dictionary (`loan_dict.csv`), rapport d'exploration `exploration.sql`, complément `exploration_complement.sql`, extraits du Plan Comptable COBAC/CEMAC.

---

## 1. Architecture générale du module CL

Le module **CL (Consumer/Corporate Lending)** de Flexcube gère le cycle de vie complet d'un crédit :

```
Création contrat → Décaissement → Échéancier (multi-composantes)
       → Accrual quotidien → Liquidation à l'échéance
       → Classification (changement de status si impayé)
       → Provisioning (dotation au pool)
       → Reprise (paiement) OU Write-off (créance irrécouvrable)
```

Toutes les écritures comptables traversent `ACTB_HISTORY` avec `module = 'CL'`. Pour les passages au statut "douteux/loss" les écritures contre-passent automatiquement les composantes en mode suspens (hors-bilan) et passent les dotations aux comptes de provision.

---

## 2. Tables clés et leur rôle

| Table | Rôle | Colonnes clés (verifiées dans le dictionnaire) |
|---|---|---|
| **CLTM_PRODUCT** | Catalogue produits crédit (paramétrage) | `product_code`, `product_category`, `product_type`, `module_code`, `contract_type`, `product_end_date` |
| **CLTB_ACCOUNT_APPS_MASTER** | 1 ligne par contrat de crédit | `account_number`, `branch_code`, `customer_id`, `product_code`, `currency`, `amount_financed`, `amount_disbursed`, `value_date`, `maturity_date`, `account_status`, **`user_defined_status`** (statut de classification), `dr_prod_ac`, `cr_prod_ac`, `dr_acc_brn`, `cr_acc_brn` |
| **CLTB_ACCOUNT_SCHEDULES** | Échéancier détaillé par composante | `account_number`, `component_name`, `schedule_due_date`, `amount_due`, `amount_settled`, `amount_overdue`, `susp_amt_due`, `susp_amt_settled`, `susp_amt_lcy`, `writeoff_amt`, `amount_waived`, `sch_status`, `schedule_flag` |
| **CSTB_AMOUNT_TAG** | Dictionnaire des balises comptables | `module`, `amount_tag`, `description`, `amount_tag_type`, `unrealised`, `track_receivable`, `track_payable`, `offset_amount_tag` |
| **ACTB_HISTORY** | Journal comptable (1 ligne par patte) | `module`, `trn_ref_no`, `event`, `ac_branch`, `ac_no`, `ac_ccy`, `drcr_ind`, `amount_tag`, `fcy_amount`, `lcy_amount`, `trn_dt`, `value_dt`, `product` |
| **STTB_ACCOUNT** | Référentiel GL + comptes client | `ac_gl_no`, `branch_code`, `ac_or_gl` (G/A), `gl_aclass_type`, `gl_category`, `ac_class`, `ac_gl_desc`, `ac_natural_gl` |

### Pivots fondamentaux

- **N° dossier crédit** = `CLTB_ACCOUNT_APPS_MASTER.account_number` = `ACTB_HISTORY.trn_ref_no`.
- **Compte client de règlement** : `CR_PROD_AC` (encaissements client) et `DR_PROD_AC` (décaissements vers client). Ces colonnes pointent vers `STTB_ACCOUNT.ac_gl_no` avec `ac_or_gl='A'`. Le n° de dossier crédit **n'est PAS** le n° de compte client.
- **Ecritures comptables** : `ACTB_HISTORY.ac_no` peut être soit un GL (`ac_or_gl='G'`) soit un compte client (`ac_or_gl='A'`), suivant la jambe de l'écriture.
- **Jointure CL ↔ Master** : `actb_history.trn_ref_no = cltb_account_apps_master.account_number` (vérifié en section 8 du rapport d'exploration).

---

## 3. Composantes de crédit (component_name / amount_tag)

Un crédit est décomposé en plusieurs composantes paramétrées dans le produit. Les balises CL repérées :

| Composante | Type tag | Rôle |
|---|---|---|
| **PRINCIPAL** | L | Capital prêté |
| **MAIN_INT** | I | Intérêt principal |
| **INT_RATE** | I | Intérêt taux variable |
| **COL_INT** | I | Intérêts collectés gros débiteurs |
| **PENAL_ODIN / ODIN_PNLTY** | P | Pénalité sur intérêt en retard |
| **PENAL_ODPR / ODPR_PNLTY / ODPR2_PNLRT** | P | Pénalité sur principal en retard |
| **PRE_PENALTY / ERLY_STLPNL** | M | Pénalité de remboursement anticipé |
| **PROC_FEE / PROCESS_FEE / FACLTY_FEE** | H/I | Frais de dossier / facilité |
| **MGT_FEE / MGT_FEES / MAN_FEE / MGTVAMI_FEE** | H | Frais de gestion |
| **APPR_FEE / APPVAMI_FEE** | H | Frais d'approbation |
| **HANDLNG_CHG / HANDG_CHG / LOAN_CHARGE** | H/O | Frais de manutention |
| **CAR_INS / HOME_INS / CREDLIF_INS** | H/I | Primes assurances |
| **MGT_TAX / INT_TAX / FACLTY_TAX / OTHER_TAX / CREDLIF_VAT** | H | TVA/taxes sur composantes |
| **PRIMEASS1 / PRIMEASS2** | H | Primes assurance prime asset |
| **PROVAMI_FEE** | H | Frais amortissement provision |

---

## 4. Statuts de classification (user_defined_status ↔ COBAC)

Les codes Flexcube vus dans les `amount_tag` et les contrats :

| Code | Signification | COBAC (classe 3) |
|---|---|---|
| **NORM** | Performant / sain | 30/31/32 selon durée |
| **WACH** | Watch / surveillance | 30-32 + suivi |
| **SUBS / SENS** | Substandard / Sensible | 341 Créances impayées |
| **OLEM** | Other Loans Especially Mentioned | 341 Créances impayées |
| **DOU1/DOU2/DOU3/DOU4/DOUB/DOUT** | Douteux niveaux progressifs | 343 (garantie Etat) / 344 (sûretés réelles) / 345 (autres) |
| **DECD / INFR** | Décédé / Infructueux | Idem douteux |
| **NANT** | Nantissement | 344 (couvert par sûretés réelles) |
| **DBTF** | Debt fully | À préciser |
| **DORM** | Dormant | Comptes sans mouvement |
| **MEMO** | Pour mémoire | Hors-bilan |
| **LOSS / WTL1/WTL2/WTL3** | Perte | 6921/6922 |
| **WOFF / WRO** | Write-off | 6921/6922 |

### Constat sur les données réelles (section C5)

Seuls **3 statuts** sont actuellement utilisés :

| Status | Nb contrats | Sum décaissé (XAF) | Outstanding | Suspense |
|---|---|---|---|---|
| NORM | 1955 | très grand | ~0 overdue | 0 |
| DOU1 | 15 | ~40,1 Md | ~147,6 M | ~2,34 M |
| SUBS | 2 | ~3,4 M | ~425 k | 0 |

**Taux NPL ≈ 17/1972 = 0,86 %** (très faible).

---

## 5. Codification des amount_tag (matrice composante × statut × action)

Format générique : `<COMPONENT>_<STATUS>_<ACTION>[_TADJ_<NBRN|OBRN>]`

### Actions principales

| Suffixe | Action métier | Effet |
|---|---|---|
| `_PROV` | **Dotation au provisioning (= alimentation du pool)** | DR 69x charge / CR 39x provision |
| `_PROV_TADJ_NBRN/OBRN` | Ajustement dotation (transfert agence) | Idem nouvelle/ancienne branche |
| `_PROV_TRFR_NBR/OBR` | Transfert solde provision entre agences | Reclassement intra-39 |
| `_WBACK_TRFR_NBR/OBR` | **Reprise de provision (writeback)** | DR 39x / CR 79x |
| `_SUSP` | Mise en suspens (intérêts/principal/charges) | DR cpte normal / CR cpte suspens (hors-bilan) |
| `_SREL` | Sortie de suspens → réel (paiement) | Inverse de SUSP |
| `_CONT` | Mise en hors-bilan (contingent) | Classe 9 |
| `_CREL` | Sortie hors-bilan → réel | Inverse de CONT |
| `_READ_SUSP / _READ_REAL` | Reclassement (read) suspens/réel | Reclasse |
| `_REAL` | Réalisation | Selon contexte |
| `_UNSEC` | Write-off non couvert | Passation perte |
| `_PWOF` | Partial Write-Off | Perte partielle |
| `_WOFF` | Write-Off complet | 6921/6922 |
| `_SACR / _SACL / _SLIQ` | Accrual / Liquidation / Reversal en suspens | Hors-bilan |
| `_RACR_SUSP` | Reversal accrual suspens | Inverse SACR |
| `_ROLL_SUSP / _SROL_SUSP` | Suspens en rollover | Roulement |
| `_OUT_SUSP_TRFR` | Transfert suspens entre branches | Reclassement inter-agence |

---

## 6. Schémas comptables types (mapping COBAC)

### a) Dotation provision (= **alimentation du loan loss pool**)
Déclenché par changement de statut vers SUBS/DOUx/LOSS.
```
DR  Cpte 69x — Dotations aux provisions sur créances clientèle   (charge)
CR  Cpte 39x — Provisions sur créances clientèle                  (passif = POOL)
```
amount_tag : `<COMPONENT>_PROV` (ex. `PRINCIPAL_PROV`, `MAIN_INT_PROV`)

**Le solde créditeur cumulé du compte 39 (et sous-comptes 391/392/393/394) = balance du loan loss pool à un instant T.**

### b) Reprise de provision
Déclenché par retour à NORM, paiement, ou clôture.
```
DR  Cpte 39x — Provisions sur créances clientèle
CR  Cpte 79x — Reprises de provisions
```
amount_tag : `<COMPONENT>_WBACK_TRFR_*` ou `_PROV` côté CR.

### c) Mise en suspens des intérêts (impayé > 3 mois)
Le COBAC impose que les intérêts décomptés sur créances en souffrance soient sortis du compte de produits et logés hors-bilan.
```
DR  Cpte produit 71x (extourne intérêts comptabilisés)
CR  Cpte hors-bilan suspens
```
amount_tag : `MAIN_INT_<STATUS>_SUSP`, `INT_RATE_<STATUS>_SUSP`, etc.

### d) Write-off / perte irrécouvrable
```
DR  Cpte 6921 (couverte par provision) ou 6922 (non couverte)
CR  Cpte 34x — Créance en souffrance
```
amount_tag : `PRINCIPAL_WOFF_UNSEC`, `_LOSS_UNSEC`, etc.

### Sous-comptes 39x à identifier dans `STTB_ACCOUNT`
- **391** Provisions sur créances impayées
- **392** Provisions sur créances immobilisées
- **393** Provisions sur créances douteuses couvertes par sûretés réelles ou garantie de l'Etat
- **394** Provisions sur créances douteuses non couvertes
- **395/396** Provisions sur créances crédit-bail (impayées / douteuses)

Ces GLs apparaissent dans `STTB_ACCOUNT.ac_gl_no` (avec `ac_or_gl='G'`). Le préfixe local de la banque pour le compte 39 reste à confirmer (voir section 9).

---

## 7. Constat fondamental sur les données

L'exécution de **C2** (top 80 GL mouvementés par module CL) et **C3** (combinaisons `amount_tag × event × GL` pour les tags suspects loss/prov/susp) a renvoyé **aucune ligne** :

- Aucun GL n'a été mouvementé par le module CL avec les patterns provision/loss/susp dans `ACTB_HISTORY`.
- Aucune balise `%PROV%`, `%LOSS%`, `%SUSP%`, `%WROFF%` n'a généré d'écriture CL.

### Interprétations possibles

1. **La banque n'a déclenché aucun cycle de provisioning automatique** via le module CL. Les balises sont définies dans `cstb_amount_tag` (paramétrage standard Flexcube) mais le moteur de classification automatique n'a pas tourné.
2. **Le provisioning est passé manuellement** via le module GL (journal manuel), donc dans `ACTB_HISTORY` avec `module ≠ 'CL'`.
3. **Le volume NPL est faible** (17 contrats sur 1972) et seul du **suspense au niveau échéance** est constaté (`susp_amt_due = 2,34 M XAF` sur DOU1), sans dotation au pool.

**Conséquence pratique** : pour répondre au mail de l'ED, le script de revue devra interroger `ACTB_HISTORY` **tous modules confondus** (CL + GL) sur les GLs identifiés comme appartenant à la classe COBAC 39 — pas seulement module CL.

---

## 8. Plan d'attaque pour le script final

### Q1 — Funding effectif du loan loss pool
- Identifier les GLs loss-pool via `STTB_ACCOUNT` (filtre sur `ac_natural_gl` préfixe 39x **OU** description / classe).
- Agréger `ACTB_HISTORY` (tous modules) sur ces GLs depuis l'origine.
- Total CR (dotations) − Total DR (reprises) = montant cumulé alimenté.
- Distinguer CL (auto) vs GL (manuel) par `module`.
- Par produit / DCP via jointure `trn_ref_no = account_number`.

### Q2 — Balance courante du pool
- Σ(CR) − Σ(DR) sur GLs 39x dans `ACTB_HISTORY` jusqu'à SYSDATE.
- Décomposition par sous-compte (391/392/393/394/395/396) et par branche / devise.
- Total global LCY (XAF).

### Q3 — Couverture des NPL
- Exposition NPL par contrat NPL :
  ```
  exposition = principal_outstanding 
             + intérêts_impayés (overdue) 
             + intérêts/charges en suspens (susp_amt_due)
  ```
  via `cltb_account_apps_master` × `cltb_account_schedules` filtré sur `user_defined_status IN ('SUBS','DOU1','DOU2','DOU3','DOU4','DOUB','DOUT','OLEM','SENS','LOSS','WOFF','WRO','WTL1','WTL2','WTL3','DECD','INFR')`.
- Détail par produit / DCP.
- Ratio = balance pool (Q2) / exposition NPL.

---

## 9. Précisions à confirmer avant d'écrire le script

1. **Préfixe GL exact des comptes 39 dans la banque** — la banque a numéroté ses GLs avec un préfixe local. Le script de revue devra confirmer via `STTB_ACCOUNT.ac_natural_gl LIKE '39%'` (ou pattern proche). À ajuster après lecture de la section 7.4/7.5 du rapport principal.
2. **Quels produits sont "product programs" et "DCPs"** au sens du mail de l'ED ? Faut-il un filtre sur `product_category` ou `product_type` ?
3. **Définition NPL** : statut système (`user_defined_status IN (...)`) suffit, ou faut-il croiser avec DPD ≥ 90 jours sur `cltb_account_schedules.schedule_due_date` ?
4. **Date d'arrêté** : SYSDATE ou date fixe (fin de mois) ?
5. **Taux de funding attendu par produit** (vient des product papers / DCPs, pas de la base) — paramètre à injecter en tête de script, ou laissé en NULL si non communiqué.
