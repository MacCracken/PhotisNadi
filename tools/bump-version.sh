#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$REPO_ROOT/VERSION"

if [ $# -ge 1 ]; then
  # If a version argument is provided, write it to VERSION first
  echo "$1" > "$VERSION_FILE"
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

if [ -z "$VERSION" ]; then
  echo "ERROR: VERSION file is empty" >&2
  exit 1
fi

# Validate format: YYYY.M.D or YYYY.M.D-P
if ! echo "$VERSION" | grep -qE '^[0-9]{4}\.[0-9]+\.[0-9]+(-[0-9]+)?$'; then
  echo "ERROR: Invalid version format: $VERSION (expected YYYY.M.D or YYYY.M.D-P)" >&2
  exit 1
fi

echo "Bumping to version: $VERSION"

# pubspec.yaml
sed -i "s/^version: .*/version: $VERSION/" "$REPO_ROOT/pubspec.yaml"
echo "  updated pubspec.yaml"

# lib/server/agnos.dart
sed -i "s/'version': '[^']*'/'version': '$VERSION'/" "$REPO_ROOT/lib/server/agnos.dart"
echo "  updated lib/server/agnos.dart"

# tools/mcp-server/package.json
sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" "$REPO_ROOT/tools/mcp-server/package.json"
echo "  updated tools/mcp-server/package.json"

echo "Done. All files updated to $VERSION"
