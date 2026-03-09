#!/bin/sh
set -e

case "${1:-web}" in
  web)
    echo "Serving Photis Nadi web on port ${PORT:-8080}..."
    exec darkhttpd /opt/photisnadi/web --port "${PORT:-8080}" --addr 0.0.0.0
    ;;
  linux)
    echo "Running Photis Nadi Linux binary..."
    exec /opt/photisnadi/linux/photisnadi "$@"
    ;;
  *)
    exec "$@"
    ;;
esac
