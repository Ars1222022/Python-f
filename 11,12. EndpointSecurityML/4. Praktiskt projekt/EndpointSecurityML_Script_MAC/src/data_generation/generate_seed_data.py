"""generate_seed_data.py - skapa start-CSV:en så projektet körs från noll.

Without this, every training script exits with "no data found" on a clean
clone. Generates a deterministic, clearly-labelled synthetic dataset with the
same columns as the SQL tables.

    python -m src.data_generation.generate_seed_data
"""

import argparse
import os
from datetime import datetime, timedelta

import numpy as np
import pandas as pd

from src.api.utils import SUSPICIOUS_PROCESSES

NORMAL_PROCESSES = [
    "explorer.exe",
    "svchost.exe",
    "chrome.exe",
    "outlook.exe",
    "notepad.exe",
    "Teams.exe",
    "OneDrive.exe",
]
NORMAL_PARENTS = ["winlogon.exe", "services.exe", "explorer.exe", "userinit.exe"]
ATTACK_PARENTS = ["services.exe", "winlogon.exe", "explorer.exe"]


def build_dataset(n_normal: int, n_attack: int, seed: int) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    start = datetime(2026, 1, 1, 0, 0, 0)
    rows = []

    def stamp():
        return start + timedelta(seconds=int(rng.integers(0, 90 * 24 * 3600)))

    for _ in range(n_normal):
        rows.append(
            {
                "Timestamp": stamp(),
                "ComputerName": f"COMPUTER{rng.integers(0, 10)}",
                "Username": "system" if rng.random() < 0.15 else "user",
                "ProcessName": str(rng.choice(NORMAL_PROCESSES)),
                "ParentProcess": str(rng.choice(NORMAL_PARENTS)),
                # Normal traffic stays low
                "NetworkConnections": int(rng.integers(0, 6)),
                "IsAttack": 0,
                "ThreatType": None,
            }
        )

    for _ in range(n_attack):
        rows.append(
            {
                "Timestamp": stamp(),
                "ComputerName": f"COMPUTER{rng.integers(0, 10)}",
                "Username": "system" if rng.random() < 0.35 else "attacker",
                "ProcessName": str(rng.choice(SUSPICIOUS_PROCESSES)),
                "ParentProcess": str(rng.choice(ATTACK_PARENTS)),
                # Attacks fan out to many hosts
                "NetworkConnections": int(rng.integers(10, 40)),
                "IsAttack": 1,
                "ThreatType": "Ransomware" if rng.random() < 0.5 else "Malware",
            }
        )

    df = pd.DataFrame(rows).sort_values("Timestamp").reset_index(drop=True)
    df.insert(0, "ActivityID", range(1, len(df) + 1))
    return df


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--normal", type=int, default=800)
    parser.add_argument("--attack", type=int, default=200)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--out",
        default=os.environ.get("DATA_DIR", "data/raw"),
        help="output directory",
    )
    args = parser.parse_args()

    df = build_dataset(args.normal, args.attack, args.seed)
    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, "endpoint_seed.csv")
    df.to_csv(path, index=False)

    print(f"Wrote {len(df)} rows to {path}")
    print(f"  Normal: {int((df['IsAttack'] == 0).sum())}")
    print(f"  Attack: {int(df['IsAttack'].sum())}")
    print("\nNext:  python -m src.training.train_with_mlflow")


if __name__ == "__main__":
    import sys

    sys.path.insert(
        0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    )
    main()
