# syntax=docker/dockerfile:1
FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

LABEL org.opencontainers.image.title="arena-security-api" \
      org.opencontainers.image.description="Compliant NBA arena security service for Falco demo" \
      org.opencontainers.image.source="https://github.com/23seriy/FALCO-in-action" \
      org.opencontainers.image.licenses="MIT"

RUN groupadd -r appuser && useradd -r -g appuser -u 10001 appuser

COPY --from=builder /install /usr/local
WORKDIR /app
COPY app.py .

USER 10001

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

CMD ["python", "app.py"]
