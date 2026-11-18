#!/usr/bin/env bash
# =============================================================================
# start-dvc.sh - Öppna ett DVC-skal  (macOS / Linux)
# =============================================================================
# Bekvämlighetsstartare för löpande DVC-arbete.
# Kör ./4setup-dvc.sh en gång först.
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Kör DVC i containern istället för den committade dvc.exe, så det fungerar
#     här och på alla andra OS, alltid med den pinnade DVC-versionen.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================================="
echo "DVC SHELL"
echo "=========================================================="
echo ""

command -v docker >/dev/null 2>&1 || { echo "Docker is required."; exit 1; }

if [ ! -d .dvc ]; then
    echo "DVC is not initialised in this folder."
    echo "Run ./4setup-dvc.sh first."
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "No command given - opening an interactive shell."
    echo "Type 'dvc --help' inside the container."
    echo ""
    docker compose --profile dvc run --rm dvc shell
else
    echo "Running: dvc $*"
    docker compose --profile dvc run --rm dvc "$@"
fi

echo ""
echo "Done."
