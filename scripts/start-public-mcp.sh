#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-3000}"
RUNTIME="$ROOT/.mcp-runtime"
KEY_FILE="$ROOT/.mcp-api-key"
mkdir -p "$RUNTIME"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared is required. Install it with: brew install cloudflared" >&2
  exit 1
fi

"$ROOT/scripts/stop-public-mcp.sh" >/dev/null 2>&1 || true

if [[ ! -f "$KEY_FILE" ]]; then
  openssl rand -hex 24 > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
fi
API_KEY="$(cat "$KEY_FILE")"

cd "$ROOT/mcp-server"
nohup env MCP_TRANSPORT=http MCP_API_KEY="$API_KEY" PORT="$PORT" \
  node index.js > "$RUNTIME/server.log" 2>&1 &
echo $! > "$RUNTIME/server.pid"

for _ in {1..20}; do
  curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  sleep 0.25
done
curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null

nohup cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:$PORT" \
  > "$RUNTIME/tunnel.log" 2>&1 &
echo $! > "$RUNTIME/tunnel.pid"

URL=""
for _ in {1..40}; do
  URL="$(grep -Eo 'https://[-a-z0-9]+\.trycloudflare\.com' "$RUNTIME/tunnel.log" | head -1 || true)"
  [[ -n "$URL" ]] && break
  sleep 0.5
done

if [[ -z "$URL" ]]; then
  echo "The tunnel did not start. See $RUNTIME/tunnel.log" >&2
  exit 1
fi

cat > "$ROOT/.env" <<EOF
MCP_SERVER_URL=$URL/mcp
MCP_AUTH_TYPE=bearer
MCP_API_KEY=$API_KEY
MCP_AUTH_HEADER="Authorization: Bearer $API_KEY"
EOF
chmod 600 "$ROOT/.env"

echo ""
echo "Public MCP URL: $URL/mcp"
echo "Authentication: API key (Bearer token)"
echo "API key: $API_KEY"
echo ""
echo "Keep this Mac awake and online. Stop access with: ./scripts/stop-public-mcp.sh"
