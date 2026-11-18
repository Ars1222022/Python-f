#!/usr/bin/env bash
# =============================================================================
# 8setup-api.sh - Bygger, tränar och startar FastAPI-tjänsten  (macOS/Linux)
# =============================================================================
# STEG 8 av 11.  ./8setup-api.sh     <-- det viktigaste steget
#
# Samma steg som Windows 8setup-api.ps1.
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Skriver inte längre över src/api/*.py. Originalet skrev över models.py,
#     utils.py och app.py med äldre kopior varje körning, vilket tyst tog bort
#     alla fixar och återförde feature-felet (2 mot 3 features).
#   - Använder Docker Compose-profiler istället för enstaka "docker run".
#   - Genererar träningsdata automatiskt så att träningen har något att läsa.
#   - Tränar en riktig modell och verifierar att en förutsägelse fungerar.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# macOS/Windows needs Docker Desktop file sharing configured, otherwise bind
# mountar visar tyst inaktuella filer. Varna en gång på macOS.
if [ "$(uname -s)" = "Darwin" ]; then
    echo "NOTE: on macOS open Docker Desktop -> Settings -> Resources ->"
    echo "      File sharing and make sure this folder is shared."
    echo ""
fi
echo "=========================================================="
echo "STEP 8/11  -  API (FastAPI)"
# macOS/Windows needs Docker Desktop file sharing configured, otherwise bind
# mountar visar tyst inaktuella filer. Varna en gång på macOS.
if [ "$(uname -s)" = "Darwin" ]; then
    echo "NOTE: on macOS open Docker Desktop -> Settings -> Resources ->"
    echo "      File sharing and make sure this folder is shared."
    echo ""
fi
echo "=========================================================="
echo ""

# --- 1. KONTROLLERA DOCKER ---------------------------------------------------------
echo "1. Checking Docker..."
if ! command -v docker >/dev/null 2>&1; then
    echo "  Docker NOT found. Install Docker Desktop / Docker Engine."
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo "  Docker daemon is NOT running. Start Docker and retry."
    exit 1
fi
echo "  Docker OK"
echo ""

# --- 2. STÄDA FÖREGÅENDE KÖRNING --------------------------------------------------
echo "2. Removing containers from any previous run..."
# Rör bara det här projektets containrar, aldrig global Docker-status.
docker compose down --remove-orphans >/dev/null 2>&1
echo "  Done"
echo ""

# --- 3. STARTA DATABAS + MLFLOW ----------------------------------------------
echo "3. Starting PostgreSQL and MLflow..."
if ! docker compose up -d postgres mlflow; then
    echo "  Failed to start the base services."
    echo "  Check: docker compose logs"
    exit 1
fi
echo "  Waiting for health (the first build can take several minutes)..."

ready=0
for i in $(seq 1 60); do
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
    echo "  Inspect with: docker compose logs mlflow"
    exit 1
fi
echo "  MLflow is up at http://localhost:5000"
echo ""

# --- 4. SEED DATA ------------------------------------------------------------
# Utan en CSV i data/raw avslutas varje träningsskript med "no data found",
# vilket var den vanligaste anledningen till att en ny klon inte startade.
echo "4. Making sure training data exists..."
if [ -f data/raw/endpoint_seed.csv ]; then
    echo "  data/raw/endpoint_seed.csv already exists"
else
    echo "  Generating synthetic seed data (1000 rows)..."
    docker compose run --rm -v "$PROJECT_ROOT:/work" -w /work \
        --entrypoint python api -m src.data_generation.generate_seed_data
    if [ $? -ne 0 ]; then
        echo "  Seed generation FAILED."
        exit 1
    fi
    echo "  Seed data created"
fi
echo ""

# --- 5. TRÄNA EN MODELL --------------------------------------------------------
# API:t svarar 503 utan en modell, så vi tränar först.
echo "5. Training the model..."
if ! docker compose --profile training run --rm trainer; then
    echo "  Training FAILED."
    echo "  Re-run manually: docker compose --profile training run --rm trainer"
    exit 1
fi

MODEL=$(ls -t models/production/*.pkl 2>/dev/null | head -1)
if [ -z "$MODEL" ]; then
    echo "  No .pkl found in models/production"
    exit 1
fi
echo "  Model saved: $(basename "$MODEL")"
echo ""

# --- 6. STARTA API:t --------------------------------------------------------
echo "6. Starting the API..."
if ! docker compose up -d api; then
    echo "  Failed to start the API."
    echo "  Check: docker compose logs api"
    exit 1
fi

api_up=0
for i in $(seq 1 30); do
    sleep 3
    if curl -fsS --max-time 3 http://localhost:8000/health >/dev/null 2>&1; then
        api_up=1
        break
    fi
done

if [ $api_up -ne 1 ]; then
    echo "  The API did not respond in time."
    echo "  Check: docker compose logs api"
    exit 1
fi
echo "  API is up"
echo ""

# --- 7. KONTROLLERA HÄLSA OCH EN RIKTIG FÖRUTSÄGELSE ------------------------------------
echo "7. Verifying..."

HEALTH=$(curl -s --max-time 10 http://localhost:8000/health)
echo "  $HEALTH"

# En förutsägelse som aldrig körs är exakt det fel originalskripten missade.
RESPONSE=$(curl -s --max-time 15 -X POST http://localhost:8000/predict \
    -H 'Content-Type: application/json' \
    -d '{"NetworkConnections": 25, "ProcessName": "mimikatz.exe", "Username": "attacker"}')

if [ -z "$RESPONSE" ]; then
    echo "  PREDICTION FAILED - the model could not be loaded."
    echo "  This usually means the trained model and the API disagree on the"
    echo "  feature set. Check: docker compose logs api"
    exit 1
fi
echo "  prediction: $RESPONSE"
echo ""

# --- 8. SUMMARY -------------------------------------------------------------
# macOS/Windows needs Docker Desktop file sharing configured, otherwise bind
# mountar visar tyst inaktuella filer. Varna en gång på macOS.
if [ "$(uname -s)" = "Darwin" ]; then
    echo "NOTE: on macOS open Docker Desktop -> Settings -> Resources ->"
    echo "      File sharing and make sure this folder is shared."
    echo ""
fi
echo "=========================================================="
echo "STEP 8 COMPLETE"
# macOS/Windows needs Docker Desktop file sharing configured, otherwise bind
# mountar visar tyst inaktuella filer. Varna en gång på macOS.
if [ "$(uname -s)" = "Darwin" ]; then
    echo "NOTE: on macOS open Docker Desktop -> Settings -> Resources ->"
    echo "      File sharing and make sure this folder is shared."
    echo ""
fi
echo "=========================================================="
echo ""
echo "YOUR SERVICES:"
echo "  API docs : http://localhost:8000/docs"
echo "  Health   : http://localhost:8000/health"
echo "  Metrics  : http://localhost:8000/metrics"
echo "  MLflow   : http://localhost:5000"
echo ""
echo "TEST A PREDICTION:"
echo "  curl -X POST http://localhost:8000/predict \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"NetworkConnections\":25,\"ProcessName\":\"mimikatz.exe\",\"Username\":\"attacker\"}'"
echo ""
echo "USEFUL COMMANDS:"
echo "  docker compose logs -f api                        # follow logs"
echo "  docker compose ps                                  # status"
echo "  docker compose down                                # stop all"
echo "  docker compose --profile training run --rm trainer # retrain"
echo ""
echo "Next steps:"
echo "  ./9setup-monitoring.sh    -  Prometheus + Grafana"
echo "  ./10setup-airflow.sh      -  orchestration"
echo ""

