# --- Stage 1: test/build (has Playwright for E2E) ---
FROM mcr.microsoft.com/playwright/python:v1.47.0-noble AS test
WORKDIR /app

# Install all Python deps (Playwright browsers too)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    python -m playwright install --with-deps

# Bring in the app code
COPY . .

# --- Stage 2: runtime (small, fewer CVEs) ---
FROM python:3.11-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app

# Install only what’s needed to RUN the app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    useradd -m appuser

# Copy built app from test stage
COPY --from=test /app /app
USER appuser

EXPOSE 8000

# Healthcheck without curl (uses Python stdlib)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health');" || exit 1

CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]

