#!/usr/bin/env bash
# =============================================================================
# 4setup-dvc.sh - Data Version Control (DVC)  (Linux)
# =============================================================================
# STEG 4 av 11 (valfritt).  ./4setup-dvc.sh
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Levererar inte längre en dvc.exe-binär. DVC körs i en container byggd från
#     Dockerfile.versioning, så samma skript fungerar på alla OS och kan aldrig
#     avvika från den pinnade DVC-versionen.
#   - Sätter DVC_UID till ditt eget id så filer inte skapas som root.
#   - Vägrar skriva över en befintlig .dvc-katalog.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================================="
echo "STEP 4/11  -  DATA VERSIONING (DVC)"
echo "=========================================================="
echo ""

echo "1. Checking Docker..."
command -v docker >/dev/null 2>&1 || { echo "  Docker NOT found. DVC runs in a container."; exit 1; }
docker info >/dev/null 2>&1 || { echo "  Docker daemon is NOT running."; exit 1; }
echo "  Docker OK"
echo ""

dvc() { docker compose --profile dvc run --rm dvc "$@"; }

# --- 2. DVC_UID --------------------------------------------------------------
# Containrar körs som root som standard och skulle skapa root-ägda filer i din
# utcheckning. Att mappa uid:t håller ägandet korrekt.
echo "2. Configuring DVC_UID..."
if [ -f .env ]; then
    if ! grep -q '^DVC_UID=' .env; then
        echo "DVC_UID=$(id -u)" >> .env
        echo "  Added DVC_UID=$(id -u) to .env"
    else
        echo "  DVC_UID already set"
    fi
fi
echo ""

# --- 3. INITIALISE -----------------------------------------------------------
echo "3. Initialising DVC..."
if [ -d .dvc ]; then
    echo "  .dvc already exists - skipping init (never overwrite it)"
else
    dvc init || { echo "  DVC init failed."; exit 1; }
    echo "  DVC initialised"
fi
echo ""

# --- 4. GIT CONFIG -----------------------------------------------------------
echo "4. Telling Git not to track the DVC internals..."
if [ -f .gitignore ]; then
    if ! grep -q '\.dvc/cache' .gitignore; then
        printf '\n# DVC internals (added by 4setup-dvc.sh)\n.dvc/cache/\n.dvc/tmp/\n' >> .gitignore
        echo "  .gitignore updated"
    else
        echo "  .gitignore already correct"
    fi
fi
echo ""

# --- 5. SPÅRA DATAMAPPEN ------------------------------------------------
echo "5. Tracking data/raw..."
dvc add data/raw || echo "  (already tracked, or nothing to add)"
echo ""

# --- 6. STATUS ---------------------------------------------------------------
echo "6. Current DVC status:"
dvc status
echo ""

echo "=========================================================="
echo "STEP 4 COMPLETE"
echo "=========================================================="
echo ""
echo "COMMON DVC COMMANDS:"
echo "  ./5dvc-kommandon.sh        interactive menu"
echo "  ./start-dvc.sh             shell inside the DVC container"
echo ""
echo "Or directly:"
echo "  docker compose --profile dvc run --rm dvc status"
echo "  docker compose --profile dvc run --rm dvc add data/raw"
echo "  docker compose --profile dvc run --rm dvc commit -m 'message'"
echo ""
