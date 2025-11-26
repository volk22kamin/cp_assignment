FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY app.py .

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "60", "app:app"]
