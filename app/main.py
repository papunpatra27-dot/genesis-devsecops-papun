"""
Genesis Platform API
A minimal production-quality FastAPI application with Prometheus instrumentation.
"""
import os
import uuid
from datetime import datetime, timezone
import logging

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, field_validator
from prometheus_client import Counter, Histogram, make_asgi_app
import time

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Application bootstrap
# ---------------------------------------------------------------------------
app = FastAPI(title="Genesis Platform API", version="1.0.0")

# ---------------------------------------------------------------------------
# Prometheus metrics
# ---------------------------------------------------------------------------
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP request count",
    ["method", "endpoint", "status_code"],
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)

# Custom business metric — tenant-labelled unit creation counter
# Referenced in Argo Rollouts AnalysisTemplate and SLO definition
UNITS_CREATED_TOTAL = Counter(
    "genesis_units_created_total",
    "Total units created, labelled by tenant",
    ["tenant_id"],
)

# Mount /metrics endpoint (Prometheus scrape target)
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# ---------------------------------------------------------------------------
# Environment configuration
# ---------------------------------------------------------------------------
K8S_NAMESPACE: str = os.getenv("K8S_NAMESPACE", "default")
APP_VERSION: str = os.getenv("APP_VERSION", "1.0.0")

# ---------------------------------------------------------------------------
# In-memory storage (sufficient for this platform demo)
# ---------------------------------------------------------------------------
units_db: dict[str, dict] = {}


# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------
class UnitCreateRequest(BaseModel):
    unit_id: str
    status: str
    tenant_id: str

    @field_validator("unit_id", "status", "tenant_id")
    @classmethod
    def must_not_be_blank(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("Field must not be blank")
        return value.strip()


# ---------------------------------------------------------------------------
# Middleware — record metrics for every request
# ---------------------------------------------------------------------------
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    elapsed = time.perf_counter() - start

    # Normalise path so /platform/units/abc and /platform/units/xyz
    # collapse to the same label cardinality.
    path = request.url.path
    if path.startswith("/platform/units/"):
        label_path = "/platform/units/{unit_id}"
    else:
        label_path = path

    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=label_path,
        status_code=str(response.status_code),
    ).inc()

    REQUEST_LATENCY.labels(
        method=request.method,
        endpoint=label_path,
    ).observe(elapsed)

    return response


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@app.get("/health", summary="Liveness / readiness probe")
async def health_check():
    """
    Returns service health, version, and the Kubernetes namespace the pod
    is running in (injected via the K8S_NAMESPACE environment variable in
    the Rollout manifest).
    """
    return {
        "status": "ok",
        "version": APP_VERSION,
        "namespace": K8S_NAMESPACE,
    }


@app.post("/platform/units", status_code=201, summary="Create a platform unit")
async def create_unit(unit: UnitCreateRequest, request: Request):
    """
    Accepts a JSON body with unit_id, status, and tenant_id.
    Returns 201 with unit_id and created_at on success.
    Returns 409 if the unit already exists.
    """
    if unit.unit_id in units_db:
        raise HTTPException(
            status_code=409,
            detail={
                "error": "Unit already exists",
                "code": "UNIT_CONFLICT",
                "request_id": str(uuid.uuid4()),
            },
        )

    created_at = datetime.now(timezone.utc).isoformat()
    units_db[unit.unit_id] = {
        "unit_id": unit.unit_id,
        "status": unit.status,
        "tenant_id": unit.tenant_id,
        "created_at": created_at,
    }

    # Increment business metric with tenant dimension
    UNITS_CREATED_TOTAL.labels(tenant_id=unit.tenant_id).inc()

    logger.info(
        "Unit created: unit_id=%s tenant_id=%s", unit.unit_id, unit.tenant_id
    )
    return {"unit_id": unit.unit_id, "created_at": created_at}


@app.get(
    "/platform/units/{unit_id}",
    summary="Retrieve a platform unit by ID",
)
async def get_unit(unit_id: str, request: Request):
    """
    Returns the unit record or a structured 404 with error, code, and
    request_id so callers can correlate logs.
    """
    if unit_id not in units_db:
        raise HTTPException(
            status_code=404,
            detail={
                "error": f"Unit '{unit_id}' not found",
                "code": "UNIT_NOT_FOUND",
                "request_id": str(uuid.uuid4()),
            },
        )

    return units_db[unit_id]
