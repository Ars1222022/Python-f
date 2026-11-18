"""models.py - Pydantic request/response-scheman för API:t."""

from typing import Optional

from pydantic import BaseModel, Field


class PredictionRequest(BaseModel):
    """Single endpoint activity to classify.

    Username is optional (defaults to an empty string) so older clients that
    only send NetworkConnections + ProcessName keep working. It is used to
    derive the IsSystemUser feature.
    """

    NetworkConnections: int = Field(
        ..., ge=0, description="Number of outbound network connections"
    )
    ProcessName: str = Field(..., description="Process executable name")
    Username: str = Field(
        "", description="Account the process runs as (optional)"
    )


class PredictionResponse(BaseModel):
    prediction: int = Field(..., description="0 = Normal, 1 = Attack")
    confidence: float = Field(..., ge=0.0, le=1.0)
    threat_type: str
    model_version: str


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    model_version: Optional[str] = None
    features: Optional[list] = None

