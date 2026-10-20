# build.ps1 - gera .claude/agents/orch-*.md a partir de templates/orch.template.md
# Uso (na raiz do repo):  powershell -ExecutionPolicy Bypass -File .\build.ps1
# Edite o TEMPLATE (ou os blocos abaixo) e rode de novo. Nao edite os orch-*.md gerados a mao.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$template = [System.IO.File]::ReadAllText((Join-Path $root 'templates\orch.template.md'), [System.Text.Encoding]::UTF8)

# ---------------------------------------------------------------- blocos SQL comuns
$PAR_WEEK = @'
par AS (
  SELECT DATE_TRUNC('WEEK', DATE(CURRENT_TIMESTAMP() - INTERVAL 3 HOURS)) - INTERVAL 7 DAYS AS ini_atual,
         DATE_TRUNC('WEEK', DATE(CURRENT_TIMESTAMP() - INTERVAL 3 HOURS)) AS fim_atual,
         DATE_TRUNC('WEEK', DATE(CURRENT_TIMESTAMP() - INTERVAL 3 HOURS)) - INTERVAL 14 DAYS AS ini_ant,
         DATE_TRUNC('WEEK', DATE(CURRENT_TIMESTAMP() - INTERVAL 3 HOURS)) - INTERVAL 7 DAYS AS fim_ant
)
'@

$PAR_DAY = @'
par AS (
  SELECT CAST(DATE(CURRENT_TIMESTAMP() - INTERVAL 3 HOURS) - INTERVAL 1 DAY AS TIMESTAMP) AS ini_atual,
         CAST(DATE(CURRENT_TIMESTAMP() - INTERVAL 3 HOURS) AS TIMESTAMP) AS fim_atual,
         CAST(DATE(CURRENT_TIMESTAMP() - INTERVAL 3 HOURS) - INTERVAL 8 DAYS AS TIMESTAMP) AS ini_ant,
         CAST(DATE(CURRENT_TIMESTAMP() - INTERVAL 3 HOURS) - INTERVAL 7 DAYS AS TIMESTAMP) AS fim_ant
)
'@

$BASE_CTE = @'
base AS (
  SELECT q.*,
    CASE WHEN (q.received_timestamp - INTERVAL 3 HOURS) >= p.ini_atual AND (q.received_timestamp - INTERVAL 3 HOURS) < p.fim_atual THEN 'atual'
         WHEN (q.received_timestamp - INTERVAL 3 HOURS) >= p.ini_ant   AND (q.received_timestamp - INTERVAL 3 HOURS) < p.fim_ant   THEN 'anterior' END AS periodo,
    CASE WHEN q.quality_label = 'sem_dados' OR q.score_overall IS NULL THEN NULL
         WHEN q.score_overall >= 7 AND q.score_resolution > 2 AND q.score_escalation > 2 THEN true
         ELSE false END AS nota_ok
  FROM prod.cx.fat_botmaker_conversations_quality q CROSS JOIN par p
  WHERE q.flow = '{{FLOW}}'
    AND q.received_timestamp >= p.ini_ant + INTERVAL 3 HOURS
    AND q.received_timestamp <  p.fim_atual + INTERVAL 3 HOURS
  QUALIFY ROW_NUMBER() OVER (PARTITION BY q.request_id ORDER BY q.analyzed_timestamp DESC, q.ingested_at DESC) = 1
)
'@

$COBERTURA_WEEK = @'
SELECT DATE_TRUNC('WEEK', received_timestamp - INTERVAL 3 HOURS) AS semana,
       COUNT(*) AS n,
       COUNT(DISTINCT DATE(received_timestamp - INTERVAL 3 HOURS)) AS dias_com_dado,
       MAX(ingested_at) AS ultima_ingestao
FROM prod.cx.fat_botmaker_conversations_quality
WHERE flow = '{{FLOW}}'
  AND received_timestamp >= DATE_TRUNC('WEEK', DATE(CURRENT_TIMESTAMP() - INTERVAL 3 HOURS)) - INTERVAL 42 DAYS
GROUP BY 1
ORDER BY 1
'@

$COBERTURA_DAY = @'
SELECT DATE(received_timestamp - INTERVAL 3 HOURS) AS dia,
       COUNT(*) AS n,
       MAX(ingested_at) AS ultima_ingestao
FROM prod.cx.fat_botmaker_conversations_quality
WHERE flow = '{{FLOW}}'
  AND received_timestamp >= CURRENT_TIMESTAMP() - INTERVAL 22 DAYS
GROUP BY 1
ORDER BY 1
'@

$COBERTURA_REGRAS_WEEK = @'
- `n_atual` e `dias_com_dado_atual`: linha cuja `semana` = `data_inicio` do Passo 1 (sem linha = `n_atual = 0`).
- `media_previa`: média de `n` das semanas anteriores à atual que tenham linha (até 4).
- `cobertura_baixa = sim` se `dias_com_dado_atual < 5` **ou** `n_atual < 50% de media_previa`.
- `comparacao_indisponivel = sim` se não existir linha para a semana imediatamente anterior (`data_inicio` − 7 dias).
- Semanas sem linha entre a primeira linha retornada e a semana atual = **buracos de dados**: liste-as.
'@

$COBERTURA_REGRAS_DAY = @'
- `n_atual`: linha cujo `dia` = `data_inicio` do Passo 1 (sem linha = `n_atual = 0`).
- `media_previa`: média de `n` dos dias de D-15 a D-2 que tenham linha.
- `cobertura_baixa = sim` se `n_atual < 50% de media_previa`.
- `comparacao_indisponivel = sim` se não existir linha para o dia D-8.
- Dias sem linha nos últimos 14 dias = **buracos de dados**: liste-os.
'@

$PERIODO_WEEK = @'
A rotina executa toda segunda-feira. O período **atual** é a semana anterior completa (segunda a domingo, BRT) e o **anterior** é a semana imediatamente antes dela — ambos já estão definidos em `par` (bloco base). Obtenha as datas por consulta (não calcule de cabeça):

```sql
WITH {{PAR}}
SELECT DATE_FORMAT(ini_atual, 'dd/MM/yyyy') AS data_inicio,
       DATE_FORMAT(fim_atual - INTERVAL 1 DAY, 'dd/MM/yyyy') AS data_fim,
       DATE_FORMAT(ini_ant, 'dd/MM/yyyy') AS ant_inicio,
       DATE_FORMAT(fim_ant - INTERVAL 1 DAY, 'dd/MM/yyyy') AS ant_fim
FROM par
```
'@

$PERIODO_DAY = @'
A rotina executa todos os dias. O período **atual** é D-1 (ontem, BRT) e o **anterior** é o mesmo dia da semana anterior (D-8) — ambos definidos em `par` (bloco base). Obtenha as datas por consulta (não calcule de cabeça):

```sql
WITH {{PAR}}
SELECT DATE_FORMAT(ini_atual, 'dd/MM/yyyy') AS data_inicio,
       DATE_FORMAT(ini_atual, 'dd/MM/yyyy') AS data_fim,
       DATE_FORMAT(ini_ant, 'dd/MM/yyyy') AS ant_inicio
FROM par
```
'@

$ELEGIVEL_STD = "retention_type IN ('transbordo','abandono','loop') OR nota_ok = false"
$ELEGIVEL_STD_B = "b.retention_type IN ('transbordo','abandono','loop') OR b.nota_ok = false"

$HP_COLS_TOTAIS = @'
,
  SUM(CASE WHEN welcome_not_found = false AND pages_fetched > 0 THEN 1 ELSE 0 END) AS n_hp_pleno,
  SUM(CASE WHEN welcome_not_found = true OR pages_fetched = 0 THEN 1 ELSE 0 END) AS n_hp_degradado,
  ROUND(100.0 * SUM(CASE WHEN welcome_not_found = true OR pages_fetched = 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_degradado,
  ROUND(100.0 * SUM(CASE WHEN nota_ok = true AND welcome_not_found = false AND pages_fetched > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN nota_ok IS NOT NULL AND welcome_not_found = false AND pages_fetched > 0 THEN 1 ELSE 0 END), 0), 1) AS bqs_pleno,
  ROUND(100.0 * SUM(CASE WHEN nota_ok = true AND (welcome_not_found = true OR pages_fetched = 0) THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN nota_ok IS NOT NULL AND (welcome_not_found = true OR pages_fetched = 0) THEN 1 ELSE 0 END), 0), 1) AS bqs_degradado
'@

$HP_DIM_EXTRA = @'
,
    ROUND(100.0 * SUM(CASE WHEN nota_ok = true AND welcome_not_found = false AND pages_fetched > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN nota_ok IS NOT NULL AND welcome_not_found = false AND pages_fetched > 0 THEN 1 ELSE 0 END), 0), 1) AS bqs_hp_pleno,
    ROUND(100.0 * SUM(CASE WHEN welcome_not_found = true OR pages_fetched = 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_degradado
'@

function New-DimAgg([string[]]$dims, [string]$extra) {
    $parts = foreach ($d in $dims) {
@"
  SELECT '$d' AS dimensao, COALESCE(NULLIF(TRIM(CAST($d AS STRING)), ''), '(sem valor)') AS valor, COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_volume,
    ROUND(100.0 * SUM(CASE WHEN nota_ok = true THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN nota_ok IS NOT NULL THEN 1 ELSE 0 END), 0), 1) AS bqs,
    ROUND(100.0 * SUM(CASE WHEN retention_type IN ('transbordo','abandono','loop') AND COALESCE(customer_requested_transfer, false) = false THEN 1 ELSE 0 END) / COUNT(*), 1) AS tfc,
    ROUND(100.0 * SUM(CASE WHEN customer_requested_transfer = true THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_pediu_humano$extra
  FROM base WHERE periodo = 'atual' GROUP BY $d
"@
    }
    return ($parts -join "  UNION ALL`n").TrimEnd()
}

# ---------------------------------------------------------------- pacotes de dados (Passo 4)
$PACOTES_COMUM = @'
Todas as consultas começam com `[BASE]`. Formate cada resultado como texto estruturado (uma linha por conversa, campos nomeados), com o `diagnostics` legível (categoria — descrição — ação sugerida).

### Pacote A — Fluxo do bot (destinatário: `chatbot-cx-botmaker`)

```sql
[BASE]
SELECT ticket_id, effective_vertical, topic, botmaker_chatbot_flow, botmaker_stage, retention_type, nota_ok,
       score_understanding, score_efficiency, intent_detected,
       SUBSTR(diagnostics, 1, 1200) AS diagnostics, SUBSTR(summary, 1, 600) AS summary, botmaker_link_chatbot
FROM base
WHERE periodo = 'atual' AND nota_ok IS NOT NULL
  AND (retention_type IN ('loop','transbordo')
       OR diagnostics LIKE '%falha_de_fluxo%' OR diagnostics LIKE '%falha_de_interpretacao%'
       OR diagnostics LIKE '%resposta_generica%' OR diagnostics LIKE '%resposta_incorreta%')
ORDER BY xxhash64(request_id)
LIMIT 120
```

### Pacote B — Base de conhecimento (destinatário: `zendesk-guide-expert`)

B1 — alinhamento por vertical (tabela pré-calculada):

```sql
[BASE]
SELECT COALESCE(effective_vertical, '(sem valor)') AS vertical, COUNT(*) AS n,
       SUM(CASE WHEN kb_alignment = 'alinhado' THEN 1 ELSE 0 END) AS alinhado,
       SUM(CASE WHEN kb_alignment = 'parcialmente_alinhado' THEN 1 ELSE 0 END) AS parcial,
       SUM(CASE WHEN kb_alignment = 'desalinhado' THEN 1 ELSE 0 END) AS desalinhado,
       SUM(CASE WHEN kb_alignment = 'sem_artigo' THEN 1 ELSE 0 END) AS sem_artigo,
       ROUND(100.0 * SUM(CASE WHEN kb_alignment IN ('parcialmente_alinhado','desalinhado','sem_artigo') THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_problema
FROM base WHERE periodo = 'atual'
GROUP BY 1 ORDER BY n DESC
```

B2 — artigos com mais problema (tabela pré-calculada):

```sql
[BASE]
SELECT kb_matched_article_title AS artigo, MAX(kb_matched_article_url) AS url, COUNT(*) AS n,
       SUM(CASE WHEN kb_alignment IN ('parcialmente_alinhado','desalinhado') THEN 1 ELSE 0 END) AS n_problema,
       ROUND(AVG(kb_score), 1) AS kb_score_medio
FROM base
WHERE periodo = 'atual' AND kb_matched_article_title IS NOT NULL AND TRIM(kb_matched_article_title) <> ''
GROUP BY 1
HAVING SUM(CASE WHEN kb_alignment IN ('parcialmente_alinhado','desalinhado') THEN 1 ELSE 0 END) > 0
ORDER BY n_problema DESC LIMIT 15
```

B3 — conversas com problema de KB (exemplos reais, piores primeiro):

```sql
[BASE]
SELECT ticket_id, topic, effective_vertical, kb_alignment, kb_score, kb_matched_article_title, kb_matched_article_url,
       SUBSTR(kb_discrepancies, 1, 500) AS kb_discrepancies, kb_articles_evaluated_count, SUBSTR(summary, 1, 500) AS summary
FROM base
WHERE periodo = 'atual' AND kb_alignment IN ('desalinhado','parcialmente_alinhado','sem_artigo')
ORDER BY kb_score ASC, xxhash64(request_id)
LIMIT 80
```
Atenção: `kb_alignment = 'sem_artigo'` com `kb_matched_article_title` preenchido é possível — trate como "artigo ausente ou inadequado", citando o título retornado.

### Pacote V — versões de prompt do bot no período (para detectar deploys)

```sql
[BASE]
SELECT bot_prompt_version, COUNT(*) AS n FROM base WHERE periodo = 'atual' GROUP BY 1 ORDER BY n DESC
```
'@

$PACOTE_HP = @'

### Pacote C — Hiperpersonalização (destinatário: `chatbot-hp-variaveis`; todas as conversas degradadas + amostra de pleno com sinal de falha)

```sql
[BASE]
SELECT ticket_id, topic, effective_vertical, welcome_not_found, pages_fetched, hp_tag_raw, nota_ok,
       score_understanding, score_efficiency, quality_label, retention_type,
       SUBSTR(diagnostics, 1, 1000) AS diagnostics, SUBSTR(summary, 1, 500) AS summary
FROM base
WHERE periodo = 'atual'
  AND (welcome_not_found = true OR pages_fetched = 0
       OR diagnostics LIKE '%consulta_ausente%' OR diagnostics LIKE '%limitacao_estrutural%' OR diagnostics LIKE '%resposta_generica%')
ORDER BY CASE WHEN welcome_not_found = true OR pages_fetched = 0 THEN 0 ELSE 1 END, xxhash64(request_id)
LIMIT 90
```
'@

$HP_5_3 = @'

### 5.3 — Análise de hiperpersonalização

```
subagent_type: chatbot-hp-variaveis
prompt: |
  MODO CURADORIA ativo.
  Fluxo: Cartão HP | Período: [data_inicio] a [data_fim]

  MÉTRICAS BASE (SQL — não recalcule):
  - Total: [n_total] | Avaliáveis: [n_avaliaveis]
  - HP pleno: [n_hp_pleno] | HP degradado: [n_hp_degradado] ([pct_degradado]% — limite 5%)
  - BQS geral: [bqs]% | BQS pleno: [bqs_pleno]% | BQS degradado: [bqs_degradado]%
  - Critério mais baixo: [nome] (média [m_*])
  - Versões de prompt: [Pacote V]

  TABELAS POR DIMENSÃO (inclui bqs_hp_pleno e pct_degradado):
  [tabela_dimensoes]

  ALERTAS DISPARADOS: [lista]

  DADOS DAS CONVERSAS:
  [PACOTE C formatado como texto estruturado]

  Analise a saúde do contexto HP e retorne o output estruturado conforme a seção MODO CURADORIA do seu sistema
  (5 blocos + snapshot semanal).
```
Guarde como `output_hp`.

'@

$HP_OPO_BLOCO = @'

  === ANÁLISE HP ===
  [output_hp]
'@

$HP_RELATORIO_BLOCO = @'
  - HP pleno: [n_hp_pleno] | HP degradado: [n_hp_degradado] ([pct_degradado]% — limite 5%, alerta de engenharia sempre em destaque)
  - BQS pleno: [bqs_pleno]% | BQS degradado: [bqs_degradado]% | gap de contexto (pp): [use o valor informado por output_hp]
  - Versões de prompt do bot no período: [Pacote V]
'@

$HP_OUTPUT_RELATORIO = @'

  === ANÁLISE HP ===
  [output_hp]
'@

# ---------------------------------------------------------------- definicao de cada fluxo
$CTX_ALEATORIO = @'

**Atenção ao universo deste fluxo:** na série histórica, ~100% das conversas da aba aleatória terminam em transbordo e ~96% foram pedidos explícitos de atendente. Se `pct_transbordo ≥ 90`, o BQS deste fluxo mede a conduta **até o transbordo**, não a qualidade geral do bot — diga isso no relatório e trate o CE (contatos evitáveis) como o número principal. Cubra todas as verticais presentes; não foque só nas piores.
'@

$CTX_HP = @'

**Contexto do fluxo (Cartão de Crédito HP):** todo atendimento de cartão passa pelo fluxo de Hiperpersonalização: o bot atende com o contexto do cliente carregado (status do cartão, limite, fatura, histórico). Há dois agentes especializados no Botmaker — `Agente CC Produção` (bloco `Cartao Recargapay IA`; `effective_vertical = cartao_credito`) e `Agente CC Anuidade` (bloco `Cartao Anuidade IA`; `effective_vertical = cc_anuidade`) — compare sempre os dois nas quebras por dimensão. O eixo diagnóstico central é: **o HP está entregando o que promete — atendimento contextualizado e resolutivo — em todos os temas de cartão, e retendo?**

| Segmento | Como identificar | O que significa |
|---|---|---|
| **HP pleno** | `welcome_not_found = false` E `pages_fetched > 0` | Bot atendeu com contexto carregado. Falha aqui = falha de prompt, conteúdo ou fluxo (dono: Produto CX / Help Design). |
| **HP degradado** | `welcome_not_found = true` OU `pages_fetched = 0` | Bot operou sem contexto. Falha de infraestrutura/integração (dono: Produto CX — Engenharia). Não penalizar o prompt. |

HP degradado > 5% do volume é **alerta próprio**, independente do BQS.
'@

$CTX_CRITICOS = @'

**Casos críticos (CSAT 1 e 2):** são os piores atendimentos do período — trate como **censo**, não como amostra. BQS baixo é esperado; destaque o **padrão de falha mais recorrente** e o que teria evitado a insatisfação. Se o volume do período estiver muito abaixo do usual (Passo 2), trate como cobertura baixa — nunca como "melhora".
'@

$flows = @(
    @{
        NAME = 'orch-aleatorio'; ROTINA = 'Aleatório (cross-vertical)'; CHAVE = 'aleatorio'
        FLOW = 'Conversations n8n_fluxo_generativo_aleatorio'; PERIODICIDADE = 'semanal'; WEEKLY = $true
        DESCRICAO = 'Orquestrador da análise semanal de qualidade do fluxo Aleatório (cross-vertical). Ativado toda segunda-feira às 14:00 BRT pela rotina cloud.'
        CTX = $CTX_ALEATORIO; DIMS = @('effective_vertical','topic'); ELEGIVEL = $ELEGIVEL_STD; ELEGIVEL_B = $ELEGIVEL_STD_B
        HP = $false; ALERTAS_EXTRA = ''
        REGRAS_EXTRA = '- Este fluxo NÃO tem HP — não incluir análise de `welcome_not_found` / `pages_fetched`.'
    },
    @{
        NAME = 'orch-cartao-hp'; ROTINA = 'Cartão de Crédito HP'; CHAVE = 'cartao-hp'
        FLOW = 'Conversations fluxo_hp_botmaker'; PERIODICIDADE = 'semanal'; WEEKLY = $true
        DESCRICAO = 'Orquestrador da análise semanal de qualidade do fluxo Cartão de Crédito HP. Ativado toda segunda-feira às 10:00 BRT pela rotina cloud.'
        CTX = $CTX_HP; DIMS = @('effective_vertical','topic'); ELEGIVEL = $ELEGIVEL_STD; ELEGIVEL_B = $ELEGIVEL_STD_B
        HP = $true; ALERTAS_EXTRA = ' · `pct_degradado > 5` (HP degradado — alerta de engenharia, sempre em destaque) · mais de 40% das conversas classificadas no Passo 6 com causa `contexto_degradado`'
        REGRAS_EXTRA = '- `welcome_not_found` e `pages_fetched` são os únicos sinais de HP degradado — não inferir por outros campos.' + "`n" + '- HP degradado > 5% do volume é alerta de engenharia — incluir sempre em destaque no relatório.'
    },
    @{
        NAME = 'orch-criticos'; ROTINA = 'Casos Críticos (diário)'; CHAVE = 'criticos-diario'
        FLOW = 'Conversations n8n_fluxo_generativo_critico'; PERIODICIDADE = 'diária'; WEEKLY = $false
        DESCRICAO = 'Orquestrador da análise diária de qualidade dos Casos Críticos (CSAT 1 e 2). Ativado todos os dias às 09:40 BRT pela rotina cloud (período: D-1).'
        CTX = $CTX_CRITICOS; DIMS = @('product','effective_vertical','topic'); ELEGIVEL = 'true'; ELEGIVEL_B = 'true'
        HP = $false; ALERTAS_EXTRA = ''
        REGRAS_EXTRA = '- Este fluxo NÃO tem HP — não incluir análise de `welcome_not_found` / `pages_fetched`.' + "`n" + '- São casos críticos (CSAT 1 e 2): BQS baixo é esperado. Foco em padrões e ações imediatas. Dimensões com n < 30 nunca são ranqueadas (volume diário é pequeno) — descreva padrões, não percentuais.'
    },
    @{
        NAME = 'orch-criticos-semanal'; ROTINA = 'Casos Críticos (semanal)'; CHAVE = 'criticos-semanal'
        FLOW = 'Conversations n8n_fluxo_generativo_critico'; PERIODICIDADE = 'semanal'; WEEKLY = $true
        DESCRICAO = 'Orquestrador da análise semanal de qualidade dos Casos Críticos (CSAT 1 e 2). Ativado toda segunda-feira às 15:00 BRT pela rotina cloud.'
        CTX = $CTX_CRITICOS; DIMS = @('product','effective_vertical','topic'); ELEGIVEL = 'true'; ELEGIVEL_B = 'true'
        HP = $false; ALERTAS_EXTRA = ''
        REGRAS_EXTRA = '- Este fluxo NÃO tem HP — não incluir análise de `welcome_not_found` / `pages_fetched`.' + "`n" + '- São casos críticos (CSAT 1 e 2): BQS baixo é esperado. Foco em padrões recorrentes e ações imediatas. A análise semanal permite comparação por produto (`product`) — inclua sempre.'
    }
)

# ---------------------------------------------------------------- geracao
$outDir = Join-Path $root '.claude\agents'
foreach ($f in $flows) {
    $map = [ordered]@{}
    $map['NAME'] = $f.NAME
    $map['DESCRICAO'] = $f.DESCRICAO
    $map['ROTINA'] = $f.ROTINA
    $map['PERIODICIDADE'] = $f.PERIODICIDADE
    $map['CHAVE_ARTEFATO'] = $f.CHAVE
    $map['CONTEXTO_FLUXO'] = $f.CTX
    $map['PERIODO_TEXTO'] = $(if ($f.WEEKLY) { $PERIODO_WEEK } else { $PERIODO_DAY })
    $map['COBERTURA_SQL'] = $(if ($f.WEEKLY) { $COBERTURA_WEEK } else { $COBERTURA_DAY }).TrimEnd()
    $map['COBERTURA_REGRAS'] = $(if ($f.WEEKLY) { $COBERTURA_REGRAS_WEEK } else { $COBERTURA_REGRAS_DAY }).TrimEnd()
    $map['ELEGIVEL_B'] = $f.ELEGIVEL_B
    $map['ELEGIVEL'] = $f.ELEGIVEL
    $map['HP_COLS_TOTAIS'] = $(if ($f.HP) { $HP_COLS_TOTAIS.TrimEnd() } else { '' })
    $map['DIM_AGG'] = New-DimAgg $f.DIMS $(if ($f.HP) { $HP_DIM_EXTRA.TrimEnd() } else { '' })
    $map['ALERTAS_EXTRA'] = $f.ALERTAS_EXTRA
    $map['PACOTES_TEXTO'] = ($PACOTES_COMUM.TrimEnd() + $(if ($f.HP) { "`n" + $PACOTE_HP.TrimEnd() } else { '' }))
    $map['HP_REF_5'] = $(if ($f.HP) { ', 5.3' } else { '' })
    $map['HP_5_3'] = $(if ($f.HP) { $HP_5_3 } else { "`n" })
    $map['HP_OPO_BLOCO'] = $(if ($f.HP) { $HP_OPO_BLOCO } else { '' })
    $map['HP_RELATORIO_BLOCO'] = $(if ($f.HP) { $HP_RELATORIO_BLOCO } else { '' })
    $map['HP_OUTPUT_RELATORIO'] = $(if ($f.HP) { $HP_OUTPUT_RELATORIO } else { '' })
    $map['REGRAS_EXTRA'] = $f.REGRAS_EXTRA
    $map['PAR'] = $(if ($f.WEEKLY) { $PAR_WEEK } else { $PAR_DAY }).TrimEnd()
    $map['BASE_CTE'] = $BASE_CTE.TrimEnd()
    $map['FLOW'] = $f.FLOW

    $text = $template
    for ($i = 0; $i -lt 6; $i++) {
        foreach ($k in $map.Keys) { $text = $text.Replace('{{' + $k + '}}', [string]$map[$k]) }
        if ($text -notmatch '\{\{[A-Z_0-9]+\}\}') { break }
    }
    if ($text -match '\{\{[A-Z_0-9]+\}\}') { throw "Placeholder sem valor em $($f.NAME): $($Matches[0])" }
    $text = $text -replace "`r`n", "`n"
    $path = Join-Path $outDir ($f.NAME + '.md')
    [System.IO.File]::WriteAllText($path, $text, $utf8)
    Write-Host ("gerado {0} ({1} linhas)" -f $f.NAME, ($text -split "`n").Count)
}
