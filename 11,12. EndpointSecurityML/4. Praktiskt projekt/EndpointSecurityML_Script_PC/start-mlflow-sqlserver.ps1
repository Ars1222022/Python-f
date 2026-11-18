# =============================================================================
# start-mlflow-sqlserver.ps1 - MLflow UI med SQL Server
# =============================================================================
# Bekvämlighetsstartare för den VALFRIRA SQL Server-vägen.
# Rekommenderad standard är 6setup-mlflow.ps1 (SQLite), som kräver inget extra.
# Använd det här bara om du redan underhåller SQL Server.
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - `mlflow ui` -> `mlflow server` (det gamla aliaset är deprecated).
#   - Kontrollerar förutsättningar (venv, pyodbc, databas) INNAN start, istället
#     för att misslyckas med ett otydligt drivrutefel halvvägs.
#   - Öppnar på 127.0.0.1 istället för 0.0.0.0, så det inte av misstag
#     exponeras för hela nätverket.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "MLFLOW UI - SQL SERVER BACKEND" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot

# --- 1. PREREQUISITES -------------------------------------------------------
$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    Write-Host "No virtual environment found." -ForegroundColor Red
    Write-Host "Run 3setup-ml-environment.ps1 first." -ForegroundColor Yellow
    exit 1
}

Write-Host "1. Checking pyodbc..." -ForegroundColor Yellow
& $VenvPython -c "import pyodbc" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  pyodbc is NOT installed" -ForegroundColor Red
    Write-Host "  Install it with:  .\.venv\Scripts\pip.exe install pyodbc" -ForegroundColor Yellow
    Write-Host "  And install 'ODBC Driver 17 for SQL Server'." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Consider the simpler alternative instead:" -ForegroundColor Cyan
    Write-Host "    .\6setup-mlflow.ps1        (SQLite, works everywhere)" -ForegroundColor White
    exit 1
}
Write-Host "  pyodbc OK" -ForegroundColor Green
Write-Host ""

# --- 2. DATABASE CHECK ------------------------------------------------------
Write-Host "2. Checking the EndpointSecurityML database..." -ForegroundColor Yellow
$check = @'
import sys
try:
    import pyodbc
    conn = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;"
        "DATABASE=master;Trusted_Connection=yes;", timeout=5)
    cur = conn.cursor()
    cur.execute("SELECT name FROM sys.databases WHERE name = 'EndpointSecurityML'")
    exists = cur.fetchone() is not None
    conn.close()
    print("  database found" if exists else "  database MISSING")
    sys.exit(0 if exists else 1)
except Exception as exc:
    print("  could not connect: %s" % exc)
    sys.exit(2)
'@
$checkFile = Join-Path $env:TEMP "check_db.py"
Set-Content -Path $checkFile -Value $check -Encoding UTF8
& $VenvPython $checkFile
$dbResult = $LASTEXITCODE
Remove-Item $checkFile -ErrorAction SilentlyContinue

if ($dbResult -eq 1) {
    Write-Host ""
    Write-Host "The database does not exist yet." -ForegroundColor Red
    Write-Host "Run 2setup-database.sql in SSMS first." -ForegroundColor Yellow
    exit 1
}
if ($dbResult -eq 2) {
    Write-Host ""
    Write-Host "Cannot reach SQL Server on localhost." -ForegroundColor Red
    Write-Host "Start SQL Server, then run 2setup-database.sql." -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# --- 3. START ---------------------------------------------------------------
$SqlUri = "mssql+pyodbc://@localhost/EndpointSecurityML?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"

Write-Host "3. Starting MLflow on http://localhost:5000" -ForegroundColor Yellow
Write-Host "  Press Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""
& $VenvPython -m mlflow server `
    --backend-store-uri $SqlUri `
    --host 127.0.0.1 `
    --port 5000

Write-Host ""
Write-Host "MLflow stopped." -ForegroundColor Cyan
