# Session: 2026-05-03 01:45:26 GMT-3

- **Session Key**: agent:main:telegram:direct:1073265075
- **Session ID**: 066559c9-994d-456c-915e-2bda9b74b1cf
- **Source**: telegram

## Conversation Summary

assistant: ✅ New session started.
user: [Sun 2026-05-03 01:14 GMT-3] Faça uma análise completa e profunda do repositório LuaEduca, presente no workspace. Entenda o Banco de dados, funcionamento, propostas... uma análise completa e geral, aprenda tudo sobre.
assistant: Vou fazer uma análise completa do repositório LuaEduca. Começo mapeando a estrutura e lendo os arquivos-chave.
assistant: Agora tenho uma visão completa. Vou consolidar tudo na análise.

---

# 🔍 Análise Completa — LuaEduca

## 1. Visão Geral do Produto

**LuaEduca** é uma plataforma de reforço escolar com IA para alunos do 6º ao 9º ano do Ensino Fundamental II. O aluno envia dúvidas por texto ou foto, e a assistente **"Lua"** guia o raciocínio passo a passo **sem entregar a resposta pronta** — diagnosticando o tipo de travamento (interpretação, método, base ou checagem) e adaptando o nível de dica progressivamente.

**Proposta de valor central:** transformar "tô travado/não sei por onde começar" em "agora sei o próximo passo" em 30 segundos.

| Ator | Mecanismo |
|------|-----------|
| Responsável (pai/mãe) | Supabase Auth (JWT) — email + OAuth Google |
| Aluno | Auth custom — username + senha PBKDF2-SHA256, sessão de 30 dias com sliding window |
| Trial (homepage) | Cookie + fingerprint — 10 msgs/24h sem login |

| Plano | Preço | Alunos | Tokens/dia |
|-------|-------|--------|------------|
| Free | R$0 | 1 | 10 |
| Plus | R$39,90/mês | 2 | 20 |
| Pro | R$80,00/mês | 4 | 80 |

---

## 2. Arquitetura Completa

```
┌──────────────────────────┐     ┌───────────────────────────┐     ┌──────────────────────┐
│  LuaEducaWeb (React SPA)  │────▶│  Supabase Cloud            │────▶│  n8n (Docker local)   │
│  Vite 6 + TS strict       │     │  13 Edge Functions (Deno)   │     │  4 workflows IA        │
│  Deploy: Vercel (PWA)      │     │  PostgreSQL + RLS          │     │  OpenRouter LLM        │
│  shadcn/ui + Tailwind      │     │  Storage (imagens)          │     │  Cloudflare Tunnel      │
└──────────────────────────┘     └───────────────────────────┘     └──────────────────────┘
      Frontend                            Backend                          Motor IA
```

### Fluxo Principal (Chat do Aluno)

```
Aluno digita mensagem/foto
  → Frontend: useChatSend.ts → POST /functions/v1/n8n-proxy (SSE)
    → Edge Function n8n-proxy:
        ├─ Valida session_token (SHA-256 lookup em student_sessions)
        ├─ Valida token_id pertence ao aluno
        └─ POST /webhook/lua-chat0 (n8n via Cloudflare Tunnel ou localhost)
            → LuaEduca-PRO workflow:
                ├─ Auth + contexto (students, student_pfa, guardian_subscriptions, plan_definitions)
                ├─ Classificação de intenção (heurística JS → fallback LangChain Agent)
                │   ├─ SOCIAL → resposta direta (sem pipeline pedagógica)
                │   └─ DOUBT → pipeline pedagógica
                ├─ Montagem do prompt (perfil FPA + histórico + hint_level)
                ├─ LLM (OpenRouter) → resposta JSON {assistant_message, next_stage, hint_level}
                ├─ Persistência: token_sessions + tokens
                └─ Retorna JSON para o proxy
    ← n8n-proxy: re-emite SSE tokens ao frontend
  ← Frontend: renderiza com animação de digitação
```

### Persistência em 3 Camadas

| Camada | Mecanismo | Detalhe |
|--------|-----------|---------|
| n8n (authoritative) | LuaEduca-Persist workflow | Atualiza token_sessions, tokens, student_pfa |
| Proxy fallback | n8n-proxy Edge Function | Se n8n não retornar session_id, persiste localmente |
| Frontend | optimistic UI + polling | Chat history via GET /functions/v1/chat-history |

Modos de persistência configuráveis: `n8n_authoritative` (default), `proxy_fallback`, `proxy_always`.

---

## 3. Banco de Dados — Schema Completo

**Projeto Supabase:** `texgadrxlsagbglfpjgy` | **26 migrations SQL**

### Tabelas (14)

| Tabela | Função | Linhas-chave |
|--------|--------|-------------|
| `students` | Perfil do aluno | `id`, `guardian_user_id` (FK auth.users), `name`, `school_year` (6-9), `username` (UNIQUE), `password_hash` (PBKDF2-SHA256), `magic_link_token_hash` (SHA-256), `is_active` |
| `tokens` | Interações/dúvidas | `id`, `student_id`, `input_text` (max 5000), `image_urls` (text[]), `token_type` (doubt/social), `status` (active/resolved/failed), `casual_count` |
| `token_sessions` | Estado de conversa multi-agente | `stage` (TRIAGE→CLARIFY→WAITING_CLARIFICATION→RESEARCH→TUTOR→DIALOGUE→RESOLVED), `hint_level` (0-4), `conversation_history` (jsonb), `lua_handoff`, `triage_briefing`, `session_report` |
| `lua_responses` | Respostas da IA (formato legado) | `diagnosis_type`, `subject`, `steps_json`, `next_hint`, `blocked_final_answer` |
| `student_sessions` | Sessões auth custom | `token_hash` (SHA-256 UNIQUE), `expires_at`, `revoked_at`, `last_used_at` (sliding window 30 dias) |
| `student_pfa` | Ficha de Perfil do Aluno | `learning_style`, `total_sessions`, campos `fpa_*` (forças, dificuldades, recomendações) |
| `topic_mastery` | Domínio por aluno/matéria/tópico | `mastery_score` (0-100), `sessions_count`, `trend` (improving/declining/stable) |
| `guardian_profiles` | Perfil do responsável | `guardian_user_id` (= auth.users.id), `full_name`, `phone` |
| `guardian_subscriptions` | Assinatura Stripe | `plan_code`, `status`, `stripe_customer_id`, `stripe_subscription_id` |
| `plan_definitions` | Planos disponíveis | `code` (free/plus/pro), `student_limit`, `tokens_per_day`, `price_cents` |
| `homepage_trial_sessions` | Sessões trial (sem login) | `cookie_id` (UNIQUE), `fingerprint_hash`, `first_ip`, `last_ip` |
| `homepage_trial_tokens` | Tokens do trial | `session_id`, `message`, `ip`, `fingerprint_hash` |
| `stripe_processed_events` | Idempotência Stripe | `event_id` (PK), `event_type` |
| `guardian_alerts` | Alertas do Agente 4 | `alert_type` (progress/difficulty/inactivity/celebration/emotional), `read_at` |

### RLS (Row Level Security)

Ativo em **todas as tabelas**. Políticas por tipo:
- Responsável: vê/edita apenas seus próprios dados e dos seus alunos
- Aluno: vê apenas seus próprios tokens e sessões
- Trial: gerenciado por Edge Functions (service_role)
- `plan_definitions`: leitura pública
- `student_sessions`, `token_sessions`, `homepage_trial_*`: service_role apenas

### Storage

Bucket `doubt-images` — privado, 5MB/arquivo, JPEG/PNG/WebP, path `{guardian_user_id}/{timestamp}-{random}.{ext}`, URLs assinadas com TTL 48h.

---

## 4. Frontend — LuaEducaWeb

### Stack

React 18 + Vite 6 + TypeScript strict + Tailwind CSS + shadcn/ui (Radix) + PWA (Workbox)

### Estrutura de Páginas

| Rota | Componente | Função |
|------|-----------|--------|
| `/` | Index (579 linhas) | Homepage com hero, features, FAQ, trial chat |
| `/acesso` | Acesso (8.6KB) | Login dual (Responsável/Aluno) |
| `/cadastro` | Cadastro (628 linhas) | Multi-step (dados → plano → alunos → confirmação) |
| `/planos` | Planos (6.6KB) | Cards de planos + Stripe Checkout |
| `/painel` | Painel (434 linhas) | Dashboard do responsável (métricas por aluno) |
| `/info` | Info (629 linhas) | Gerenciar conta, alunos, plano |
| `/aluno/entrar` | Entrar (8.2KB) | Login do aluno |
| `/aluno/sala` | Sala (204 linhas) | Hub do aluno (perfil, frequência, CTA) |
| `/aluno/chat` | Chat (wrapper) | Chat com a Lua |
| `/suporte`, `/termos`, `/privacidade` | — | Páginas legais |

### Componentes Chat (núcleo do produto)

| Arquivo | Linhas | Função |
|---------|--------|--------|
| `useChatSend.ts` | 743 | Hook principal — envio de mensagens, SSE, retry, quota |
| `ChatContainer.tsx` | 222 | Orquestrador do chat |
| `ChatMessages.tsx` | 162 | Lista de mensagens |
| `ChatInput.tsx` | 188 | Input de texto + upload de imagem |
| `ChatMessageItem.tsx` | 144 | Renderização de mensagem individual |
| `ChatQuotaBanner.tsx` | 58 | Banner de quota restante |
| `MarkdownContent.tsx` | 95 | Renderização de markdown nas respostas |
| `TypingMessage.tsx` | 48 | Animação de digitação |
| `useChatHistory.ts` | 188 | Carregamento de histórico |
| `useChatImageUpload.ts` | 110 | Upload de imagem com thumbnail |

### Libs Frontend-chave

| Arquivo | Linhas | Função |
|---------|--------|--------|
| `chat-stream.ts` | 288 | SSE parsing e re-emissão |
| `student-session.ts` | 243 | Auth custom (login, hash, sessão) |
| `homepage-chat.ts` | 317 | Chat trial sem login (cookie + fingerprint + quota) |
| `chat-send-utils.ts` | 225 | Utilidades de envio |
| `chat-error-messages.ts` | 94 | Mapeamento de códigos de erro |
| `feature-flags.ts` | 17 | Flags (Google Auth, Trial Chat, Debug Mode) |
| `guardian-oauth.ts` | 80 | OAuth Google para responsáveis |
| `schemas/` | — | Validação Zod (edge-responses, n8nResponse) |
| `types.ts` | 87 | Tipos TypeScript canônicos |

### Design System

- **Font:** Nunito (primária), Inter (fallback)
- **Paleta:** Lua Teal `#04556E` + Lua Orange `#FF9030`
- **Proporção:** 70% neutros / 20% teal / 10% laranja
- **Tema:** Night mode com tokens `lua-night-*` e `lua-amber-*`
- **PWA scope:** `/aluno/`

---

## 5. Backend — Edge Functions (13)

| Function | Linhas | JWT | Função |
|----------|--------|-----|--------|
| `n8n-proxy` | 1388 | ✅ | Relay principal → n8n (SSE + persistence fallback) |
| `homepage-chat-proxy` | 721 | ✅ | Chat trial (cookie/fingerprint/IP quota) |
| `chat-history` | 594 | ✅ | Histórico completo (multi-agent + legacy) |
| `student-auth` | 463 | ✅ | Login/logout/check/magic-link do aluno |
| `submit-doubt` | 242 | ✅ | Cria token de dúvida (quota diária) |
| `n8n-teste` | 205 | ✅ | Relay teste |
| `stripe-webhook` | 170 | ❌ | Lifecycle de assinatura Stripe |
| `create-checkout-session` | 125 | ✅ | Stripe Checkout |
| `upload-image` | 115 | ✅ | Upload multipart → Storage |
| `send-support-email` | 114 | ✅ | Email via Resend |
| `doubt-status` | 98 | ✅ | Polling de status |
| `student-stats` | 91 | ✅ | Métricas semanais |
| `billing-portal` | 90 | ✅ | Stripe Portal |

**Shared code:** `_shared/http.ts` (CORS whitelist + validação de origem) e `_shared/student-session.ts` (hash SHA-256 + resolve de sessão).

---

## 6. Motor IA — n8n

### Workflows

| Workflow | ID | Webhook | Nós | Função |
|----------|----|---------|-----|--------|
| **LuaEduca-PRO** | `eXxcOcksE8Mv78R1` | `/webhook/lua-chat0` | 45 | Chat principal com SSE |
| **LuaEduca-Context** | `qAUUUY2H0KG050Hy` | interno | 23 | Contexto do aluno (FPA, plano, histórico) |
| **LuaEduca-Persist** | `z02wbtRjDqajq05W` | interno | 11 | Persistência (token_sessions, tokens, FPA) |
| **LuaEduca-Homepage-Trial** | `LvXaH6oJqukDJFzE` | `/webhook/lua-homepage-trial` | 15 | Trial sem login |
| *(arquivado)* PRO-DEBUG | `a7f8e61f-910e-44d5-b557` | — | — | Debug |

### Máquina de Estados (LuaEduca-PRO)

```
TRIAGE
  ├─> CLARIFY (ambiguidade no assunto)
  │     └─> WAITING_CLARIFICATION (aguardando resposta)
  └─> RESEARCH (assunto claro)
        └─> TUTOR (tutoria ativa, hint_level progressivo)
              └─> DIALOGUE (conversa em andamento)
                    └─> RESOLVED (resolvido, hint_level ≥ 4 ou aluno confirmou)
```

### Pipeline Pedagógica (4 Agentes)

1. **Intake** — Classifica intenção (DOUBT vs SOCIAL), extrai metadados
2. **Triage** — Diagnostica tipo de travamento (interpretação/método/base/checagem), monta briefing
3. **Educator** — Gera resposta pedagogica com hint_level progressivo (0=pergunta exploratória → 4=resolução completa)
4. **Memory** — Atualiza FPA do aluno, topic_mastery, gera alertas para o responsável

### Infraestrutura

- Docker Compose: `n8nio/n8n:2.9.4`, container `liaeduca-n8n`, porta 5678
- DNS fixo: `8.8.8.8` + `1.1.1.1` (workaround para `EAI_AGAIN` no Docker)
- Cloudflare Quick Tunnel: URL dinâmica, auto-atualizada em `start.sh`
- Secrets sincronizados: `start.sh` atualiza `N8N_WEBHOOK_*` no Supabase

---

## 7. Mobile — Flutter

App Flutter com:
- `flutter_riverpod` (state management)
- `go_router` (navegação)
- `supabase_flutter` (auth + DB)
- `dio` (HTTP)
- `flutter_secure_storage` + `crypto` (auth custom)
- Estrutura: `core/` + `features/` + `app/` (feature-first)
- Status: em desenvolvimento, paridade com web sendo mantida

---

## 8. Segurança e Hardening

### Auditoria Realizada (2026-05-01)

| Severidade | Contagem |
|-----------|----------|
| CRITICAL | 4 |
| HIGH | 7 |
| MEDIUM | 8 |
| LOW | 8 |

### Problemas Críticos (já identificados, alguns corrigidos)

| ID | Problema | Status |
|----|---------|--------|
| C-01 | Comparação de senha com timing attack (`===`) | **Corrigido** (constant-time) |
| C-02 | `magic_link_token` em plaintext | **Corrigido** (mig `20260503_000001` → `magic_link_token_hash`) |
| C-03 | Zero rate limiting no login de aluno | **Pendente** |
| C-04 | Sem limite de tamanho na senha de login (DoS via PBKDF2) | **Corrigido** (max 128 chars) |

### Hardening Aplicado (migrations 2026-03-23)

- `security_rls_least_privilege.sql` — RLS com least privilege
- `storage_schema_revoke.sql` — Revogação de schema público no Storage
- `column_level_privileges.sql` — Privileges a nível de coluna
- `magic_link_expiry.sql` — Expiração de magic links

### Segurança por Camada

| Camada | Mecanismo |
|--------|-----------|
| Frontend | Apenas `VITE_SUPABASE_ANON_KEY`, nunca service_role |
| Edge Functions | JWT verification (`verify_jwt = true` em config.toml, exceto `stripe-webhook`) |
| CORS | Whitelist de origens (`_shared/http.ts`) — exceto `stripe-webhook` (H-01: wildcard, pendente) |
| RLS | Ativo em todas as tabelas, políticas por role |
| Auth Aluno | PBKDF2-SHA256 (100k iterações), sessão SHA-256 com sliding window |
| Stripe | Webhook signature verification, idempotência via `stripe_processed_events` |

---

## 9. Testes

| Categoria | Ferramenta | Qtd |
|-----------|-----------|-----|
| Unit tests | Vitest (jsdom) | 42-43 |
| E2E | Playwright (iPhone 14 primary) | 44 |
| Intent battery | Custom script | 9 |
| Webhook contract | Custom script | 2 |
| Debug loop | Custom script (5 casos) | 5 |

Scripts de teste em `scripts/`: `test-intent-battery.mjs`, `test-lua-chat-webhook-contract.mjs`, `n8n-debug-loop.mjs`, `test-n8n-mcp.mjs`, `test-workflow.py`.

---

## 10. Pendências e Dívida Técnica

### Críticas (segurança)

1. **Rate limiting de login de aluno** — sem proteção contra brute-force
2. **Rate limiting de magic login** — sem proteção
3. **Rate limiting de `send-support-email`** — sem proteção
4. **CORS wildcard no `stripe-webhook`** (H-01)

### Médias (arquitetura)

5. **Hash de `magic_link_token`** — migração aplicada, mas verificar se dados legados foram migrados
6. **Separação de resolução de sessões órfãs** do endpoint de leitura
7. **Unificação de parsing SSE** — código duplicado entre n8n-proxy e homepage-chat-proxy
8. **Validação de env vars no startup** das Edge Functions

### Frontend

9. **Lint com 5 errors + 4 warnings** (auditado)
10. **npm audit com 11 vulnerabilidades** (auditado)
11. **Componentes grandes** — `useChatSend.ts` (743 linhas), `Cadastro.tsx` (628 linhas), `Index.tsx` (579 linhas), `Info.tsx` (629 linhas) — candidatos a refatoração

### Mobile

12. **App Flutter em desenvolvimento** — paridade com web em andamento
13. **Sem E2E tests mobile** documentados

---

## 11. Diagrama de Dados (Entidades Principais)

```
auth.users (Supabase Auth)
    │
    ├── 1:N ── guardian_profiles
    │              └── full_name, phone
    │
    ├── 1:N ── guardian_subscriptions
    │              └── plan_code → plan_definitions
    │              └── stripe_customer_id, stripe_subscription_id
    │
    └── 1:N ── students
                   ├── username (UNIQUE), password_hash
                   ├── school_year (6-9), is_active
                   ├── magic_link_token_hash (SHA-256)
                   │
                   ├── 1:N ── student_sessions
                   │              └── token_hash (SHA-256 UNIQUE), expires_at
                   │
                   ├── 1:N ── tokens (dúvidas)
                   │              ├── input_text, image_urls, token_type
                   │              ├── status (active/resolved/failed)
                   │              └── 1:1 ── lua_responses
                   │                             └── diagnosis_type, subject, steps_json
                   │
                   ├── 1:1 ── student_pfa (Ficha de Perfil)
                   │              └── learning_style, fpa_* fields
                   │
                   ├── N:M ── topic_mastery
                   │              └── mastery_score (0-100), trend
                   │
                   └── 1:N ── token_sessions (conversa multi-agente)
                                  ├── stage, hint_level, attempt_count
                                  ├── conversation_history (jsonb)
                                  ├── lua_handoff, triage_briefing, session_report
                                  └── emotional_flag

homepage_trial_sessions (independente de auth)
    └── 1:N ── homepage_trial_tokens
                   └── cookie_id, fingerprint_hash, ip, message

stripe_processed_events (idempotência)
guardian_alerts (alertas do Agente 4 para responsáveis)
```

---

## 12. Resumo Executivo

| Dimensão | Estado |
|----------|--------|
| **Produto** | MVP funcional completo — chat pedagógico com IA, auth dual, Stripe, trial |
| **Stack** | Moderna e consistente — React/Vite/TS, Supabase Edge Functions, n8n + OpenRouter |
| **Banco** | 14 tabelas com RLS, 26 migrations, schema bem documentado |
| **IA** | Pipeline de 4 agentes com máquina de estados, hint_level progressivo, FPA adaptativo |
| **Segurança** | Hardening significativo (RLS, constant-time auth, SHA-256 sessions), mas rate limiting pendente |
| **Testes** | 86+ testes (unit + E2E + integration), debug loop automatizado |
| **Mobile** | Flutter em desenvolvimento, sem paridade completa |
| **Dívida técnica** | 27 itens auditados (4 críticos), maioria de segurança (rate limiting) e component size |

O LuaEduca é um projeto **maduro e bem estruturado**, com documentação extensa, arquitetura limpa e pipeline de IA sofisticada. Os principais riscos atuais são **rate limiting** nos endpoints de auth e suporte, e a **complexidade do n8n-proxy** (1388 linhas) que concentra muitas responsabilidades.
user: [Sun 2026-05-03 01:20 GMT-3] continue
assistant: Vou aprofundar nos pontos que faltaram — detalhes internos das Edge Functions, componentes do frontend, fluxo Stripe, Fluxo de Auth, e o app mobile.
assistant: Tenho todos os detalhes necessários. Vou agora consolidar a análise completa restante.

---

# 🔍 Análise Completa — LuaEduca (Continuação)

## 13. Edge Functions — Anatomia Detalhada

### Linhas de Código por Camada

| Camada | Linhas |
|--------|--------|
| Frontend (TSX/TS) | 10.316 |
| Edge Functions (TS) | 4.556 |
| Migrations SQL | 2.262 |
| Mobile (Dart) | 3.836 |
| **Total** | **~20.970** |

### student-auth (463 linhas) — Auth Custom do Aluno

5 ações suportadas:

| Ação | Descrição | Proteção |
|------|-----------|----------|
| `login` | Username/senha ou accessCode + senha | PBKDF2-SHA256 100k iterações, timing-safe comparison (C-01), dummy hash anti-enumeration (C-03), max 128 chars (C-04) |
| `logout` | Revoga sessão (set `revoked_at`) | — |
| `check` | Valida sessão + renova sliding window | Atualiza `expires_at` a cada check |
| `hashPassword` | Hash de senha para cadastro (requer JWT guardian) | JWT verification |
| `magic-login` | Login via magic link token (SHA-256 hashed, C-02) | Token consumido após uso (one-time) |
| `regenerate-magic-token` | Gera novo magic link (requer JWT guardian) | Retorna UUID raw apenas uma vez |

**Fluxo de sessão:**
1. Login gera `crypto.getRandomValues(32 bytes)` → hash SHA-256 → armazena em `student_sessions.token_hash`
2. Sessão com TTL de 30 dias (configurável via `STUDENT_SESSION_TTL_DAYS`)
3. Sliding window: cada `check` renova `expires_at`
4. Logout seta `revoked_at` na sessão

### n8n-proxy (1.388 linhas) — O Coração do Sistema

A Edge Function mais complexa. Responsabilidades:

1. **Validação de sessão** — `resolveActiveStudentSession()` (valida UUID, hash SHA-256, não-revogada, não-expirada)
2. **Resolução de webhook URL** — `resolveN8nWebhookUrl()` com fallback entre URLs configuradas
3. **Proxy SSE** — Re-emite stream do n8n para o frontend enquanto bufferiza o resultado final
4. **Persistence fallback** — 3 modos (`n8n_authoritative`, `proxy_fallback`, `proxy_always`)
5. **Error handling categorizado** — Tipos: `validation`, `auth`, `quota`, `upstream`, `network`, `config`, `internal`
6. **Timeout** — 25 segundos para upstream n8n

### submit-doubt (242 linhas) — Criação de Token com Quota

1. Valida sessão do aluno
2. Busca plano e quota do responsável
3. Conta tokens usados hoje por todos os alunos do mesmo responsável
4. Rejeita se excedeu (`QUOTA_EXCEEDED`, HTTP 429)
5. Limita `input_text` a 5000 chars (H-03)
6. Cria registro em `tokens` com status `active` e expiry de 48h
7. Retorna `{ tokenId, status, quota: { used, limit } }`

### stripe-webhook (170 linhas) — Lifecycle de Pagamento

Eventos tratados:

| Evento | Ação |
|--------|------|
| `checkout.session.completed` | Ativa assinatura (plan_code do metadata) |
| `customer.subscription.updated` | Atualiza status (active/trialing/past_due/canceled) |
| `customer.subscription.deleted` | Rebaixa para plano free |
| `invoice.payment_failed` | Marca como `past_due` |

**Proteções:** assinatura Stripe verification, idempotência via `stripe_processed_events` (migração `20260503_000002`), CORS corrigido (H-01).

### create-checkout-session (125 linhas) — Stripe Checkout

- Preços inline (sem Price IDs pre-criados): Plus R$39,90/mês, Pro R$80,00/mês
- Cria customer Stripe se não existir
- Valida return URLs contra whitelist (`isSafeReturnUrl`)
- Metadata: `guardian_user_id` + `plan_code`

### homepage-chat-proxy (721 linhas) — Trial sem Login

- Cookie `lua_trial_id` (180 dias) + fingerprint SHA-256 (user-agent + lang + platform) + IP
- Quota: 10 mensagens por 24h (configurável via env)
- Mensagem limitada a 1000 chars (ou 20000 com `HOMEPAGE_TRIAL_DISABLE_LIMITS=true`)
- Não requer JWT — acesso público
- Persiste em `homepage_trial_sessions` + `homepage_trial_tokens`

### chat-history (594 linhas) — Histórico Multi-agente

- Busca tokens do aluno + `token_sessions` correspondentes
- Merge de respostas legadas (`lua_responses`) com formato multi-agente (`token_sessions.conversation_history`)
- Regenera URLs assinadas de imagens (48h TTL)
- Retorna `{ messages, quota, activeDoubt }` para reconstrução do estado do chat

### upload-image (115 linhas) — Upload de Imagem

- Multipart form data → Supabase Storage bucket `doubt-images`
- Path: `{guardian_user_id}/{timestamp}-{random}.{ext}`
- Max 5MB, formatos JPEG/PNG/WebP, até 4 arquivos por request
- Retorna caminho + URL assinada

---

## 14. Fluxo de Auth Completo (Diagrama)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        AUTH GUARDIAN (Supabase Auth)                  │
│                                                                        │
│  /cadastro → email+senha ou Google OAuth                               │
│     ↓                                                                  │
│  Supabase Auth (JWT) → guardian_profiles → guardian_subscriptions       │
│     ↓                                                                  │
│  Cadastro de alunos (username+senha ou magic link)                     │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│                        AUTH ALUNO (Custom)                             │
│                                                                        │
│  /aluno/entrar → username+senha                                        │
│     ↓                                                                  │
│  POST /functions/v1/student-auth { action: 'login' }                   │
│     ↓                                                                  │
│  PBKDF2-SHA256(100k iters) → timing-safe compare                       │
│     ↓                                                                  │
│  Gera token (crypto.getRandomValues 32 bytes)                          │
│     ↓                                                                  │
│  Hash SHA-256 do token → student_sessions.token_hash                   │
│     ↓                                                                  │
│  Frontend salva token em localStorage                                  │
│     ↓                                                                  │
│  Requests subsequentes: session_token (hash) em cada chamada           │
│     ↓                                                                  │
│  Sliding window: cada check renova expires_at                          │
│     ↓                                                                  │
│  Logout: set revoked_at                                                 │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│                     TRIAL HOMEPAGE (Sem Auth)                          │
│                                                                        │
│  Cookie lua_trial_id (180 dias) + fingerprint + IP                     │
│     ↓                                                                  │
│  POST /functions/v1/homepage-chat-proxy                                 │
│     ↓                                                                  │
│  Upsert homepage_trial_sessions                                        │
│  Count tokens nas últimas 24h → quota check (10 msgs)                 │
│  Insert homepage_trial_tokens                                          │
│     ↓                                                                  │
│  Proxy → n8n /webhook/lua-homepage-trial                               │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 15. Fluxo Stripe (Pagamentos)

```
Responsável clica "Escolher Plano"
  ↓
POST /functions/v1/create-checkout-session
  { planCode: "plus"|"pro", successUrl, cancelUrl }
  ↓
Stripe Checkout Session criada (preço inline, sem Price IDs)
  ↓
Responsário completa pagamento no Stripe
  ↓
Stripe envia webhook → POST /functions/v1/stripe-webhook
  ↓
Verificação de assinatura (STRIPE_WEBHOOK_SECRET)
  ↓
Idempotência: checa stripe_processed_events
  ↓
Atualiza guardian_subscriptions:
  checkout.session.completed → status: active
  customer.subscription.updated → status: mapeado
  customer.subscription.deleted → status: free
  invoice.payment_failed → status: past_due
  ↓
Frontend polling: /functions/v1/student-stats ou redirect

Planos:
  Free: 1 aluno, 10 tokens/dia
  Plus: R$39,90/mes (3990 centavos), 2 alunos, 20 tokens/dia
  Pro: R$80,00/mes (8000 centavos), 4 alunos, 80 tokens/dia
```

---

## 16. Pipeline de IA — Detalhamento dos 4 Agentes

### Agente 1: Intake (Heurística JS)
- Análise rápida da mensagem do aluno
- Classificação `DOUBT` vs `SOCIAL` com score de confiança
- Se score alto (>0.8): decisão direta, sem chamar LLM
- Se ambíguo: passa para LangChain Agent

### Agente 2: Triage (Diagnóstico)
- Diagnostica tipo de travamento: `interpretação` | `método` | `base` | `checagem`
- Monta briefing com matéria, tema, nível do aluno
- Define `hint_level` inicial

### Agente 3: Educator (Tutoria)
- Recebe briefing + histórico da conversa + FPA do aluno
- Gera resposta pedagogica com `hint_level` progressivo (0-4)
- Nunca entrega resposta final diretamente (exceto hint_level 4 após tentativas suficientes)
- Output: `{ assistant_message, next_stage, hint_level, need_more_info, resolved }`

### Agente 4: Memory (Persistência)
- Atualiza `student_pfa` (forças, dificuldades, estilo de aprendizagem)
- Atualiza `topic_mastery` (domínio por matéria/tópico)
- Gera `guardian_alerts` para o responsável (progresso, dificuldade, inatividade)
- Registra `session_report` em `token_sessions`

### Hint Levels (Guardrail Pedagógico)

| Nível | Tipo | Exemplo |
|-------|------|---------|
| 0 | Pergunta exploratória | "O que você já tentou?" |
| 1 | Dica conceitual | "Lembra que equação é como uma balança?" |
| 2 | Passo direcionado | "Tente isolar o x passando o 3 pro outro lado" |
| 3 | Guia detalhado com verificação | "Faça X, Y, Z e me diz o que deu" |
| 4 | Resolução completa | "A resposta é X, mas vamos entender por quê" (após tentativas suficientes) |

**Invariante:** `hint_level` nunca decresce dentro da mesma sessão de token.

---

## 17. Mobile — Flutter (Paridade em Desenvolvimento)

### Estrutura Feature-First

```
lib/
├── main.dart
├── app/
│   ├── app.dart           # App shell com Riverpod
│   └── router.dart        # GoRouter com auth guard
├── core/
│   ├── theme/             # AppTheme (Nunito, cores LuaEduca)
│   ├── storage/           # session_storage (flutter_secure_storage)
│   │                       local_cache (shared_preferences)
│   ├── network/           # dio_provider + SSE parser
│   ├── config/            # app_config (URLs, flags)
│   └── errors/            # api_exception
├── features/
│   ├── auth_student/      # Login do aluno
│   │   ├── ui/student_login_page.dart
│   │   ├── auth_controller.dart (Riverpod)
│   │   ├── model/ (student_session, auth_state)
│   │   └── data/student_auth_api.dart
│   ├── chat/              # Chat com a Lua
│   │   ├── ui/chat_page.dart
│   │   ├── chat_controller.dart
│   │   ├── model/chat_models.dart
│   │   └── data/chat_api.dart
│   ├── sala/               # Hub do aluno
│   │   ├── ui/sala_page.dart
│   │   └── data/student_stats_api.dart
│   └── common/            # Componentes compartilhados
│       └── ui/ (config_error, starry_background, loading, lua_button)
```

### Stack Flutter

| Pacote | Uso |
|--------|-----|
| `flutter_riverpod` | State management |
| `go_router` | Navegação com auth guard |
| `supabase_flutter` | Auth guardian + DB |
| `dio` | HTTP client |
| `flutter_secure_storage` | Sessão do aluno (criptografada) |
| `crypto` | Hash SHA-256 (paridade com web) |
| `image_picker` | Upload de fotos |

### Rotas

| Rota | Widget | Auth |
|------|--------|------|
| `/loading` | LoadingPage | — |
| `/aluno/acesso` | StudentLoginPage | Unauthenticated |
| `/aluno/sala` | SalaPage | Authenticated |
| `/aluno/chat` | ChatPage | Authenticated |

---

## 18. Fluxo de Dados — Diagrama de Sequência (Chat do Aluno)

```
Aluno digita mensagem + possível foto
  │
  ├─[1] Frontend: useChatSend.ts
  │     ├─ Valida input (texto > 0 ou imagens)
  │     ├─ Se tem imagem: POST /functions/v1/upload-image
  │     │   └─ Retorna { path, signedUrl }
  │     ├─ POST /functions/v1/submit-doubt
  │     │   └─ Retorna { tokenId, quota: { used, limit } }
  │     └─ POST /functions/v1/n8n-proxy (SSE)
  │           body: { session_token, message, token_id, student_id, session_id, ... }
  │
  ├─[2] n8n-proxy Edge Function
  │     ├─ resolveActiveStudentSession() — valida hash SHA-256
  │     ├─ POST /webhook/lua-chat0 (Cloudflare Tunnel ou localhost)
  │     ├─ Stream SSE tokens de volta ao frontend
  │     └─ Bufferiza resposta final para persistência fallback
  │
  ├─[3] n8n Workflow: LuaEduca-PRO
  │     ├─ Auth Sessão → Buscar Aluno → Buscar FPA → Buscar Assinatura
  │     ├─ Gerir Token (cria ou reutiliza token + token_session)
  │     ├─ Classificar Intenção (heurística → LangChain se ambíguo)
  │     │   ├─ SOCIAL → resposta direta, incrementa casual_count
  │     │   └─ DOUBT → pipeline pedagógica
  │     ├─ Montar Prompt Lua (perfil + histórico + hint_level)
  │     ├─ LLM (OpenRouter) → resposta JSON
  │     ├─ Processar Resposta (parse, validar, ajustar estado)
  │     ├─ Salvar Sessão (token_sessions)
  │     ├─ Atualizar Token (tokens)
  │     └─ Retorna { assistant_message, stage, hint_level, ... }
  │
  ├─[4] Persistência
  │     ├─ n8n (LuaEduca-Persist): token_sessions + tokens + student_pfa
  │     └─ n8n-proxy fallback: se n8n não retornar session_id
  │
  └─[5] Frontend: renderização
        ├─ SSE tokens → animação de digitação (TypingMessage)
        ├─ Event "final" → atualiza estado (stage, hintLevel, quota)
        └─ Cache local (localStorage) para restaurar ao reabrir
```

---

## 19. Infraestrutura e Deploy

| Componente | Ambiente | Detalhes |
|-----------|----------|---------|
| **Frontend** | Vercel | Auto-deploy do repo LuaEducaWeb, SPA rewrite, PWA scope `/aluno/` |
| **Edge Functions** | Supabase Cloud | 13 functions Deno, deploy via CLI |
| **PostgreSQL** | Supabase Cloud | Project `texgadrxlsagbglfpjgy`, 26 migrations |
| **Storage** | Supabase | Bucket `doubt-images`, privado, URLs assinadas 48h |
| **n8n** | Docker local | `liaeduca-n8n`, imagem `n8nio/n8n:2.9.4`, porta 5678 |
| **Tunnel** | Cloudflare Quick | URL dinâmica, atualizada via `start.sh` |
| **Stripe** | Cloud | Checkout inline, webhook com signature verification |
| **Email** | Resend | `send-support-email` Edge Function |
| **LLM** | OpenRouter | Modelo configurável via `OPENROUTER_MODEL` |

### Variáveis de Ambiente Críticas

| Variável | Onde | Descrição |
|----------|------|-----------|
| `SUPABASE_URL` | Edge Functions + n8n | URL do projeto Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions + n8n | Chave admin (nunca no frontend) |
| `SUPABASE_ANON_KEY` | Frontend | Chave pública (VITE_) |
| `N8N_WEBHOOK_LUA_PRO_URL` | Supabase secrets | URL do tunnel Cloudflare |
| `OPENROUTER_API_KEY` | n8n | Chave do LLM |
| `STRIPE_SECRET_KEY` | Edge Functions | Chave Stripe |
| `STRIPE_WEBHOOK_SECRET` | stripe-webhook | Secret de verificação |
| `STUDENT_SESSION_TTL_DAYS` | student-auth | TTL da sessão (default 30) |
| `HOMEPAGE_TRIAL_TOKEN_LIMIT` | homepage-chat-proxy | Quota trial (default 10) |
| `N8N_PROXY_PERSISTENCE_MODE` | n8n-proxy | Modo de persistência |

---

## 20. Métricas de Sucesso do Produto (PRD)

| Métrica | Meta |
|---------|------|
| % de dúvidas respondidas sem pedir resposta final | > 70% |
| Tempo médio de processamento | < 15 segundos |
| Taxa de retorno em 48h | > 40% |
| Frequência média semanal dos alunos | > 3 dias |
| NPS dos responsáveis | > 50 |
| Conversão Free → Pago | > 10% |

---

## 21. Pontos Fortes da Arquitetura

1. **Separação clara de responsabilidades** — Frontend (Vite/React) → Edge Functions (Deno) → n8n (orquestração IA) → LLM (OpenRouter). Cada camada tem papel bem definido.

2. **Auth dual robusto** — Supabase Auth para responsáveis, auth custom com PBKDF2-SHA256 para alunos. Sessões hasheadas com SHA-256, timing-safe comparison, dummy hash anti-enumeration.

3. **Máquina de estados pedagógica** — `TRIAGE → CLARIFY → WAITING → RESEARCH → TUTOR → DIALOGUE → RESOLVED` com `hint_level` progressivo que nunca decresce.

4. **RLS em todas as tabelas** — Cada tabela tem políticas de Row Level Security. Alunos só veem seus dados, responsáveis só veem dados dos seus filhos.

5. **Idempotência no Stripe** — Tabela `stripe_processed_events` com PK no `event_id`, auto-cleanup de 7 dias.

6. **SSE streaming com fallback** — O n8n-proxy re-emite tokens SSE ao frontend enquanto bufferiza a resposta final. Se o n8n falhar na persistência, o proxy assume.

7. **Trial sem login funcional** — Cookie + fingerprint + IP com quota de 10 msgs/24h. Permite experimentar antes de comprar.

8. **Documentação extensa** — 7+ docs de integração, PRD detalhado, copy de marketing, cores da marca, análise de workflow, schema do banco, referência de tipos.

---

## 22. Pontos de Atenção e Riscos

### Críticos (segurança)

| # | Risco | Impacto | Status |
|---|-------|---------|--------|
| 1 | Rate limiting ausente em `student-auth` (login) | Brute-force de senhas | ❌ Pendente |
| 2 | Rate limiting ausente em magic-login | Abuso de magic links | ❌ Pendente |
| 3 | Rate limiting ausente em `send-support-email` | Spam de emails | ❌ Pendente |
| 4 | CORS wildcard no `stripe-webhook` (H-01) | Information leakage | ❌ Pendente (corrigido no código mas não verificado em produção) |

### Médios (arquitetura/técnica)

| # | Risco | Impacto | Status |
|---|-------|---------|--------|
| 5 | `n8n-proxy` com 1.388 linhas | Manutenibilidade | ⚠️ Monitorar |
| 6 | Componentes grandes no frontend (`useChatSend` 743 linhas, `Cadastro` 628) | Complexidade | ⚠️ Refatorar quando possível |
| 7 | SSE parsing duplicado entre `n8n-proxy` e `homepage-chat-proxy` | DRY | ⚠️ Pendente |
| 8 | Validação de env vars no startup das Edge Functions | Falhas silenciosas | ⚠️ Pendente |
| 9 | `web/` é submodule vazio — confusão para novos devs | Onboarding | ⚠️ Documentado em CLAUDE.md |
| 10 | URL do tunnel Cloudflare dinâmica | Debug local requer `start.sh` | ⚠️ By design |

### Mobile

| # | Risco | Impacto |
|---|-------|---------|
| 11 | App Flutter sem paridade completa com web | Funcionalidades faltando |
| 12 | Sem testes E2E mobile documentados | Regressões |
| 13 | SSE parsing no mobile pode ter edge cases | Conexão instável |

### Operacional

| # | Risco | Impacto |
|---|-------|---------|
| 14 | n8n roda local (Docker) — sem HA | Downtime se máquina reiniciar |
| 15 | Tunnel Cloudflare muda a cada restart | Sincronização de secrets automática mas com janela de indisponibilidade |
| 16 | LLM dependente de OpenRouter | Custo variável, latência, rate limits |

---

## 23. Roadmap Sugerido (Baseado em Riscos)

### Prioridade 1 — Segurança (Semanas 1-2)

1. **Implementar rate limiting** em `student-auth` (login), magic-login e `send-support-email`
2. **Verificar CORS wildcard** do `stripe-webhook` em produção
3. **Separar resolução de sessões órfãs** do endpoint de leitura em `chat-history`

### Prioridade 2 — Arquitetura (Semanas 3-4)

4. **Extrair lógica comum de SSE** de `n8n-proxy` e `homepage-chat-proxy` para `_shared/sse-stream.ts`
5. **Quebrar `useChatSend.ts`** em hooks menores (useSSEStream, useQuota, useTokenManagement)
6. **Validar env vars no startup** de cada Edge Function

### Prioridade 3 — Produto (Semanas 5-8)

7. **Completar paridade mobile** (chat com SSE, upload de imagem, quota)
8. **Adicionar E2E tests mobile** (Flutter integration tests)
9. **Migrar n8n para deploy cloud** (n8n Cloud ou VPS) para alta disponibilidade
10. **Adicionar rate limiting por IP no Trial** (atualmente só por cookie/fingerprint)

---

Essa análise cobre a totalidade do repositório LuaEduca — produto, arquitetura, banco de dados, Edge Functions, workflows IA, frontend, mobile, segurança e riscos. Se quiser que eu aprofunde em qualquer área específica (ex: refatorar um componente, implementar rate limiting, otimizar queries), é só dizer.
