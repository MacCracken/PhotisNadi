#!/bin/sh
set -e

case "${1:-web}" in
  web)
    echo "Serving Photis Nadi web on port 8080 via Caddy..."
    exec caddy run --config /opt/photisnadi/Caddyfile --adapter caddyfile
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
