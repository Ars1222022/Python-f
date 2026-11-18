"""train_no_mlflow.py - träna en modell utan MLflow-spårning.

Useful for quick local iteration. Uses the exact same feature contract as
train_with_mlflow.py, so the resulting .pkl is drop-in compatible with the API.
"""

import argparse
import glob
import os
import sys
from datetime import datetime

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from src.api.utils import FEATURE_NAMES, is_suspicious, is_system_user  # noqa: E402

DATA_DIR = os.environ.get("DATA_DIR", "data/raw")
MODEL_DIR = os.environ.get("MODEL_DIR", "models/production")
RANDOM_STATE = 42


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--n-estimators", type=int, default=100)
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

    model = RandomForestClassifier(
        n_estimators=args.n_estimators, random_state=RANDOM_STATE, n_jobs=-1
    )
    model.fit(X_train, y_train)

    accuracy = accuracy_score(y_test, model.predict(X_test))
    print(f"Accuracy: {accuracy:.3f}")

    # makedirs saknades här - det orsakade FileNotFoundError på en ren klon
    os.makedirs(MODEL_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    model_path = os.path.join(MODEL_DIR, f"endpoint_model_{timestamp}.pkl")
    joblib.dump(model, model_path)
    print(f"Model saved: {model_path}")
    print("Training complete.")


if __name__ == "__main__":
    main()

