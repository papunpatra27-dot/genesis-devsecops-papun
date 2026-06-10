"""
Unit and integration tests for the Genesis Platform API.
Coverage target: >= 75 %

Run from the app/ directory:
    py -m pytest tests/ -v --tb=short --cov=. --cov-report=term-missing --cov-fail-under=75
"""
import os
import pytest
from fastapi.testclient import TestClient

# Inject K8s namespace before importing app so the env var is set
os.environ["K8S_NAMESPACE"] = "test-namespace"
os.environ["APP_VERSION"] = "1.0.0"

# Import from 'main' (not 'app.main') because pytest runs from app/ directory
from main import app, units_db  # noqa: E402

client = TestClient(app)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _clear_db():
    units_db.clear()


# ---------------------------------------------------------------------------
# GET /health
# ---------------------------------------------------------------------------
class TestHealth:
    def test_health_returns_200(self):
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_body_shape(self):
        response = client.get("/health")
        body = response.json()
        assert body["status"] == "ok"
        assert body["version"] == "1.0.0"
        assert body["namespace"] == "test-namespace"

    def test_health_content_type_json(self):
        response = client.get("/health")
        assert "application/json" in response.headers["content-type"]


# ---------------------------------------------------------------------------
# POST /platform/units
# ---------------------------------------------------------------------------
class TestCreateUnit:
    def setup_method(self):
        _clear_db()

    def test_create_unit_returns_201(self):
        payload = {"unit_id": "u-001", "status": "active", "tenant_id": "tenant-a"}
        response = client.post("/platform/units", json=payload)
        assert response.status_code == 201

    def test_create_unit_response_body(self):
        payload = {"unit_id": "u-002", "status": "pending", "tenant_id": "tenant-b"}
        response = client.post("/platform/units", json=payload)
        body = response.json()
        assert body["unit_id"] == "u-002"
        assert "created_at" in body

    def test_create_unit_conflict_returns_409(self):
        payload = {"unit_id": "u-dup", "status": "active", "tenant_id": "tenant-a"}
        client.post("/platform/units", json=payload)
        response = client.post("/platform/units", json=payload)
        assert response.status_code == 409

    def test_create_unit_conflict_error_code(self):
        payload = {"unit_id": "u-dup2", "status": "active", "tenant_id": "tenant-a"}
        client.post("/platform/units", json=payload)
        response = client.post("/platform/units", json=payload)
        assert response.json()["detail"]["code"] == "UNIT_CONFLICT"

    def test_create_unit_missing_field_returns_422(self):
        response = client.post("/platform/units", json={"unit_id": "u-003", "status": "active"})
        assert response.status_code == 422

    def test_create_unit_blank_tenant_id_returns_422(self):
        payload = {"unit_id": "u-004", "status": "active", "tenant_id": "   "}
        response = client.post("/platform/units", json=payload)
        assert response.status_code == 422

    def test_create_unit_blank_unit_id_returns_422(self):
        payload = {"unit_id": "", "status": "active", "tenant_id": "tenant-a"}
        response = client.post("/platform/units", json=payload)
        assert response.status_code == 422


# ---------------------------------------------------------------------------
# GET /platform/units/{unit_id}
# ---------------------------------------------------------------------------
class TestGetUnit:
    def setup_method(self):
        _clear_db()

    def test_get_unit_returns_200(self):
        client.post("/platform/units", json={"unit_id": "u-get-1", "status": "active", "tenant_id": "t1"})
        response = client.get("/platform/units/u-get-1")
        assert response.status_code == 200

    def test_get_unit_body_contains_fields(self):
        client.post("/platform/units", json={"unit_id": "u-get-2", "status": "inactive", "tenant_id": "t2"})
        body = client.get("/platform/units/u-get-2").json()
        assert body["unit_id"] == "u-get-2"
        assert body["status"] == "inactive"
        assert body["tenant_id"] == "t2"
        assert "created_at" in body

    def test_get_unit_not_found_returns_404(self):
        response = client.get("/platform/units/nonexistent-unit")
        assert response.status_code == 404

    def test_get_unit_not_found_error_structure(self):
        response = client.get("/platform/units/ghost")
        detail = response.json()["detail"]
        assert detail["code"] == "UNIT_NOT_FOUND"
        assert "request_id" in detail


# ---------------------------------------------------------------------------
# GET /metrics — Prometheus metrics endpoint
# ---------------------------------------------------------------------------
class TestMetrics:
    """Verifies the /metrics endpoint emits the required custom counters.

    The instruction requires genesis_units_created_total{tenant_id=...} to be
    visible on the Grafana dashboard — which means it MUST appear in the
    Prometheus scrape output.  These tests prove that the FastAPI app correctly
    registers and increments the counter, and that the prometheus_client
    exposition format is exposed at /metrics.
    """

    def setup_method(self):
        _clear_db()

    def test_metrics_endpoint_returns_200(self):
        """Stage 4 gate: /metrics must be reachable with HTTP 200."""
        response = client.get("/metrics")
        assert response.status_code == 200

    def test_metrics_content_type_is_prometheus_text(self):
        """Prometheus scraper expects text/plain; version=0.0.4."""
        response = client.get("/metrics")
        ct = response.headers.get("content-type", "")
        assert "text/plain" in ct

    def test_metrics_contains_http_requests_total(self):
        """http_requests_total counter must be present for SLO PromQL to work."""
        # Generate at least one request to populate the counter
        client.get("/health")
        response = client.get("/metrics")
        assert "http_requests_total" in response.text

    def test_metrics_contains_http_request_duration_seconds(self):
        """Histogram required for P50/P99 latency Grafana panels."""
        client.get("/health")
        response = client.get("/metrics")
        assert "http_request_duration_seconds" in response.text

    def test_metrics_contains_genesis_units_created_total(self):
        """Custom counter genesis_units_created_total MUST appear in /metrics.

        This is the primary business metric displayed on the Grafana dashboard
        (panel: 'Units Created by Tenant').  If this counter is absent,
        the dashboard panel will show 'No data' and the SLO/AnalysisTemplate
        queries will produce incorrect results.
        """
        # Create a unit so the counter is incremented
        client.post(
            "/platform/units",
            json={"unit_id": "metric-unit-1", "status": "active", "tenant_id": "tenant-metrics"},
        )
        response = client.get("/metrics")
        assert "genesis_units_created_total" in response.text, (
            "genesis_units_created_total counter not found in /metrics — "
            "check that UNITS_CREATED_TOTAL.labels(tenant_id=...).inc() is called in POST /platform/units"
        )

    def test_metrics_genesis_counter_increments_per_tenant(self):
        """Each unique tenant_id creates a separate label dimension."""
        # Create units for two different tenants
        client.post(
            "/platform/units",
            json={"unit_id": "mt-a1", "status": "active", "tenant_id": "alpha"},
        )
        client.post(
            "/platform/units",
            json={"unit_id": "mt-b1", "status": "active", "tenant_id": "beta"},
        )
        response = client.get("/metrics")
        body = response.text
        # Both tenant labels must appear as separate series
        assert 'tenant_id="alpha"' in body, "Missing tenant_id=alpha label dimension"
        assert 'tenant_id="beta"' in body, "Missing tenant_id=beta label dimension"

    def test_metrics_counter_value_increases_after_post(self):
        """Counter value MUST be >= 1 after at least one successful POST."""
        client.post(
            "/platform/units",
            json={"unit_id": "mt-c1", "status": "active", "tenant_id": "tenant-count"},
        )
        response = client.get("/metrics")
        # Find the line with our counter for this tenant
        lines = response.text.splitlines()
        counter_lines = [
            ln for ln in lines
            if "genesis_units_created_total" in ln
            and "tenant_id=\"tenant-count\"" in ln
            and not ln.startswith("#")
        ]
        assert len(counter_lines) >= 1, "No metric line found for genesis_units_created_total{tenant_id=tenant-count}"
        # The value at the end of the line must be >= 1.0
        value = float(counter_lines[0].split()[-1])
        assert value >= 1.0, f"Counter value {value} is < 1.0 after successful POST"

    def test_http_requests_total_increments_on_health_call(self):
        """Middleware must record every HTTP call; this underpins the SLO error-rate query."""
        # Make several health calls
        for _ in range(3):
            client.get("/health")
        response = client.get("/metrics")
        lines = response.text.splitlines()
        # Find http_requests_total line(s) with method=GET and endpoint=/health
        req_lines = [
            ln for ln in lines
            if "http_requests_total" in ln
            and "endpoint=\"/health\"" in ln
            and not ln.startswith("#")
        ]
        assert len(req_lines) >= 1, "http_requests_total not recorded for /health calls"
        total = sum(float(ln.split()[-1]) for ln in req_lines)
        assert total >= 3.0, f"Expected >= 3 recorded /health requests, got {total}"


# ---------------------------------------------------------------------------
# Middleware / observability
# ---------------------------------------------------------------------------
class TestMiddleware:
    """Verify the Prometheus middleware correctly labels requests."""

    def setup_method(self):
        _clear_db()

    def test_404_request_still_recorded_in_metrics(self):
        """Even 404 responses must be counted by the middleware (error rate calc)."""
        client.get("/platform/units/does-not-exist-middleware-test")
        response = client.get("/metrics")
        # Check there's at least one 404 line in http_requests_total
        lines = response.text.splitlines()
        err_lines = [
            ln for ln in lines
            if "http_requests_total" in ln and "404" in ln and not ln.startswith("#")
        ]
        assert len(err_lines) >= 1, "404 responses not captured in http_requests_total counter"

    def test_post_conflict_409_recorded_in_metrics(self):
        """409 conflict responses must appear in metrics so SLO query has accurate data."""
        payload = {"unit_id": "mw-dup", "status": "active", "tenant_id": "mw-t"}
        client.post("/platform/units", json=payload)
        client.post("/platform/units", json=payload)  # triggers 409
        response = client.get("/metrics")
        lines = response.text.splitlines()
        conflict_lines = [
            ln for ln in lines
            if "http_requests_total" in ln and "409" in ln and not ln.startswith("#")
        ]
        assert len(conflict_lines) >= 1, "409 responses not captured in http_requests_total counter"
