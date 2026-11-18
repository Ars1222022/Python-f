#!/usr/bin/env bash
# =============================================================================
# start-mlflow-sqlserver.sh - MLflow UI med SQL Server  (Linux)
# =============================================================================
# Bekvämlighetsstartare för den VALFRIRA SQL Server-vägen.
# Rekommenderad standard är ./6setup-mlflow.sh (SQLite), som kräver inget
# extra. Använd det här bara om du redan underhåller SQL Server.
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - `mlflow ui` -> `mlflow server` (det gamla aliaset är deprecated).
#   - Kontrollerar förutsättningar INNAN start, istället för att misslyckas med
#     ett otydligt drivrutefel halvvägs.
#   - Binder till 127.0.0.1 istället för 0.0.0.0 så det inte exponeras för nätverket.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================================="
echo "MLFLOW UI - SQL SERVER BACKEND"
echo "=========================================================="
echo ""

VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python"
if [ ! -f "$VENV_PYTHON" ]; then
    echo "No virtual environment found."
    echo "Run ./3setup-ml-environment.sh first."
    exit 1
fi

echo "1. Checking pyodbc..."
if ! "$VENV_PYTHON" -c "import pyodbc" 2>/dev/null; then
    echo "  pyodbc is NOT installed"
    echo "  Install it with:  .venv/bin/pip install pyodbc"
    echo "  And install 'ODBC Driver 17 for SQL Server'."
    echo ""
    echo "  Consider the simpler alternative instead:"
    echo "    ./6setup-mlflow.sh        (SQLite, works everywhere)"
    exit 1
fi
echo "  pyodbc OK"
echo ""

echo "2. Checking the EndpointSecurityML database..."
DB_CHECK='
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
'
echo "$DB_CHECK" > /tmp/check_db.py
"$VENV_PYTHON" /tmp/check_db.py
DB_RESULT=$?
rm -f /tmp/check_db.py

if [ $DB_RESULT -eq 1 ]; then
    echo ""
    echo "The database does not exist yet."
    echo "Run 2setup-database.sql in SSMS first."
    exit 1
fi
if [ $DB_RESULT -eq 2 ]; then
    echo ""
    echo "Cannot reach SQL Server on localhost."
    echo "Start SQL Server, then run 2setup-database.sql."
    exit 1
fi
echo ""

SQL_URI="mssql+pyodbc://@localhost/EndpointSecurityML?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"

echo "3. Starting MLflow on http://localhost:5000"
echo "  Press Ctrl+C to stop."
echo ""
"$VENV_PYTHON" -m mlflow server --backend-store-uri "$SQL_URI" \
    --host 127.0.0.1 --port 5000

echo ""
echo "MLflow stopped."
