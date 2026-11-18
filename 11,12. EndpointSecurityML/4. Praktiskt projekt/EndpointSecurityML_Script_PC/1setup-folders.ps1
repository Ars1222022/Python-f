# =============================================================================
# 1setup-folders.ps1 - Skapar projektstrukturen
# =============================================================================
# STEG 1 av 11. Kör det här först.
# Skapar alla mappar projektet behöver, lägger till .gitkeep så tomma mappar
# följer med i git, kopierar .env.example -> .env och kontrollerar att Docker
# är installerat och igång.
#
# Fungerar med PowerShell 5.1 och senare.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 1/11  -  FOLDER STRUCTURE" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot
Write-Host "Project folder: $ProjectRoot" -ForegroundColor Green
Write-Host ""

# --- 1. KONTROLLERA DOCKER --------------------------------------------------
# Docker är det enda hårda kravet. Allt annat körs i containrar, så
# Python eller PostgreSQL behöver inte installeras på datorn.
Write-Host "1. Checking Docker..." -ForegroundColor Yellow

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "  Docker NOT FOUND." -ForegroundColor Red
    Write-Host "  Install Docker Desktop: https://docs.docker.com/desktop/install/windows-install/" -ForegroundColor Yellow
    Write-Host "  Then enable the WSL 2 backend and restart." -ForegroundColor Yellow
    exit 1
}

docker compose version *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Docker Compose v2 is not available." -ForegroundColor Red
    Write-Host "  Update Docker Desktop to a recent version." -ForegroundColor Yellow
    exit 1
}
Write-Host "  Docker + Compose v2 OK" -ForegroundColor Green

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Docker daemon is NOT running. Start Docker Desktop and re-run this script." -ForegroundColor Red
    exit 1
}
Write-Host "  Daemon reachable" -ForegroundColor Green
Write-Host ""

# --- 2. CREATE FOLDERS -------------------------------------------------------
Write-Host "2. Creating folders..." -ForegroundColor Yellow

$Folders = @(
    "data\raw",
    "data\processed",
    "models\production",
    "src\api",
    "src\training",
    "src\data_generation",
    "tests",
    "airflow\dags",
    "airflow\logs",
    "airflow\plugins",
    "prometheus",
    "grafana\dashboards",
    "grafana\provisioning\datasources",
    "grafana\provisioning\dashboards",
    "postgres\init",
    "k8s",
    ".github\workflows"
)

$created = 0
foreach ($Folder in $Folders) {
    $FullPath = Join-Path $ProjectRoot $Folder
    if (-not (Test-Path $FullPath)) {
        New-Item -ItemType Directory -Path $FullPath -Force | Out-Null
        Write-Host "  Created: $Folder" -ForegroundColor Green
        $created++
    }
}
Write-Host "  $created new folder(s) created" -ForegroundColor Green
Write-Host ""

# --- 3. .gitkeep FILES -------------------------------------------------------
# Git spårar inte tomma mappar. Dessa platshållare gör att strukturen syns
# i en ny klon (annars skapar Docker mapparna som root).
Write-Host "3. Creating .gitkeep placeholders..." -ForegroundColor Yellow

$KeepFiles = @(
    "data\raw\.gitkeep",
    "data\processed\.gitkeep",
    "models\production\.gitkeep",
    "airflow\logs\.gitkeep",
    "airflow\plugins\.gitkeep"
)
foreach ($kf in $KeepFiles) {
    $p = Join-Path $ProjectRoot $kf
    if (-not (Test-Path $p)) {
        New-Item -ItemType File -Path $p -Force | Out-Null
        Write-Host "  Created: $kf" -ForegroundColor Green
    }
}
Write-Host ""

# --- 4. ENVIRONMENT FILE -----------------------------------------------------
# .env innehåller portar och hemligheter. Den är git-ignorerad, så vi
# skapar den från mallen när mappen klonas.
Write-Host "4. Setting up .env..." -ForegroundColor Yellow

$EnvPath = Join-Path $ProjectRoot ".env"
$EnvExample = Join-Path $ProjectRoot ".env.example"

if (-not (Test-Path $EnvExample)) {
    Write-Host "  .env.example is missing - cannot create .env" -ForegroundColor Red
} elseif (Test-Path $EnvPath) {
    Write-Host "  .env already exists - left untouched" -ForegroundColor Gray
} else {
    Copy-Item $EnvExample $EnvPath
    Write-Host "  Created .env from .env.example" -ForegroundColor Green
    Write-Host "  Edit it to add Docker Hub / Grafana / Airflow secrets" -ForegroundColor Gray
}
Write-Host ""

# --- 5. SUMMARY -------------------------------------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 1 COMPLETE" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step:" -ForegroundColor Yellow
Write-Host "  3setup-ml-environment.ps1  -  Python environment + dependencies" -ForegroundColor White
Write-Host ""
Write-Host "The PostgreSQL database and its schema are created automatically by" -ForegroundColor Gray
Write-Host "Docker on first start. You do NOT need 2setup-database.sql unless you" -ForegroundColor Gray
Write-Host "choose the optional SQL Server path." -ForegroundColor Gray
Write-Host ""
