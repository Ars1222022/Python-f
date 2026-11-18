"""train_from_sql.py - träna direkt från databasen och lagra förutsägelser.

Reads endpoint activities straight from PostgreSQL (or SQL Server), trains
using the shared feature contract, saves the model and writes predictions
back to the ThreatDetections table.

The previous version used 5 features (including Hour/DayOfWeek) which the API
cannot supply, so the served model could never be used. It now uses the same
3 features as everything else.
"""

import argparse
import os
import sys
from datetime import datetime

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from src.api.utils import (  # noqa: E402
    FEATURE_NAMES,
    get_threat_type,
    is_suspicious,
    is_system_user,
)

DIALECT = os.environ.get("DB_DIALECT", "postgres")
MODEL_DIR = os.environ.get("MODEL_DIR", "models/production")
RANDOM_STATE = 42

PG_CONFIG = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": os.environ.get("PGPORT", "5432"),
    "user": os.environ.get("PGUSER", "airflow"),
    "password": os.environ.get("PGPASSWORD", "airflow"),
    "dbname": os.environ.get("PGDATABASE", "endpointsecurity"),
}

# PostgreSQL använder EXTRACT(HOUR ...); SQL Server använder DATEPART(HOUR ...)
HOUR_EXPR = "EXTRACT(HOUR FROM Timestamp)" if DIALECT == "postgres" else "DATEPART(HOUR, Timestamp)"

SELECT_SQL = f"""
SELECT ActivityID, Timestamp, ComputerName, Username, ProcessName,
       ParentProcess, NetworkConnections, IsAttack, ThreatType,
       {HOUR_EXPR} AS Hour
FROM endpoint_activities
"""

# %s är den portabla platshållaren för både psycopg och pyodbc
INSERT_SQL = """
INSERT INTO threat_detections
    (activity_id, detected_at, predicted_threat_type, confidence_score, model_version)
VALUES (%s, %s, %s, %s, %s)
"""


def get_connection():
    if DIALECT == "mssql":
        import pyodbc

        conn_str = (
            f"DRIVER={{{os.environ.get('MSSQL_DRIVER', 'ODBC Driver 17 for SQL Server')}}};"
            f"SERVER={os.environ.get('MSSQL_SERVER', 'localhost')};"
            f"DATABASE={os.environ.get('MSSQL_DATABASE', 'EndpointSecurityML')};"
            f"Trusted_Connection={os.environ.get('MSSQL_TRUSTED', 'yes')};"
        )
        return pyodbc.connect(conn_str, timeout=10)
    import psycopg

    return psycopg.connect(**PG_CONFIG)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--n-estimators", type=int, default=100)
    parser.add_argument("--max-depth", type=int, default=10)
    parser.add_argument(
        "--no-write-back",
        action="store_true",
        help="Train only; do not insert predictions back into the database",
    )
    args = parser.parse_args()

    print(f"Connecting to {DIALECT}...")
    conn = get_connection()

    print("Reading training data...")
    df = pd.read_sql(SELECT_SQL, conn)
    if df.empty:
        print("No rows in endpoint_activities. Load the seed data first.")
        conn.close()
        raise SystemExit(1)

    print(f"Loaded {len(df)} rows")
    print(f"  Normal: {int((df['IsAttack'] == 0).sum())}")
    print(f"  Attack: {int(df['IsAttack'].sum())}")

    df["IsSystemUser"] = df["Username"].map(is_system_user).astype(int)
    df["IsSuspiciousProcess"] = df["ProcessName"].map(is_suspicious).astype(int)

    X = df[FEATURE_NAMES]
    y = df["IsAttack"].astype(int)
    if y.nunique() < 2:
        print("Only one class present - cannot train.")
        conn.close()
        raise SystemExit(1)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=RANDOM_STATE, stratify=y
    )

    model = RandomForestClassifier(
        n_estimators=args.n_estimators,
        max_depth=args.max_depth,
        random_state=RANDOM_STATE,
        n_jobs=-1,
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    print("\n=== CLASSIFICATION REPORT ===")
    print(classification_report(y_test, y_pred, target_names=["Normal", "Attack"], zero_division=0))

    print("\n=== FEATURE IMPORTANCE ===")
    for name, importance in zip(FEATURE_NAMES, model.feature_importances_):
        print(f"  {name}: {importance:.3f}")

    os.makedirs(MODEL_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    model_path = os.path.join(MODEL_DIR, f"endpoint_model_{timestamp}.pkl")
    joblib.dump(model, model_path)
    print(f"\nModel saved: {model_path}")

    if args.no_write_back:
        print("Skipping write-back (--no-write-back).")
        conn.close()
        return

    print("\nWriting predictions back...")
    predictions = model.predict(X)
    confidences = model.predict_proba(X).max(axis=1)
    model_version = f"v{timestamp}"

    saved = 0
    with conn.cursor() as cur:
        for activity_id, pred, conf in zip(df["ActivityID"], predictions, confidences):
            try:
                cur.execute(
                    INSERT_SQL,
                    (
                        activity_id,
                        datetime.now(),
                        get_threat_type(pred),
                        float(conf),
                        model_version,
                    ),
                )
                saved += 1
            except Exception as exc:  # noqa: BLE001
                print(f"  warning: could not store row {activity_id}: {exc}")
                conn.rollback()
    conn.commit()
    print(f"Stored {saved} predictions")
    conn.close()
    print("\nDone.")


if __name__ == "__main__":
    main()

