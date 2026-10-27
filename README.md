# bot-quality-score-agents

Agentes Claude para análise automatizada de qualidade do chatbot de CX da RecargaPay (**BQS 2.0**).

Escopo: **somente conversas do bot** e **somente conteúdo externo da Central de Ajuda** (títulos com 🔒 ou 🔍 são internos e ficam fora). Relatórios semanais em `#lideres-cx-e-cxm`; alertas de casos críticos em `#team_product_cx`; erros de rotina só em `#tarefas-let`. O n8n não é alterado.

## BQS 2.0 em uma frase

Uma conversa conta como boa quando a **conduta** do bot foi boa (nota geral ponderada ≥ 7, resolução > 2, transbordo > 2) **e** o **desfecho** é aceitável: resolvida pelo bot, transferida a pedido do cliente (fluxo esperado) ou abandonada depois de uma resposta boa (resolução ≥ 7). Loop e transbordo **sem pedido do cliente** reprovam, e o transbordo sem pedido é **sinalizado** para análise. Recontato em 24h, TFC e contatos evitáveis são indicadores de acompanhamento, fora da conta. Dashboards e histórico recomeçam em 20/10/2026. Detalhes em `docs/REVISAO-REGRAS-BQS.md`.

## Estrutura

| Caminho | O que é |
| --- | --- |
| `.claude/agents/orch-*.md` | Três orquestradores semanais (aleatório, agente de cartão de crédito e casos críticos). **Gerados** por `build.ps1`; não edite à mão. |
| `.claude/agents/bqs-contencao.md` | Classifica cada conversa em contato evitável × só humano e diz o que teria retido. |
| `.claude/agents/bqs-auditor.md` | Lê a transcrição dos casos duvidosos e revisa a nota (entra no BQS 2.0). |
| `.claude/agents/bqs-alertas.md` | Detector de casos críticos (erro técnico do bot, loop, jurídico/órgãos, fraude sem encaminhamento, vulnerabilidade). Não calcula BQS; avisa no `#team_product_cx` só quando há ticket novo. Roda numa rotina própria (sem orquestrador), independente dos fluxos. |
| `.claude/agents/chatbot-*.md`, `zendesk-guide-expert.md` | Especialistas de fluxo, HP, oportunidades, propostas, relatório e KB. |
| `templates/orch.template.md` | Fonte única dos orquestradores (SQL determinístico, passos, subagentes). |
| `templates/playbook-cartao.md` | Playbook de retenção do cartão, injetado em `bqs-contencao`, `bqs-auditor` e `chatbot-proposta-ajustes`. |
| `templates/painel-schema.md` | Contrato de dados do painel, injetado em `chatbot-relatorio-cx`. |
| `artifact/alertas.html` | Artefato privado "Alertas do BQS": temas, regras e histórico dos alertas; guarda o controle de tickets já avisados. |
| `artifact/painel.html` | Painel (artefato) "BQS 2.0 RecargaBot": lê `data/<chave>/latest.json` e `history.json`. |
| `artifact/data/` | Dados de teste usados na publicação. |
| `build.ps1` | Gera os orquestradores e injeta playbook e contrato: `powershell -ExecutionPolicy Bypass -File .\build.ps1` (salvar o script com BOM UTF-8). |
| `docs/CHANGES-v2.md` | O que mudou, achados do teste de ponta a ponta e pendências. |
| `docs/REVISAO-REGRAS-BQS.md` | Diagnóstico do cálculo antigo, simulações e a definição do BQS 2.0. |

## Rotinas em nuvem (Claude Code)

Cada rotina clona este repositório e executa o orquestrador correspondente.

| Rotina | Orquestrador | Agenda (BRT) | Chave do painel |
| --- | --- | --- | --- |
| Agente de Cartão de Crédito (semanal) | `orch-cartao-hp` | segunda a sábado 10:00 (análise diária; envio na segunda) | `cartao-hp` |
| Casos Críticos (semanal) | `orch-criticos-semanal` | segunda a sábado 15:00 (análise diária; envio na segunda) | `criticos-semanal` |
| Aleatório (semanal) | `orch-aleatorio` | segunda a sábado 14:00 (análise diária; envio na segunda) | `aleatorio` |
| Alertas de casos críticos | `bqs-alertas` (sem orquestrador) | segunda a sábado 09:30 (só avisa se houver ticket novo) | artefato próprio "Alertas do BQS" |

## Alertas de casos críticos (`bqs-alertas`)

Uma vez por dia (segunda a sábado, 09:30 BRT), numa **rotina própria** ("Bot Quality — Alertas", independente das rotinas de cada fluxo), o detector varre os últimos 7 dias da transcrição de **todas as conversas do bot** (Cartão, Casos Críticos, Aleatório e qualquer outro fluxo; a transcrição chega com atraso, por isso a janela). Se houver ticket novo em algum dos 5 temas, envia **uma** mensagem em `#team_product_cx`; se não houver, não envia nada. Os `ticket_id` já avisados e o histórico ficam num artefato privado só de alertas (`artifact/alertas.html`, https://claude.ai/artifact/UmFJ3rmQCerkx1aq2LFcnM, arquivo `data/enviados.json`), **fora do painel do BQS**, e nunca são repetidos. Palavras de risco só contam quando ditas pelo cliente e quando o bot não encaminhou para humano. Modo `TESTE`: não posta nem grava. Falha do detector vai só para o `#tarefas-let` e não bloqueia o relatório semanal.

## Fluxo de cada rotina

1. SQL: período, cobertura, BQS 2.0, TFC, recontato 24h e sinalizados.
2. Subagentes em levas de até 3: fluxo, KB, HP (cartão) e contenção por lotes.
3. Auditoria pela transcrição dos casos duvidosos; consolidação em SQL (contenção e BQS 2.0).
4. Oportunidades → propostas → relatório: dados no painel (artefato) e **uma mensagem curta, só texto** no Slack, com o link do painel uma vez.
