# Intentionally runs as root — this is the "bad" container for the demo.
# It needs root to read /etc/shadow, write to /usr/bin, etc.
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080

CMD ["python", "app.py"]
