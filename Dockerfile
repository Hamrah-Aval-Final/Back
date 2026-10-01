FROM python:3.11-slim AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

RUN python -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .

RUN pip install --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt


FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

RUN groupadd --gid 10001 app \
    && useradd \
        --uid 10001 \
        --gid app \
        --create-home \
        --home-dir /app \
        --shell /usr/sbin/nologin \
        app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=10001:10001 \
    __init__.py \
    cache.py \
    config.py \
    database.py \
    main.py \
    models.py \
    schemas.py \
    /app/Back/

COPY --chown=10001:10001 routers/ /app/Back/routers/
USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/live', timeout=2).read()" || exit 1

CMD ["uvicorn", "Back.main:app", "--host", "0.0.0.0", "--port", "8000"]