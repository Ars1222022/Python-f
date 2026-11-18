"""train_with_mlflow_sqlserver.py - LEGACY / OPTIONAL.

Same training logic as train_with_mlflow.py but tracks to SQL Server instead of
the bundled MLflow server.

Use only if you already run SQL Server. It needs pyodbc + the Microsoft ODBC
Driver, which does not build reliably on Linux/ARM - prefer the default
PostgreSQL-backed train_with_mlflow.py everywhere else.

Feature engineering is imported from src.api.utils so this stays compatible
with the API.
"""

import argparse
import glob
import os
import sys
from datetime import datetime

import joblib
import mlflow
import mlflow.sklearn
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score
from sklearn.model_selection import train_test_split

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from src.api.utils import FEATURE_NAMES, is_suspicious, is_system_user  # noqa: E402

DATA_DIR = os.environ.get("DATA_DIR", "data/raw")
MODEL_DIR = os.environ.get("MODEL_DIR", "models/production")
RANDOM_STATE = 42

DEFAULT_URI = (
    "mssql+pyodbc://@localhost/EndpointSecurityML"
    "?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--n-estimators", type=int, default=100)
    parser.add_argument("--max-depth", type=int, default=10)
    parser.add_argument(
        "--tracking-uri",
        default=os.environ.get("MLFLOW_TRACKING_URI", DEFAULT_URI),
        help="SQL Server MLflow backend URI",
    )
    args = parser.parse_args()

    files = glob.glob(os.path.join(DATA_DIR, "*.csv"))
    if not files:
        raise FileNotFoundError(f"No CSV found in {DATA_DIR!r}")
    latest = max(files, key=os.path.getmtime)
    print(f"Data file: {latest}")

    df = pd.read_csv(latest)
    df["IsSystemUser"] = df["Username"].map(is_system_user).astype(int)
    df["IsSuspiciousProcess"] = df["ProcessName"].map(is_suspicious).astype(int)

    X = df[FEATURE_NAMES]
    y = df["IsAttack"].astype(int)
    if y.nunique() < 2:
        raise ValueError("Training data contains only one class.")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=RANDOM_STATE, stratify=y
    )

    mlflow.set_tracking_uri(args.tracking_uri)
    mlflow.set_experiment(f"EndpointSecurity_{datetime.now():%Y%m%d}")

    with mlflow.start_run() as run:
        mlflow.log_param("model_type", "RandomForestClassifier")
        mlflow.log_param("n_estimators", args.n_estimators)
        mlflow.log_param("max_depth", args.max_depth)
        mlflow.log_param("random_state", RANDOM_STATE)
        mlflow.log_param("data_file", os.path.basename(latest))
        mlflow.log_param("features", ",".join(FEATURE_NAMES))

        model = RandomForestClassifier(
            n_estimators=args.n_estimators,
            max_depth=args.max_depth,
            random_state=RANDOM_STATE,
            n_jobs=-1,
        )
        model.fit(X_train, y_train)

        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        precision = precision_score(y_test, y_pred, zero_division=0)
        recall = recall_score(y_test, y_pred, zero_division=0)
        f1 = f1_score(y_test, y_pred, zero_division=0)

        mlflow.log_metric("accuracy", accuracy)
        mlflow.log_metric("precision", precision)
        mlflow.log_metric("recall", recall)
        mlflow.log_metric("f1_score", f1)
        for name, importance in zip(FEATURE_NAMES, model.feature_importances_):
            mlflow.log_metric(f"importance_{name}", float(importance))

        print(
            f"\nAccuracy: {accuracy:.3f}\nPrecision: {precision:.3f}"
            f"\nRecall: {recall:.3f}\nF1: {f1:.3f}"
        )

        mlflow.sklearn.log_model(model, "random_forest_model")

        os.makedirs(MODEL_DIR, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        model_path = os.path.join(MODEL_DIR, f"endpoint_model_{timestamp}.pkl")
        joblib.dump(model, model_path)
        print(f"Model saved: {model_path}")
        print(f"MLflow run: {run.info.run_id}")

    print("Training complete.")


if __name__ == "__main__":
    main()
