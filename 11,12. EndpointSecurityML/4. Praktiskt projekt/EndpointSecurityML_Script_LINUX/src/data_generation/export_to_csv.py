"""export_to_csv.py - exportera endpointaktivitet från PostgreSQL till CSV.

Default target is the PostgreSQL instance in docker-compose.yml, which is
what runs on Linux, macOS and Windows alike.

Set DB_DIALECT=mssql to use SQL Server instead (requires pyodbc + the ODBC
driver, and is only practical from Windows/macOS - not from Linux containers).
"""

import argparse
import os
from datetime import datetime

import pandas as pd

DATA_DIR = os.environ.get("DATA_DIR", "data/raw")
DIALECT = os.environ.get("DB_DIALECT", "postgres")

PG_CONFIG = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": os.environ.get("PGPORT", "5432"),
    "user": os.environ.get("PGUSER", "airflow"),
    "password": os.environ.get("PGPASSWORD", "airflow"),
    "dbname": os.environ.get("PGDATABASE", "endpointsecurity"),
}

MSSQL_CONFIG = {
    "driver": os.environ.get("MSSQL_DRIVER", "ODBC Driver 17 for SQL Server"),
    "server": os.environ.get("MSSQL_SERVER", "localhost"),
    "database": os.environ.get("MSSQL_DATABASE", "EndpointSecurityML"),
    "trusted_connection": os.environ.get("MSSQL_TRUSTED", "yes"),
}

QUERY = """
SELECT ActivityID, Timestamp, ComputerName, Username, ProcessName,
       ParentProcess, NetworkConnections, IsAttack, ThreatType
FROM EndpointActivities
"""


def get_connection():
    if DIALECT == "mssql":
        import pyodbc  # imported lazily - not needed for PostgreSQL

        conn_str = (
            f"DRIVER={{{MSSQL_CONFIG['driver']}}};"
            f"SERVER={MSSQL_CONFIG['server']};"
            f"DATABASE={MSSQL_CONFIG['database']};"
            f"Trusted_Connection={MSSQL_CONFIG['trusted_connection']};"
        )
        return pyodbc.connect(conn_str, timeout=10)
    import psycopg

    return psycopg.connect(**PG_CONFIG)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--table", default="endpoint_activities")
    args = parser.parse_args()

    query = QUERY.replace("EndpointActivities", args.table)

    print(f"Connecting to {DIALECT}...")
    try:
        conn = get_connection()
    except Exception as exc:  # noqa: BLE001
        print(f"Could not connect: {exc}")
        raise SystemExit(1)

    print(f"Reading from {args.table}...")
    try:
        df = pd.read_sql(query, conn)
    except Exception as exc:  # noqa: BLE001
        print(f"Query failed: {exc}")
        conn.close()
        raise SystemExit(1)

    if df.empty:
        print("No rows found. Load the seed data first (see postgres/init).")
        conn.close()
        raise SystemExit(1)

    os.makedirs(DATA_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_path = os.path.join(DATA_DIR, f"endpoint_data_{timestamp}.csv")
    df.to_csv(csv_path, index=False)

    print(f"Wrote {len(df)} rows to {csv_path}")
    conn.close()
    print("Export complete.")


if __name__ == "__main__":
    main()

