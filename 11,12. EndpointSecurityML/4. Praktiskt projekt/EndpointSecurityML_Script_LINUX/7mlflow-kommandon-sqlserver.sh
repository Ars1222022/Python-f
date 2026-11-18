#!/usr/bin/env bash
# =============================================================================
# 7mlflow-kommandon-sqlserver.sh - MLflow on SQL Server  (Linux)
# =============================================================================
# STEG 7 hjälpskript - VALFRIRT, bara om du använder SQL Server för spårning.
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - `mlflow ui` -> `mlflow server` (det gamla aliaset är deprecated).
#   - Kontrollerar förutsättningar INNAN den försöker ansluta, istället för att
#     misslyckas senare med ett otydligt drivrutefel.
#   - Varnar i förväg om plattformsbegränsningen.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================================="
echo "MLFLOW - SQL SERVER BACKEND"
echo "=========================================================="
echo ""

# pyodbc + Microsoft ODBC-drivern är otillförlitlig på Linux/ARM.
if [ "$(uname)" = "Linux" ] || [ "$(uname -m)" = "arm64" ]; then
    echo "NOTE: pyodbc has no reliable wheels on Linux/ARM." | sed 's/^/  /'
    echo "      Prefer the default SQLite backend: ./6setup-mlflow.sh" | sed 's/^/  /'
    echo ""
fi

SQL_URI="mssql+pyodbc://@localhost/EndpointSecurityML?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"

VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python"
if [ ! -f "$VENV_PYTHON" ]; then
    echo "No virtual environment found." | sed 's/^/  /'
    echo "Run ./3setup-ml-environment.sh first." | sed 's/^/  /'
    exit 1
fi

echo "1. Checking prerequisites..."
if ! "$VENV_PYTHON" -c "import pyodbc" 2>/dev/null; then
    echo "  pyodbc is NOT installed"
    echo "  Install it with:  .venv/bin/pip install pyodbc"
    echo "  And install 'ODBC Driver 17 for SQL Server'."
    echo ""
    echo "  Consider instead:  ./6setup-mlflow.sh   (SQLite, works everywhere)"
    exit 1
fi
echo "  pyodbc OK"

CONNECT_TEST='
import sys
try:
    import pyodbc
    conn = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;"
        "DATABASE=EndpointSecurityML;Trusted_Connection=yes;", timeout=5)
    print("  Connected to EndpointSecurityML")
    conn.close()
    sys.exit(0)
except Exception as exc:
    print("  Could not connect: %s" % exc)
    sys.exit(1)
'
echo "$CONNECT_TEST" > /tmp/test_mssql.py
"$VENV_PYTHON" /tmp/test_mssql.py
RESULT=$?
rm -f /tmp/test_mssql.py

if [ $RESULT -ne 0 ]; then
    echo ""
    echo "SQL Server is not reachable. Check that:" | sed 's/^/  /'
    echo "  - SQL Server is running" | sed 's/^/  /'
    echo "  - the database 'EndpointSecurityML' exists (run 2setup-database.sql)" | sed 's/^/  /'
    echo "  - ODBC Driver 17 for SQL Server is installed" | sed 's/^/  /'
    exit 1
fi
echo ""

echo "Tracking URI:"
echo "  $SQL_URI"
echo ""

while true; do
    echo "--------------------------------------------------"
    echo " 1) Train and log a run to SQL Server"
    echo " 2) Start the MLflow server on SQL Server"
    echo " 3) Show the latest experiments"
    echo " 4) Show saved models"
    echo " 0) Exit"
    echo "--------------------------------------------------"
    printf "Choose: "
    read -r choice

    case "$choice" in
        1)
            echo ""
            MLFLOW_TRACKING_URI="$SQL_URI" DATA_DIR="data/raw" \
            MODEL_DIR="models/production" \
                "$VENV_PYTHON" -m src.training.train_with_mlflow_sqlserver
            ;;
        2)
            echo ""
            echo "Starting the server. Press Ctrl+C to stop." | sed 's/^/  /'
            echo "Then open http://localhost:5000" | sed 's/^/  /'
            echo ""
            "$VENV_PYTHON" -m mlflow server --backend-store-uri "$SQL_URI" \
                --host 127.0.0.1 --port 5000
            ;;
        3)
            echo ""
            MLFLOW_TRACKING_URI="$SQL_URI" \
                "$VENV_PYTHON" -m mlflow experiments search --max-results 5
            ;;
        4)
            echo ""
            echo "Saved models:"
            ls -lt models/production/*.pkl 2>/dev/null || echo "  No models in models/production"
            ;;
        0) break ;;
        *) echo "  Invalid choice" ;;
    esac
done

echo ""
echo "Bye!"
