# MEMORY.md - Long-Term Memory

Use este arquivo apenas para contexto duravel que muda decisoes futuras.
Nao use como changelog longo. O runtime atual continua sendo a fonte principal.

## Workspace OpenClaw

- Este workspace controla o OpenClaw local em `/home/cunhadev/.openclaw`.
- `BOOTSTRAP.md` e `AGENTS.md` definem o estado operacional imediato.
- Manter este arquivo curto para evitar truncation no bootstrap.

## Operador

- Cunha prefere pt-BR direto, sem enrolacao.
- Quando a tarefa for operacional, executar primeiro e explicar depois.

## WraithM / Phantom

### Snapshot

- Projeto Windows-only para FiveM. Eu rodo em Linux.
- Regra permanente: eu faco analise estatica, auditoria e patches; validacao de build/runtime precisa de agente Windows.
- Repo principal: `git@github.com:CunhaBSb/Phantom.git`, branch `main`.
- Arquitetura atual: `WraithM.exe` unificado com 3 modos e `rage_extension.dll` embedded.
- Engine Mode: RAM-only real, bind `0.0.0.0` para dashboard mobile.
- Deployer Mode: GUI instalador quando rodar em disco fixo.
- Pipeline principal: `src/unified_main.cpp`, `src/unified_resources.rc`, `src/deployer/*`, `scripts/build_unified.py`, `CMakeLists.txt`.
- Status alto nivel: cleanup e fixes principais concluidos; build Windows e hardening final seguem pendentes.

### Pendencias reais

- Ainda dependem de validacao/runtime Windows: race residual, TLS do control interface, e validacao final de hardening.
- PolymorphEngine v3.2 foi revertido e so deve voltar depois de validacao Windows.

### Regras permanentes de engenharia

- PIMPL obrigatorio para WinAPI em headers.
- RNG do IF sempre deterministico; nunca baseado em `thread_id`.
- Proibido `catch(...)` silencioso.
- Burn protocol e hygiene forense sao prioridade alta.
- JSON/web/mobile precisam respeitar limites pequenos de payload.
- Rate limit e validacao estrita de tipos sao obrigatorios nas superficies HTTP.
- Prioridade tecnica: estabilidade do core > stealth > performance.
- Evitar em dash em arquivos do projeto; usar hifen normal.

## LuaEduca

### Produto e escopo

- Plataforma de reforco escolar com IA para alunos do 6o ao 9o ano.
- A assistente "Lua" guia o raciocinio passo a passo e evita entregar resposta pronta cedo demais.
- Comprador principal: pais/responsaveis. Usuario final: aluno.

### Repos e diretorios

- Monorepo local: `/home/cunhadev/Projetos/LuaEduca/`
- Frontend ativo: `LuaEducaWeb/`
- Nao editar `web/`; e submodule e nao e a superficie principal.
- Backend e banco: `supabase/`
- Workflows IA: `n8n/`
- Mobile: `mobile/`
- Docs: `docs/`

### Arquitetura

- Fluxo principal: Frontend Vercel -> Supabase Edge Functions/Postgres/RLS -> n8n Docker -> OpenRouter.
- Chat do aluno passa por `n8n-proxy`, persiste contexto no banco e retorna SSE para o frontend.
- Ha 13 Edge Functions; as principais sao `student-auth`, `n8n-proxy`, `homepage-chat-proxy`, `chat-history`, `upload-image`, `submit-doubt`, `stripe-webhook`.
- Supabase project ref: `texgadrxlsagbglfpjgy`.
- n8n roda local em Docker; webhook/tunnel pode mudar a cada `start.sh`.

### Auth e estado

- Responsavel: Supabase Auth com email e Google OAuth.
- Aluno: auth custom com username/senha e sessao deslizante.
- Trial publico: cookie + fingerprint com quota diaria.
- Estado de conversa fica em `token_sessions`.

### Frontend e convencoes

- Stack web: React 18, Vite 6, TypeScript strict, Tailwind, shadcn/ui, PWA.
- Dev server padrao: porta `3000`, nao `5173`.
- UI e textos sempre em pt-BR.
- Codigo, comentarios e commits em ingles.
- Validacao de respostas via Zod e parte importante da arquitetura.
- Trial chat existe na homepage.
- Stripe usa precos inline; nao depende de Price IDs pre-criados.

### Mobile

- App Flutter com Riverpod, `go_router`, `supabase_flutter` e `dio`.
- Objetivo recorrente: manter paridade com o backend/web, sem inventar stack paralela.

### Auditoria completa (maio 2026)

- Relatorio principal: `LuaEducaWeb/AUDIT_REPORT.md`.
- 27 problemas originais; fase 1 limpou build, lint e testes.

### P0 implementados (maio 2026)

- Rate limiting migrado de in-memory Map para Postgres RPC com fallback in-memory. Callers: student-auth, send-support-email, homepage-chat-proxy.
- n8n-teste agora usa validateEnv() com SUPABASE_URL + SERVICE_ROLE_KEY.
- CORS: localhost origins removidos de producao. Ativos apenas com ENVIRONMENT != production.
- Nova Edge Function health-check: probes Supabase, n8n, OpenRouter.
- Script tunnel-health-check.sh: monitora Docker + tunnel com auto-restart.

### P1 pendentes (maio 2026)

- Remover auth duplicada n8n (proxy valida sessao, n8n valida novamente = +200-400ms).
- Refatorar n8n-proxy em modulos: sse-handler, persistence, context-builder, upstream.
- Refatorar useChatSend.ts (743 linhas) em hooks menores.
- Circuit breaker/retry com backoff no n8n.
- SSE parser compartilhado frontend/backend (DRY).
- Dividir workflow PRO (45 nodes) em sub-workflows.

### Pendencias resolvidas (maio 2026)

- Hash de `magic_link_token` com migracao segura — C-02: SHA-256 hash, coluna `magic_link_token_hash`.
- Rate limiting de login de aluno — 10/IP/15min via `_shared/rate-limit.ts`.
- Rate limiting de magic login — 5/IP/15min.
- Rate limiting de magic-token regenerate — 3/guardian/15min.
- Rate limiting de `send-support-email` — 3/IP/hora.
- Rate limiting de homepage trial flood — 10/IP/min.
- Separar resolucao de sessoes orfas de endpoint de leitura — `cleanup-orphan-sessions` + `cleanup-sessions` dedicados.
- Validar env vars no startup das funcoes — `_shared/env.ts` com `validateEnv()`, cobertura 100% (exceto `n8n-teste`).
- SSE parser unificado — `_shared/sse-parser.ts` criado.
- Migrations de seguranca — 3 arquivos SQL para magic_link_hash, stripe_idempotency, rate_limits.
- P0 security hardening — rate-limit Postgres, CORS localhost conditional, n8n-teste validateEnv, health-check endpoint.

### Docs para abrir quando necessario

- `docs/product/LuaEduca-PRD.md`
- `docs/product/LuaEduca-Coresdamarca.md`
- `docs/integration/N8N-INTEGRATION.md`
- `docs/integration/LuaEduca-PRO-WORKFLOW-ANALYSIS.md`
- `docs/integration/SUPABASE-SCHEMA.md`
- `docs/integration/TYPES-REFERENCE.md`

## Regra de Ouro: Projetos de SO unico

- Se o target OS do projeto nao for o meu, deixar isso explicito no inicio.
- Linux aqui significa analise estatica para projetos Windows-only.
- Validacao final de runtime deve ser feita no SO real, com ciclo audit -> fix -> build/test -> report.
