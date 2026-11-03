-- Abandono ATIVO do bot: por semana (seg-dom) e por entry_theme + total do periodo.
-- Fonte: prod.cx.fat_botmaker_metrics (flg_active_abandonment=1). Abandono passivo fica FORA.
-- Coortes completas: so semanas cujo domingo <= hoje-8 dias; 8 ultimas semanas.
-- Recontato 7d = nova sessao do mesmo user_id em ate 7 dias apos creation_ts (qualquer tema); "mesmo tema" = mesmo entry_theme.
-- Nota media = prod.cx.fat_botmaker_conversations_quality (amostra ~13%), join metrics.chat_id = quality.botmaker_chat_id.
-- Linhas: semana x tema | semana x 'TOTAL' | 'PERIODO' x tema | 'PERIODO' x 'TOTAL'.
WITH lim AS (
  SELECT date_trunc('week', date_sub(date_sub(current_date(), 8), 6)) AS ult_seg
),
per AS (SELECT date_sub(ult_seg, 49) AS ini, date_add(ult_seg, 6) AS fim FROM lim),
sess AS (  -- todas as sessoes (denominador e recontato)
  SELECT user_id, session_id, creation_ts, creation_date, entry_theme
  FROM prod.cx.fat_botmaker_metrics, per
  WHERE creation_date BETWEEN per.ini AND date_add(per.fim, 8)
),
aband AS (
  SELECT m.session_id, m.user_id, m.creation_ts, m.entry_theme, date_trunc('week', m.creation_date) AS semana, m.chat_id
  FROM prod.cx.fat_botmaker_metrics m, per
  WHERE m.creation_date BETWEEN per.ini AND per.fim AND m.flg_active_abandonment = 1
),
rec AS (
  SELECT a.session_id, a.user_id, a.semana, a.entry_theme, a.chat_id,
         MAX(CASE WHEN s.session_id IS NOT NULL THEN 1 ELSE 0 END) AS voltou,
         MAX(CASE WHEN s.entry_theme = a.entry_theme THEN 1 ELSE 0 END) AS voltou_mesmo_tema
  FROM aband a
  LEFT JOIN sess s ON s.user_id = a.user_id AND s.session_id <> a.session_id
       AND s.creation_ts > a.creation_ts AND s.creation_ts <= a.creation_ts + INTERVAL 7 DAYS
  GROUP BY a.session_id, a.user_id, a.semana, a.entry_theme, a.chat_id
),
q AS (SELECT botmaker_chat_id, AVG(score_overall) AS nota FROM prod.cx.fat_botmaker_conversations_quality GROUP BY botmaker_chat_id),
tot AS (  -- sessoes totais por semana e por semana x tema
  SELECT date_trunc('week', creation_date) AS semana, entry_theme, COUNT(*) AS sessoes
  FROM sess, per WHERE creation_date BETWEEN per.ini AND per.fim GROUP BY 1, 2
),
base AS (
  SELECT r.*, q.nota FROM rec r LEFT JOIN q ON q.botmaker_chat_id = r.chat_id
),
ag AS (
  SELECT COALESCE(CAST(semana AS STRING), 'PERIODO') AS semana, COALESCE(entry_theme, 'TOTAL') AS entry_theme,
         COUNT(*) AS abandonos, COUNT(DISTINCT user_id) AS usuarios,
         SUM(voltou) AS recontato_7d, SUM(voltou_mesmo_tema) AS recontato_mesmo_tema_7d,
         ROUND(AVG(nota), 2) AS nota_media_amostra, COUNT(nota) AS n_amostra
  FROM base
  GROUP BY GROUPING SETS ((semana, entry_theme), (semana), (entry_theme), ())
),
den AS (
  SELECT COALESCE(CAST(semana AS STRING), 'PERIODO') AS semana, COALESCE(entry_theme, 'TOTAL') AS entry_theme, SUM(sessoes) AS sessoes
  FROM tot GROUP BY GROUPING SETS ((semana, entry_theme), (semana), (entry_theme), ())
),
den_sem AS (SELECT semana, sessoes AS sessoes_total_semana FROM den WHERE entry_theme = 'TOTAL')
SELECT ag.semana, ag.entry_theme, ag.abandonos, ag.usuarios,
       ROUND(100.0 * ag.abandonos / ds.sessoes_total_semana, 2) AS pct_sobre_sessoes_totais,
       ROUND(100.0 * ag.abandonos / d.sessoes, 2) AS pct_abandono_no_tema,
       ag.recontato_7d, ROUND(100.0 * ag.recontato_7d / ag.abandonos, 1) AS pct_recontato_7d,
       ag.recontato_mesmo_tema_7d, ROUND(100.0 * ag.recontato_mesmo_tema_7d / ag.abandonos, 1) AS pct_mesmo_tema_7d,
       ag.nota_media_amostra, ag.n_amostra
FROM ag JOIN den d ON d.semana = ag.semana AND d.entry_theme = ag.entry_theme
        JOIN den_sem ds ON ds.semana = ag.semana
WHERE ag.entry_theme = 'TOTAL' OR ag.abandonos >= 100 OR ag.semana = 'PERIODO'
ORDER BY ag.semana DESC, ag.abandonos DESC

-- ============================================================================
-- CONSULTA 2 - SEMANA PARCIAL (rodar separada). NAO entra em history.json nem em tendencia/ranking.
-- Semana mais recente seg-dom com domingo <= hoje-1: volume completo, recontato 7d ainda em aberto.
-- Devolve 1 linha: volume, usuarios, % das sessoes, recontato/mesmo tema OBSERVADOS ate agora (parcial)
-- e o recontato so nos abandonos com janela de 7d ja fechada (creation_ts <= now-7d) + n_janela_completa.
-- Gravar em latest.json > semana_parcial; fecha_em = fim + 7 dias.
-- ============================================================================
WITH lim AS (SELECT date_trunc('week', date_sub(date_sub(current_date(), 1), 6)) AS ini),
per AS (SELECT ini, date_add(ini, 6) AS fim FROM lim),
sess AS (
  SELECT user_id, session_id, creation_ts, creation_date, entry_theme
  FROM prod.cx.fat_botmaker_metrics, per
  WHERE creation_date BETWEEN per.ini AND current_date()
),
aband AS (
  SELECT s.* FROM sess s JOIN prod.cx.fat_botmaker_metrics m ON m.session_id = s.session_id
  CROSS JOIN per WHERE s.creation_date BETWEEN per.ini AND per.fim AND m.flg_active_abandonment = 1
),
rec AS (
  SELECT a.session_id, a.user_id, a.creation_ts,
         MAX(CASE WHEN s.session_id IS NOT NULL THEN 1 ELSE 0 END) AS voltou,
         MAX(CASE WHEN s.entry_theme = a.entry_theme THEN 1 ELSE 0 END) AS voltou_mesmo_tema
  FROM aband a
  LEFT JOIN sess s ON s.user_id = a.user_id AND s.session_id <> a.session_id
       AND s.creation_ts > a.creation_ts AND s.creation_ts <= a.creation_ts + INTERVAL 7 DAYS
  GROUP BY a.session_id, a.user_id, a.creation_ts
),
tot AS (SELECT COUNT(*) AS sessoes FROM sess, per WHERE creation_date BETWEEN per.ini AND per.fim)
SELECT CAST(per.ini AS STRING) AS inicio, CAST(per.fim AS STRING) AS fim,
       COUNT(*) AS abandonos, COUNT(DISTINCT r.user_id) AS usuarios,
       ROUND(100.0 * COUNT(*) / MAX(tot.sessoes), 2) AS pct_sessoes,
       SUM(r.voltou) AS recontato_7d_parcial,
       ROUND(100.0 * SUM(r.voltou) / COUNT(*), 1) AS pct_recontato_7d_parcial,
       ROUND(100.0 * SUM(r.voltou_mesmo_tema) / COUNT(*), 1) AS pct_mesmo_tema_parcial,
       SUM(CASE WHEN r.creation_ts <= current_timestamp() - INTERVAL 7 DAYS THEN 1 ELSE 0 END) AS n_janela_completa,
       ROUND(100.0 * SUM(CASE WHEN r.creation_ts <= current_timestamp() - INTERVAL 7 DAYS THEN r.voltou ELSE 0 END)
             / NULLIF(SUM(CASE WHEN r.creation_ts <= current_timestamp() - INTERVAL 7 DAYS THEN 1 ELSE 0 END), 0), 1) AS pct_recontato_janela_completa
FROM rec r CROSS JOIN per CROSS JOIN tot GROUP BY per.ini, per.fim;
