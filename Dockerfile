FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    WEB_CONCURRENCY=2 \
    WEB_TIMEOUT=60

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py db.py auth.py ./
COPY templates ./templates
COPY static ./static

EXPOSE 5000

# Worker count and timeout are env-configurable so deployers can tune
# without rebuilding the image.
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:5000 --workers ${WEB_CONCURRENCY} --timeout ${WEB_TIMEOUT} app:app"]
