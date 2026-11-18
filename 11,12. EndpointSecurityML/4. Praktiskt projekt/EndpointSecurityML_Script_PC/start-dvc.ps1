# =============================================================================
# start-dvc.ps1 - Open a DVC shell
# =============================================================================
# Bekvämlighetsstartare för löpande DVC-arbete.
# Kör 4setup-dvc.ps1 en gång först.
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Kör DVC i containern istället för den committade dvc.exe, så det fungerar
#     på Windows, macOS och Linux och alltid använder den pinnade DVC-versionen.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "DVC SHELL" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker is required." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path (Join-Path $ProjectRoot ".dvc"))) {
    Write-Host "DVC is not initialised in this folder." -ForegroundColor Red
    Write-Host "Run 4setup-dvc.ps1 first." -ForegroundColor Yellow
    exit 1
}

$Args = $args
if ($Args.Count -eq 0) {
    Write-Host "No command given - opening an interactive shell." -ForegroundColor Gray
    Write-Host "Type 'dvc --help' inside the container." -ForegroundColor Gray
    Write-Host ""
    docker compose --profile dvc run --rm dvc shell
} else {
    Write-Host "Running: dvc $($Args -join ' ')" -ForegroundColor Cyan
    docker compose --profile dvc run --rm dvc @Args
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
