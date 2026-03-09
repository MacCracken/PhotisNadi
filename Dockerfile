# Photis Nadi — Flutter web build on agnosticos base
#
# Build:  docker build -t photisnadi:latest .
# Run:    docker run --rm -p 8080:8080 photisnadi:latest

# ---------------------------------------------------------------------------
# Stage 1: Flutter web build
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch stable \
    https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN flutter precache --web

WORKDIR /build
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

# ---------------------------------------------------------------------------
# Stage 2: Serve on agnosticos with Caddy
# ---------------------------------------------------------------------------
FROM ghcr.io/maccracken/agnosticos:latest

LABEL org.opencontainers.image.title="Photis Nadi"
LABEL org.opencontainers.image.description="Kanban task management with daily rituals"
LABEL org.opencontainers.image.source="https://github.com/maccracken/photisnadi"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    caddy \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/photisnadi/web \
    && chown -R agnos:agnos /opt/photisnadi

COPY --from=builder /build/build/web/ /opt/photisnadi/web/
COPY docker/Caddyfile /opt/photisnadi/Caddyfile
COPY docker/entrypoint.sh /opt/photisnadi/entrypoint.sh
RUN chmod +x /opt/photisnadi/entrypoint.sh

EXPOSE 8080

USER agnos
WORKDIR /opt/photisnadi

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -sf http://localhost:8080/ || exit 1

ENTRYPOINT ["/opt/photisnadi/entrypoint.sh"]
CMD ["web"]
