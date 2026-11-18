# =============================================================================
# 6setup-mlflow.ps1 - MLflow experiment-spårning
# =============================================================================
# STEG 6 av 11 (valfritt - API:t fungerar utan det)
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Använder `mlflow server` istället för det deprecated `mlflow ui`. MLflow
#     bytte namn på kommandot och det gamla aliaset ger varningar och kan tas bort.
#   - Använder en ABSOLUT sqlite-sökväg (/mlflow/mlflow.db på en namngiven volym)
#     istället för en relativ. Den relativa sparade databasen utanför volymen,
#     så varje `down -v` kastade tyst experimenthistoriken.
#   - Genererar inte längre träningsskript genom att skriva över filer i src\.
#     Skripten följer med projektet; det här startar bara tjänsten.
#   - Tränar en gång så att UI:t har något att visa.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 6/11  -  MLFLOW" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot

# --- 1. KONTROLLERA DOCKER --------------------------------------------------
Write-Host "1. Checking Docker..." -ForegroundColor Yellow
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "  Docker NOT found." -ForegroundColor Red
    exit 1
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Docker daemon is NOT running." -ForegroundColor Red
    exit 1
}
Write-Host "  Docker OK" -ForegroundColor Green
Write-Host ""

# --- 2. SE TILL ATT API:OCH DATABASEN ÄR UPP --------------------------------
Write-Host "2. Making sure PostgreSQL and the API are running..." -ForegroundColor Yellow
docker compose up -d postgres api 2>$null | Out-Null
Write-Host "  Done" -ForegroundColor Green
Write-Host ""

# --- 3. START MLFLOW ---------------------------------------------------------
Write-Host "3. Starting MLflow..." -ForegroundColor Yellow
docker compose up -d --build mlflow
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Failed to start MLflow." -ForegroundColor Red
    Write-Host "  Check: docker compose logs mlflow" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Waiting for it to become healthy..."

$ready = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 5
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch {
        # still starting
    }
    if (($i % 6) -eq 0) { Write-Host "    still waiting... ($($i * 5)s)" -ForegroundColor DarkGray }
}

if (-not $ready) {
    Write-Host "  MLflow did not become healthy in time." -ForegroundColor Red
    Write-Host "  Check: docker compose logs mlflow" -ForegroundColor Yellow
    exit 1
}
Write-Host "  MLflow is up" -ForegroundColor Green
Write-Host ""

# --- 4. TRÄNA EN KÖRNING SÅ ATT UI:T INTE ÄR TOMT ----------------------------
Write-Host "4. Running one training pass so the UI has data..." -ForegroundColor Yellow

$SeedCsv = Join-Path $ProjectRoot "data\raw\endpoint_seed.csv"
if (-not (Test-Path $SeedCsv)) {
    Write-Host "  No seed data yet - generating..." -ForegroundColor Gray
    docker compose run --rm -v "${ProjectRoot}:/work" -w /work `
        --entrypoint python api -m src.data_generation.generate_seed_data 2>&1 | Out-Null
}

docker compose --profile training run --rm trainer
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Training FAILED - the UI will be empty." -ForegroundColor Red
    Write-Host "  Check: docker compose --profile training run --rm trainer" -ForegroundColor Yellow
} else {
    Write-Host "  Training run logged to MLflow" -ForegroundColor Green
}
Write-Host ""

# --- 5. OPEN / SUMMARY ------------------------------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 6 COMPLETE" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "MLflow UI : http://localhost:5000" -ForegroundColor White
Write-Host ""
Write-Host "In the UI, pick an experiment named EndpointSecurity_<date>." -ForegroundColor Gray
Write-Host ""
Write-Host "VIEW LOGS:" -ForegroundColor Gray
Write-Host "  docker compose logs mlflow" -ForegroundColor DarkGray
Write-Host ""
Write-Host "OPTIONAL - MLflow backed by SQL Server instead:" -ForegroundColor Gray
Write-Host "  .\7mlflow-kommandon-sqlserver.ps1" -ForegroundColor DarkGray
Write-Host "  .\start-mlflow-sqlserver.ps1" -ForegroundColor DarkGray
Write-Host ""
