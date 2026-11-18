#!/usr/bin/env bash
# =============================================================================
# 10setup-airflow.sh - Airflow orchestration  (Linux)
# =============================================================================
# STEG 10 av 11 (valfritt).  ./10setup-airflow.sh
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Det hårdkodade nätverket "endpointsecuritymluppgift1_default" är BORTA. Det
#     gamla körde `docker run --network ...` piped till /dev/null, så när mappen
#     bytte namn misslyckades migreringen tyst och Airflow crashloopade mot en
#     omigrerad databas.
#   - Migreringen är nu en riktig `airflow-init`-tjänst i docker-compose.yml som
#     kör FÖRE webservern och schemaläggaren.
#   - LocalExecutor ersätter CeleryExecutor, så ingen Redis broker/worker behövs
#     för en demo med en enda nod.
#   - Webserverns hälsa kontrolleras faktiskt innan framgång rapporteras.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================================="
echo "STEP 10/11  -  AIRFLOW"
echo "=========================================================="
echo ""

echo "1. Checking Docker..."
command -v docker >/dev/null 2>&1 || { echo "  Docker NOT found."; exit 1; }
docker info >/dev/null 2>&1 || { echo "  Docker daemon is NOT running."; exit 1; }
echo "  Docker OK"
echo ""

echo "2. Checking DAG folders..."
for d in airflow/dags airflow/logs airflow/plugins models/production data/raw; do
    [ -d "$d" ] || { mkdir -p "$d"; echo "  Created: $d"; }
done
echo ""

echo "3. Checking the DAGs..."
if [ -z "$(ls airflow/dags/*.py 2>/dev/null)" ]; then
    echo "  No DAGs found in airflow/dags"
    echo "  Expected: ml_training_dag.py and monitoring_dag.py"
    exit 1
fi
for dag in airflow/dags/*.py; do
    echo "  Found: $(basename "$dag")"
done
echo ""

echo "4. Making sure the DAG has data..."
if [ ! -f data/raw/endpoint_seed.csv ]; then
    echo "  No seed data - generating..."
    docker compose run --rm -v "$PROJECT_ROOT:/work" -w /work \
        --entrypoint python api -m src.data_generation.generate_seed_data >/dev/null 2>&1
    [ -f data/raw/endpoint_seed.csv ] && echo "  Seed data created"
else
    echo "  Seed data present"
fi
echo ""

echo "5. Starting the Airflow stack..."
echo "  (the first build installs the Airflow image and takes a while)"
if ! docker compose --profile airflow up -d; then
    echo "  Failed to start Airflow."
    echo "  Check: docker compose --profile airflow logs"
    exit 1
fi
echo ""

# airflow-init måste klara sig, annars crashloopar webservern.
echo "6. Waiting for the database migration..."
migrated=0
for i in $(seq 1 60); do
    sleep 5
    if docker compose ps --status exited --format '{{.Service}}' 2>/dev/null | grep -q airflow-init; then
        if docker compose logs airflow-init 2>&1 | grep -qiE 'error|fatal|Traceback'; then
            echo "  Migration FAILED:"
            docker compose logs airflow-init 2>&1 | tail -20 | sed 's/^/  /'
            exit 1
        fi
        migrated=1
        break
    fi
    if [ $((i % 6)) -eq 0 ]; then
        echo "    migrating... ($((i * 5))s)"
    fi
done

if [ $migrated -eq 1 ]; then
    echo "  Database migrated"
else
    echo "  Migration did not finish in time."
    echo "  Check: docker compose logs airflow-init"
fi
echo ""

echo "7. Waiting for the Airflow UI..."
up=0
for i in $(seq 1 40); do
    sleep 5
    if curl -fsS --max-time 3 http://localhost:8080/health >/dev/null 2>&1; then
        up=1
        break
    fi
    if [ $((i % 6)) -eq 0 ]; then
        echo "    waiting... ($((i * 5))s)"
    fi
done

if [ $up -ne 1 ]; then
    echo "  The Airflow UI did not respond in time."
    echo "  Check: docker compose logs airflow-webserver"
    exit 1
fi
echo "  Airflow is up"
echo ""

echo "=========================================================="
echo "STEP 10 COMPLETE"
echo "=========================================================="
echo ""
echo "  Airflow UI : http://localhost:8080   (admin / admin)"
echo ""
echo "EXPECTED DAGS:"
echo "  ml_training    - retrains the model every night at 03:00"
echo "  api_monitoring - checks API health every hour"
echo ""
echo "USEFUL COMMANDS:"
echo "  docker compose --profile airflow ps"
echo "  docker compose --profile airflow logs -f airflow-scheduler"
echo "  docker compose --profile airflow down"
echo ""
echo "Next step:"
echo "  ./11setup-github-actions.sh  -  CI/CD"
echo ""
