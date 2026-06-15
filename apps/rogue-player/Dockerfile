# syntax=docker/dockerfile:1
# Intentionally runs as root — this is the "bad" container for the demo.
# It needs root to read /etc/shadow, write to /usr/bin, etc.
FROM python:3.12-slim

LABEL org.opencontainers.image.title="rogue-player" \
      org.opencontainers.image.description="Attack simulation pod for Falco demo (intentionally insecure)" \
      org.opencontainers.image.source="https://github.com/23seriy/FALCO-in-action" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

CMD ["python", "app.py"]
