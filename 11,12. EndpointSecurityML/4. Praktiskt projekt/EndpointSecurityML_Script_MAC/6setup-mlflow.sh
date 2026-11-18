#!/usr/bin/env bash
# =============================================================================
# 6setup-mlflow.sh - MLflow experiment tracking  (macOS / Linux)
# =============================================================================
# STEG 6 av 11 (valfritt - API:t fungerar utan det).  ./6setup-mlflow.sh
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Använder `mlflow server` istället för det deprecated `mlflow ui`.
#   - Använder en ABSOLUT sqlite-sökväg på en namngiven volym. Den relativa
#     sparade databasen utanför volymen, så varje `down -v` kastade tyst
#     experimenthistoriken.
#   - Genererar inte längre träningsskript genom att skriva över filer i src/.
#   - Tränar en gång så att UI:t inte är tomt när du öppnar det.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================================="
echo "STEP 6/11  -  MLFLOW"
echo "=========================================================="
echo ""

echo "1. Checking Docker..."
command -v docker >/dev/null 2>&1 || { echo "  Docker NOT found."; exit 1; }
docker info >/dev/null 2>&1 || { echo "  Docker daemon is NOT running."; exit 1; }
echo "  Docker OK"
echo ""

echo "2. Making sure PostgreSQL and the API are running..."
docker compose up -d postgres api >/dev/null 2>&1
echo "  Done"
echo ""

echo "3. Starting MLflow..."
if ! docker compose up -d --build mlflow; then
    echo "  Failed to start MLflow."
    echo "  Check: docker compose logs mlflow"
    exit 1
fi
echo "  Waiting for it to become healthy..."

ready=0
for i in $(seq 1 40); do
    sleep 5
    if curl -fsS --max-time 3 http://localhost:5000/health >/dev/null 2>&1; then
        ready=1
        break
    fi
    if [ $((i % 6)) -eq 0 ]; then
        echo "    still waiting... ($((i * 5))s)"
    fi
done

if [ $ready -ne 1 ]; then
    echo "  MLflow did not become healthy in time."
    echo "  Check: docker compose logs mlflow"
    exit 1
fi
echo "  MLflow is up"
echo ""

echo "4. Running one training pass so the UI has data..."
if [ ! -f data/raw/endpoint_seed.csv ]; then
    echo "  No seed data yet - generating..."
    docker compose run --rm -v "$PROJECT_ROOT:/work" -w /work \
        --entrypoint python api -m src.data_generation.generate_seed_data >/dev/null 2>&1
fi

if docker compose --profile training run --rm trainer; then
    echo "  Training run logged to MLflow"
else
    echo "  Training FAILED - the UI will be empty."
    echo "  Check: docker compose --profile training run --rm trainer"
fi
echo ""

echo "=========================================================="
echo "STEP 6 COMPLETE"
echo "=========================================================="
echo ""
echo "MLflow UI : http://localhost:5000"
echo ""
echo "In the UI, pick an experiment named EndpointSecurity_<date>."
echo ""
echo "VIEW LOGS:"
echo "  docker compose logs mlflow"
echo ""
echo "OPTIONAL - MLflow backed by SQL Server instead:"
echo "  ./7mlflow-kommandon-sqlserver.sh"
echo "  ./start-mlflow-sqlserver.sh"
echo ""
