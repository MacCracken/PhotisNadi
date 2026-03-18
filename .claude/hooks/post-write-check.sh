#!/bin/bash
# Post-write hook: runs format, lint, typecheck & security on changed Dart files
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only run on .dart files
[[ "$FILE_PATH" != *.dart ]] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

ERRORS=""

# 1. Format
FORMAT_OUT=$(dart format "$FILE_PATH" 2>&1)
if [ $? -ne 0 ]; then
  ERRORS+="FORMAT FAILED:\n$FORMAT_OUT\n\n"
fi

# 2. Lint + Typecheck (dart analyze covers both)
ANALYZE_OUT=$(dart analyze "$FILE_PATH" 2>&1)
if echo "$ANALYZE_OUT" | grep -q "error -"; then
  ERRORS+="ANALYSIS ERRORS:\n$ANALYZE_OUT\n\n"
fi

# 3. Security: check for common issues in the changed file
SEC_ISSUES=""

# Hardcoded secrets
if grep -nE '(password|secret|api_key|token)\s*=\s*["\x27][^"\x27]{8,}' "$FILE_PATH" 2>/dev/null; then
  SEC_ISSUES+="Possible hardcoded secret found\n"
fi

# SQL injection (string interpolation in queries)
if grep -nE "query\(.*\\\$" "$FILE_PATH" 2>/dev/null; then
  SEC_ISSUES+="Possible SQL injection (string interpolation in query)\n"
fi

# Dangerous process execution
if grep -nE "Process\.run\(|Process\.start\(" "$FILE_PATH" 2>/dev/null; then
  SEC_ISSUES+="Process execution found - verify input sanitization\n"
fi

if [ -n "$SEC_ISSUES" ]; then
  ERRORS+="SECURITY WARNINGS in $FILE_PATH:\n$SEC_ISSUES\n"
fi

# Report
if [ -n "$ERRORS" ]; then
  echo -e "$ERRORS" >&2
  exit 1
fi

exit 0
