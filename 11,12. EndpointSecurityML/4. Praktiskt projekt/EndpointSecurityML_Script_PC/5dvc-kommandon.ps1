# =============================================================================
# 5dvc-kommandon.ps1 - Interactive DVC command menu
# =============================================================================
# STEG 5 hjälpskript (valfritt, kräver att 4setup-dvc.ps1 körts först)
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Originalet startade den committade dvc.exe, som bara fungerar på
#     Windows och kan avvika från den pinnade DVC-versionen. DVC körs nu i
#     containern som byggs från Dockerfile.versioning, så det fungerar överallt.
#   - Varje kommando bekräftas innan det körs, så ett vildkort tryck inte kan
#     discard tracked data.
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "DVC COMMAND MENU" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot

if (-not (Test-Path (Join-Path $ProjectRoot ".dvc"))) {
    Write-Host "DVC is not initialised here." -ForegroundColor Red
    Write-Host "Run 4setup-dvc.ps1 first." -ForegroundColor Yellow
    exit 1
}

function Invoke-Dvc {
    docker compose --profile dvc run --rm dvc @args
}

function Confirm-Action {
    param([string] $Question)
    $answer = Read-Host "  $Question (y/N)"
    return ($answer -eq 'y' -or $answer -eq 'Y')
}

$running = $true
while ($running) {
    Write-Host ""
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " 1) status        - what changed" -ForegroundColor White
    Write-Host " 2) diff          - what changed in detail" -ForegroundColor White
    Write-Host " 3) add data/raw  - start tracking a file/folder" -ForegroundColor White
    Write-Host " 4) commit        - save a version with a message" -ForegroundColor White
    Write-Host " 5) log           - history of versions" -ForegroundColor White
    Write-Host " 6) pull          - fetch remote versions" -ForegroundColor White
    Write-Host " 7) push          - send local versions to the remote" -ForegroundColor White
    Write-Host " 8) list models   - tracked .pkl files" -ForegroundColor White
    Write-Host " 0) exit" -ForegroundColor White
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray

    $choice = Read-Host "Choose"
    switch ($choice) {
        "1" { Invoke-Dvc status }
        "2" { Invoke-Dvc diff }
        "3" {
            $target = Read-Host "  Path to track [data/raw]"
            if (-not $target) { $target = "data/raw" }
            Invoke-Dvc add $target
        }
        "4" {
            $msg = Read-Host "  Commit message"
            if ($msg) {
                if (Confirm-Action "Save this version?") {
                    Invoke-Dvc commit -m $msg
                } else {
                    Write-Host "  Cancelled" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  A message is required" -ForegroundColor Yellow
            }
        }
        "5" { Invoke-Dvc log }
        "6" { Invoke-Dvc pull }
        "7" {
            if (Confirm-Action "Send your versions to the remote?") {
                Invoke-Dvc push
            } else {
                Write-Host "  Cancelled" -ForegroundColor Yellow
            }
        }
        "8" { Invoke-Dvc list "models/production/*.pkl" }
        "0" { $running = $false }
        default { Write-Host "  Invalid choice" -ForegroundColor Yellow }
    }
}

Write-Host ""
Write-Host "Bye!" -ForegroundColor Cyan
