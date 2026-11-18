#!/usr/bin/env bash
# =============================================================================
# 11setup-github-actions.sh - CI/CD pipelines  (Linux)
# =============================================================================
# STEG 11 av 11.  ./11setup-github-actions.sh
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Workflows skrivs inte längre över varje körning. Originalet skrev ci.yml
#     och cd.yml från strängar, så alla manuella fixar tyst återställdes nästa
#     gång du körde skriptet.
#   - Den gamla CI avslutades med `pytest ... || echo "No tests yet"`, vilket
#     gjorde bygget grönt även när alla tester misslyckades. CI misslyckas nu
#     på riktigt.
#   - CI kontrollerar också att den tränade modellen och API:t är överens om
#     antalet features - det var felet som bröt /predict tidigare.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================================="
echo "STEP 11/11  -  GITHUB ACTIONS (CI/CD)"
echo "=========================================================="
echo ""

echo "1. Checking Git..."
if ! command -v git >/dev/null 2>&1; then
    echo "  Git NOT found. Install from https://git-scm.com/downloads"
    exit 1
fi
echo "  $(git --version)"

if [ -d .git ]; then
    echo "  Repository: yes (branch '$(git rev-parse --abbrev-ref HEAD 2>/dev/null)')"
    git remote get-url origin 2>/dev/null | sed 's/^/  Remote    : /'
else
    echo "  This folder is NOT a git repository yet."
fi
echo ""

echo "2. Checking the workflow files..."
mkdir -p .github/workflows

missing=0
for wf in ci.yml cd.yml; do
    if [ -f ".github/workflows/$wf" ]; then
        echo "  $wf found - left untouched"
    else
        echo "  $wf is MISSING"
        missing=1
    fi
done
[ $missing -eq 1 ] && echo "  Copy them from the repository - this script no longer generates them."
echo ""

echo "3. What the workflows do:"
echo "  ci.yml  (Continuous Integration)"
echo "    Runs on every push and pull request. Installs requirements.txt,"
echo "    generates seed data, trains a model, verifies the feature contract,"
echo "    then runs pytest. A failing test now fails the build."
echo ""
echo "  cd.yml  (Continuous Deployment)"
echo "    Runs on push to main. Builds Dockerfile.api and Dockerfile.mlflow"
echo "    and pushes them to Docker Hub with branch, sha and latest tags."
echo ""

echo "4. Writing github-actions-instructions.txt..."
cat > github-actions-instructions.txt <<EOF
GITHUB ACTIONS - DET DU MÅSTE GÖRA MANUELLT
===========================================================

A. SKICKA UPP KODEN
-----------------------------------------------------------
cd "$ProjectRoot"

git init                     # hoppa över om det redan är ett repo
git add .
git commit -m "EndpointSecurityML MLOps stack"
git branch -M main
git remote add origin https://github.com/<du>/<repo>.git
git push -u origin main

B. SKAPA REPOTS HEMLIGHETER (SECRETS)
-----------------------------------------------------------
GitHub: Settings -> Secrets and variables -> Actions -> New repository secret

  DOCKER_USERNAME   ditt Docker Hub-användarnamn
  DOCKER_PASSWORD   en Docker Hub ACCESS TOKEN, inte ditt lösenord
                    (Docker Hub -> Account settings -> Personal access tokens)

Lägg till dem BARA om du vill att cd.yml ska skicka images. CI fungerar utan dem.

C. AKTIVERA WORKFLOWS
-----------------------------------------------------------
Actions-fliken -> de två workflows visas. Aktivera dem om GitHub frågar.

D. VERIFIERA
-----------------------------------------------------------
CI:  skicka in någon ändring och kontrollera sedan Actions-fliken.
     Ett rött X betyder att ett test misslyckades - klicka på det för att se vilket.

CD:  skicka till main, eller använd knappen 'Run workflow' på cd.yml.
     Kontrollera Docker Hub efter endpointsecurity-api och endpointsecurity-mlflow.

FELSÖKNING
-----------------------------------------------------------
Workflow visas inte
    Filerna måste ligga i .github/workflows/*.yml - inte en nivå djupare.

Secrets hittas inte
    Kontrollera att namnen stämmer EXAKT (versaler, inga stavfel).

Docker Hub avvisar pushen
    Använd en access token och kontrollera att repot finns i Docker Hub.
EOF
echo "  github-actions-instructions.txt written"
echo ""

echo "5. The tests should also pass locally:"
echo "  .venv/bin/python -m pytest tests/ -v"
echo "  or:  docker compose run --rm --entrypoint pytest api tests/ -v"
echo ""

echo "=========================================================="
echo "STEP 11 COMPLETE"
echo "=========================================================="
echo ""
echo "Read github-actions-instructions.txt for the manual GitHub steps."
echo ""
echo "=========================================================="
echo "ALL 11 STEPS COMPLETE"
echo "=========================================================="
echo ""
echo "RUNNING SERVICES:"
echo "  API        http://localhost:8000/docs"
echo "  MLflow     http://localhost:5000"
echo "  Airflow    http://localhost:8080  (step 10)"
echo "  Prometheus http://localhost:9090  (step 9)"
echo "  Grafana    http://localhost:3000  (step 9, admin/admin)"
echo ""
echo "STOP EVERYTHING:"
echo "  docker compose --profile '*' down"
echo ""