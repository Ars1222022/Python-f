# =============================================================================
# 9setup-monitoring.ps1 - Prometheus + Grafana
# =============================================================================
# STEG 9 av 11 (valfritt)
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Tar inte längre bort prometheus\- och grafana\-mapparna. Originalet körde
#     `Remove-Item -Recurse -Force` på båda i början, vilket raderade varje
#     dashboard eller datakälla du redigerat. Nu skapas bara det som saknas.
#   - Grafana konfigureras automatiskt (datakälla + dashboard-JSON), så den
#     manuella "Importera dashboard"-dansen är borta.
#   - Använder compose-profilen `monitoring` istället för enstaka docker run.
#   - Verifierar att Prometheus faktiskt kan skrapa API:t.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 9/11  -  MONITORING (Prometheus + Grafana)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot

# --- 1. KONTROLLERA DOCKER --------------------------------------------------
Write-Host "1. Checking Docker..." -ForegroundColor Yellow
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "  Docker NOT found." -ForegroundColor Red
    exit 1
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Docker daemon is NOT running." -ForegroundColor Red
    exit 1
}
Write-Host "  Docker OK" -ForegroundColor Green
Write-Host ""

# --- 2. REQUIRED FILES -------------------------------------------------------
# Skapa bara det som saknas. Radera aldrig befintlig konfiguration.
Write-Host "2. Checking configuration files..." -ForegroundColor Yellow

$PromDir = Join-Path $ProjectRoot "prometheus"
$GrafDir = Join-Path $ProjectRoot "grafana"
$DashDir = Join-Path $GrafDir "dashboards"
$DsDir    = Join-Path $GrafDir "provisioning\datasources"
$ProvDir  = Join-Path $GrafDir "provisioning\dashboards"

foreach ($d in @($PromDir, $DashDir, $DsDir, $ProvDir)) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Write-Host "  Created: $($d.Replace($ProjectRoot, '.'))" -ForegroundColor Green
    }
}

$PromYml = Join-Path $PromDir "prometheus.yml"
if (-not (Test-Path $PromYml)) {
    $PromConfig = @'
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
'@
    Set-Content -Path $PromYml -Value $PromConfig -Encoding UTF8
    Write-Host "  Created prometheus.yml" -ForegroundColor Green
} else {
    Write-Host "  prometheus.yml already exists - left untouched" -ForegroundColor Gray
}

$DsFile = Join-Path $DsDir "prometheus.yaml"
if (-not (Test-Path $DsFile)) {
    $DsConfig = @'
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
'@
    Set-Content -Path $DsFile -Value $DsConfig -Encoding UTF8
    Write-Host "  Created Grafana datasource (auto-provisioned)" -ForegroundColor Green
} else {
    Write-Host "  Grafana datasource already exists" -ForegroundColor Gray
}

$ProvFile = Join-Path $ProvDir "provider.yaml"
if (-not (Test-Path $ProvFile)) {
    $ProvConfig = @'
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
'@
    Set-Content -Path $ProvFile -Value $ProvConfig -Encoding UTF8
    Write-Host "  Created Grafana dashboard provider" -ForegroundColor Green
} else {
    Write-Host "  Grafana provider already exists" -ForegroundColor Gray
}
Write-Host ""

# --- 3. API:T MÅSTE VARA IGÅNG ------------------------------------------------
Write-Host "3. Making sure the API is up..." -ForegroundColor Yellow
docker compose up -d api 2>$null | Out-Null
Write-Host "  Done" -ForegroundColor Green
Write-Host ""

# --- 4. START MONITORING -----------------------------------------------------
Write-Host "4. Starting Prometheus and Grafana..." -ForegroundColor Yellow
docker compose --profile monitoring up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Failed to start monitoring." -ForegroundColor Red
    Write-Host "  Check: docker compose --profile monitoring logs" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Waiting for Prometheus..."
Start-Sleep -Seconds 15
Write-Host "  Done" -ForegroundColor Green
Write-Host ""

# --- 5. GENERATE TRAFFIC -----------------------------------------------------
# Prometheus registrerar mätvärden först efter att förfrågan har hanterats, så en
# färsk installation visar tomma grafer tills något anropar API:t.
Write-Host "5. Generating sample traffic so the graphs have data..." -ForegroundColor Yellow
for ($i = 0; $i -lt 12; $i++) {
    try {
        if ($i % 2 -eq 0) {
            $b = @{ NetworkConnections = 0; ProcessName = "explorer.exe"; Username = "user" } | ConvertTo-Json
        } else {
            $b = @{ NetworkConnections = 25; ProcessName = "mimikatz.exe"; Username = "attacker" } | ConvertTo-Json
        }
        Invoke-RestMethod -Uri "http://localhost:8000/predict" -Method Post `
                          -Body $b -ContentType "application/json" -TimeoutSec 5 | Out-Null
    } catch {
        # API:t är kanske inte redo än - det är okej
    }
}
Write-Host "  Sent 12 sample predictions" -ForegroundColor Green
Write-Host ""

# --- 6. VERIFIERA SKRAPNING -------------------------------------------------
Write-Host "6. Verifying that Prometheus can scrape the API..." -ForegroundColor Yellow
Start-Sleep -Seconds 20
try {
    $targets = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -TimeoutSec 10
    $up = @($targets.data.activeTargets | Where-Object { $_.health -eq "up" })
    if ($up.Count -gt 0) {
        Write-Host "  Target is UP: $($up[0].scrapeUrl)" -ForegroundColor Green
    } else {
        Write-Host "  No scrape targets are up yet." -ForegroundColor Yellow
        Write-Host "  Wait 30s and refresh, or check: docker compose logs prometheus" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Prometheus is not responding yet - give it another 30s" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "STEP 9 COMPLETE" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "YOUR SERVICES:" -ForegroundColor Yellow
Write-Host "  Prometheus : http://localhost:9090" -ForegroundColor White
Write-Host "  Grafana    : http://localhost:3000  (admin/admin)" -ForegroundColor White
Write-Host "  API metrics: http://localhost:8000/metrics" -ForegroundColor White
Write-Host ""
Write-Host "The dashboard is provisioned automatically." -ForegroundColor Gray
Write-Host "In Grafana: Dashboards -> EndpointSecurityML folder." -ForegroundColor Gray
Write-Host "See grafana-setup-instructions.txt for details." -ForegroundColor Gray
Write-Host ""
Write-Host "Next step:" -ForegroundColor Yellow
Write-Host "  10setup-airflow.ps1  -  orchestration" -ForegroundColor White
Write-Host ""

