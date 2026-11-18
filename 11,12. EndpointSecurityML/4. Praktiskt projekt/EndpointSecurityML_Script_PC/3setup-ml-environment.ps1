# =============================================================================
# 3setup-ml-environment.ps1 - Python environment + dependencies
# =============================================================================
# STEG 3 av 11.
#
# Skapar en isolerad virtuell miljö, installerar exakt versionerna i
# requirements.txt och verifierar sedan att de importeras utan fel.
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Kräver inte längre SQL Server. Originalet avslutade med ett fel när
#     SQL Server-testet misslyckades, vilket blockerade hela projektet trots att
#     SQL Server nu är valfritt.
#   - Använder en lokal .venv så den aldrig blandas med systempaket.
#   - Verifierar att de pinnade versionerna stämmer, så en trasig global miljö
#     fångas här istället för vid träningstillfället.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 3/11  -  PYTHON ML ENVIRONMENT" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot

# --- 1. FIND PYTHON ----------------------------------------------------------
Write-Host "1. Locating Python..." -ForegroundColor Yellow

$PythonCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $result = & $cmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $PythonCmd = $cmd
            Write-Host "  Found: $cmd ($($result))" -ForegroundColor Green
            break
        }
    } catch {
        # keep looking
    }
}

if (-not $PythonCmd) {
    Write-Host "  Python was NOT found." -ForegroundColor Red
    Write-Host "  Install Python 3.11 from https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "  or run:  winget install Python.Python.3.11" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Note: Python is only needed to run tests locally." -ForegroundColor Gray
    Write-Host "  Docker runs the application itself." -ForegroundColor Gray
    exit 1
}
Write-Host ""

# --- 2. CREATE VIRTUAL ENVIRONMENT ------------------------------------------
# En egen .venv förhindrar versionskonflikter med andra projekt.
Write-Host "2. Creating virtual environment (.venv)..." -ForegroundColor Yellow

$VenvPath = Join-Path $ProjectRoot ".venv"
if (-not (Test-Path $VenvPath)) {
    & $PythonCmd -m venv $VenvPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Failed to create the virtual environment." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Created .venv" -ForegroundColor Green
} else {
    Write-Host "  .venv already exists - reusing it" -ForegroundColor Gray
}

$VenvPython = Join-Path $VenvPath "Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    Write-Host "  Cannot find $VenvPython" -ForegroundColor Red
    exit 1
}
Write-Host ""

# --- 3. INSTALL DEPENDENCIES ------------------------------------------------
Write-Host "3. Installing dependencies from requirements.txt..." -ForegroundColor Yellow
Write-Host "  This downloads MLflow/scikit-learn and can take several minutes." -ForegroundColor Gray

& $VenvPython -m pip install --upgrade pip --quiet
& $VenvPython -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Dependency installation FAILED." -ForegroundColor Red
    Write-Host "  Check your internet connection, then re-run." -ForegroundColor Yellow
    exit 1
}
Write-Host "  Dependencies installed" -ForegroundColor Green
Write-Host ""

# --- 4. KONTROLLERA VERSIONER ------------------------------------------------
# requirements.txt är den enda sanningen. Om dessa glider isär laddas inte en
# modell-pickle som sparats i en miljö i en annan.
Write-Host "4. Verifying installed versions..." -ForegroundColor Yellow

$verifyScript = @'
import sys
expected = {
    "fastapi": "0.115.12", "uvicorn": "0.34.2", "pydantic": "2.11.4",
    "numpy": "1.26.4", "pandas": "2.2.3", "sklearn": "1.4.2",
    "joblib": "1.4.2", "mlflow": "2.12.2", "prometheus_client": "0.21.1",
}
ok = True
print("  Python %s" % sys.version.split()[0])
for mod, want in expected.items():
    try:
        got = getattr(__import__(mod), "__version__", "?")
        match = (got == want)
        ok = ok and match
        print("    %s %-18s %-12s (want %s)" % ("OK " if match else "XX ", mod, got, want))
    except ImportError:
        ok = False
        print("    XX %-18s NOT INSTALLED (want %s)" % (mod, want))
print("  RESULT=" + ("OK" if ok else "MISMATCH"))
sys.exit(0 if ok else 1)
'@

$verifyFile = Join-Path $env:TEMP "verify_versions.py"
Set-Content -Path $verifyFile -Value $verifyScript -Encoding UTF8
& $VenvPython $verifyFile
$verifyExit = $LASTEXITCODE
Remove-Item $verifyFile -ErrorAction SilentlyContinue

if ($verifyExit -ne 0) {
    Write-Host "  Version mismatch - delete .venv and re-run for a clean install." -ForegroundColor Yellow
}
Write-Host ""

# --- 5. IMPORT CHECK ---------------------------------------------------------
# Catch a broken fastapi/starlette pairing now rather than mid-training.
Write-Host "5. Checking that the API imports..." -ForegroundColor Yellow

$importScript = @'
import sys
sys.path.insert(0, ".")
try:
    from src.api.utils import FEATURE_NAMES, prepare_features
    from src.api.app import app
    frame = prepare_features(5, "powershell.exe", "system")
    assert list(frame.columns) == FEATURE_NAMES, "feature column mismatch"
    assert frame.shape == (1, len(FEATURE_NAMES)), "feature width mismatch"
    print("  API imports OK")
    print("  Feature contract:", FEATURE_NAMES)
    sys.exit(0)
except Exception as exc:
    print("  API import FAILED: %s" % exc)
    sys.exit(1)
'@

$importFile = Join-Path $env:TEMP "verify_import.py"
Set-Content -Path $importFile -Value $importScript -Encoding UTF8
& $VenvPython $importFile
$importExit = $LASTEXITCODE
Remove-Item $importFile -ErrorAction SilentlyContinue
Write-Host ""

# --- 6. SUMMARY -------------------------------------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
if ($verifyExit -eq 0 -and $importExit -eq 0) {
    Write-Host "STEP 3 COMPLETE" -ForegroundColor Green
} else {
    Write-Host "STEP 3 FINISHED WITH WARNINGS" -ForegroundColor Yellow
}
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Activate the environment with:" -ForegroundColor Yellow
Write-Host "  .\.venv\Scripts\Activate.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Run the tests with:" -ForegroundColor Yellow
Write-Host "  .\.venv\Scripts\python.exe -m pytest tests\ -v" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  8setup-api.ps1     -  build + start API, train a model" -ForegroundColor White
Write-Host "  4setup-dvc.ps1     -  optional, data versioning" -ForegroundColor White
Write-Host "  6setup-mlflow.ps1  -  optional, experiment tracking UI" -ForegroundColor White
Write-Host ""
Write-Host "Only needed for the optional SQL Server path:" -ForegroundColor DarkGray
Write-Host "  2setup-database.sql                   (SQL Server schema)" -ForegroundColor DarkGray
Write-Host "  7mlflow-kommandon-sqlserver.ps1        (MLflow on SQL Server)" -ForegroundColor DarkGray
Write-Host ""

