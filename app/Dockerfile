# ── Stage 1: builder ────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

# Install dependencies into a local prefix so the runtime stage stays small
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime ────────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

# Security: run as a non-root user (UID 1000)
RUN groupadd --gid 1000 appgroup && \
    useradd --uid 1000 --gid appgroup --no-create-home --shell /sbin/nologin appuser

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY main.py .

# Drop privileges before starting the server
USER appuser

ENV APP_VERSION="1.0.0" \
    K8S_NAMESPACE="default" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8000

# Use exec form so signals propagate correctly
ENTRYPOINT ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
