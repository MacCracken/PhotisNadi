#!/bin/sh
set -e

case "${1:-web}" in
  web)
    # Always start API server in background
    echo "Starting Photis Nadi API server on port ${PHOTISNADI_API_PORT:-8094}..."
    /opt/photisnadi/photisnadi --headless \
      --db /opt/photisnadi/data/photisnadi.db \
      --port "${PHOTISNADI_API_PORT:-8094}" &
    API_PID=$!
    # Shut down API server when entrypoint exits
    trap "kill $API_PID 2>/dev/null" EXIT

    echo "Serving Photis Nadi web on port 8080 via Caddy..."
    exec caddy run --config /opt/photisnadi/Caddyfile --adapter caddyfile
    ;;
  api)
    echo "Running Photis Nadi API server only..."
    exec /opt/photisnadi/photisnadi --headless \
      --db /opt/photisnadi/data/photisnadi.db \
      --port "${PHOTISNADI_API_PORT:-8094}"
    ;;
  *)
    exec "$@"
    ;;
esac
