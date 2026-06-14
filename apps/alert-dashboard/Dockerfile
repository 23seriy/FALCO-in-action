FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

RUN groupadd -r appuser && useradd -r -g appuser -u 10001 appuser

COPY --from=builder /install /usr/local
WORKDIR /app
COPY app.py .

USER 10001

EXPOSE 8080

CMD ["python", "app.py"]
