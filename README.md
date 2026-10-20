# bot-quality-score-agents

Agentes Claude para análise automatizada de qualidade do chatbot de CX da RecargaPay (BQS).

Escopo: **somente conversas do bot** e **somente conteúdo externo da Central de Ajuda** (títulos com 🔒 ou 🔍 são internos e ficam fora). Resultados sempre em `#bot-quality-score`.

## Estrutura

| Caminho | O que é |
|---|---|
| `.claude/agents/orch-*.md` | Quatro orquestradores (aleatório, cartão HP, críticos diário e semanal). **Gerados** por `build.ps1`; não edite à mão. |
| `.claude/agents/bqs-contencao.md` | Classifica cada conversa em contato evitável × só humano e diz o que teria retido. |
| `.claude/agents/bqs-auditor.md` | Lê a transcrição dos casos duvidosos e revisa a nota (entra no BQS final). |
| `.claude/agents/chatbot-*.md`, `zendesk-guide-expert.md` | Especialistas de fluxo, HP, oportunidades, propostas, relatório e KB. |
| `templates/orch.template.md` | Fonte única dos orquestradores (SQL determinístico, passos, subagentes). |
| `templates/playbook-cartao.md` | Playbook de retenção do cartão, injetado em `bqs-contencao`, `bqs-auditor` e `chatbot-proposta-ajustes`. |
| `templates/painel-schema.md` | Contrato de dados do painel, injetado em `chatbot-relatorio-cx`. |
| `artifact/painel.html` | Painel (artefato) "BQS RecargaBot", página fixa que lê `data/<rotina>/latest.json` e `history.json`. |
| `artifact/data/` | Dados da rodada de teste usados na primeira publicação. |
| `build.ps1` | Gera os orquestradores e injeta playbook e contrato. Rode: `powershell -ExecutionPolicy Bypass -File .\build.ps1`. |
| `docs/CHANGES-v2.md` | O que mudou, por quê, achados da auditoria e pendências. |

## Fluxo de cada rotina

1. Orquestrador consulta o Databricks (SQL: BQS, TFC, cobertura, pacotes).
2. Subagentes em levas de até 3: fluxo, KB, HP (cartão) e contenção por lotes.
3. Auditoria pela transcrição dos casos duvidosos; consolidação em SQL (contenção e BQS final).
4. Oportunidades → propostas → relatório: dados no painel e duas mensagens no Slack.

O n8n não é alterado: tudo o que dependeria dele é resolvido na rotina, com SQL e conectores.
