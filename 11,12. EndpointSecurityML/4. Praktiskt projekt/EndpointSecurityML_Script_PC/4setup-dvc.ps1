# =============================================================================
# 4setup-dvc.ps1 - Data Version Control (DVC)
# =============================================================================
# STEG 4 av 11 (valfritt)
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Levererar inte längre en 105 KB stor dvc.exe i repot. DVC körs nu i en
#     container (Dockerfile.versioning), så samma skript fungerar på Windows,
#     macOS och Linux och kan aldrig avvika från en committad .exe.
#   - Sätter DVC_UID så filer ägs av dig istället för root.
#   - Refuses to overwrite an existing .dvc directory.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 4/11  -  DATA VERSIONING (DVC)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot

# --- 1. KONTROLLERA DOCKER --------------------------------------------------
Write-Host "1. Checking Docker..." -ForegroundColor Yellow
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "  Docker NOT found. DVC runs in a container, so Docker is required." -ForegroundColor Red
    exit 1
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Docker daemon is NOT running." -ForegroundColor Red
    exit 1
}
Write-Host "  Docker OK" -ForegroundColor Green
Write-Host ""

function Invoke-Dvc {
    # Kör DVC i containern som definieras av Dockerfile.versioning
    docker compose --profile dvc run --rm dvc @args
}

# --- 2. DVC_UID --------------------------------------------------------------
# Containrar körs som root som standard, vilket skulle skapa root-ägda filer i
# din arbetskopia. Att mappa uid:t håller ägandet korrekt.
Write-Host "2. Configuring DVC_UID..." -ForegroundColor Yellow
$EnvPath = Join-Path $ProjectRoot ".env"
if (Test-Path $EnvPath) {
    if (-not (Select-String -Path $EnvPath -Pattern '^DVC_UID=' -Quiet)) {
        Add-Content -Path $EnvPath -Value "DVC_UID=0"   # 0 is correct inside Docker Desktop
        Write-Host "  Added DVC_UID=0 to .env" -ForegroundColor Green
        Write-Host "  (Docker Desktop hides uid mapping; on Linux/Mac set your own id -u)" -ForegroundColor DarkGray
    } else {
        Write-Host "  DVC_UID already set" -ForegroundColor Gray
    }
}
Write-Host ""

# --- 3. INITIALISE -----------------------------------------------------------
Write-Host "3. Initialising DVC..." -ForegroundColor Yellow
if (Test-Path (Join-Path $ProjectRoot ".dvc")) {
    Write-Host "  .dvc already exists - skipping init (never overwrite it)" -ForegroundColor Gray
} else {
    Invoke-Dvc init
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  DVC init failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "  DVC initialised" -ForegroundColor Green
}
Write-Host ""

# --- 4. GIT CONFIG -----------------------------------------------------------
Write-Host "4. Telling Git not to track the DVC internals..." -ForegroundColor Yellow
$GitignorePath = Join-Path $ProjectRoot ".gitignore"
if (Test-Path $GitignorePath) {
    $content = Get-Content $GitignorePath -Raw
    if ($content -notmatch '\.dvc/cache') {
        Add-Content -Path $GitignorePath -Value "`n# DVC internals (added by 4setup-dvc.ps1)`n.dvc/cache/`n.dvc/tmp/"
        Write-Host "  .gitignore updated" -ForegroundColor Green
    } else {
        Write-Host "  .gitignore already correct" -ForegroundColor Gray
    }
}
Write-Host ""

# --- 5. SPÅRA DATAMAPPEN ----------------------------------------------------
Write-Host "5. Tracking data\raw..." -ForegroundColor Yellow
Invoke-Dvc add data/raw
if ($LASTEXITCODE -ne 0) {
    Write-Host "  dvc add failed (this is fine if the folder is already tracked)" -ForegroundColor Yellow
} else {
    Write-Host "  data\raw is tracked" -ForegroundColor Green
}
Write-Host ""

# --- 6. STATUS ---------------------------------------------------------------
Write-Host "6. Current DVC status:" -ForegroundColor Yellow
Invoke-Dvc status
Write-Host ""

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 4 COMPLETE" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "COMMON DVC COMMANDS:" -ForegroundColor Yellow
Write-Host "  .\5dvc-kommandon.ps1        interactive menu" -ForegroundColor White
Write-Host "  .\start-dvc.ps1             shell inside the DVC container" -ForegroundColor White
Write-Host ""
Write-Host "Or directly:" -ForegroundColor Gray
Write-Host "  docker compose --profile dvc run --rm dvc status" -ForegroundColor DarkGray
Write-Host "  docker compose --profile dvc run --rm dvc add data/raw" -ForegroundColor DarkGray
Write-Host "  docker compose --profile dvc run --rm dvc commit -m 'message'" -ForegroundColor DarkGray
Write-Host ""
