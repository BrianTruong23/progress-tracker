#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/.mcp-runtime"

for name in tunnel server; do
  PID_FILE="$RUNTIME/$name.pid"
  if [[ -f "$PID_FILE" ]]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
done

echo "Public Progress Tracker MCP stopped."
