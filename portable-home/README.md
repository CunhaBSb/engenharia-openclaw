# portable-home

Snapshot portátil das configurações globais que não moram dentro de `~/.openclaw/workspace`.

## Conteúdo

- `openclaw/`: snapshot sanitizado de `~/.openclaw/openclaw.json`, envs de exemplo e plugins instalados.
- `codex/`: `AGENTS.md`, agentes auxiliares, `config.toml`, `default.rules` e `.mcp.json` sanitizados.
- `gemini/`: settings, políticas e mapeamento de projetos confiáveis.
- `claude/`: settings, comandos, agentes e regra local do Context7.
- `ollama/`: `config.json`.
- `context7/`: estado da CLI e `credentials.example.json` sanitizado.
- `opencode/`: instruções e config sanitizada.
- `agents/`: skills instaladas via `~/.agents`.

## Uso em outra máquina

1. Clone este repositório.
2. Copie o conteúdo raiz do repo para `~/.openclaw/workspace`.
3. Copie os arquivos de `portable-home/` para os caminhos equivalentes na nova `home`.
4. Revise todos os arquivos `*.example` e restaure manualmente os segredos reais.
5. Reautentique OAuths e credenciais locais que não são versionadas aqui.
