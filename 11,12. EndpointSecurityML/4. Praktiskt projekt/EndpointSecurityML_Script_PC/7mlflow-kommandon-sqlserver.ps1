# =============================================================================
# 7mlflow-kommandon-sqlserver.ps1 - MLflow commands (SQL Server backend)
# =============================================================================
# STEG 7 hjälpskript - VALFRIRT, bara om du använder SQL Server för spårning.
#
# Standarduppsättningen av MLflow (steg 6) sparar experiment i SQLite, som
# fungerar överallt. Använd det här bara om du redan underhåller SQL Server.
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - `mlflow ui` -> `mlflow server` (det gamla aliaset är deprecated).
#   - Kontrollerar att SQL Server-databasen faktiskt existerar innan den försöker
#     ansluta, istället för att misslyckas senare med ett otydligt drivrutefel.
#   - Förklarar begränsningen för Linux/macOS direkt.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "MLFLOW - SQL SERVER BACKEND" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot

# --- 0. PLATFORM WARNING -----------------------------------------------------
# pyodbc saknar tillförlitliga Linux/ARM-wheels, så den här vägen är Windows-först.
if ($env:OS -ne 'Windows_NT') {
    Write-Host "NOTE: this path uses pyodbc + the Microsoft ODBC driver." -ForegroundColor Yellow
    Write-Host "      That combination is unreliable on Linux/macOS ARM." -ForegroundColor Yellow
    Write-Host "      Prefer the default SQLite backend from 6setup-mlflow.ps1." -ForegroundColor Gray
    Write-Host ""
}

$SqlUri = "mssql+pyodbc://@localhost/EndpointSecurityML?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"

# --- 1. PREFLIGHT -----------------------------------------------------------
Write-Host "Testing the SQL Server connection..." -ForegroundColor Yellow

$test = @'
import sys
try:
    import pyodbc
except ImportError:
    print("  pyodbc is NOT installed")
    sys.exit(2)
try:
    conn = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;"
        "DATABASE=EndpointSecurityML;Trusted_Connection=yes;",
        timeout=5,
    )
    print("  Connected to EndpointSecurityML")
    conn.close()
    sys.exit(0)
except Exception as exc:
    print("  Could not connect: %s" % exc)
    sys.exit(1)
'@

$testFile = Join-Path $env:TEMP "test_mssql.py"
Set-Content -Path $testFile -Value $test -Encoding UTF8

$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (Test-Path $VenvPython) {
    $PythonCmd = $VenvPython
} else {
    $PythonCmd = $null
    foreach ($cmd in @("python", "py")) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) { $PythonCmd = $cmd; break }
    }
}

if (-not $PythonCmd) {
    Write-Host "  No Python found. Run 3setup-ml-environment.ps1 first." -ForegroundColor Red
    Remove-Item $testFile -ErrorAction SilentlyContinue
    exit 1
}

& $PythonCmd $testFile
$result = $LASTEXITCODE
Remove-Item $testFile -ErrorAction SilentlyContinue

if ($result -eq 2) {
    Write-Host ""
    Write-Host "pyodbc is missing. Install it with:  pip install pyodbc" -ForegroundColor Yellow
    Write-Host "and install 'ODBC Driver 17 for SQL Server'." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Prefer the recommended SQLite backend instead:  .\6setup-mlflow.ps1" -ForegroundColor Yellow
    exit 1
}

if ($result -ne 0) {
    Write-Host ""
    Write-Host "SQL Server is not reachable." -ForegroundColor Red
    Write-Host "Check that:" -ForegroundColor Yellow
    Write-Host "  - SQL Server is running" -ForegroundColor Yellow
    Write-Host "  - the database 'EndpointSecurityML' exists (run 2setup-database.sql)" -ForegroundColor Yellow
    Write-Host "  - ODBC Driver 17 for SQL Server is installed" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# --- MENU -------------------------------------------------------------------
Write-Host "Tracking URI:" -ForegroundColor Cyan
Write-Host "  $SqlUri" -ForegroundColor Gray
Write-Host ""

$loop = $true
while ($loop) {
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " 1) Train and log a run to SQL Server" -ForegroundColor White
    Write-Host " 2) Start the MLflow server on SQL Server" -ForegroundColor White
    Write-Host " 3) Show the latest experiments" -ForegroundColor White
    Write-Host " 4) Show saved models" -ForegroundColor White
    Write-Host " 0) Exit" -ForegroundColor White
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray

    $choice = Read-Host "Choose"
    switch ($choice) {
        "1" {
            $env:MLFLOW_TRACKING_URI = $SqlUri
            $env:DATA_DIR = "data/raw"
            $env:MODEL_DIR = "models/production"
            Write-Host ""
            & $PythonCmd -m src.training.train_with_mlflow_sqlserver
            if ($LASTEXITCODE -ne 0) { Write-Host "  Training failed" -ForegroundColor Red }
        }
        "2" {
            Write-Host ""
            Write-Host "Starting the server. Press Ctrl+C to stop." -ForegroundColor Yellow
            Write-Host "Then open http://localhost:5000" -ForegroundColor Yellow
            Write-Host ""
            & $PythonCmd -m mlflow server `
                --backend-store-uri $SqlUri `
                --host 127.0.0.1 --port 5000
        }
        "3" {
            Write-Host ""
            $env:MLFLOW_TRACKING_URI = $SqlUri
            & $PythonCmd -m mlflow experiments search --max-results 5
        }
        "4" {
            Write-Host ""
            $models = @(Get-ChildItem (Join-Path $ProjectRoot "models\production\*.pkl") -ErrorAction SilentlyContinue)
            if ($models.Count -gt 0) {
                Write-Host "Saved models:" -ForegroundColor Yellow
                foreach ($m in $models) {
                    Write-Host ("  {0}  ({1:N1} KB, {2})" -f $m.Name, ($m.Length / 1KB), $m.LastWriteTime)
                }
            } else {
                Write-Host "No models in models\production" -ForegroundColor Yellow
            }
        }
        "0" { $loop = $false }
        default { Write-Host "  Invalid choice" -ForegroundColor Yellow }
    }
}

Write-Host ""
Write-Host "Bye!" -ForegroundColor Cyan

