#!/bin/sh
set -e

case "${1:-web}" in
  web)
    # Start API server in background (if API key is set)
    if [ -n "$PHOTISNADI_API_KEY" ]; then
      echo "Starting Photis Nadi API server on port ${PHOTISNADI_API_PORT:-8081}..."
      /opt/photisnadi/server &
      API_PID=$!
      # Shut down API server when entrypoint exits
      trap "kill $API_PID 2>/dev/null" EXIT
    else
      echo "PHOTISNADI_API_KEY not set — API server disabled"
    fi

    echo "Serving Photis Nadi web on port 8080 via Caddy..."
    exec caddy run --config /opt/photisnadi/Caddyfile --adapter caddyfile
    ;;
  api)
    echo "Running Photis Nadi API server only..."
    exec /opt/photisnadi/server
    ;;
  linux)
    shift
    echo "Running Photis Nadi Linux binary..."
    exec /opt/photisnadi/linux/photisnadi "$@"
    ;;
  *)
    exec "$@"
    ;;
esac
