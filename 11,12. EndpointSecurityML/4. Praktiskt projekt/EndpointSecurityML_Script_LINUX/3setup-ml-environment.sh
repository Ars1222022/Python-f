#!/usr/bin/env bash
# =============================================================================
# 3setup-ml-environment.sh - Python environment + dependencies  (Linux)
# =============================================================================
# STEG 3 av 11.  ./3setup-ml-environment.sh
#
# Samma steg som Windows 3setup-ml-environment.ps1.
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Kräver inte längre SQL Server (pyodbc saknar ARM-wheels på macOS, vilket
#     gjorde att originalet avslutade med ett fel på Apple Silicon).
#   - Använder en lokal .venv så den aldrig blandas med systempaket.
#   - Verifierar att de pinnade versionerna stämmer och att API:t importeras.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================================="
echo "STEP 3/11  -  PYTHON ML ENVIRONMENT"
echo "=========================================================="
echo ""

# --- 1. FIND PYTHON ----------------------------------------------------------
echo "1. Locating Python..." | sed 's/^/  /'

PYTHON_CMD=""
for cmd in python3 python; do
    if command -v "$cmd" >/dev/null 2>&1 && "$cmd" --version >/dev/null 2>&1; then
        PYTHON_CMD="$cmd"
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "  Python was NOT found."
    echo "  macOS:  brew install python@3.11"
    echo "  Linux:  sudo apt install python3.11 python3.11-venv"
    echo ""
    echo "  Note: Python is only needed to run tests locally."
    echo "  Docker runs the application itself."
    exit 1
fi
echo "  Found: $PYTHON_CMD ($($PYTHON_CMD --version 2>&1))"
echo ""

# --- 2. CREATE VIRTUAL ENVIRONMENT ------------------------------------------
echo "2. Creating virtual environment (.venv)..."

if [ ! -d .venv ]; then
    if ! "$PYTHON_CMD" -m venv .venv; then
        echo "  Failed to create the virtual environment."
        echo "  On Debian/Ubuntu install the venv package:"
        echo "    sudo apt install python3.11-venv"
        exit 1
    fi
    echo "  Created .venv"
else
    echo "  .venv already exists - reusing it"
fi

VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python"
if [ ! -f "$VENV_PYTHON" ]; then
    echo "  Cannot find $VENV_PYTHON"
    exit 1
fi
echo ""

# --- 3. INSTALL DEPENDENCIES ------------------------------------------------
echo "3. Installing dependencies from requirements.txt..."
echo "  This downloads MLflow/scikit-learn and can take several minutes."

"$VENV_PYTHON" -m pip install --upgrade pip --quiet
if ! "$VENV_PYTHON" -m pip install -r requirements.txt; then
    echo "  Dependency installation FAILED."
    echo "  Check your internet connection, then re-run."
    exit 1
fi
echo "  Dependencies installed"
echo ""

# --- 4. KONTROLLERA VERSIONER ------------------------------------------------------
# requirements.txt är den enda sanningen. Om dessa glider isär laddas inte en
# modell-pickle som sparats i en miljö i en annan.
echo "4. Verifying installed versions..."

VERIFY_SCRIPT='
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
'
echo "$VERIFY_SCRIPT" > /tmp/verify_versions.py
"$VENV_PYTHON" /tmp/verify_versions.py
VERIFY_EXIT=$?
rm -f /tmp/verify_versions.py

if [ $VERIFY_EXIT -ne 0 ]; then
    echo "  Version mismatch - delete .venv and re-run for a clean install."
fi
echo ""

# --- 5. IMPORTERINGSKONTROLL ---------------------------------------------------------
# Catch a broken fastapi/starlette pairing now rather than mid-training.
echo "5. Checking that the API imports..."

IMPORT_SCRIPT='
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
'
echo "$IMPORT_SCRIPT" > /tmp/verify_import.py
"$VENV_PYTHON" /tmp/verify_import.py
IMPORT_EXIT=$?
rm -f /tmp/verify_import.py
echo ""

# --- 6. SUMMARY -------------------------------------------------------------
echo "=========================================================="
if [ $VERIFY_EXIT -eq 0 ] && [ $IMPORT_EXIT -eq 0 ]; then
    echo "STEP 3 COMPLETE"
else
    echo "STEP 3 FINISHED WITH WARNINGS"
fi
echo "=========================================================="
echo ""
echo "Activate the environment with:"
echo "  source .venv/bin/activate"
echo ""
echo "Run the tests with:"
echo "  .venv/bin/python -m pytest tests/ -v"
echo ""
echo "Next steps:"
echo "  ./8setup-api.sh        -  build + start API, train a model"
echo "  ./4setup-dvc.sh        -  optional, data versioning"
echo "  ./6setup-mlflow.sh     -  optional, experiment tracking UI"
echo ""
echo "Only needed for the optional SQL Server path:"
echo "  2setup-database.sql                    (SQL Server schema)"
echo "  ./7mlflow-kommandon-sqlserver.sh        (MLflow on SQL Server)"
echo ""

