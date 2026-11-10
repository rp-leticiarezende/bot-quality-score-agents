-- Abandono ATIVO do bot (regra nova, 10/11/2026): recontato em 72 HORAS, instabilidade separada.
-- Fonte: prod.cx.fat_botmaker_metrics (flg_active_abandonment=1). Abandono passivo fica FORA.
-- Abandono ativo: a sessao fecha como abandono apos 8h sem resposta do usuario; cada sessao abandonada conta (nao ha abandono duplo na sessao). Mostrar tambem usuarios distintos.
-- ANCORA: fim da sessao = creation_ts + resolution_seconds. Verificado: nas sessoes de abandono ativo resolution_seconds tem mediana ~8,03h (p10 8,01h; p90 8,24h; p99 12,6h; sem nulos),
--   ou seja, INCLUI as ~8h de inatividade que fecham a sessao. Serve como "fim da sessao" (a nova sessao so abre depois do fechamento); o prazo de 72h vale a partir do fechamento, ~8h depois da ultima mensagem.
-- RECONTATO 72h = o mesmo user_id abre NOVA sessao do bot (novo contato em N1) com creation_ts > creation_ts do abandono e <= fim da sessao + 72h.
-- 3 FATIAS (somam 100%): voltou no MESMO stage (stage nao nulo igual) / voltou em OUTRO stage / NAO voltou. "Mesmo" tem prioridade se houve os dois.
-- INSTABILIDADE (stage com 'instabilidade'): (a) sessao que volta de instabilidade NAO conta como recontato no geral (se so voltou assim, o abandono entra como "nao voltou" e e contado em retorno_so_instab);
--   (b) abandonos com stage de origem de instabilidade SAEM da base GERAL; (c) viram o grupo INSTAB, com todas as sessoes que voltam contando (voltou_em_instab = voltou tambem em stage de instabilidade).
-- Coortes completas: so abandonos com fim + 72h <= agora. Semanas completas (history/tendencia): domingo <= hoje-4 dias; 8 ultimas. Semana parcial: so em latest.json (consulta 2).
-- stage nulo vira "(sem stage)": nunca e "mesmo stage"; seus recontatos caem em "outro".
-- Nota media = prod.cx.fat_botmaker_conversations_quality (amostra ~13%), join metrics.chat_id = quality.botmaker_chat_id.
-- CONSULTA 1 devolve linhas (bloco, json); cada json e colado no campo correspondente de latest.json / history.json:
--   geral_periodo -> periodo_total | geral_semana_atual -> semana_atual | geral_historico -> history.json | geral_stages -> stages | geral_stages_semanal -> stages_semanal
--   inst_periodo/inst_semana_atual/inst_historico/inst_stages/inst_stages_semanal -> instabilidade{periodo_total, semana_atual, historico, stages, stages_semanal}
WITH lim AS (
  SELECT date_trunc('week', date_sub(date_sub(current_date(), 4), 6)) AS ult_seg
),
per AS (SELECT date_sub(ult_seg, 49) AS ini, date_add(ult_seg, 6) AS fim FROM lim),
sess AS (  -- todas as sessoes (denominador e recontato)
  SELECT user_id, session_id, creation_ts, creation_date, stage,
         CASE WHEN lower(stage) LIKE '%instabilidade%' THEN 1 ELSE 0 END AS is_inst
  FROM prod.cx.fat_botmaker_metrics, per
  WHERE creation_date BETWEEN per.ini AND date_add(per.fim, 9)
),
aband AS (
  SELECT m.session_id, m.user_id, m.creation_ts, m.stage, m.chat_id, date_trunc('week', m.creation_date) AS semana,
         m.creation_ts + m.resolution_seconds * INTERVAL 1 SECOND AS end_ts,
         CASE WHEN lower(m.stage) LIKE '%instabilidade%' THEN 1 ELSE 0 END AS is_inst
  FROM prod.cx.fat_botmaker_metrics m, per
  WHERE m.creation_date BETWEEN per.ini AND per.fim AND m.flg_active_abandonment = 1
    AND m.creation_ts + m.resolution_seconds * INTERVAL 1 SECOND + INTERVAL 7 DAYS <= current_timestamp()
),
rec AS (
  SELECT a.session_id, a.user_id, a.semana, a.stage, a.chat_id, a.is_inst,
    MAX(CASE WHEN s.session_id IS NOT NULL AND s.creation_ts <= a.end_ts + INTERVAL 72 HOURS AND (a.is_inst = 1 OR s.is_inst = 0) THEN 1 ELSE 0 END) AS voltou,
    MAX(CASE WHEN s.session_id IS NOT NULL AND s.creation_ts <= a.end_ts + INTERVAL 72 HOURS THEN 1 ELSE 0 END) AS voltou_qualquer,
    MAX(CASE WHEN a.stage IS NOT NULL AND s.stage = a.stage AND s.creation_ts <= a.end_ts + INTERVAL 72 HOURS THEN 1 ELSE 0 END) AS mesmo,
    MAX(CASE WHEN s.is_inst = 1 AND s.creation_ts <= a.end_ts + INTERVAL 72 HOURS THEN 1 ELSE 0 END) AS volta_inst,
    MAX(CASE WHEN s.session_id IS NOT NULL AND s.creation_ts <= a.end_ts + INTERVAL 24 HOURS AND (a.is_inst = 1 OR s.is_inst = 0) THEN 1 ELSE 0 END) AS v24,
    MAX(CASE WHEN s.session_id IS NOT NULL AND s.creation_ts <= a.end_ts + INTERVAL 48 HOURS AND (a.is_inst = 1 OR s.is_inst = 0) THEN 1 ELSE 0 END) AS v48,
    MAX(CASE WHEN s.session_id IS NOT NULL AND (a.is_inst = 1 OR s.is_inst = 0) THEN 1 ELSE 0 END) AS v7d,
    MAX(CASE WHEN s.session_id IS NOT NULL AND s.creation_ts <= a.end_ts AND s.creation_ts <= a.end_ts + INTERVAL 72 HOURS AND (a.is_inst = 1 OR s.is_inst = 0) THEN 1 ELSE 0 END) AS antes_do_fim
  FROM aband a
  LEFT JOIN sess s ON s.user_id = a.user_id AND s.session_id <> a.session_id
       AND s.creation_ts > a.creation_ts AND s.creation_ts <= a.end_ts + INTERVAL 7 DAYS
  GROUP BY a.session_id, a.user_id, a.semana, a.stage, a.chat_id, a.is_inst
),
q AS (SELECT botmaker_chat_id, AVG(score_overall) AS nota FROM prod.cx.fat_botmaker_conversations_quality GROUP BY botmaker_chat_id),
base AS (
  SELECT r.*, CASE WHEN r.is_inst = 1 THEN 'inst' ELSE 'geral' END AS grp, COALESCE(r.stage, '(sem stage)') AS stage_l, q.nota
  FROM rec r LEFT JOIN q ON q.botmaker_chat_id = r.chat_id
),
ag AS (
  SELECT grp, COALESCE(CAST(semana AS STRING), 'PERIODO') AS semana, COALESCE(stage_l, 'TOTAL') AS stage,
         COUNT(*) AS ab, COUNT(DISTINCT user_id) AS us,
         SUM(voltou) AS rec, SUM(CASE WHEN mesmo = 1 THEN 1 ELSE 0 END) AS mesmo, SUM(CASE WHEN voltou = 1 AND mesmo = 0 THEN 1 ELSE 0 END) AS outro,
         SUM(voltou_qualquer - voltou) AS so_inst, SUM(volta_inst) AS volta_inst, SUM(v24) AS v24, SUM(v48) AS v48, SUM(v7d) AS v7d, SUM(antes_do_fim) AS antes_do_fim,
         ROUND(AVG(nota), 2) AS nota, COUNT(nota) AS n_nota
  FROM base
  GROUP BY GROUPING SETS ((grp, semana, stage_l), (grp, semana), (grp, stage_l), (grp))
),
tot AS (
  SELECT CASE WHEN is_inst = 1 THEN 'inst' ELSE 'geral' END AS grp, date_trunc('week', creation_date) AS semana, COALESCE(stage, '(sem stage)') AS stage, COUNT(*) AS sessoes
  FROM sess, per WHERE creation_date BETWEEN per.ini AND per.fim GROUP BY 1, 2, 3
),
den AS (
  SELECT grp, COALESCE(CAST(semana AS STRING), 'PERIODO') AS semana, COALESCE(stage, 'TOTAL') AS stage, SUM(sessoes) AS sessoes
  FROM tot GROUP BY GROUPING SETS ((grp, semana, stage), (grp, semana), (grp, stage), (grp))
),
j AS (
  SELECT ag.*, d.sessoes AS sess_stage, ds.sessoes AS sess_sem
  FROM ag JOIN den d ON d.grp = ag.grp AND d.semana = ag.semana AND d.stage = ag.stage
          JOIN den ds ON ds.grp = ag.grp AND ds.semana = ag.semana AND ds.stage = 'TOTAL'
),
f AS (  -- campos finais (nomes do JSON)
  SELECT grp, semana, stage, ab, us, rec, mesmo, outro,
    ROUND(100.0 * ab / sess_sem, 2) AS pct_sessoes, ROUND(100.0 * ab / sess_stage, 2) AS pct_abandono_no_stage,
    ROUND(100.0 * rec / ab, 1) AS pct_rec, ROUND(100.0 * mesmo / ab, 1) AS pct_mesmo, ROUND(100.0 * outro / ab, 1) AS pct_outro, ROUND(100.0 * (ab - rec) / ab, 1) AS pct_nao,
    so_inst, volta_inst, ROUND(100.0 * v24 / ab, 1) AS pct_24h, ROUND(100.0 * v48 / ab, 1) AS pct_48h, ROUND(100.0 * v7d / ab, 1) AS pct_7d, antes_do_fim,
    nota, n_nota, sess_sem
  FROM j
)
SELECT concat(grp, '_periodo') AS bloco, to_json(struct(ab AS abandonos, us AS usuarios, pct_sessoes, rec AS recontato_72h, pct_rec AS pct_recontato_72h,
  mesmo AS recontato_mesmo_stage_72h, pct_mesmo AS pct_mesmo_stage_72h, outro AS recontato_outro_stage_72h, pct_outro AS pct_outro_stage_72h,
  (ab - rec) AS nao_voltou_72h, pct_nao AS nunca_voltam_pct, pct_24h AS pct_recontato_24h, pct_48h AS pct_recontato_48h, pct_7d AS pct_recontato_7d,
  so_inst AS retorno_so_instab, volta_inst AS voltou_em_instab, antes_do_fim AS voltou_antes_do_fim_da_sessao, nota AS nota_amostra, n_nota AS n_amostra, sess_sem AS sessoes_total)) AS json
FROM f WHERE semana = 'PERIODO' AND stage = 'TOTAL'
UNION ALL
SELECT concat(grp, '_semana_atual'), to_json(struct(CAST(CAST(semana AS DATE) AS STRING) AS inicio, CAST(date_add(CAST(semana AS DATE), 6) AS STRING) AS fim, ab AS abandonos, us AS usuarios, pct_sessoes,
  rec AS recontato_72h, pct_rec AS pct_recontato_72h, mesmo AS recontato_mesmo_stage_72h, pct_mesmo AS pct_mesmo_stage_72h, outro AS recontato_outro_stage_72h, pct_outro AS pct_outro_stage_72h,
  (ab - rec) AS nao_voltou_72h, pct_nao AS nunca_voltam_pct, so_inst AS retorno_so_instab, nota AS nota_amostra, n_nota AS n_amostra))
FROM f WHERE stage = 'TOTAL' AND semana = (SELECT MAX(semana) FROM f WHERE semana <> 'PERIODO')
UNION ALL
SELECT concat(grp, '_historico'), concat('[', concat_ws(',', transform(sort_array(collect_list(struct(semana, to_json(struct(CAST(CAST(semana AS DATE) AS STRING) AS inicio, CAST(date_add(CAST(semana AS DATE), 6) AS STRING) AS fim,
  ab AS abandonos, us AS usuarios, pct_sessoes, rec AS recontato_72h, pct_rec AS pct_recontato_72h, pct_mesmo AS pct_mesmo_stage_72h, pct_outro AS pct_outro_stage_72h, pct_nao AS nunca_voltam_pct)) AS j))), x -> x.j)), ']')
FROM f WHERE stage = 'TOTAL' AND semana <> 'PERIODO' GROUP BY grp
UNION ALL
SELECT concat(grp, '_stages'), concat('[', concat_ws(',', collect_list(to_json(struct(stage, ab AS abandonos, us AS usuarios, pct_abandono_no_stage, rec AS recontato_72h, pct_rec AS pct_recontato_72h,
  mesmo AS recontato_mesmo_stage_72h, pct_mesmo AS pct_mesmo_stage_72h, outro AS recontato_outro_stage_72h, pct_outro AS pct_outro_stage_72h, (ab - rec) AS nao_voltou_72h, pct_nao AS pct_nao_voltou_72h,
  nota AS nota_amostra, n_nota AS n_amostra)))), ']')
FROM f WHERE semana = 'PERIODO' AND stage <> 'TOTAL' AND ab >= 100 GROUP BY grp
UNION ALL
SELECT concat(grp, '_stages_semanal'), concat('{', concat_ws(',', collect_list(concat('"', replace(stage, '"', ''), '":', a))), '}')
FROM (SELECT grp, stage, concat('[', concat_ws(',', transform(sort_array(collect_list(struct(semana, concat('["', CAST(date_add(CAST(semana AS DATE), 6) AS STRING), '",', ab, ',', rec, ',', mesmo, ']') AS t))), x -> x.t)), ']') AS a
      FROM f WHERE semana <> 'PERIODO' AND stage <> 'TOTAL'
        AND stage IN (SELECT stage FROM f f2 WHERE f2.semana = 'PERIODO' AND f2.stage <> 'TOTAL' AND f2.ab >= 100 AND f2.grp = f.grp)
      GROUP BY grp, stage) GROUP BY grp;
-- Formato de stages_semanal: {"<stage>": [["AAAA-MM-DD(fim da semana)", abandonos, recontato_72h, recontato_mesmo_stage_72h], ...]}  (outro = recontato - mesmo; nao voltou = abandonos - recontato)

-- ============================================================================
-- CONSULTA 2 - SEMANA PARCIAL (rodar separada; devolve 1 linha json -> latest.json > semana_parcial). NAO entra em history.json nem em tendencia/ranking.
-- Semana seg-dom mais recente com domingo <= hoje-1: volume completo, recontato 72h ainda em aberto para os abandonos mais novos.
-- Base GERAL (sem instabilidade na origem, retorno de instabilidade nao conta). n_janela_completa = abandonos com fim da sessao + 72h ja passado.
-- ============================================================================
WITH per AS (SELECT date_trunc('week', date_sub(date_sub(current_date(), 1), 6)) AS ini),
p AS (SELECT ini, date_add(ini, 6) AS fim FROM per),
sess AS (
  SELECT user_id, session_id, creation_ts, creation_date, stage, CASE WHEN lower(stage) LIKE '%instabilidade%' THEN 1 ELSE 0 END AS is_inst
  FROM prod.cx.fat_botmaker_metrics, p WHERE creation_date BETWEEN p.ini AND current_date()
),
aband AS (
  SELECT m.session_id, m.user_id, m.creation_ts, m.stage, m.creation_ts + m.resolution_seconds * INTERVAL 1 SECOND AS end_ts,
         CASE WHEN lower(m.stage) LIKE '%instabilidade%' THEN 1 ELSE 0 END AS is_inst
  FROM prod.cx.fat_botmaker_metrics m, p WHERE m.creation_date BETWEEN p.ini AND p.fim AND m.flg_active_abandonment = 1
),
rec AS (
  SELECT a.session_id, a.user_id, a.is_inst, a.end_ts,
    MAX(CASE WHEN s.session_id IS NOT NULL AND s.is_inst = 0 THEN 1 ELSE 0 END) AS voltou,
    MAX(CASE WHEN a.stage IS NOT NULL AND s.stage = a.stage THEN 1 ELSE 0 END) AS mesmo
  FROM aband a
  LEFT JOIN sess s ON s.user_id = a.user_id AND s.session_id <> a.session_id AND s.creation_ts > a.creation_ts AND s.creation_ts <= a.end_ts + INTERVAL 72 HOURS
  WHERE a.is_inst = 0
  GROUP BY a.session_id, a.user_id, a.is_inst, a.end_ts
),
tot AS (SELECT COUNT(*) AS sessoes FROM sess, p WHERE is_inst = 0 AND creation_date BETWEEN p.ini AND p.fim),
ins AS (SELECT COUNT(*) AS ab_inst FROM aband WHERE is_inst = 1)
SELECT to_json(struct(CAST(p.ini AS STRING) AS inicio, CAST(p.fim AS STRING) AS fim, COUNT(*) AS abandonos, COUNT(DISTINCT r.user_id) AS usuarios,
  ROUND(100.0 * COUNT(*) / MAX(tot.sessoes), 2) AS pct_sessoes,
  SUM(r.voltou) AS recontato_72h_parcial, ROUND(100.0 * SUM(r.voltou) / COUNT(*), 1) AS pct_recontato_72h_parcial,
  ROUND(100.0 * SUM(r.mesmo) / COUNT(*), 1) AS pct_mesmo_stage_parcial,
  SUM(CASE WHEN r.end_ts + INTERVAL 72 HOURS <= current_timestamp() THEN 1 ELSE 0 END) AS n_janela_completa,
  ROUND(100.0 * SUM(CASE WHEN r.end_ts + INTERVAL 72 HOURS <= current_timestamp() THEN r.voltou ELSE 0 END) / NULLIF(SUM(CASE WHEN r.end_ts + INTERVAL 72 HOURS <= current_timestamp() THEN 1 ELSE 0 END), 0), 1) AS pct_recontato_janela_completa,
  CAST(CAST(MAX(r.end_ts) + INTERVAL 72 HOURS AS DATE) AS STRING) AS fecha_em, MAX(ins.ab_inst) AS abandonos_instab, true AS parcial)) AS json
FROM rec r CROSS JOIN p CROSS JOIN tot CROSS JOIN ins GROUP BY p.ini, p.fim;

-- ============================================================================
-- CONSULTA 3 - DIARIO (alimenta latest.json > diario, filtro de periodo/dia da tendencia). Base GERAL, 120 dias, so abandonos com fim da sessao + 72h ja passado.
-- 1 linha com o array [[ "AAAA-MM-DD", abandonos, recontato_72h, recontato_mesmo_stage_72h ], ...]. A soma dos dias de uma semana seg-dom bate com history.json.
-- ============================================================================
WITH per AS (SELECT date_sub(current_date(), 127) AS ini, date_sub(current_date(), 4) AS fim),
sess AS (
  SELECT user_id, session_id, creation_ts, stage, CASE WHEN lower(stage) LIKE '%instabilidade%' THEN 1 ELSE 0 END AS is_inst
  FROM prod.cx.fat_botmaker_metrics, per WHERE creation_date BETWEEN per.ini AND date_add(per.fim, 5)
),
aband AS (
  SELECT m.session_id, m.user_id, m.creation_ts, m.stage, m.creation_date AS dia, m.creation_ts + m.resolution_seconds * INTERVAL 1 SECOND AS end_ts
  FROM prod.cx.fat_botmaker_metrics m, per
  WHERE m.creation_date BETWEEN per.ini AND per.fim AND m.flg_active_abandonment = 1 AND lower(COALESCE(m.stage, '')) NOT LIKE '%instabilidade%'
    AND m.creation_ts + m.resolution_seconds * INTERVAL 1 SECOND + INTERVAL 72 HOURS <= current_timestamp()
),
rec AS (
  SELECT a.session_id, a.dia,
    MAX(CASE WHEN s.session_id IS NOT NULL AND s.is_inst = 0 THEN 1 ELSE 0 END) AS voltou,
    MAX(CASE WHEN a.stage IS NOT NULL AND s.stage = a.stage THEN 1 ELSE 0 END) AS mesmo
  FROM aband a
  LEFT JOIN sess s ON s.user_id = a.user_id AND s.session_id <> a.session_id AND s.creation_ts > a.creation_ts AND s.creation_ts <= a.end_ts + INTERVAL 72 HOURS
  GROUP BY a.session_id, a.dia
),
d AS (SELECT dia, COUNT(*) AS ab, SUM(voltou) AS r72, SUM(mesmo) AS ms FROM rec GROUP BY dia)
SELECT COUNT(*) AS dias, MIN(dia) AS primeiro, MAX(dia) AS ultimo,
       concat('[', concat_ws(',', collect_list(concat('["', CAST(dia AS STRING), '",', ab, ',', r72, ',', ms, ']'))), ']') AS diario
FROM (SELECT * FROM d ORDER BY dia);
