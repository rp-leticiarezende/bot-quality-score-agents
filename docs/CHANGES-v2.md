# BQS agentes — v2 (passos 1 e 2: base confiável + contatos evitáveis)

Branch: `bqs-v2-estrito-contencao` · Data: 20/10/2026 · Status: **não publicado** (nenhum push, nenhuma rotina alterada).

## Escopo (decisão de 20/10)

**Somente conversas do bot.** Nenhum agente analisa ou recomenda sobre o atendimento humano (macros, orientação a atendentes, filas, TMO, CSAT do humano). Donos de ação: **Produto CX** e **Help Design**. Quando só uma pessoa resolve (classe D), a análise é sobre o que o bot deveria ter coletado e informado antes de transferir.

## Por que mudar

A taskforce quer reduzir contatos. O BQS respondia "o bot conduziu bem?", mas não "quantos contatos ele poderia ter evitado e o que teria retido o cliente". Além disso, a auditoria dos dados (20/10/2026, tabela `prod.cx.fat_botmaker_conversations_quality`) mostrou problemas que distorciam o próprio BQS.

## O que a auditoria encontrou (dados reais)

| # | Achado | Evidência | Efeito |
|---|---|---|---|
| 1 | `approved` não é confiável | No Databricks é booleano, na origem é 1/0.5/0. Conversas `regular` (0.5) chegam como `NULL` e saem do denominador. Há combinações incoerentes (`regular` com `approved = true`; `bom` com `NULL`). Em 60 dias: 1.273 `regular` + 169 `bom` + 13 `ruim` com `approved = NULL`. | O BQS reportado (approved) superestima. Semana 12–18/10, HP: **81,4% (legado) × 72,4% (estrito)**; 43 conversas fora do denominador. |
| 2 | Transbordo bem executado é aprovado mesmo com resposta falha | Amostra HP 12–18/10: muitos transbordos `excelente/bom` em que o cliente respondeu "Não" à confirmação de resolução e pediu atendente; o avaliador aprova "por atender ao pedido de transferência". | BQS alto convive com contato evitável. |
| 3 | Composição da aba "aleatório" | 12–20/10: **100% transbordo** e **~96% pediram atendente** (120 de 120). A amostra é aleatória e o filtro vem do Zendesk (**decisão: manter**). | Só uma nota informativa quando `pct_transbordo ≥ 90`: o BQS mede a conduta até o transbordo; o CE vira o número principal. |
| 4 | Buraco de dados e cobertura baixa | Sem dados de **11/09 a 14/10** (retomou em 15/10, sem fim de semana). Semana 12–18/10 do HP tem dado em só 2 dias. | Comparação semana a semana indisponível; números atuais são amostra reduzida. |
| 5 | Agente de KB recebia pacote sem os campos de KB | Os orquestradores diziam que `kb_*` eram sempre NULL. Na verdade estão preenchidos (`kb_alignment`, `kb_score`, `kb_matched_article_title`, `kb_discrepancies`); só `issues` e `improvement_suggestions` estão vazios. | A análise de KB não conseguia nomear artigos. Hoje: 66% das conversas do agente de cartão têm algum problema de KB. |
| 6 | `chatbot-hp-variaveis` consultava colunas inexistentes | `hp_personalization_*` / `hp_variable_errors` não existem na tabela; o arquivo também não tinha frontmatter. | Análise de HP não funcionava. |
| 7 | `botmaker_chatbot_flow` 0% preenchido; `botmaker_stage` 37% (HP) | Medido em 12–20/10. | A análise "por estágio e fluxo" do agente de fluxo era vazia. |
| 8 | Artefato: colisão de título | Busca por "contém" → "Críticos" casava com diário e semanal; um sobrescrevia o outro. | Corrigido: título exato `BQS · [chave]`. |
| 9 | Contas feitas pelo LLM | Orquestradores pediam ao modelo que calculasse BQS/TFC sobre centenas de linhas. | Agora todo número vem de SQL. |
| 10 | Resumos contêm nomes de clientes | Observado em `summary`. | Regra de nunca repassar dado pessoal para relatório/artefato/Slack. |

## Métricas canônicas (definidas uma vez, em SQL)

```
nota_ok = score_overall >= 7 AND score_resolution > 2 AND score_escalation > 2   (NULL se sem_dados)
BQS     = nota_ok / avaliáveis                       (regular reprovado, sem crédito parcial)
TFC     = (transbordo|abandono|loop) sem pedido do cliente / total
CE      = conversas classificadas A+B+C pelo bqs-contencao / classificadas  (+ estimativa sobre o total)
```
O BQS legado (`approved`) aparece só em rodapé, para comparação histórica. Os limiares de alerta de TFC, pedido de humano e prioridade por contatos evitáveis são **provisórios** até haver 4 períodos de série.

## Arquivos

| Arquivo | Mudança |
|---|---|
| `templates/orch.template.md` + `build.ps1` | **Novo.** Fonte única dos 4 orquestradores. Rode `powershell -ExecutionPolicy Bypass -File .\build.ps1` para regenerar. |
| `.claude/agents/orch-*.md` (4) | **Gerados.** SQL determinístico (período BRT atual × anterior, cobertura/frescor, métricas, quebras, pacotes), subagentes em levas de até 3, consolidação da contenção por `VALUES`. |
| `.claude/agents/bqs-contencao.md` | **Novo.** Classifica cada conversa em A/B/C/D/R/E, causa, dono e "o que teria retido"; busca o próprio lote (30 conversas) no Databricks. |
| `chatbot-cx-botmaker.md` | Reescrito: colunas corretas, limitações de campo declaradas, padrões de falha em vez de "por estágio". |
| `chatbot-hp-variaveis.md` | Reescrito: frontmatter, mapa de variáveis de cartão (API de Contexto v2), saúde do contexto, 5 blocos + snapshot. |
| `zendesk-guide-expert.md` | MODO CURADORIA usa tabelas pré-calculadas, `sem_artigo` com título, URL redigida, primeira frase do artigo. |
| `chatbot-oportunidades.md` | MODO CURADORIA prioriza por contatos evitáveis (observado × estimado), por classe/causa/dono. |
| `chatbot-proposta-ajustes.md` | MODO CURADORIA: "o que teria retido (antes → depois)", referência de nós do cartão, proibição de inventar nós, política de transbordo com validação Compliance/Jurídico. |
| `chatbot-relatorio-cx.md` | MODO CURADORIA: BQS estrito, TFC/CE, cobertura, `MODO SEM DADOS`, donos só **Produto CX** e **Help Design**, título único do artefato, regra de dados pessoais. O visual (Slack/artefato) fica para o passo 5. |

## Taxonomia da contenção

| Classe | Significado | Dono |
|---|---|---|
| A | Bot resolvia hoje (falha de execução: loop, NLU, prompt, regra de transbordo) | Produto CX |
| B | Resolveria com ajuste (artigo, variável existente, roteamento) | Help Design / Produto CX |
| C | Exigiria capacidade nova (consulta, ação, integração) | Produto CX |
| D | Só humano resolve — avalia o handoff **do bot** (correto / improvisado / tardio) | Produto CX |
| R | Retido provável (abandono após resposta correta) | — |
| E | Indeterminado → candidato a auditoria (passo 4) | — |

Teste real: 30 conversas HP não-sucesso (semana 12–18/10) → A 16 · B 4 · C 0 · D 4 · R 4 · E 2; 20 evitáveis (66,7%); 10 marcadas para auditoria. Amostra **não** representativa (só não-sucessos); serve para validar o formato e o critério.

## Pendências e validações

- Confirmar com Produto CX: cancelamento de cartão **físico** só com atendimento (observado em conversas/artigos, não consta na documentação do agente); variáveis `agcc_desambiguacao` × `cc_desambiguacao` (nomes divergentes na doc); modelo do agente de cartão.
- Compliance/Jurídico (SAC) antes de qualquer mudança na regra de transbordo por pedido de humano.
- O n8n precisa de PR do time cyber (v2 em `Downloads\bqs-n8n-v2`) para gravar `approved` coerente; até lá o BQS estrito neutraliza o problema.
- Canal: **decidido** — todos os relatórios (inclusive críticos) vão para `#bot-quality-score` (C0BP08WPMLP). O Confluence ainda cita `#casos-criticos-bot` e precisa ser corrigido.
- Os agentes de rotina em nuvem precisam enxergar `bqs-contencao` (está em `.claude/agents`) e ter o MCP de dados disponível para subagentes.
- Atualizar a página do Confluence do BQS (fórmula, campos, agentes) depois da validação.

## Próximos passos
3. Playbook de retenção por tema de cartão · 4. Subagente `bqs-auditor` (transcrição via `prod.cx.fat_tickets_transcription` / Zendesk) · 5. Artefato consolidado + Slack visual.
