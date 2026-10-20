# BQS agentes — v2 (passos 1 e 2: base confiável + contatos evitáveis)

Branch: `bqs-v2-estrito-contencao` · Data: 20/10/2026 · Status: **não publicado** (nenhum push, nenhuma rotina alterada).

## Escopo (decisão de 20/10)

**Só conteúdo externo da Central de Ajuda** (o que o bot consome): artigos cujo título começa com 🔒 ou 🔍 são internos, não são consultados pelo bot e ficam fora de qualquer análise, fonte ou recomendação. Verificado em 15–20/10: nenhuma conversa foi associada pelo avaliador a título 🔒/🔍.

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
| `chatbot-proposta-ajustes.md` | MODO CURADORIA: "o que teria retido (antes → depois)", referência de nós do cartão, proibição de inventar nós, política de transbordo. |
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
- **Decisão: não alterar o fluxo do n8n** (complexidade). O que dependeria dele é resolvido na rotina, com SQL e conectores: o BQS é recalculado a partir das notas (não do `approved`), a cobertura e os buracos de dados são detectados por consulta, o piso de resolução/transbordo é aplicado em SQL, a nota revisada vem do auditor (transcrição) e o painel é publicado pelo agente de relatório. O que a rotina **não** corrige (ex.: ausência de registros em fim de semana, `botmaker_chatbot_flow` vazio) é sinalizado como limitação no relatório.
- Canal: **decidido** — todos os relatórios (inclusive críticos) vão para `#bot-quality-score` (C0BP08WPMLP). O Confluence ainda cita `#casos-criticos-bot` e precisa ser corrigido.
- Os agentes de rotina em nuvem precisam enxergar `bqs-contencao` (está em `.claude/agents`) e ter o MCP de dados disponível para subagentes.
- Atualizar a página do Confluence do BQS (fórmula, campos, agentes) depois da validação.

## Passo 3 — Playbook de retenção do cartão

`templates/playbook-cartao.md` é a **fonte única** (17 temas); o `build.ps1` o injeta entre os marcadores `PLAYBOOK_CARTAO` de `bqs-contencao.md` e `chatbot-proposta-ajustes.md`. Cada tema traz: indicadores do fluxo (15–20/10), fatos do artigo oficial (prazos, caminhos), variáveis do payload, **resposta que retém** (rascunho para o Produto CX validar), lacunas (B/C) e quando é `D` com o handoff correto do bot. Cobre os dois agentes (`Agente CC Produção` e `Agente CC Anuidade`).
Fontes: Parte 5 do Confluence, API de Contexto v2, 12 artigos públicos (4 via Zendesk, 8 via site público; 4 temas ficaram sem leitura: acessar/pagar fatura, cancelar transação, resgatar saldo, aumentar limite — o conector Zendesk não busca por título e o site devolveu 429).
Reteste do `bqs-contencao` nas mesmas 30 conversas: `o_que_reteria` passou a citar prazo, caminho e artigo concretos (ex.: "1 dia útil, não 30 minutos"). Distribuição A/B/C/D/R/E: de 16/4/0/4/4/2 para 18/1/3/3/3/2; evitáveis 67% → 73% (amostra só de não-sucessos, não representativa). `auditar` veio alto (14 de 30), então os gatilhos ficaram seletivos (~20% do lote) — **reteste pendente** dessa mudança.

**Achados de conteúdo para o Help Design (independem do bot):**
- Dois artigos públicos têm marcações internas **`[VALIDAR: …]`** no texto: 51856715765267 (compra não reconhecida) e 51706375319827 (compra recusada).
- Não existe conteúdo **externo** com o passo a passo de "Encerrar relacionamento com cartão"; o público de cancelar físico (54886179457427) termina em "conforme detalhado abaixo" sem conteúdo e tem HTML sujo de colagem.
- "Roubaram meu cartão" (43654947527443): a 1ª frase não responde e 93% das conversas do tema têm problema de KB, com TFC 73%.
- Cashback em 7 cópias e anuidade de limite garantido em 2 cópias.
- O artigo de limite pré-aprovado está em rascunho.
- Taxonomia de `topic` com variantes de grafia (`roubaram-meu-cartão` × `roubaram-meu-cartao`).

## Passo 4 — `bqs-auditor` (nota revisada com a transcrição)

- **Agente novo** `bqs-auditor.md`: lê a transcrição (`prod.cx.fat_tickets_transcription`, em janelas de 6.000 caracteres; reserva: Zendesk `get_ticket` com `full_comments`), reavalia as 6 dimensões com a régua do pipeline (pesos 30/20/20/15/10/5 e piso) e a classe/causa de contenção. Decide `CONFIRMA`, `REVISA` ou `SEM_TRANSCRICAO`. Só lê o trecho do bot (até a primeira fala humana), só conteúdo externo, e nunca copia dados pessoais.
- **Orquestradores:** novo **Passo 5B** (até 12 tickets `auditar = sim`, em até 2 auditores de 6; ordem: classe E, confiança baixa, demais) e **Passo 6.2** (BQS final por SQL: a nota geral revisada é `ROUND(0,30·res + 0,20·eff + 0,20·esc + 0,15·und + 0,10·cla + 0,05·ton)`, aprovada com `≥ 7` e piso; `REVISA` substitui a nota, `CONFIRMA` mantém). As correções de classe do auditor substituem as do `bqs-contencao` no Passo 6.1.
- **Decisão da usuária:** a nota revisada **entra no BQS** do relatório. O cabeçalho mostra o BQS final, o original, nº de auditados, nº de revisados e o saldo de trocas de aprovação. As tabelas por dimensão e o período anterior continuam **originais** (a auditoria é uma amostra seletiva de casos duvidosos, não aleatória).
- **Evidência:** 99% das notas já seguem a média ponderada arredondada (820 de 830), e 12 conversas violam o piso na origem — por isso o BQS final recalcula a regra em SQL.
- **Teste real (4 tickets do HP, 12–18/10):** o auditor revisou os 4; em todos a nota original estava **alta demais** (o avaliador premia o transbordo mesmo quando a resposta anterior falhou); um mudou de aprovado para reprovado (nota 8 → 4). SQL do 6.2 validada: BQS 72,4% → 72,2%. A amostra é seletiva e pequena — não generalizar.
- **Ajustes após o teste:** fim do trecho do bot (falas `RecargaPay:`/`RecargaPay Ajuda:` e "você será conectado…"), transferência anunciada e não executada, pergunta SIM/NÃO do fluxo ≠ CSAT, regra para conversa em fases, `REVISA` só quando muda aprovação, `resolution`/`escalation` ≥ 2 pontos ou a classe.
- **Não testado:** a reserva via Zendesk (todas as transcrições do teste estavam na tabela; cobertura da tabela 66–78% nos tickets avaliados) e a execução dentro da rotina em nuvem (nome do conector Zendesk `mcp__MCP_Proxy_RecargaPay__zendesk` e limite de consultas simultâneas ao Databricks).

## Passo 5 — Painel (artefato) e Slack visual

- **Painel único** `artifact/painel.html` ("BQS RecargaBot"): página fixa, sem biblioteca externa, tema claro/escuro, responsiva. Abas: **Visão geral** (cartões por rotina, onde estão os contatos evitáveis, tendência, o que mais pesa, auditoria), **Cartão HP**, **Aleatório**, **Casos críticos** (semanal/diário) e **Como ler**. Cada aba de fluxo traz KPIs, pontos de atenção, desfecho, qualidade por agente e tema, contatos evitáveis por causa e dono, e **"O que mudar"** com filtro por frente (Artigos, Variáveis e prompts, Fluxo e regras, Capacidades novas, Handoff) e cada oportunidade com antes → depois.
- **Como as rotinas atualizam:** cada rotina publica só os **seus dois arquivos** (`data/<chave>/latest.json` e `history.json`) ao lado da página, com a ferramenta de artefato que o agente de relatório já usa. Não depende de banco, de n8n nem de capacidade especial. Contrato em `templates/painel-schema.md` (injetado no `chatbot-relatorio-cx` pelo build). Conflito entre rotinas: relê e publica de novo uma vez.
- **Slack:** duas mensagens em `#bot-quality-score` (canal único). A 1ª é um resumo visual em markdown (título, tabela de KPIs, barra de desfecho em quadrados, auditoria, pontos de atenção com 🔴🟠🔵, link do painel); a 2ª, na thread, traz o plano de ação em tabelas por dono (Produto CX e Help Design, máx. 3 cada) com "teria retido". O HTML antigo saiu do agente de relatório.
- **Primeira publicação (rodada de teste, 20/10/2026):** https://claude.ai/artifact/SziKVqFyjwbNk3vR2YdsbQ (privado). Cartão HP com métricas reais, contenção por amostra de 30, auditoria de 4 tickets, 9 oportunidades e 8 artigos; Aleatório e Casos críticos só com métricas; sem histórico (a tendência aparece na 2ª rodada). Banner "Rodada de teste" nos dados com `meta.origem = "teste"`.
- **Verificação:** a página rodou sem erros de console em desktop e celular (tema claro e escuro) com os mesmos JSONs; os 4 arquivos conferem no artefato publicado. Não testado: a publicação feita por uma rotina em nuvem (permissões da ferramenta de artefato e do Slack no ambiente da rotina).
- **Datas para o JSON:** o Passo 1 dos orquestradores passou a devolver `inicio_iso`, `fim_iso` e `gerado_em_brt` (Spark junta literais adjacentes, então `''T''` falha; usa-se `CONCAT`).

## Próximos passos
- Rodada de teste ponta a ponta (modo sombra) dos orquestradores em paralelo ao que existe hoje, sem postar no canal; reteste da auditoria seletiva da contenção.
- Atualizar o Confluence (fórmula do BQS, campos, agentes, escopo só-bot, canal único, regra de conteúdo externo, painel).
- Enviar ao GitHub e abrir PR para revisão, só com autorização.
- Pendências com terceiros: validação do Produto CX sobre as respostas-modelo do playbook; compartilhar o painel com quem for consultar (hoje privado).

## Passo 5b — ajustes pedidos em 20/10/2026 (revisão da Leticia)

- **BQS único:** removidos "BQS original" e "legado" do painel, do Slack, do contrato e dos agentes. Nota geral sempre recalculada (ponderada) a partir das 6 notas; a série inteira fica comparável.
- **Linha do tempo no painel:** aba nova com gráfico por data (BQS, TFC e contatos evitáveis), faixa de hiato, marcos (`data/eventos.json`, manual) e mudança de `prompt_version` detectada sozinha, tabela de períodos com variação; cada aba de fluxo ganhou "Evolução desta rotina". Histórico semanal reconstruído do Databricks (jul a out/2026). Após pausa, a variação mostra "sem base de comparação" e o último ponto conhecido.
- **Link do painel** no topo das duas mensagens do Slack (e no rodapé da primeira); aviso de que o artefato é privado e precisa ser compartilhado.
- **HP pleno × degradado** rebaixado a "indicador em revisão" (informativo, sem alerta nem oportunidade). Evidência em `docs/REVISAO-REGRAS-BQS.md`.
- **Regras a revisar** (BQS de cartão não é oficial; simulações; hiato 11/09–14/10, retorno em 14/10): `docs/REVISAO-REGRAS-BQS.md`.
- BQS por agente e por tema: mantido.

## Passo 5c — conteúdo do painel (20/10/2026)

- **Tickets de exemplo** (até 3, só `ticket_id`): em "Principais ações", em "Contatos evitáveis" (por causa, na visão geral e na aba do fluxo), em "O que mudar" (resumo de cada oportunidade e coluna na tabela de artigos) e nos pontos de atenção dos casos críticos/aleatório. Contrato atualizado (`tickets` em causas, artigos e pontos de atenção).
- **Nome:** "Cartão HP" virou "Agente de Cartão de Crédito" (painel, dados, Slack, orquestrador). A chave técnica `cartao-hp` não mudou.
- **Períodos:** Agente de Cartão de Crédito e Aleatório com visão semanal e mensal; Casos críticos com semanal, diário e mensal; a Visão geral filtra por semanal ou mensal para todos os produtos. A linha do tempo também alterna semanal/mensal.
- **Visões mensais e diária:** dados de teste calculados no Databricks (sem auditoria nem classificação); a consolidação mensal a partir das semanais fica para depois (otimização de tokens). Chaves novas: `cartao-hp-mensal`, `aleatorio-mensal`, `criticos-mensal`.

## Passo 6 — BQS 2.0 (20/10/2026)

- **Regra nova** (ver `docs/REVISAO-REGRAS-BQS.md`, seção 8): conduta boa E desfecho aceitável (resolutiva; transbordo pedido pelo cliente; abandono depois de resposta boa). Loop e transbordo sem pedido reprovam; o transbordo sem pedido é sinalizado.
- **SQL:** `BASE_CTE` ganhou `desfecho_ok`, `transbordo_sem_pedido` e `recontato_24h` (join com `prod.cx.fat_botmaker_metrics`); Passo 3.1/3.2 e 6.2 calculam o BQS 2.0; novo Passo 3.4 (sinalizados).
- **Painel e Slack:** nome BQS 2.0; indicador de recontato 24h; seção "Sinalizados para análise"; histórico e linha do tempo recomeçam em 20/10/2026 (marco "Início do BQS 2.0"); explicação em "Como ler".

## Teste de ponta a ponta (20/10/2026) — Agente de Cartão de Crédito, semana 12 a 18/10

Rodada completa com postagem real no #bot-quality-score (marcada como TESTE): SQL → fluxo, KB, HP → 2 lotes de contenção (60 de 276) → 2 auditores (9 tickets) → SQL de consolidação → oportunidades e propostas (25) → painel (versão 6) e 2 mensagens. Resultado: **BQS 2.0 63,4%** (64,4% antes da auditoria; 4 de 9 tickets auditados passaram de aprovado para reprovado), contatos evitáveis ≈ 54% (IC 66–87% das classificadas), 32 transbordos sem pedido sinalizados.

Achados do teste e o que foi feito ou fica pendente:
- **Resultado grande demais no conector** (Pacote A, 190 mil caracteres) e `diagnostics` cortado no meio do JSON: reduzi o pacote (70 linhas, `diagnostics` 700 e `summary` 350 caracteres) — feito.
- **Modelo pull:** os especialistas buscaram os próprios dados e gravaram a saída em arquivo; o orquestrador só passou caminhos. Gastou muito menos contexto que colar linhas no prompt. Vale adotar na rotina.
- **Pacote A não traz** `user_messages`/motivo de abandono: o especialista de fluxo não consegue aplicar a regra de loop. Pendente.
- **Régua do avaliador:** não distingue "transferência anunciada e nunca conectada" de "executada tarde" (tickets 46605356, 46610432). Pendente: ajustar a rubrica do bqs-auditor.
- **Distribuição por desfecho soma 394, não 398** (4 conversas sem `retention_type`): o relatório já trata, mas vale uma linha "sem classificação" no contrato.
- **Contrato:** oportunidades com 0 observados ficam com estimado 0; falta o valor "n/c". Pendente.
- **Ferramentas:** o agente de relatório cita nomes de conector que não existem neste ambiente (`mcp__Slack__*`); na rotina em nuvem os nomes são os do ambiente dela. Conferir no modo sombra.
- **Conflito de regras para o Produto CX decidir:** guardrails do bot proíbem orientar caminho no app, mas as propostas citam caminho; variável de desambiguação com dois nomes (`agcc_desambiguacao` × `cc_desambiguacao`).

## Primeira execução real na nuvem — Casos Críticos (diário), 20/10/2026

Rodada manual da rotina `Bot Quality — Casos Críticos` (dia 19/10). Cadeia completa: SQL, fluxo, contenção (24 conversas), auditoria (4 tickets), consolidação, oportunidades (12), propostas e relatório. **BQS 2.0: 33,3%** (45,8% antes da auditoria; 3 aprovações revertidas), contatos evitáveis ≈ 60%.

O que quebrou e como ficou:
- **`zendesk-guide-expert` não subia** (o conector Zendesk não existe na nuvem e era a única ferramenta listada): agora herda as ferramentas disponíveis. A análise de KB não rodou nesta execução.
- **`chatbot-relatorio-cx` não conseguiu publicar o painel** (faltava a ferramenta `Read`, e o Artifact exige ler a página inteira): adicionadas `Read`, `Glob`, `Grep` e `Bash`. Nesta rodada o orquestrador publicou o painel (versão 10) depois da mensagem, que saiu com "painel indisponível neste ciclo".
- **Negrito no Slack:** o conector trata `*texto*` como itálico; o formato agora usa `**texto**`.
- Instrução nova: o painel é publicado **antes** da mensagem do Slack.
