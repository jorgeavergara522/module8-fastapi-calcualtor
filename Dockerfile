# ---------- Stage 1: test/build (includes Playwright + pytest etc.) ----------
FROM mcr.microsoft.com/playwright/python:v1.47.0-noble AS test
WORKDIR /app

# Install BOTH runtime and dev/test deps for CI
COPY requirements.txt .
COPY dev-requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt -r dev-requirements.txt

# Bring in the source code (tests, app, etc.)
COPY . .

# No CMD here — this stage is only for building & running tests


# ---------- Stage 2: runtime (small, fewer CVEs) ----------
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install ONLY the runtime deps (no Playwright/pytest/httpx/etc.)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    useradd -m appuser

# Copy the built app from the test stage (code only)
COPY --from=test /app /app

USER appuser
EXPOSE 8000

# Healthcheck without curl (uses Python stdlib)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Start the API
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
