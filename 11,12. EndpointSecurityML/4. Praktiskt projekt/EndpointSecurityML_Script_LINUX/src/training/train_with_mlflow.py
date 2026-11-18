"""train_with_mlflow.py - canonical training script.

Trains a Random Forest on the newest CSV in DATA_DIR and logs params,
metrics, feature importances and the model itself to MLflow.

Feature engineering is imported from src.api.utils so training and serving
can never drift apart.
"""

import argparse
import glob
import os
import sys
from datetime import datetime

import joblib
import mlflow
import mlflow.sklearn
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score
from sklearn.model_selection import train_test_split

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from src.api.utils import FEATURE_NAMES, is_suspicious, is_system_user  # noqa: E402

DATA_DIR = os.environ.get("DATA_DIR", "data/raw")
MODEL_DIR = os.environ.get("MODEL_DIR", "models/production")
RANDOM_STATE = 42


def find_latest_csv():
    files = glob.glob(os.path.join(DATA_DIR, "*.csv"))
    if not files:
        raise FileNotFoundError(
            f"No CSV found in {DATA_DIR!r}. Run the data-generation step first."
        )
    return max(files, key=os.path.getmtime)


def build_features(df: pd.DataFrame) -> pd.DataFrame:
    """Hämta de delade featurekolumnerna ur råa aktivitetsrader."""
    df = df.copy()
    df["IsSystemUser"] = df["Username"].map(is_system_user).astype(int)
    df["IsSuspiciousProcess"] = df["ProcessName"].map(is_suspicious).astype(int)
    return df


def main():
    parser = argparse.ArgumentParser(description="Train the endpoint model")
    parser.add_argument("--n-estimators", type=int, default=100)
    parser.add_argument("--max-depth", type=int, default=10)
    parser.add_argument("--tracking-uri", default=os.environ.get("MLFLOW_TRACKING_URI"))
    args = parser.parse_args()

    latest = find_latest_csv()
    print(f"Data file: {latest}")
    df = pd.read_csv(latest)
    print(f"Rows: {len(df)}")

    df = build_features(df)
    X = df[FEATURE_NAMES]
    y = df["IsAttack"].astype(int)

    if y.nunique() < 2:
        raise ValueError("Training data contains only one class - nothing to learn.")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=RANDOM_STATE, stratify=y
    )
    print(f"Train: {len(X_train)}  Test: {len(X_test)}")
    print(f"Attack: {int(y.sum())}  Normal: {int(len(y) - y.sum())}")

    mlflow.set_tracking_uri(args.tracking_uri or "sqlite:///mlflow.db")
    experiment_name = f"EndpointSecurity_{datetime.now():%Y%m%d}"
    mlflow.set_experiment(experiment_name)

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
        print(f"Experiment: {experiment_name}")

    print("Training complete.")


if __name__ == "__main__":
    main()

