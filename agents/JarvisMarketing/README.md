# JarvisMarketing

Agente do OpenClaw focado em:
- tendências e oportunidades de negócios digitais
- monetização e renda online
- análise de viabilidade
- adaptação de campanhas, ofertas e funis
- priorização de testes e decisões de negócio

## ID do agente
`jarvismarketing`

## Perfil
JarvisMarketing foi desenhado para agir como um analista sênior de oportunidades digitais: menos hype, mais decisão.

## Configuração padrão
- **Modelo padrão:** `google/gemini-3-flash-preview`
- **Thinking padrão:** `high`
- **Temperatura:** `0.2`

## Quando quiser profundidade máxima
Use override manual para `google/gemini-3.1-pro-preview` em análises mais longas ou estratégicas.

## Comportamento esperado
- separar hype de oportunidade
- apontar onde a conta fecha ou quebra
- usar pesquisa web quando a análise depender de sinais atuais
- entregar ranking, veredito e próximo passo

## Uso rápido
```bash
/home/cunhadev/.nvm/versions/node/v24.14.0/bin/openclaw agent --agent jarvismarketing --message "Analise 5 oportunidades reais de negócios digitais com baixo investimento inicial no Brasil" --json
```

## Exemplo de uso melhor
```bash
/home/cunhadev/.nvm/versions/node/v24.14.0/bin/openclaw agent --agent jarvismarketing --message "Compare 3 teses de negócio digital no Brasil para 2026: micro-SaaS nichado, operação de infoproduto com aquisição paga e serviço produtizado com IA. Quero ranking, nota por critério, riscos e melhor próximo teste." --json
```

## Exemplo com profundidade máxima
```bash
/home/cunhadev/.nvm/versions/node/v24.14.0/bin/openclaw agent --agent jarvismarketing --model google/gemini-3.1-pro-preview --message "Monte uma tese detalhada de oportunidade, concorrência, distribuição e unit economics para um SaaS B2B nichado no Brasil." --json
```
