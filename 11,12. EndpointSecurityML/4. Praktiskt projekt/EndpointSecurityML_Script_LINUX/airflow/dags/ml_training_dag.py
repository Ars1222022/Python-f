"""ml_training_dag.py - tränar om modellen varje natt kl. 03:00.

Uses the SAME feature contract as src/api/utils.py (imported, not copied), so
the model this DAG produces is always loadable by the API.
"""

import glob
import os
import sys
from datetime import datetime, timedelta

import joblib
import pandas as pd
from airflow import DAG
from airflow.operators.python import PythonOperator
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score
from sklearn.model_selection import train_test_split

# Gör /opt/airflow/src importabelt så vi återanvänder API:ts feature-logik
sys.path.insert(0, "/opt/airflow")
from src.api.utils import (  # noqa: E402
    FEATURE_NAMES,
    is_suspicious,
    is_system_user,
)

DATA_DIR = os.environ.get("DATA_DIR", "/opt/airflow/data/raw")
MODEL_DIR = os.environ.get("MODEL_DIR", "/opt/airflow/models/production")
RANDOM_STATE = 42

default_args = {
    "owner": "ml_team",
    "start_date": datetime(2026, 3, 1),
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="ml_training",
    default_args=default_args,
    schedule="0 3 * * *",  # `schedule_interval` is deprecated in Airflow 2.x
    catchup=False,
    description="Train the endpoint model on the latest activity data",
) as dag:

    def train_model(**context):
        files = glob.glob(os.path.join(DATA_DIR, "*.csv"))
        if not files:
            raise FileNotFoundError(f"No CSV found in {DATA_DIR}")

        latest = max(files, key=os.path.getmtime)
        df = pd.read_csv(latest)

        df["IsSystemUser"] = df["Username"].map(is_system_user).astype(int)
        df["IsSuspiciousProcess"] = df["ProcessName"].map(is_suspicious).astype(int)

        X = df[FEATURE_NAMES]
        y = df["IsAttack"].astype(int)
        if y.nunique() < 2:
            raise ValueError("Only one class present - cannot train.")

        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=RANDOM_STATE, stratify=y
        )

        model = RandomForestClassifier(
            n_estimators=100, random_state=RANDOM_STATE, n_jobs=-1
        )
        model.fit(X_train, y_train)

        accuracy = accuracy_score(y_test, model.predict(X_test))
        f1 = f1_score(y_test, model.predict(X_test), zero_division=0)

        # makedirs saknades tidigare -> FileNotFoundError på en ren volym
        os.makedirs(MODEL_DIR, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        # Samma filnamnsmönster som API:ts get_model_version() förväntar sig
        path = os.path.join(MODEL_DIR, f"endpoint_model_{timestamp}.pkl")
        joblib.dump(model, path)

        return (
            f"accuracy={accuracy:.4f} f1={f1:.4f} "
            f"features={FEATURE_NAMES} saved={path}"
        )

    train_task = PythonOperator(
        task_id="train_model",
        python_callable=train_model,
        provide_context=True,
    )

