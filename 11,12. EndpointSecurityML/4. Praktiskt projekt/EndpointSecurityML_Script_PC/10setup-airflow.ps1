# =============================================================================
# 10setup-airflow.ps1 - Airflow-orkestrering
# =============================================================================
# STEG 10 av 11 (valfritt)
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Det gamla projektnamnet är BORTA. Originalet hårdkodade nätverket
#     "endpointsecuritymluppgift1_default" och körde `docker run --network ...`
#     piped till Out-Null, så när mappen bytte namn misslyckades migreringen
#     och felet svaldes. Airflow startade sedan mot en omigrerad databas och
#     crashloopade.
#   - Databasmigreringen är nu en riktig `airflow-init`-tjänst i
#     docker-compose.yml som kör FÖRE webservern och schemaläggaren.
#   - LocalExecutor ersätter CeleryExecutor, så ingen Redis broker/worker
#     behövs för en demo med en enda nod.
#   - Webserverns hälsa kontrolleras faktiskt innan framgång rapporteras.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 10/11  -  AIRFLOW" -ForegroundColor Cyan
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

# --- 2. DAG DIRECTORIES ------------------------------------------------------
Write-Host "2. Checking DAG folders..." -ForegroundColor Yellow
foreach ($d in @("airflow\dags", "airflow\logs", "airflow\plugins", "models\production", "data\raw")) {
    $p = Join-Path $ProjectRoot $d
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        Write-Host "  Created: $d" -ForegroundColor Green
    }
}
Write-Host ""

# --- 3. DAGS PRESENT? -------------------------------------------------------
Write-Host "3. Checking the DAGs..." -ForegroundColor Yellow
$DagDir = Join-Path $ProjectRoot "airflow\dags"
$dags = @(Get-ChildItem (Join-Path $DagDir "*.py") -ErrorAction SilentlyContinue)
if ($dags.Count -eq 0) {
    Write-Host "  No DAGs found in airflow\dags" -ForegroundColor Red
    Write-Host "  Expected: ml_training_dag.py and monitoring_dag.py" -ForegroundColor Yellow
    exit 1
}
foreach ($d in $dags) {
    Write-Host "  Found: $($d.Name)" -ForegroundColor Green
}
Write-Host ""

# --- 4. DATA FÖR TRÄNINGS-DAG:EN --------------------------------------------
# DAG:en kl. 03:00 läser data\raw och skriver models\production. Är något av
# dem tomt misslyckas DAG:en varje natt med ett förvirrande fel.
Write-Host "4. Making sure the DAG has data..." -ForegroundColor Yellow

$SeedCsv = Join-Path $ProjectRoot "data\raw\endpoint_seed.csv"
if (-not (Test-Path $SeedCsv)) {
    Write-Host "  No seed data - generating..." -ForegroundColor Gray
    docker compose run --rm -v "${ProjectRoot}:/work" -w /work `
        --entrypoint python api -m src.data_generation.generate_seed_data 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "  Seed data created" -ForegroundColor Green }
} else {
    Write-Host "  Seed data present" -ForegroundColor Gray
}
Write-Host ""

# --- 5. START EVERYTHING -----------------------------------------------------
Write-Host "5. Starting the Airflow stack..." -ForegroundColor Yellow
Write-Host "  (the first build installs the Airflow image and takes a while)" -ForegroundColor Gray
docker compose --profile airflow up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Failed to start Airflow." -ForegroundColor Red
    Write-Host "  Check: docker compose --profile airflow logs" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# --- 6. VÄNTA PÅ DATABASMIGRERINGEN -----------------------------------------
# airflow-init måste klara sig, annars crashloopar webservern.
Write-Host "6. Waiting for the database migration..." -ForegroundColor Yellow
$migrated = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 5
    $initState = (docker compose ps --status exited --format '{{.Service}}' airflow-init 2>$null | Out-String).Trim()
    if ($initState -match 'airflow-init') {
        $logs = docker compose logs airflow-init 2>&1 | Out-String
        if ($logs -match 'error|fatal|Traceback') {
            Write-Host "  Migration FAILED:" -ForegroundColor Red
            Write-Host "  $logs" -ForegroundColor DarkGray
            exit 1
        }
        $migrated = $true
        break
    }
    if (($i % 6) -eq 0) { Write-Host "    migrating... ($($i * 5)s)" -ForegroundColor DarkGray }
}

if (-not $migrated) {
    Write-Host "  Migration did not finish in time." -ForegroundColor Yellow
    Write-Host "  Check: docker compose logs airflow-init" -ForegroundColor Yellow
} else {
    Write-Host "  Database migrated" -ForegroundColor Green
}
Write-Host ""

# --- 7. VÄNTA PÅ WEBSERVERN -------------------------------------------------
Write-Host "7. Waiting for the Airflow UI..." -ForegroundColor Yellow
$up = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 5
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $up = $true; break }
    } catch {
        # still starting
    }
    if (($i % 6) -eq 0) { Write-Host "    waiting... ($($i * 5)s)" -ForegroundColor DarkGray }
}

if (-not $up) {
    Write-Host "  The Airflow UI did not respond in time." -ForegroundColor Red
    Write-Host "  Check: docker compose logs airflow-webserver" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Airflow is up" -ForegroundColor Green
Write-Host ""

# --- 8. SUMMARY -------------------------------------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 10 COMPLETE" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Airflow UI : http://localhost:8080   (admin / admin)" -ForegroundColor White
Write-Host ""
Write-Host "EXPECTED DAGS:" -ForegroundColor Yellow
Write-Host "  ml_training    - retrains the model every night at 03:00" -ForegroundColor Gray
Write-Host "  api_monitoring - checks API health every hour" -ForegroundColor Gray
Write-Host ""
Write-Host "If a DAG shows 'import error' it is usually a library version mismatch" -ForegroundColor Gray
Write-Host "inside the Airflow image. Check:" -ForegroundColor Gray
Write-Host "  docker compose --profile airflow logs airflow-scheduler" -ForegroundColor DarkGray
Write-Host ""
Write-Host "USEFUL COMMANDS:" -ForegroundColor Gray
Write-Host "  docker compose --profile airflow ps" -ForegroundColor DarkGray
Write-Host "  docker compose --profile airflow logs -f airflow-scheduler" -ForegroundColor DarkGray
Write-Host "  docker compose --profile airflow down" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next step:" -ForegroundColor Yellow
Write-Host "  11setup-github-actions.ps1  -  CI/CD" -ForegroundColor White
Write-Host ""

