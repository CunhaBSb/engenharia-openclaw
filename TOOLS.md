# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

## n8n Integration

### n8n Instance (LuaEduca)
- **Host**: `http://localhost:5678`
- **API Base**: `http://localhost:5678/api/v1`
- **API Key**: Stored in `/home/cunhadev/Projetos/LuaEduca/n8n/.env` → `N8N_API_KEY`
- **Tunnel**: Dynamic Cloudflare (see `.tunnel-url` in n8n dir)
- **Container**: `liaeduca-n8n` (Docker, image `n8nio/n8n:2.9.4`)
- **Compose**: `/home/cunhadev/Projetos/LuaEduca/n8n/docker-compose.yml`

### Active Workflows
| ID | Name | Status |
|----|------|--------|
| `LvXaH6oJqukDJFzE` | LuaEduca-Homepage-Trial | ✅ Active |
| `eXxcOcksE8Mv78R1` | LuaEduca-PRO | ✅ Active |
| `qAUUUY2H0KG050Hy` | LuaEduca-Context | ✅ Active |
| `z02wbtRjDqajq05W` | LuaEduca-Persist | ✅ Active |
| `a7f8e61f-910e-44d5-b557-4c396df50687` | LuaEduca-PRO-DEBUG | ⏸️ Inactive |
| `OSvtQIDZWLgDCNeD` | OpenClaw-Integration-Test | ✅ Active |

### Webhook Paths
- PRO: `/webhook/lua-chat0`
- Homepage-Trial: `/webhook/lua-homepage-trial`
- Test: `/webhook/lua-chat0-teste`

### How to use
- List workflows: `curl -s http://localhost:5678/api/v1/workflows -H "X-N8N-API-KEY: $N8N_API_KEY"`
- Trigger webhook: `curl -s -X POST http://localhost:5678/webhook/lua-chat0 -H "Content-Type: application/json" -d '{...}'`
- API key is in `.env`; never hardcode in workflows or responses.

## Related

- [Agent workspace](/concepts/agent-workspace)
