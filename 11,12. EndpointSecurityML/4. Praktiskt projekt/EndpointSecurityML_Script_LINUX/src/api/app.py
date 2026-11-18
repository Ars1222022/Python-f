"""app.py - FastAPI-tjänst med Prometheus-mätvärden."""

import os
import time
from contextlib import asynccontextmanager

import joblib
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from prometheus_client import (
    REGISTRY,
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)

from .models import HealthResponse, PredictionRequest, PredictionResponse
from .utils import (
    FEATURE_NAMES,
    find_latest_model,
    get_model_version,
    get_threat_type,
    prepare_features,
)

REQUEST_COUNT = Counter(
    "http_requests_total", "Total requests", ["method", "endpoint", "status"]
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds", "Request duration", ["method", "endpoint"]
)
PREDICTION_COUNT = Counter(
    "predictions_total", "Total predictions", ["threat_type"]
)
ERROR_COUNT = Counter("http_errors_total", "Total errors", ["method", "endpoint"])
PREDICTION_CONFIDENCE = Histogram(
    "prediction_confidence",
    "Model confidence",
    buckets=(0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.99, 1.0),
)

model = None
model_version = None


def _load_model():
    """Ladda den nyaste modellen vid start. Loggar istället för att krascha."""
    global model, model_version
    path = find_latest_model()
    if not path:
        print("[api] WARNING: no model found - /predict will return 503")
        return
    try:
        model = joblib.load(path)
        model_version = get_model_version(path)
        print(f"[api] Model loaded: {path} (version={model_version})")
    except Exception as exc:  # noqa: BLE001
        print(f"[api] ERROR loading model {path}: {exc}")
        model = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    _load_model()
    yield


app = FastAPI(
    title="Endpoint Security ML API",
    version=model_version or "1.0.0",
    lifespan=lifespan,
)


@app.middleware("http")
async def monitor_requests(request: Request, call_next):
    method = request.method
    endpoint = request.url.path
    start = time.time()
    try:
        response = await call_next(request)
    except Exception:
        ERROR_COUNT.labels(method=method, endpoint=endpoint).inc()
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(
            time.time() - start
        )
        raise
    duration = time.time() - start
    REQUEST_COUNT.labels(
        method=method, endpoint=endpoint, status=response.status_code
    ).inc()
    REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(duration)
    if response.status_code >= 400:
        ERROR_COUNT.labels(method=method, endpoint=endpoint).inc()
    return response



@app.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(
        status="ok",
        model_loaded=model is not None,
        model_version=model_version,
        features=FEATURE_NAMES,
    )


@app.get("/reload")
async def reload_model():
    """Läs om den nyaste modellen från disk (efter omtränning)."""
    if model is None:
        _load_model()
        if model is None:
            raise HTTPException(status_code=503, detail="No model available")
    return {
        "reloaded": True,
        "model_version": model_version,
        "features": FEATURE_NAMES,
    }


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    if model is None:
        raise HTTPException(status_code=503, detail="No model loaded")

    features = prepare_features(
        request.NetworkConnections, request.ProcessName, request.Username
    )

    if hasattr(model, "predict_proba"):
        confidence = float(model.predict_proba(features).max())
    else:  # pragma: no cover - defensive
        confidence = 1.0

    pred = int(model.predict(features)[0])
    threat = get_threat_type(pred)

    PREDICTION_COUNT.labels(threat_type=threat).inc()
    PREDICTION_CONFIDENCE.observe(confidence)

    return PredictionResponse(
        prediction=pred,
        confidence=confidence,
        threat_type=threat,
        model_version=model_version or "unknown",
    )


@app.get("/metrics")
async def get_metrics():
    return Response(content=generate_latest(REGISTRY), media_type=CONTENT_TYPE_LATEST)


@app.get("/")
async def root():
    return {
        "message": "Endpoint Security ML API",
        "docs": "/docs",
        "health": "/health",
        "metrics": "/metrics",
        "reload": "/reload",
        "predict": "/predict (POST)",
        "features": FEATURE_NAMES,
    }

