"""utils.py - feature-ingenjörskap som delas mellan träning och serving.

VIKTIGT: FEATURE_NAMES och SUSPICIOUS_PROCESSES här är den enda sanningen.
Alla träningsskript och Airflow-DAG:en måste importera från den här modulen,
så att modellens inputbredd alltid matchar vad API:t skickar.
"""

import glob
import os

import numpy as np

# --- Modellkatalog ---------------------------------------------------------
# Miljövariabeln vinner, så samma kod fungerar lokalt och i containern.
MODEL_DIR = os.environ.get("MODEL_DIR", "models/production")

# --- Featurekontraktet -----------------------------------------------------
FEATURE_NAMES = [
    "NetworkConnections",
    "IsSystemUser",
    "IsSuspiciousProcess",
]

# Måste vara identiskt med listan som användes vid träningen (mimikatz.exe
# saknades tidigare här, så det tränades som attack men värderades som normalt).
SUSPICIOUS_PROCESSES = [
    "powershell.exe",
    "cmd.exe",
    "wannacry.exe",
    "mimikatz.exe",
]

SYSTEM_USER = "system"


def find_latest_model(model_dir: str = None):
    """Returnera den senast ändrade .pkl i modellkatalogen."""
    directory = model_dir or MODEL_DIR
    files = glob.glob(os.path.join(directory, "*.pkl"))
    if not files:
        return None
    return max(files, key=os.path.getmtime)


def is_suspicious(process_name: str) -> int:
    """1 om processen är ett känt attackverktyg, annars 0. Skiftlägesokänslig."""
    if not process_name:
        return 0
    return 1 if process_name.strip().lower() in SUSPICIOUS_PROCESSES else 0


def is_system_user(username: str) -> int:
    """1 om kontot är det lokala systemkontot, annars 0."""
    if not username:
        return 0
    return 1 if username.strip().lower() == SYSTEM_USER else 0


def prepare_features(network_connections, process_name, username=""):
    """Bygg featureramen i FEATURE_NAMES-ordning.

    Returns a single-row DataFrame with the exact column names the model was
    trained on. Passing a DataFrame (rather than a bare numpy array) keeps
    scikit-learn's feature-name validation happy and surfaces column drift as
    a clear error instead of a silent misalignment.
    """
    import pandas as pd  # imported here to keep the import cost off startup

    return pd.DataFrame(
        [
            {
                "NetworkConnections": float(network_connections),
                "IsSystemUser": float(is_system_user(username)),
                "IsSuspiciousProcess": float(is_suspicious(process_name)),
            }
        ],
        columns=FEATURE_NAMES,
    )


def get_threat_type(prediction) -> str:
    """Map a raw model output to a label."""
    return "Attack" if int(prediction) == 1 else "Normal"


def get_model_version(model_path: str) -> str:
    """Extrahera en versionssträng från endpoint_model_<version>.pkl."""
    name = os.path.basename(model_path)
    for prefix in ("endpoint_model_", "model_"):
        if name.startswith(prefix):
            return name[len(prefix) : -len(".pkl")]
    return os.path.splitext(name)[0]

