# =============================================================================
# 11setup-github-actions.ps1 - CI/CD pipelines
# =============================================================================
# STEG 11 av 11
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Workflows skrivs inte längre över varje körning. Originalet skrev
#     ci.yml och cd.yml från strängar, så alla manuella fixar tyst återställdes
#     nästa gång du körde skriptet. De följer nu med projektet.
#   - Den gamla CI avslutades med `pytest ... || echo "No tests yet"`, vilket
#     gjorde bygget grönt även när alla tester misslyckades. CI misslyckas nu
#     på riktigt.
#   - CI kontrollerar också att den tränade modellen och API:t är överens om
#     antalet features - det var felet som bröt /predict tidigare.
#   - CD bygger och skickar BÅDA images (api och mlflow) med korrekta taggar.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 11/11  -  GITHUB ACTIONS (CI/CD)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot

# --- 1. CHECK GIT ------------------------------------------------------------
Write-Host "1. Checking Git..." -ForegroundColor Yellow
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  Git NOT found. Install from https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}
Write-Host "  $(git --version)" -ForegroundColor Green

if (Test-Path (Join-Path $ProjectRoot ".git")) {
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    $remote = git remote get-url origin 2>$null
    Write-Host "  Repository: yes (branch '$branch')" -ForegroundColor Green
    if ($remote) { Write-Host "  Remote    : $remote" -ForegroundColor Gray }
} else {
    Write-Host "  This folder is NOT a git repository yet." -ForegroundColor Yellow
}
Write-Host ""

# --- 2. WORKFLOW FILES -------------------------------------------------------
Write-Host "2. Checking the workflow files..." -ForegroundColor Yellow
$WorkflowDir = Join-Path $ProjectRoot ".github\workflows"
if (-not (Test-Path $WorkflowDir)) {
    New-Item -ItemType Directory -Path $WorkflowDir -Force | Out-Null
    Write-Host "  Created .github\workflows" -ForegroundColor Green
}

$missing = $false
foreach ($wf in @("ci.yml", "cd.yml")) {
    $p = Join-Path $WorkflowDir $wf
    if (Test-Path $p) {
        Write-Host "  $wf found - left untouched" -ForegroundColor Green
    } else {
        Write-Host "  $wf is MISSING" -ForegroundColor Red
        $missing = $true
    }
}
if ($missing) {
    Write-Host "  Copy them from the repository - these scripts no longer generate them." -ForegroundColor Yellow
}
Write-Host ""

# --- 3. FÖRKLARA VAD VARJE WORKFLOW GÖR -------------------------------------
Write-Host "3. What the workflows do:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ci.yml  (Continuous Integration)" -ForegroundColor White
Write-Host "    Runs on every push and pull request." -ForegroundColor Gray
Write-Host "    Installs requirements.txt, generates seed data, trains a model," -ForegroundColor Gray
Write-Host "    verifies the feature contract, then runs pytest." -ForegroundColor Gray
Write-Host "    A failing test now fails the build (the old '|| echo' is gone)." -ForegroundColor Gray
Write-Host ""
Write-Host "  cd.yml  (Continuous Deployment)" -ForegroundColor White
Write-Host "    Runs on push to main, or manually via 'workflow_dispatch'." -ForegroundColor Gray
Write-Host "    Builds Dockerfile.api and Dockerfile.mlflow and pushes them to" -ForegroundColor Gray
Write-Host "    Docker Hub with branch, commit-sha and latest tags." -ForegroundColor Gray
Write-Host ""

# --- 4. SECRET INSTRUCTIONS -------------------------------------------------
Write-Host "4. Writing github-actions-instructions.txt..." -ForegroundColor Yellow
$instructions = @"
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
"@
Set-Content -Path (Join-Path $ProjectRoot "github-actions-instructions.txt") `
             -Value $instructions -Encoding UTF8
Write-Host "  github-actions-instructions.txt written" -ForegroundColor Green
Write-Host ""

# --- 5. LOCAL TEST CHECK ----------------------------------------------------
Write-Host "5. The tests should also pass locally..." -ForegroundColor Cyan
Write-Host "  If .venv exists:" -ForegroundColor Gray
Write-Host "    .\.venv\Scripts\python.exe -m pytest tests\ -v" -ForegroundColor DarkGray
Write-Host "  Or inside Docker:" -ForegroundColor Gray
Write-Host "    docker compose run --rm --entrypoint pytest api tests/ -v" -ForegroundColor DarkGray
Write-Host ""

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 11 COMPLETE" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Read github-actions-instructions.txt for the manual GitHub steps." -ForegroundColor White
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "ALL 11 STEPS COMPLETE" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "RUNNING SERVICES:" -ForegroundColor Yellow
Write-Host "  API        http://localhost:8000/docs" -ForegroundColor White
Write-Host "  MLflow     http://localhost:5000" -ForegroundColor White
Write-Host "  Airflow    http://localhost:8080  (step 10)" -ForegroundColor White
Write-Host "  Prometheus http://localhost:9090  (step 9)" -ForegroundColor White
Write-Host "  Grafana    http://localhost:3000  (step 9, admin/admin)" -ForegroundColor White
Write-Host ""
Write-Host "STOP EVERYTHING:" -ForegroundColor Gray
Write-Host "  docker compose --profile '*' down" -ForegroundColor DarkGray
Write-Host ""