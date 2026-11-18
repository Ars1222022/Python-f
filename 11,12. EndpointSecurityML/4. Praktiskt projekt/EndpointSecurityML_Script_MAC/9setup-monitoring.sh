#!/usr/bin/env bash
# =============================================================================
# 9setup-monitoring.sh - Prometheus + Grafana  (macOS / Linux)
# =============================================================================
# STEG 9 av 11 (valfritt).  ./9setup-monitoring.sh
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Tar inte längre bort prometheus/- och grafana/-mapparna. Originalet körde
#     `rm -rf` på båda i början, vilket raderade varje dashboard du redigerat.
#     Nu skapas bara det som saknas.
#   - Grafana konfigureras automatiskt (datakälla + dashboard), så det manuella
#     steget "Importera dashboard" är borta.
#   - Använder compose-profilen `monitoring`.
#   - Verifierar att Prometheus faktiskt kan skrapa API:t.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================================="
echo "STEP 9/11  -  MONITORING (Prometheus + Grafana)"
echo "=========================================================="
echo ""

echo "1. Checking Docker..."
command -v docker >/dev/null 2>&1 || { echo "  Docker NOT found."; exit 1; }
docker info >/dev/null 2>&1 || { echo "  Docker daemon is NOT running."; exit 1; }
echo "  Docker OK"
echo ""

echo "2. Checking configuration files..."
mkdir -p prometheus grafana/dashboards \
         grafana/provisioning/datasources \
         grafana/provisioning/dashboards

if [ ! -f prometheus/prometheus.yml ]; then
    cat > prometheus/prometheus.yml <<'YAML'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "fastapi"
    metrics_path: /metrics
    static_configs:
      - targets: ["api:8000"]
        labels:
          service: "endpointsecurity-api"
YAML
    echo "  Created prometheus/prometheus.yml"
else
    echo "  prometheus/prometheus.yml already exists - left untouched"
fi

if [ ! -f grafana/provisioning/datasources/prometheus.yaml ]; then
    cat > grafana/provisioning/datasources/prometheus.yaml <<'YAML'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: 15s
YAML
    echo "  Created Grafana datasource (auto-provisioned)"
else
    echo "  Grafana datasource already exists"
fi

if [ ! -f grafana/provisioning/dashboards/provider.yaml ]; then
    cat > grafana/provisioning/dashboards/provider.yaml <<'YAML'
apiVersion: 1

providers:
  - name: EndpointSecurityML
    orgId: 1
    folder: EndpointSecurityML
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: false
YAML
    echo "  Created Grafana dashboard provider"
else
    echo "  Grafana provider already exists"
fi
echo ""

echo "3. Making sure the API is up..."
docker compose up -d api >/dev/null 2>&1
echo "  Done"
echo ""

echo "4. Starting Prometheus and Grafana..."
if ! docker compose --profile monitoring up -d; then
    echo "  Failed to start monitoring."
    echo "  Check: docker compose --profile monitoring logs"
    exit 1
fi
echo "  Waiting for Prometheus..."
sleep 15
echo "  Done"
echo ""

# Prometheus registrerar mätvärden först efter att förfrågan hanterats, så en
# färsk installation visar tomma grafer tills något anropar API:t.
echo "5. Generating sample traffic so the graphs have data..."
for i in $(seq 1 12); do
    if [ $((i % 2)) -eq 0 ]; then
        PAYLOAD='{"NetworkConnections": 0, "ProcessName": "explorer.exe", "Username": "user"}'
    else
        PAYLOAD='{"NetworkConnections": 25, "ProcessName": "mimikatz.exe", "Username": "attacker"}'
    fi
    curl -s -o /dev/null --max-time 5 -X POST http://localhost:8000/predict \
        -H 'Content-Type: application/json' -d "$PAYLOAD" 2>/dev/null || true
done
echo "  Sent 12 sample predictions"
echo ""

echo "6. Verifying that Prometheus can scrape the API..."
sleep 20
TARGETS=$(curl -s --max-time 10 http://localhost:9090/api/v1/targets 2>/dev/null || true)
if echo "$TARGETS" | grep -q '"health":"up"'; then
    echo "  Target is UP"
else
    echo "  No scrape targets are up yet."
    echo "  Wait 30s and refresh, or check: docker compose logs prometheus"
fi
echo ""

echo "=========================================================="
echo "STEP 9 COMPLETE"
echo "=========================================================="
echo ""
echo "YOUR SERVICES:"
echo "  Prometheus : http://localhost:9090"
echo "  Grafana    : http://localhost:3000  (admin/admin)"
echo "  API metrics: http://localhost:8000/metrics"
echo ""
echo "The dashboard is provisioned automatically."
echo "In Grafana: Dashboards -> EndpointSecurityML folder."
echo "See grafana-setup-instructions.txt for details."
echo ""
echo "Next step:"
echo "  ./10setup-airflow.sh  -  orchestration"
echo ""
