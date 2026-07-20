# ---------------------------------------------------------------------------
# Application image for the local deployment pipeline.
#
# Multi-stage so that Jenkins can run the unit tests with the exact same
# dependency set that ships to production:
#   docker build --target test .      -> runs pytest, fails the build on error
#   docker build --target runtime .   -> lean image, no test tooling inside
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /srv/app

COPY app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./

# --- test stage: executed only when built with --target test -----------------
FROM base AS test
RUN pip install --no-cache-dir pytest==8.2.2
RUN pytest -q

# --- runtime stage: the image Terraform actually deploys ---------------------
FROM base AS runtime

# Build metadata baked in by Jenkins so the running container can prove which
# commit and build produced it.
ARG BUILD_NUMBER=dev
ARG GIT_COMMIT=unknown
ENV BUILD_NUMBER=${BUILD_NUMBER} \
    GIT_COMMIT=${GIT_COMMIT} \
    APP_NAME=pipeline-demo

RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 5000

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/health').status==200 else 1)"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
