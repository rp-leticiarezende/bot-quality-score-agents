# bot-quality-score-agents

Agentes Claude para análise automatizada de qualidade do chatbot de CX da RecargaPay (**BQS 3.0**).

Escopo: **somente conversas do bot** e **somente conteúdo externo da Central de Ajuda** (títulos com 🔒 ou 🔍 são internos e ficam fora). Relatórios semanais em `#lideres-cx-e-cxm`; alertas de casos críticos em `#team_product_cx`; erros de rotina também em `#team_product_cx` (nunca em `#lideres-cx-e-cxm`). O n8n não é alterado.

## BQS 3.0

**O que é:** a mesma aprovação do BQS 2.0, agora exibida como distribuição em 4 palavras. A nota geral (0–10, média ponderada arredondada) vira: **9–10 Ótimo, 7–8 Bom, 5–6 Regular, 0–4 Ruim**.

**Regra:** se resolução ≤ 2, escalação ≤ 2 ou o desfecho não é aceitável (loop, transbordo sem pedido do cliente, abandono depois de resposta fraca), a conversa fica no **máximo Regular**.

**Relação com o BQS 2.0:** Ótimo + Bom = aprovado (`nota_ok` e `desfecho_ok`) = o antigo BQS 2.0. O número principal (campo interno `bqs`) não muda e passa a se chamar **BQS 3.0 (% de Ótimo + Bom)**; a distribuição Ótimo/Bom/Regular/Ruim é a informação mais importante.

**Sempre calibrado pela auditoria:** nas conversas auditadas vale a nota revisada do auditor; nos não auditados aplica-se a distribuição observada nas amostras de calibração (aprovados e reprovados só pela nota). As contagens são esperadas (podem ter decimais). Com menos de 5 tickets em uma das amostras, o resultado é marcado como **provisório** e o motivo aparece na mensagem. O SQL está no Passo 6.3 de `templates/orch.template.md` (objeto `bqs3` no painel e campos `bqs3_*` no histórico).

**Histórico:** a série em 4 palavras começa em **26/10/2026**; o histórico anterior segue como BQS 2.0 (mesmo número principal, sem a distribuição).

## Como o BQS conta uma conversa

Uma conversa conta como boa quando a **conduta** do bot foi boa (nota geral ponderada ≥ 7, resolução > 2, transbordo > 2) **e** o **desfecho** é aceitável: resolvida pelo bot, transferida a pedido do cliente (fluxo esperado) ou abandonada depois de uma resposta boa (resolução ≥ 7). Loop e transbordo **sem pedido do cliente** reprovam, e o transbordo sem pedido é **sinalizado** para análise. Recontato em 24h, TFC e contatos evitáveis são indicadores de acompanhamento, fora da conta. Dashboards e histórico recomeçam em 20/10/2026. Detalhes em `docs/REVISAO-REGRAS-BQS.md`.

## Estrutura

| Caminho | O que é |
| --- | --- |
| `.claude/agents/orch-*.md` | Três orquestradores semanais (aleatório, agente de cartão de crédito e casos críticos). **Gerados** por `build.ps1`; não edite à mão. |
| `.claude/agents/bqs-contencao.md` | Classifica cada conversa em contato evitável × só humano e diz o que teria retido. |
| `.claude/agents/bqs-auditor.md` | Lê a transcrição dos casos duvidosos e revisa a nota (entra no BQS 3.0). |
| `.claude/agents/bqs-alertas.md` | Detector de casos críticos (erro técnico do bot, loop, jurídico/órgãos, fraude sem encaminhamento, vulnerabilidade). Não calcula BQS; avisa no `#team_product_cx` só quando há ticket novo. Roda numa rotina própria (sem orquestrador), independente dos fluxos. |
| `.claude/agents/bqs-abandono.md` | Abandono ativo do bot (quem conversa e sai), recontato em 7 dias e no mesmo tema, por semana e `entry_theme`; alimenta a aba "Abandono" do painel (`artifact/data/abandono/`, SQL em `sql/abandono.sql`). Não calcula BQS nem envia Slack. |
| `.claude/agents/chatbot-*.md`, `zendesk-guide-expert.md` | Especialistas de fluxo, HP, oportunidades, propostas, relatório e KB. |
| `templates/orch.template.md` | Fonte única dos orquestradores (SQL determinístico, passos, subagentes). |
| `templates/playbook-cartao.md` | Playbook de retenção do cartão, injetado em `bqs-contencao`, `bqs-auditor` e `chatbot-proposta-ajustes`. |
| `templates/painel-schema.md` | Contrato de dados do painel, injetado em `chatbot-relatorio-cx`. |
| `artifact/alertas.html` | Artefato privado "Alertas do BQS": temas, regras e histórico dos alertas; guarda o controle de tickets já avisados. |
| `artifact/painel.html` | Painel (artefato) "BQS RecargaBot" (título publicado: "BQS 2.0 RecargaBot"): lê `data/<chave>/latest.json` e `history.json`. |
| `artifact/data/` | Dados de teste usados na publicação. |
| `build.ps1` | Gera os orquestradores e injeta playbook e contrato: `powershell -ExecutionPolicy Bypass -File .\build.ps1` (salvar o script com BOM UTF-8). |
| `docs/CHANGES-v2.md` | O que mudou, achados do teste de ponta a ponta e pendências. |
| `docs/REVISAO-REGRAS-BQS.md` | Diagnóstico do cálculo antigo, simulações e a definição do BQS 2.0, base do BQS 3.0. |

## Rotinas em nuvem (Claude Code)

Cada rotina clona este repositório e executa o orquestrador correspondente.

| Rotina | Orquestrador | Agenda (BRT) | Chave do painel |
| --- | --- | --- | --- |
| Agente de Cartão de Crédito (semanal) | `orch-cartao-hp` | segunda a sábado 10:00 (análise diária; envio na segunda) | `cartao-hp` |
| Casos Críticos (semanal) | `orch-criticos-semanal` | segunda a sábado 15:00 (análise diária; envio na segunda) | `criticos-semanal` |
| Aleatório (semanal) | `orch-aleatorio` | segunda a sábado 14:00 (análise diária; envio na segunda) | `aleatorio` |
| Alertas de casos críticos | `bqs-alertas` (sem orquestrador) | segunda a sábado 11:00 (14:00 UTC; só avisa se houver ticket novo) | artefato próprio "Alertas do BQS" |

## Alertas de casos críticos (`bqs-alertas`)

Uma vez por dia (segunda a sábado, 11:00 BRT, 14:00 UTC), numa **rotina própria** ("Bot Quality — Alertas", independente das rotinas de cada fluxo), o detector varre os últimos 7 dias da transcrição de **todas as conversas do bot** (Cartão, Casos Críticos, Aleatório e qualquer outro fluxo; a transcrição chega com atraso, por isso a janela). Se houver ticket novo em algum dos 5 temas, envia **uma** mensagem em `#team_product_cx`; se não houver, não envia nada. Os `ticket_id` já avisados e o histórico ficam num artefato privado só de alertas (`artifact/alertas.html`, https://claude.ai/artifact/UmFJ3rmQCerkx1aq2LFcnM, arquivo `data/enviados.json`), **fora do painel do BQS**, e nunca são repetidos. Palavras de risco só contam quando ditas pelo cliente e quando o bot não encaminhou para humano. Modo `TESTE`: não posta nem grava. Falha do detector vai só para o `#team_product_cx` e não bloqueia o relatório semanal.

## Fluxo de cada rotina

1. SQL: período, cobertura, BQS 3.0, TFC, recontato 24h e sinalizados.
2. Subagentes em levas de até 3: fluxo, KB, HP (cartão) e contenção por lotes.
3. Auditoria pela transcrição dos casos duvidosos; consolidação em SQL (contenção e BQS 3.0).
4. Oportunidades → propostas → relatório: dados no painel (artefato) e **uma mensagem curta, só texto** no Slack, com o link do painel uma vez.

Cada rodada diária salva uma cópia do JSON do dia, com o dicionário das colunas, na pasta Base BQS do Drive.
