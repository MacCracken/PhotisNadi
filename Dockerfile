# Photis Nadi — Flutter Linux build on agnosticos base
#
# Build:  docker build -t photisnadi:latest .
# Run:    docker run --rm -p 8080:8080 photisnadi:latest

# ---------------------------------------------------------------------------
# Stage 1: Flutter build
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS builder

ARG FLUTTER_VERSION=3.29.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    ca-certificates \
    libgtk-3-dev \
    pkg-config \
    cmake \
    ninja-build \
    clang \
    libayatana-appindicator3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
    https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN flutter precache --linux --web
RUN flutter doctor -v

WORKDIR /build
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release
RUN flutter build linux --release

# ---------------------------------------------------------------------------
# Stage 2: Runtime on agnosticos
# ---------------------------------------------------------------------------
FROM ghcr.io/maccracken/agnosticos:latest

LABEL org.opencontainers.image.title="Photis Nadi"
LABEL org.opencontainers.image.description="Kanban task management with daily rituals"
LABEL org.opencontainers.image.source="https://github.com/maccracken/photisnadi"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    darkhttpd \
    libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/photisnadi/web /opt/photisnadi/linux \
    && chown -R agnos:agnos /opt/photisnadi

COPY --from=builder /build/build/web/ /opt/photisnadi/web/
COPY --from=builder /build/build/linux/x64/release/bundle/ /opt/photisnadi/linux/
COPY docker/entrypoint.sh /opt/photisnadi/entrypoint.sh
RUN chmod +x /opt/photisnadi/entrypoint.sh

EXPOSE 8080

USER agnos

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -sf http://localhost:8080/ || exit 1

ENTRYPOINT ["/opt/photisnadi/entrypoint.sh"]
CMD ["web"]
