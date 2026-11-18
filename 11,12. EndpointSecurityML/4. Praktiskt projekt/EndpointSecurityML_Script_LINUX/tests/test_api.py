"""API tests.

Two layers:
  * unit tests for the feature contract - no server needed, always run
  * integration tests against a live API - skipped automatically if it is down

This means `pytest` is meaningful both in CI and on a laptop.
"""

import os

import pytest
from fastapi.testclient import TestClient

from src.api.app import app, model
from src.api.utils import (
    FEATURE_NAMES,
    get_threat_type,
    is_suspicious,
    is_system_user,
    prepare_features,
)

API_URL = os.environ.get("API_URL", "http://localhost:8000")

client = TestClient(app)


# -----------------------------------------------------------------------------
# Feature contract
# -----------------------------------------------------------------------------
def test_feature_names_are_the_shared_contract():
    assert FEATURE_NAMES == [
        "NetworkConnections",
        "IsSystemUser",
        "IsSuspiciousProcess",
    ]


def test_prepare_features_shape_and_columns():
    features = prepare_features(5, "powershell.exe", "system")
    assert list(features.columns) == FEATURE_NAMES
    assert features.shape == (1, 3)


@pytest.mark.parametrize(
    "process,expected",
    [
        ("powershell.exe", 1),
        ("cmd.exe", 1),
        ("wannacry.exe", 1),
        ("mimikatz.exe", 1),  # was missing before - caused false negatives
        ("explorer.exe", 0),
        ("notepad.exe", 0),
        ("", 0),
    ],
)
def test_is_suspicious(process, expected):
    assert is_suspicious(process) == expected


@pytest.mark.parametrize(
    "user,expected",
    [("system", 1), ("SYSTEM", 1), ("user", 0), ("", 0), (None, 0)],
)
def test_is_system_user(user, expected):
    assert is_system_user(user) == expected


def test_get_threat_type():
    assert get_threat_type(1) == "Attack"
    assert get_threat_type(0) == "Normal"


# -----------------------------------------------------------------------------
# App-level tests (no external server)
# -----------------------------------------------------------------------------
def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["features"] == FEATURE_NAMES


def test_root_endpoint():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["features"] == FEATURE_NAMES


def test_predict_requires_a_model():
    response = client.post(
        "/predict", json={"NetworkConnections": 1, "ProcessName": "cmd.exe"}
    )
    # 503 när ingen modell finns på disk, 200 när en finns - båda är giltiga
    assert response.status_code in (200, 503)


def test_predict_rejects_negative_connections():
    response = client.post(
        "/predict", json={"NetworkConnections": -1, "ProcessName": "cmd.exe"}
    )
    assert response.status_code == 422


def test_metrics_endpoint_exposes_prometheus_metrics():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_requests_total" in response.text


# -----------------------------------------------------------------------------
# Integrations tester (kräver ett körande API med en tränad modell)
# -----------------------------------------------------------------------------
def _api_is_up() -> bool:
    try:
        import requests

        return requests.get(f"{API_URL}/health", timeout=2).status_code == 200
    except Exception:  # noqa: BLE001
        return False


needs_live_api = pytest.mark.skipif(
    not _api_is_up(), reason=f"No live API at {API_URL}"
)


@needs_live_api
def test_live_health():
    import requests

    response = requests.get(f"{API_URL}/health", timeout=5)
    assert response.status_code == 200
    assert response.json()["model_loaded"] is True


@needs_live_api
def test_live_predict_normal():
    import requests

    response = requests.post(
        f"{API_URL}/predict",
        json={"NetworkConnections": 0, "ProcessName": "notepad.exe", "Username": "user"},
        timeout=5,
    )
    assert response.status_code == 200
    body = response.json()
    assert body["threat_type"] == "Normal"
    assert 0.0 <= body["confidence"] <= 1.0


@needs_live_api
def test_live_predict_attack():
    import requests

    response = requests.post(
        f"{API_URL}/predict",
        json={
            "NetworkConnections": 25,
            "ProcessName": "mimikatz.exe",
            "Username": "attacker",
        },
        timeout=5,
    )
    assert response.status_code == 200
    body = response.json()
    assert body["prediction"] == 1
    assert body["threat_type"] == "Attack"

