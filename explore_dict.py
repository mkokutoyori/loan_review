import pandas as pd
import os

CSV_PATH = os.path.join(os.path.dirname(__file__), "loan_dict.csv")

df = pd.read_csv(CSV_PATH)
df.columns = df.columns.str.strip().str.upper()

SEPARATOR = "=" * 80

# =============================================================================
# SECTION 1 – VUE D'ENSEMBLE DU DICTIONNAIRE DE DONNÉES
# =============================================================================
print(SEPARATOR)
print("SECTION 1 – VUE D'ENSEMBLE DU DICTIONNAIRE DE DONNÉES")
print(SEPARATOR)

total_tables  = df["TABLE_NAME"].nunique()
total_columns = len(df)
print(f"\nNombre total de tables  : {total_tables}")
print(f"Nombre total de colonnes: {total_columns}")

print("\n--- Toutes les tables (triées par nombre de colonnes décroissant) ---\n")
table_counts = (
    df.groupby("TABLE_NAME")["COLUMN_NAME"]
    .count()
    .reset_index()
    .rename(columns={"COLUMN_NAME": "NB_COLONNES"})
    .sort_values("NB_COLONNES", ascending=False)
    .reset_index(drop=True)
)
table_counts.index += 1
print(table_counts.to_string())

print("\n--- Répartition par type de données ---\n")
dtype_counts = df["DATA_TYPE"].value_counts().reset_index()
dtype_counts.columns = ["DATA_TYPE", "COUNT"]
print(dtype_counts.to_string(index=False))

# =============================================================================
# SECTION 2 – FOCUS SUR LES 6 TABLES CLÉS
# =============================================================================
print("\n" + SEPARATOR)
print("SECTION 2 – FOCUS SUR LES 6 TABLES CLÉS")
print(SEPARATOR)

KEY_TABLES = [
    "ACTB_HISTORY",
    "CLTB_ACCOUNT_APPS_MASTER",
    "STTB_ACCOUNT",
    "CSTB_AMOUNT_TAG",
    "CLTB_ACCOUNT_SCHEDULES",
    "CLTM_PRODUCT",
]

for tbl in KEY_TABLES:
    subset = df[df["TABLE_NAME"] == tbl].copy()
    print(f"\n{'─' * 70}")
    print(f"TABLE : {tbl}  ({len(subset)} colonnes)")
    print(f"{'─' * 70}")

    for dtype, grp in subset.groupby("DATA_TYPE"):
        cols = grp["COLUMN_NAME"].tolist()
        print(f"\n  [{dtype}]")
        for i in range(0, len(cols), 4):
            print("    " + "  |  ".join(cols[i:i+4]))

# =============================================================================
# SECTION 3 – ANALYSE DES RELATIONS INTER-TABLES (colonnes de jointure)
# =============================================================================
print("\n" + SEPARATOR)
print("SECTION 3 – RELATIONS INTER-TABLES (colonnes communes entre tables clés)")
print(SEPARATOR)

key_df = df[df["TABLE_NAME"].isin(KEY_TABLES)].copy()

col_table_map = (
    key_df.groupby("COLUMN_NAME")["TABLE_NAME"]
    .apply(list)
    .reset_index()
)
col_table_map["NB_TABLES"] = col_table_map["TABLE_NAME"].apply(len)

shared = (
    col_table_map[col_table_map["NB_TABLES"] > 1]
    .sort_values("NB_TABLES", ascending=False)
    .reset_index(drop=True)
)

print(f"\n{len(shared)} colonnes partagées entre au moins 2 tables clés :\n")
for _, row in shared.iterrows():
    tables_str = "  ↔  ".join(sorted(row["TABLE_NAME"]))
    print(f"  {row['COLUMN_NAME']:<35} ({row['NB_TABLES']} tables)  {tables_str}")

# =============================================================================
# SECTION 4 – AUTRES TABLES CLTB_* POTENTIELLEMENT UTILES
# =============================================================================
print("\n" + SEPARATOR)
print("SECTION 4 – AUTRES TABLES CLTB_* POTENTIELLEMENT UTILES")
print(SEPARATOR)

other_cltb = df[
    df["TABLE_NAME"].str.startswith("CLTB_") &
    ~df["TABLE_NAME"].isin(KEY_TABLES)
].copy()

tables_of_interest = [
    "CLTB_ACCOUNT_COMPONENTS",
    "CLTB_ACCOUNT_HISTORY",
    "CLTB_EVENT_ENTRIES",
    "CLTB_LIQ",
    "CLTB_LIQ_SETTLEMENTS",
    "CLTB_ACCOUNT_COMP_SCH",
    "CLTB_ACCOUNT_EVENTS_DIARY",
    "CLTB_ACCOUNT_UDE_VALUES",
]

for tbl in tables_of_interest:
    subset = df[df["TABLE_NAME"] == tbl]
    if subset.empty:
        print(f"\n  {tbl}: non trouvée dans le dictionnaire")
        continue
    cols = subset["COLUMN_NAME"].tolist()
    print(f"\n  {tbl} ({len(cols)} colonnes):")
    for i in range(0, len(cols), 5):
        print("    " + "  |  ".join(cols[i:i+5]))

print("\n" + SEPARATOR)
print("FIN DE L'EXPLORATION DU DICTIONNAIRE DE DONNÉES")
print(SEPARATOR)
