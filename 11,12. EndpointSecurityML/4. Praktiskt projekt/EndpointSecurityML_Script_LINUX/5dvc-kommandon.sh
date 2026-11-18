#!/usr/bin/env bash
# =============================================================================
# 5dvc-kommandon.sh - Interactive DVC command menu  (Linux)
# =============================================================================
# STEG 5 hjälpskript (valfritt, kör 4setup-dvc.sh först).  ./5dvc-kommandon.sh
#
# ÄNDRINGAR JÄMFÖRT MED ORIGINALET:
#   - Kör DVC i containern istället för den committade dvc.exe, som bara
#     fungerade på Windows och kunde avvika från den pinnade DVC-versionen.
#   - Destruktiva åtgärder frågar först om bekräftelse.
# =============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================================="
echo "DVC COMMAND MENU"
echo "=========================================================="
echo ""

if [ ! -d .dvc ]; then
    echo "DVC is not initialised here."
    echo "Run ./4setup-dvc.sh first."
    exit 1
fi

dvc() { docker compose --profile dvc run --rm dvc "$@"; }

confirm() {
    printf "  %s (y/N) " "$1"
    read -r answer
    [ "$answer" = "y" ] || [ "$answer" = "Y" ]
}

while true; do
    echo ""
    echo "--------------------------------------------------"
    echo " 1) status        - what changed"
    echo " 2) diff          - what changed in detail"
    echo " 3) add data/raw  - start tracking a file/folder"
    echo " 4) commit        - save a version with a message"
    echo " 5) log           - history of versions"
    echo " 6) pull          - fetch remote versions"
    echo " 7) push          - send local versions to the remote"
    echo " 8) list models   - tracked .pkl files"
    echo " 0) exit"
    echo "--------------------------------------------------"
    printf "Choose: "
    read -r choice

    case "$choice" in
        1) dvc status ;;
        2) dvc diff ;;
        3)
            printf "  Path to track [data/raw]: "
            read -r target
            dvc add "${target:-data/raw}"
            ;;
        4)
            printf "  Commit message: "
            read -r msg
            if [ -z "$msg" ]; then
                echo "  A message is required"
            elif confirm "Save this version?"; then
                dvc commit -m "$msg"
            else
                echo "  Cancelled"
            fi
            ;;
        5) dvc log ;;
        6) dvc pull ;;
        7)
            if confirm "Send your versions to the remote?"; then
                dvc push
            else
                echo "  Cancelled"
            fi
            ;;
        8) dvc list "models/production/*.pkl" ;;
        0) break ;;
        *) echo "  Invalid choice" ;;
    esac
done

echo ""
echo "Bye!"
