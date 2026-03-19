# Photis Nadi — Flutter web build + Rust API server
#
# Build:  docker build -t photisnadi:latest .
# Run:    docker run --rm -p 8080:8080 -p 8094:8094 -e PHOTISNADI_API_KEY=changeme photisnadi:latest

# ---------------------------------------------------------------------------
# Stage 1: Build Rust API server
# ---------------------------------------------------------------------------
FROM rust:bookworm AS rust-builder

WORKDIR /build
COPY v2/ ./
RUN cargo build --release

# ---------------------------------------------------------------------------
# Stage 2: Flutter web build
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS flutter-builder

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
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

# ---------------------------------------------------------------------------
# Stage 3: Serve on agnosticos with Caddy + API server
# ---------------------------------------------------------------------------
FROM ghcr.io/maccracken/agnosticos:latest

LABEL org.opencontainers.image.title="Photis Nadi"
LABEL org.opencontainers.image.description="Kanban task management with daily rituals"
LABEL org.opencontainers.image.source="https://github.com/maccracken/photisnadi"

USER root

RUN groupadd -g 1005 photisnadi && useradd -u 1005 -g photisnadi -m -s /bin/bash photisnadi

RUN apt-get update && apt-get install -y --no-install-recommends \
    caddy \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/photisnadi/web /opt/photisnadi/data \
    && chown -R photisnadi:photisnadi /opt/photisnadi

COPY --from=flutter-builder /build/build/web/ /opt/photisnadi/web/
COPY --from=rust-builder /build/target/release/photisnadi /opt/photisnadi/photisnadi
COPY docker/Caddyfile /opt/photisnadi/Caddyfile
COPY docker/entrypoint.sh /opt/photisnadi/entrypoint.sh
RUN chmod +x /opt/photisnadi/entrypoint.sh /opt/photisnadi/photisnadi

EXPOSE 8080 8094

USER photisnadi
WORKDIR /opt/photisnadi

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -sf http://localhost:8080/ || exit 1

ENTRYPOINT ["/opt/photisnadi/entrypoint.sh"]
CMD ["web"]
