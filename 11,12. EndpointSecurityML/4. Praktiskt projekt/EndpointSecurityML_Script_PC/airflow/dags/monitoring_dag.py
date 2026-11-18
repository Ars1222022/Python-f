"""monitoring_dag.py - kontrollerar att API:t är igång och att en modell är laddad."""

import os
from datetime import datetime, timedelta

import requests
from airflow import DAG
from airflow.operators.python import PythonOperator

API_URL = os.environ.get("API_URL", "http://api:8000")

default_args = {
    "owner": "ml_team",
    "start_date": datetime(2026, 3, 1),
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}

with DAG(
    dag_id="api_monitoring",
    default_args=default_args,
    schedule="0 * * * *",  # `schedule_interval` is deprecated in Airflow 2.x
    catchup=False,
    description="Verify API health and model availability",
) as dag:

    def check_api_health(**context):
        # Att kasta gör att uppgiften misslyckas synligt istället för att tyst
        # returnera en sträng - en monitoring-DAG som aldrig misslyckas är värdelös.
        response = requests.get(f"{API_URL}/health", timeout=5)
        response.raise_for_status()

        payload = response.json()
        if not payload.get("model_loaded"):
            raise RuntimeError(
                f"API is up but no model is loaded: {payload}"
            )
        return (
            f"OK version={payload.get('model_version')} "
            f"features={payload.get('features')}"
        )

    check_task = PythonOperator(
        task_id="check_api_health",
        python_callable=check_api_health,
        provide_context=True,
    )

