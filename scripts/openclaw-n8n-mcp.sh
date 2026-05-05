#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/home/cunhadev/Projetos/LuaEduca/n8n/.env"
NPX_BIN="/home/cunhadev/.nvm/versions/node/v24.14.0/bin/npx"

API_KEY="$(grep '^N8N_API_KEY=' "$ENV_FILE" | cut -d= -f2-)"

if [[ -z "${API_KEY:-}" ]]; then
  echo "N8N_API_KEY not found in $ENV_FILE" >&2
  exit 1
fi

export MCP_MODE="stdio"
export LOG_LEVEL="error"
export DISABLE_CONSOLE_OUTPUT="true"
export N8N_API_URL="http://localhost:5678"
export N8N_API_KEY="$API_KEY"
export WEBHOOK_SECURITY_MODE="moderate"

exec "$NPX_BIN" -y n8n-mcp
