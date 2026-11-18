#!/usr/bin/env bash
# =============================================================================
# 1setup-folders.sh - Skapar projektstrukturen  (macOS / Linux)
# =============================================================================
# STEG 1 av 11. Kör det här först:  ./1setup-folders.sh
#
# Samma steg som Windows 1setup-folders.ps1, översatta till bash.
# Skapar alla mappar projektet behöver och lägger till .gitkeep så tomma mappar
# följer med i git, kopierar .env.example -> .env och kontrollerar att Docker finns.
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
echo "STEP 1/11  -  FOLDER STRUCTURE"
# macOS/Windows needs Docker Desktop file sharing configured, otherwise bind
# mountar visar tyst inaktuella filer. Varna en gång på macOS.
if [ "$(uname -s)" = "Darwin" ]; then
    echo "NOTE: on macOS open Docker Desktop -> Settings -> Resources ->"
    echo "      File sharing and make sure this folder is shared."
    echo ""
fi
echo "=========================================================="
echo ""
echo "Project folder: $PROJECT_ROOT"
echo ""

# --- 1. KONTROLLERA DOCKER ---------------------------------------------------------
# Docker är det enda hårda kravet. Allt annat körs i containrar.
echo "1. Checking Docker..." | sed 's/^/  /'

if ! command -v docker >/dev/null 2>&1; then
    echo "  Docker NOT FOUND."
    echo "  macOS: install Docker Desktop - https://docs.docker.com/desktop/install/mac-install/"
    echo "  Linux: sudo apt install docker.io docker-compose-v2"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "  Docker Compose v2 is not available."
    echo "  Install the Compose plugin, then re-run."
    exit 1
fi
echo "  Docker $(docker version --format '{{.Client.Version}}') + Compose v2 OK"

if ! docker info >/dev/null 2>&1; then
    echo "  Docker daemon is NOT running. Start Docker and re-run this script."
    exit 1
fi
echo "  Daemon reachable"
echo ""

# --- 2. CREATE FOLDERS -------------------------------------------------------
echo "2. Creating folders..."

FOLDERS=(
    "data/raw" "data/processed" "models/production"
    "src/api" "src/training" "src/data_generation"
    "tests"
    "airflow/dags" "airflow/logs" "airflow/plugins"
    "prometheus"
    "grafana/dashboards"
    "grafana/provisioning/datasources" "grafana/provisioning/dashboards"
    "postgres/init"
    "k8s"
    ".github/workflows"
)

created=0
for folder in "${FOLDERS[@]}"; do
    if [ ! -d "$folder" ]; then
        mkdir -p "$folder"
        echo "  Created: $folder"
        created=$((created + 1))
    fi
done
echo "  $created new folder(s) created"
echo ""

# --- 3. .gitkeep FILES -------------------------------------------------------
# Git spårar inte tomma mappar; dessa håller strukturen synlig i en
# ny klon istället för att Docker skapar dem som root.
echo "3. Creating .gitkeep placeholders..."
for keep in data/raw/.gitkeep data/processed/.gitkeep \
            models/production/.gitkeep airflow/logs/.gitkeep \
            airflow/plugins/.gitkeep; do
    # NOTE: `[ -f "$k" ] || touch "$k" && echo` would be parsed as
    # `([ -f ] || touch) && echo` in bash, so it would always print
    # "Created" även när filen redan fanns. Behåll if/then.
    if [ -f "$keep" ]; then
        :
    else
        touch "$keep"
        echo "  Created: $keep"
    fi
done
echo ""

# --- 4. ENVIRONMENT FILE -----------------------------------------------------
echo "4. Setting up .env..."
if [ ! -f .env.example ]; then
    echo "  .env.example is missing - cannot create .env"
elif [ -f .env ]; then
    echo "  .env already exists - left untouched"
else
    cp .env.example .env
    echo "  Created .env from .env.example"
    echo "  Edit it to add Docker Hub / Grafana / Airflow secrets"
fi

# Låt DVC-skapade filer ägas av denna användare istället för root (skiljer sig från
# Windows, där Docker Desktop döljer uid-mappningen).
if ! grep -q '^DVC_UID=' .env 2>/dev/null; then
    echo "DVC_UID=$(id -u)" >> .env
    echo "  Added DVC_UID=$(id -u) to .env"
fi
echo ""

# --- 5. SUMMARY -------------------------------------------------------------
# macOS/Windows needs Docker Desktop file sharing configured, otherwise bind
# mountar visar tyst inaktuella filer. Varna en gång på macOS.
if [ "$(uname -s)" = "Darwin" ]; then
    echo "NOTE: on macOS open Docker Desktop -> Settings -> Resources ->"
    echo "      File sharing and make sure this folder is shared."
    echo ""
fi
echo "=========================================================="
echo "STEP 1 COMPLETE"
# macOS/Windows needs Docker Desktop file sharing configured, otherwise bind
# mountar visar tyst inaktuella filer. Varna en gång på macOS.
if [ "$(uname -s)" = "Darwin" ]; then
    echo "NOTE: on macOS open Docker Desktop -> Settings -> Resources ->"
    echo "      File sharing and make sure this folder is shared."
    echo ""
fi
echo "=========================================================="
echo ""
echo "Next step:"
echo "  ./3setup-ml-environment.sh  -  Python environment + dependencies"
echo ""
echo "The PostgreSQL database and its schema are created automatically by"
echo "Docker on first start. You do NOT need 2setup-database.sql unless you"
echo "choose the optional SQL Server path."
echo ""
