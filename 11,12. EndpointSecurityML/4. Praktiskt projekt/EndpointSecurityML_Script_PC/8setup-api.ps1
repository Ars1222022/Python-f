# =============================================================================
# 8setup-api.ps1 - Bygger, tränar och startar FastAPI-tjänsten
# =============================================================================
# STEG 8 av 11. Det här är det viktigaste steget.
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Skriver inte längre över src\api\*.py. Originalet skrev över models.py,
#     utils.py och app.py med äldre kopior varje gång det kördes, vilket tyst
#     tog bort alla fixar och återförde feature-felet (2 mot 3 features).
#     Källkoden följer med projektet och det här skriptet bygger bara och
#     startar den.
#   - Använder Docker Compose, så alla tjänster definieras på ett ställe
#     (docker-compose.yml) i stället för enstaka "docker run"-kommandon.
#   - Genererar träningsdata automatiskt så att träningen har något att läsa.
#   - Tränar en riktig modell och verifierar att en förutsägelse fungerar.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 8/11  -  API (FastAPI)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot

# --- 1. KONTROLLERA DOCKER --------------------------------------------------
Write-Host "1. Checking Docker..." -ForegroundColor Yellow
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "  Docker NOT found. Install Docker Desktop." -ForegroundColor Red
    exit 1
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Docker daemon is NOT running. Start Docker Desktop." -ForegroundColor Red
    exit 1
}
Write-Host "  Docker OK" -ForegroundColor Green
Write-Host ""

# --- 2. STÄDA FÖREGÅENDE KÖRNING -------------------------------------------
Write-Host "2. Removing containers from any previous run..." -ForegroundColor Yellow
# Rör bara det här projektets containrar, aldrig global Docker-status.
docker compose down --remove-orphans 2>$null | Out-Null
Write-Host "  Done" -ForegroundColor Green
Write-Host ""

# --- 3. START DATABASE + MLFLOW ----------------------------------------------
Write-Host "3. Starting PostgreSQL and MLflow..." -ForegroundColor Yellow
docker compose up -d postgres mlflow
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Failed to start the base services." -ForegroundColor Red
    Write-Host "  Check: docker compose logs" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Waiting for health (the first build can take several minutes)..."

$ready = $false
for ($i = 0; $i -lt 60; $i++) {
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
    Write-Host "  Inspect with: docker compose logs mlflow" -ForegroundColor Yellow
    exit 1
}
Write-Host "  MLflow is up at http://localhost:5000" -ForegroundColor Green
Write-Host ""

# --- 4. SEED DATA ------------------------------------------------------------
# Utan en CSV i data\raw avslutas varje träningsskript med "no data found",
# vilket var den vanligaste anledningen till att en ny klon inte startade.
Write-Host "4. Making sure training data exists..." -ForegroundColor Yellow

$SeedCsv = Join-Path $ProjectRoot "data\raw\endpoint_seed.csv"
if (Test-Path $SeedCsv) {
    Write-Host "  data\raw\endpoint_seed.csv already exists" -ForegroundColor Gray
} else {
    Write-Host "  Generating synthetic seed data (1000 rows)..." -ForegroundColor Gray
    docker compose run --rm -v "${ProjectRoot}:/work" -w /work `
        --entrypoint python api -m src.data_generation.generate_seed_data
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Seed generation FAILED." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Seed data created" -ForegroundColor Green
}
Write-Host ""

# --- 5. TRAIN A MODEL --------------------------------------------------------
# API:t svarar 503 utan en modell, så vi tränar först.
Write-Host "5. Training the model..." -ForegroundColor Yellow
docker compose --profile training run --rm trainer
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Training FAILED." -ForegroundColor Red
    Write-Host "  Re-run manually: docker compose --profile training run --rm trainer" -ForegroundColor Yellow
    exit 1
}

$Model = @(Get-ChildItem (Join-Path $ProjectRoot "models\production\*.pkl") -ErrorAction SilentlyContinue)
if ($Model.Count -gt 0) {
    Write-Host "  Model saved: $($Model[-1].Name)" -ForegroundColor Green
} else {
    Write-Host "  No .pkl found in models\production" -ForegroundColor Red
    exit 1
}
Write-Host ""

# --- 6. STARTA API:t --------------------------------------------------------
Write-Host "6. Starting the API..." -ForegroundColor Yellow
docker compose up -d api
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Failed to start the API." -ForegroundColor Red
    Write-Host "  Check: docker compose logs api" -ForegroundColor Yellow
    exit 1
}

$apiUp = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 3
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:8000/health" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $apiUp = $true; break }
    } catch {
        # still starting
    }
}
if (-not $apiUp) {
    Write-Host "  The API did not respond in time." -ForegroundColor Red
    Write-Host "  Check: docker compose logs api" -ForegroundColor Yellow
    exit 1
}
Write-Host "  API is up" -ForegroundColor Green
Write-Host ""

# --- 7. KONTROLLERA HÄLSA OCH EN RIKTIG FÖRUTSÄGELSE ------------------------
Write-Host "7. Verifying..." -ForegroundColor Yellow

$health = Invoke-RestMethod -Uri "http://localhost:8000/health" -TimeoutSec 10
Write-Host "  health.status      : $($health.status)" -ForegroundColor Gray
Write-Host "  health.model_loaded: $($health.model_loaded)" -ForegroundColor Gray
Write-Host "  model_version      : $($health.model_version)" -ForegroundColor Gray
Write-Host "  features           : $($health.features -join ', ')" -ForegroundColor Gray

# En förutsägelse som aldrig körs är exakt det fel originalskripten missade.
$body = @{ NetworkConnections = 25; ProcessName = "mimikatz.exe"; Username = "attacker" } | ConvertTo-Json
try {
    $pred = Invoke-RestMethod -Uri "http://localhost:8000/predict" -Method Post `
                              -Body $body -ContentType "application/json" -TimeoutSec 15
    Write-Host "  prediction         : $($pred.prediction) ($($pred.threat_type))" -ForegroundColor Gray
    Write-Host "  confidence         : $([math]::Round($pred.confidence, 4))" -ForegroundColor Gray
} catch {
    Write-Host "  PREDICTION FAILED - the model could not be loaded." -ForegroundColor Red
    Write-Host "  This usually means the trained model and the API disagree on the" -ForegroundColor Yellow
    Write-Host "  feature set. Check: docker compose logs api" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# --- 8. SUMMARY -------------------------------------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 8 COMPLETE" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "YOUR SERVICES:" -ForegroundColor Yellow
Write-Host "  API docs : http://localhost:8000/docs"      -ForegroundColor White
Write-Host "  Health   : http://localhost:8000/health"   -ForegroundColor White
Write-Host "  Metrics  : http://localhost:8000/metrics"  -ForegroundColor White
Write-Host "  MLflow   : http://localhost:5000"          -ForegroundColor White
Write-Host ""
Write-Host "TEST A PREDICTION FROM POWERSHELL:" -ForegroundColor Gray
Write-Host "  `$body = @{NetworkConnections=25; ProcessName='mimikatz.exe'; Username='attacker'} | ConvertTo-Json" -ForegroundColor DarkGray
Write-Host "  Invoke-RestMethod -Uri http://localhost:8000/predict -Method Post -Body `$body -ContentType 'application/json'" -ForegroundColor DarkGray
Write-Host ""
Write-Host "USEFUL COMMANDS:" -ForegroundColor Gray
Write-Host "  docker compose logs -f api                            # follow logs" -ForegroundColor DarkGray
Write-Host "  docker compose ps                                      # status" -ForegroundColor DarkGray
Write-Host "  docker compose down                                    # stop all" -ForegroundColor DarkGray
Write-Host "  docker compose --profile training run --rm trainer     # retrain" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  9setup-monitoring.ps1   -  Prometheus + Grafana" -ForegroundColor White
Write-Host "  10setup-airflow.ps1     -  orchestration" -ForegroundColor White
Write-Host ""

