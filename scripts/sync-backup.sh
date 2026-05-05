#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOME_DIR="${1:-${HOME}}"
WORKSPACE_DIR="${HOME_DIR}/.openclaw/workspace"
PORTABLE_DIR="${REPO_ROOT}/portable-home"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need_cmd rsync
need_cmd python3

copy_file() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "${src}" ]]; then
    echo "Skipping missing file: ${src}" >&2
    return 0
  fi

  mkdir -p "$(dirname "${dest}")"
  rsync -a "${src}" "${dest}"
}

sync_tree() {
  local src="$1"
  local dest="$2"
  shift 2

  if [[ ! -d "${src}" ]]; then
    echo "Skipping missing directory: ${src}" >&2
    return 0
  fi

  mkdir -p "${dest}"
  rsync -a --delete "$@" "${src}/" "${dest}/"
}

sanitize_text() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "${src}" ]]; then
    echo "Skipping missing file: ${src}" >&2
    return 0
  fi

  mkdir -p "$(dirname "${dest}")"
  python3 - "${src}" "${dest}" <<'PY'
from pathlib import Path
import re
import sys

src = Path(sys.argv[1])
dest = Path(sys.argv[2])
text = src.read_text()

patterns = [
    (r'ghp_[A-Za-z0-9]+', '<REDACTED_GITHUB_TOKEN>'),
    (r'ctx7sk-[A-Za-z0-9-]+', '<REDACTED_CONTEXT7_API_KEY>'),
    (r'nmcp_[A-Za-z0-9]+', '<REDACTED_N8N_MCP_TOKEN>'),
    (r'oat_[A-Z0-9]+', '<REDACTED_CONTEXT7_ACCESS_TOKEN>'),
    (r'AIza[0-9A-Za-z\-_]+', '<REDACTED_GEMINI_API_KEY>'),
    (r'\b\d{6,}:[A-Za-z0-9_-]{20,}\b', '<REDACTED_TELEGRAM_BOT_TOKEN>'),
    (r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', '<REDACTED_JWT>'),
    (r'(?<=--dart-define=SUPABASE_ANON_KEY=)[^"\]]+', '<REDACTED_SUPABASE_ANON_KEY>'),
    (r'(?<="GOOGLE_GEMINI_API_KEY": ")[^"]+(?=")', '<REDACTED_GEMINI_API_KEY>'),
    (r'(?<="username":")[^"]+(?=")', '<REDACTED_USERNAME>'),
    (r'(?<="sessionToken":")[^"]+(?=")', '<REDACTED_SESSION_TOKEN>'),
    (r'(?<="password":")[^"]+(?=")', '<REDACTED_PASSWORD>'),
    (r'(?<="token":")[^"]+(?=")', '<REDACTED_TOKEN>'),
    (r'(?<="text", ")[^"]+(?=")', '<REDACTED_INPUT_TEXT>'),
    (r'(?<=input text )[A-Za-z0-9_@.-]{4,}(?=[ "])', '<REDACTED_INPUT_TEXT>'),
    (r'(?<="Authorization: Bearer )[^"]+(?=")', '<REDACTED_BEARER>'),
    (r'\bmurilo01\b', '<REDACTED_TEST_USERNAME>'),
    (r'\b226263\b', '<REDACTED_TEST_PASSWORD>'),
    (r'\baluno_debug\b', '<REDACTED_TEST_USERNAME>'),
    (r'\bsenha123\b', '<REDACTED_TEST_PASSWORD>'),
]

for pattern, replacement in patterns:
    text = re.sub(pattern, replacement, text)

dest.write_text(text)
PY
}

sanitize_env_example() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "${src}" ]]; then
    echo "Skipping missing file: ${src}" >&2
    return 0
  fi

  mkdir -p "$(dirname "${dest}")"
  python3 - "${src}" "${dest}" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])
dest = Path(sys.argv[2])
out = []

for raw_line in src.read_text().splitlines():
    line = raw_line.strip()
    if not line or line.startswith('#') or '=' not in raw_line:
        out.append(raw_line)
        continue

    key, _ = raw_line.split('=', 1)
    out.append(f"{key}=<REDACTED>")

dest.write_text("\n".join(out) + "\n")
PY
}

sanitize_json() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "${src}" ]]; then
    echo "Skipping missing file: ${src}" >&2
    return 0
  fi

  mkdir -p "$(dirname "${dest}")"
  python3 - "${src}" "${dest}" <<'PY'
from pathlib import Path
import json
import re
import sys

src = Path(sys.argv[1])
dest = Path(sys.argv[2])
secret_key_rx = re.compile(r'(token|secret|password|api[_-]?key|auth|credential)', re.I)

def mask_string(value: str) -> str:
    replacements = [
        (r'ghp_[A-Za-z0-9]+', '<REDACTED_GITHUB_TOKEN>'),
        (r'ctx7sk-[A-Za-z0-9-]+', '<REDACTED_CONTEXT7_API_KEY>'),
        (r'nmcp_[A-Za-z0-9]+', '<REDACTED_N8N_MCP_TOKEN>'),
        (r'oat_[A-Z0-9]+', '<REDACTED_CONTEXT7_ACCESS_TOKEN>'),
        (r'AIza[0-9A-Za-z\-_]+', '<REDACTED_GEMINI_API_KEY>'),
        (r'\b\d{6,}:[A-Za-z0-9_-]{20,}\b', '<REDACTED_TELEGRAM_BOT_TOKEN>'),
        (r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', '<REDACTED_JWT>'),
    ]
    for pattern, replacement in replacements:
        value = re.sub(pattern, replacement, value)
    return value

def sanitize(node, key_hint=None):
    if isinstance(node, dict):
        new = {}
        for key, value in node.items():
            if isinstance(value, str) and secret_key_rx.search(key) and not value.startswith('${'):
                new[key] = mask_string('<REDACTED>')
            else:
                new[key] = sanitize(value, key)
        return new

    if isinstance(node, list):
        new = []
        i = 0
        while i < len(node):
            item = node[i]
            if item == '--api-key' and i + 1 < len(node):
                new.append(item)
                new.append('<REDACTED>')
                i += 2
                continue
            new.append(sanitize(item, key_hint))
            i += 1
        return new

    if isinstance(node, str):
        if key_hint and secret_key_rx.search(str(key_hint)) and not node.startswith('${'):
            return '<REDACTED>'
        return mask_string(node)

    return node

data = json.loads(src.read_text())
sanitized = sanitize(data)
dest.write_text(json.dumps(sanitized, indent=2, ensure_ascii=False) + "\n")
PY
}

sync_workspace_backup() {
  local root_files=(
    "AGENTS.md"
    "BOOTSTRAP.md"
    "HEARTBEAT.md"
    "IDENTITY.md"
    "MEMORY.md"
    "README.md"
    "SOUL.md"
    "TOOLS.md"
    "USER.md"
    "<empty-string>"
  )

  for item in "${root_files[@]}"; do
    copy_file "${WORKSPACE_DIR}/${item}" "${REPO_ROOT}/${item}"
  done

  copy_file "${WORKSPACE_DIR}/.clawhub/lock.json" "${REPO_ROOT}/.clawhub/lock.json"
  copy_file "${WORKSPACE_DIR}/.openclaw/workspace-state.json" "${REPO_ROOT}/.openclaw/workspace-state.json"
  copy_file "${WORKSPACE_DIR}/workspace/index.md" "${REPO_ROOT}/workspace/index.md"
  copy_file "${WORKSPACE_DIR}/scripts/openclaw-n8n-mcp.sh" "${REPO_ROOT}/scripts/openclaw-n8n-mcp.sh"

  sync_tree "${WORKSPACE_DIR}/memory" "${REPO_ROOT}/memory"
  sync_tree "${WORKSPACE_DIR}/skills" "${REPO_ROOT}/skills"
  sync_tree "${WORKSPACE_DIR}/agents/JarvisMarketing" "${REPO_ROOT}/agents/JarvisMarketing" --exclude '.git'
  sync_tree "${WORKSPACE_DIR}/gemini-context-mcp-server" "${REPO_ROOT}/mcp/gemini-context-mcp-server" --exclude '.git' --exclude 'node_modules' --exclude '.env'
}

sync_portable_configs() {
  mkdir -p "${PORTABLE_DIR}"

  copy_file "${HOME_DIR}/.codex/AGENTS.md" "${PORTABLE_DIR}/codex/AGENTS.md"
  copy_file "${HOME_DIR}/.codex/agents/create-project.md" "${PORTABLE_DIR}/codex/agents/create-project.md"
  copy_file "${HOME_DIR}/.codex/agents/mcp-manager.md" "${PORTABLE_DIR}/codex/agents/mcp-manager.md"
  sanitize_text "${HOME_DIR}/.codex/config.toml" "${PORTABLE_DIR}/codex/config.toml"
  sanitize_json "${HOME_DIR}/.codex/skills/.mcp.json" "${PORTABLE_DIR}/codex/skills/.mcp.json"
  sanitize_text "${HOME_DIR}/.codex/rules/default.rules" "${PORTABLE_DIR}/codex/rules/default.rules"

  copy_file "${HOME_DIR}/.gemini/GEMINI.md" "${PORTABLE_DIR}/gemini/GEMINI.md"
  sanitize_json "${HOME_DIR}/.gemini/settings.json" "${PORTABLE_DIR}/gemini/settings.json"
  copy_file "${HOME_DIR}/.gemini/policies/auto-saved.toml" "${PORTABLE_DIR}/gemini/policies/auto-saved.toml"
  copy_file "${HOME_DIR}/.gemini/projects.json" "${PORTABLE_DIR}/gemini/projects.json"
  copy_file "${HOME_DIR}/.gemini/trustedFolders.json" "${PORTABLE_DIR}/gemini/trustedFolders.json"

  sanitize_json "${HOME_DIR}/.claude/settings.json" "${PORTABLE_DIR}/claude/settings.json"
  copy_file "${HOME_DIR}/.claude/settings.local.json" "${PORTABLE_DIR}/claude/settings.local.json"
  copy_file "${HOME_DIR}/.claude/rules/context7.md" "${PORTABLE_DIR}/claude/rules/context7.md"
  sync_tree "${HOME_DIR}/.claude/commands" "${PORTABLE_DIR}/claude/commands"
  sync_tree "${HOME_DIR}/.claude/agents" "${PORTABLE_DIR}/claude/agents"

  sanitize_json "${HOME_DIR}/.openclaw/openclaw.json" "${PORTABLE_DIR}/openclaw/openclaw.json"
  sanitize_env_example "${HOME_DIR}/.openclaw/.env" "${PORTABLE_DIR}/openclaw/.env.example"
  sanitize_env_example "${HOME_DIR}/.openclaw/gateway.systemd.env" "${PORTABLE_DIR}/openclaw/gateway.systemd.env.example"
  sanitize_env_example "${HOME_DIR}/.openclaw/secrets/gemini.env" "${PORTABLE_DIR}/openclaw/secrets/gemini.env.example"
  sanitize_env_example "${HOME_DIR}/.openclaw/secrets/ollama.env" "${PORTABLE_DIR}/openclaw/secrets/ollama.env.example"
  copy_file "${HOME_DIR}/.openclaw/plugins/installs.json" "${PORTABLE_DIR}/openclaw/plugins/installs.json"

  copy_file "${HOME_DIR}/.ollama/config.json" "${PORTABLE_DIR}/ollama/config.json"

  copy_file "${HOME_DIR}/.context7/cli-state.json" "${PORTABLE_DIR}/context7/cli-state.json"
  sanitize_json "${HOME_DIR}/.context7/credentials.json" "${PORTABLE_DIR}/context7/credentials.example.json"

  copy_file "${HOME_DIR}/.config/opencode/AGENTS.md" "${PORTABLE_DIR}/opencode/AGENTS.md"
  sanitize_json "${HOME_DIR}/.config/opencode/opencode.json" "${PORTABLE_DIR}/opencode/opencode.json"

  copy_file "${HOME_DIR}/.agents/.skill-lock.json" "${PORTABLE_DIR}/agents/.skill-lock.json"
  sync_tree "${HOME_DIR}/.agents/skills" "${PORTABLE_DIR}/agents/skills"
}

sanitize_repo_exports() {
  while IFS= read -r -d '' file; do
    sanitize_text "${file}" "${file}"
  done < <(
    find "${REPO_ROOT}" \
      -type f \
      ! -path "${REPO_ROOT}/.git/*" \
      ! -path "${REPO_ROOT}/scripts/sync-backup.sh" \
      -print0
  )
}

main() {
  sync_workspace_backup
  sync_portable_configs
  sanitize_repo_exports
  echo "Backup sync complete."
}

main "$@"
