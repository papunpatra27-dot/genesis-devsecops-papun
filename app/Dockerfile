FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim AS runtime

RUN groupadd --gid 1000 appgroup && \
    useradd \
      --uid 1000 \
      --gid appgroup \
      --create-home \
      --shell /usr/sbin/nologin \
      appuser

WORKDIR /app

COPY --from=builder /install /usr/local
COPY main.py .

ENV APP_VERSION="1.0.0" \
    K8S_NAMESPACE="default" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

USER 1000:1000

EXPOSE 8000

ENTRYPOINT ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]