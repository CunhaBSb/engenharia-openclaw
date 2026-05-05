# Segredos e Estado Omitidos

Os arquivos abaixo não devem ser enviados com valores reais para o Git. Eles precisam ser recriados, restaurados por outro canal seguro ou gerados novamente na máquina nova.

- `~/.openclaw/.env`
- `~/.openclaw/gateway.systemd.env`
- `~/.openclaw/secrets/*.env`
- `~/.openclaw/identity/*`
- `~/.openclaw/credentials/*`
- `~/.openclaw/devices/*`
- `~/.openclaw/auth*`, logs, sqlite, history, tasks e sessions
- `~/.codex/auth.json`, `history.jsonl`, sqlite e caches
- `~/.gemini/oauth_creds.json`, `google_accounts.json`, tokens OAuth e caches
- `~/.claude/.credentials.json`, `history.jsonl`, sessions e caches
- `~/.context7/credentials.json` com valores reais
- `~/.ollama/id_ed25519`
- `~/.ollama/models/`
- `~/.mcp-auth/`
