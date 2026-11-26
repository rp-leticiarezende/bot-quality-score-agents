### Contrato de dados do painel (`bqs-run/1`)

O painel (`artifact/painel.html`) é uma página fixa que lê arquivos JSON publicados ao lado dela. Cada rotina publica **dois arquivos próprios** e nunca mexe nos das outras:
- `data/<chave>/latest.json` — a rodada atual completa;
- `data/<chave>/history.json` — a série da linha do tempo (array, até 104 itens ≈ 2 anos de semanas).
Chaves das rotinas: `cartao-hp` (Agente de Cartão de Crédito, semanal), `aleatorio`, `criticos-semanal`. Chaves das visões mensais: `cartao-hp-mensal` (alimentada por `cartao-hp`), `aleatorio-mensal` (por `aleatorio`) e `criticos-mensal` (por `criticos-semanal`); `periodo.tipo = "mensal"`.
**Regra de ouro do histórico: ele só cresce.** Nunca recrie `history.json` do zero: leia o arquivo publicado, acrescente (ou, se já existir um item com o mesmo `fim`, atualize só esse item) e publique o conjunto completo. Se a leitura falhar, tente de novo uma vez; se falhar de novo, **não publique** `history.json` (deixe-o fora de `files`, o publicado se mantém) e avise no resultado da rotina.
**Painel principal x mensal:** `latest.json` de cada rotina **substitui** o anterior e mostra o resultado mais recente (semana, dia). A visão **mensal acumula**: `data/<chave>-mensal/latest.json` e o seu `history.json` (um ponto por mês, atualizado a cada rodada, com os `bqs3_*` do mês somados como abaixo) consolidam **todas as rodadas do mês até agora** a partir dos pontos do `history.json` da rotina (a rodada pertence ao mês do seu `fim`): `n_total` e `n_avaliaveis` = soma; `bqs` = média de `bqs` ponderada por `n_avaliaveis`; `tfc` e `pct_recontato_24h` = médias ponderadas por `n_total`; `calibracao.n_amostra` e `n_revertidos` = soma, e `taxa_falso_aprovado` = revertidos ÷ amostra (calibrado se a amostra somada for 5 ou mais); `sinalizados` = soma; **`bqs3` do mês = SOMA das contagens `bqs3_otimo`, `bqs3_bom`, `bqs3_regular`, `bqs3_ruim` e `bqs3_n` das semanas fechadas do mês** (cada semana já calibrada por si; os pontos do `history.json` com `bqs3_*`), com `pct_otimo_bom` calculado da soma ((otimo + bom) ÷ n × 100, 1 casa) e `provisorio = true` se alguma semana somada for provisória (`motivo_provisorio` diz quantas semanas); semanas sem `bqs3_*` (antes de 26/10/2026) ficam fora da soma de `bqs3`, e se nenhuma semana do mês tiver `bqs3`, omita o objeto. `periodo`: `inicio` = dia 1 do mês, `fim` = `fim` da última rodada; `cobertura.texto` diz quantas rodadas e dias com dado entraram. A visão mensal não traz oportunidades nem tabelas por tema (essas ficam nas rodadas e no Backlog). Em `sem_artigo_porta`, o mensal soma `n` (do `n_sem_porta` dos itens do histórico), recalcula `pct` sobre `n_total` e junta os `itens` dos `latest.json` do mês (os mais recentes, até 30, sem repetir `ticket_id`).
O arquivo `data/eventos.json` (marcos manuais, como o hiato do BQS) é **global e mantido por humanos**: nenhuma rotina escreve nele.

**Regras do JSON:** válido (aspas duplas, sem comentários, sem vírgula final); números como número (nunca `"72,2%"`); `null` quando o dado não existir; textos em português; **nenhum dado pessoal** (nome, e-mail, telefone, CPF, cartão) e **nenhuma transcrição** — conversas só por `ticket_id`; percentuais com 1 casa decimal; todos os números vêm do prompt do orquestrador (SQL), nunca calculados por você, exceto `ic95`, `pct_total` e `estimado` das oportunidades, que você calcula como descrito abaixo. Existe **um único BQS, o BQS 3.0** (% de Ótimo + Bom: conduta boa e desfecho aceitável, já com a nota revisada pelo auditor e calibrado; igual ao antigo BQS 2.0, agora com a distribuição em 4 palavras em `bqs3`): não grave "BQS original" nem "BQS legado". O campo `bqs` continua sendo o número principal. O histórico em 4 palavras começa em 26/10/2026; antes disso só há `bqs` (BQS 2.0).

```
{
  "schema": "bqs-run/1",
  "chave": "cartao-hp | aleatorio | criticos-semanal | cartao-hp-mensal | aleatorio-mensal | criticos-mensal",
  "rotina": "nome legível da rotina",
  "meta": { "origem": "rotina" },                     // "teste" só em rodadas de validação manual; "nota" opcional
  "periodo": { "tipo": "semanal | diario | mensal", "inicio": "AAAA-MM-DD", "fim": "AAAA-MM-DD", "label": "12/10 a 18/10/2026" },
  "gerado_em": "AAAA-MM-DDThh:mm:ss-03:00",
  "cobertura": { "baixa": true|false, "comparacao_indisponivel": true|false, "texto": "frase curta (dias com dado, buracos, ingestão atrasada)" },
  "metricas": {
    "n_total": 0, "n_avaliaveis": 0, "n_ok": 0,
    "bqs": 0.0, "bqs_avaliador": 0.0, "bqs_anterior": null, "ultimo_ponto_anterior": { "bqs": 0.0, "fim": "AAAA-MM-DD" },   // ultimo_ponto_anterior: só quando não há período anterior comparável (ex.: depois de um hiato); senão null
    "calibracao": { "calibrado": true, "n_amostra": 0, "n_revertidos": 0, "taxa_falso_aprovado": 0.0, "calibrado_reprovados": true, "n_amostra_reprovados": 0, "n_revertidos_reprovados": 0, "taxa_falso_reprovado": 0.0, "faixa": [0.0, 0.0] },   // a faixa NÃO é exibida; `bqs` é o BQS 3.0 calibrado (um número só)
    "bqs3": { "otimo": 0.0, "bom": 0.0, "regular": 0.0, "ruim": 0.0, "n": 0, "pct_otimo_bom": 0.0, "provisorio": false, "motivo_provisorio": "só quando provisorio = true" },   // distribuição calibrada do Passo 6.3 (contagens ESPERADAS, podem ter decimais; otimo + bom + regular + ruim = n); `pct_otimo_bom` = `bqs`; provisório quando n_cal < 5 ou n_calr < 5; omita o objeto (ou use null) só em rodadas sem o Passo 6.3
    "prompt_version": "versão do prompt do bot dominante no período (Pacote V) ou null",
    "tfc": 0.0, "pct_pediu_humano": 0.0, "pct_transbordo": 0.0, "n_transbordo_nota_ok": 0,
    "labels": { "excelente": 0, "bom": 0, "regular": 0, "ruim": 0, "critico": 0 },
    "retention": { "resolutiva": 0, "abandono": 0, "transbordo": 0, "loop": 0 },
    "criterios": { "understanding": 0.0, "resolution": 0.0, "clarity": 0.0, "tone": 0.0, "efficiency": 0.0, "escalation": 0.0 },
    "pct_recontato_24h": 0.0,                        // indicador de acompanhamento; NÃO entra no BQS 3.0
    "sinalizados": { "transbordo_sem_pedido": { "n": 0, "pct": 0.0, "tickets": ["até 3 ticket_id de exemplo"] } },   // reprovam o BQS 3.0 e vão para análise
    "sem_artigo_porta" /* não é mais exibido pelo painel */ : { "tag": "chat-default-instead-form", "n": 0, "pct": 0.0, "pct_aprovadas_avaliador": 0.0, "itens": [ { "ticket_id": 0, "tema": "topic ou null", "vertical": "effective_vertical ou null", "desfecho": "resolutiva|abandono|transbordo|loop", "aprovada_avaliador": true } ] },   // conversas que entraram sem passar por artigo da Central (porta não mapeada); até 25 itens, os mais recentes; só análise manual, fora do BQS; `n`, `pct` e `pct_aprovadas_avaliador` vêm do passo 3.5
    "qualidade_dado": { "n_sem_boas_vindas": 0, "pct_sem_boas_vindas": 0.0 }   // só no cartao-hp; indicador em revisão, informativo
  },
  "auditoria": { "auditados": 0, "revisados": 0, "aprovado_para_reprovado": 0, "reprovado_para_aprovado": 0, "divergencias": ["frase sem dados pessoais"] },
  "dimensoes": {                                        // top 12 do Passo 3.2, valores ORIGINAIS (sem auditoria)
    "effective_vertical": [ { "valor": "", "rotulo": "nome legível (opcional; no cartão: cartao_credito = \"Agente Geral\", cc_anuidade = \"Agente de Anuidade\")", "n": 0, "pct_volume": 0.0, "bqs": 0.0, "tfc": 0.0, "pct_pediu_humano": 0.0 } ],
    "topic": [ ... ], "product": [ ... ]                // só as dimensões da rotina
  },
  "contencao": {                                        // do Passo 6.1; omita o objeto se não houve classificação
    "n_classificadas": 0, "n_elegiveis": 0, "pct_evitavel": 0.0, "ic95": [0, 0], "ce_pct_total": 0.0,
    "classes": { "A": 0, "B": 0, "C": 0, "D": 0, "R": 0, "E": 0 },
    "causas": [ { "classe": "A", "causa": "prompt_resposta", "causa_rotulo": "texto legível", "n": 0, "tickets": ["ticket_id", "até 3 exemplos"] } ],
    "por_dono": { "Produto CX": 0, "Help Design": 0 },
    "handoff": { "correto": 0, "improvisado": 0, "tardio": 0 }
  },
  "pontos_atencao": [ { "tipo": "crit | warn | info", "texto": "frase", "tickets": ["opcional: até 3 ticket_id de exemplo"] } ],      // máx. 4 + o de cobertura
  "oportunidades": [ {
    "id": "OPO-001", "prioridade": "alta | media | baixa", "classe": "A|B|C|D", "causa": "…", "tipo": "cross-domain | fluxo | politica | variavel | capacidade | integracao | handoff | artigo",
    "frente": "artigo | variavel_hp | prompt | fluxo | politica | capacidade | handoff",
    "titulo": "…", "titulo_curto": "≤ 12 palavras, onde + o que mudar (linha do Slack)", "vertical_tema": "…", "problema": "…", "evidencia": "…", "tickets": ["ticket_id"],
    "contatos": { "observado": 0, "estimado": 0, "pct_total": 0.0 }, "nota_impacto": "…",
    "antes": "o que o bot fez (sem dados pessoais)", "depois": "o que teria retido (texto da resposta ou regra)",
    "proposta": "…", "no": "nó/artigo confirmado ou 'nó a confirmar pelo Produto CX'",
    "dono": "Produto CX | Help Design", "prazo": "Imediato | Sprint | Backlog", "dependencias": "…", "como_medir": "…"
  } ],
  "artigos": [ { "acao": "criar | atualizar", "tickets": ["até 3 ticket_id de exemplo"], "titulo": "título exato do artigo público", "secao": "…", "problema": "…", "primeira_frase": "resposta direta sugerida", "conversas": 0, "prioridade": "alta | media | baixa" } ]
}
```

**Como preencher o que exige conta (apenas estes):**
- `contatos.estimado` = `observado × (n_elegiveis / n_classificadas)`, arredondado; `contatos.pct_total` = `estimado / n_total × 100` (1 casa).
- `contencao.ic95` = intervalo de Wilson de 95% da proporção `pct_evitavel` (em %, inteiros) com `n = n_classificadas`.
- `contencao.ce_pct_total` = `pct_evitavel × n_elegiveis / n_total` (vem pronto do SQL do Passo 6.1; copie).
- Só entram em `oportunidades` itens com dono **Produto CX** ou **Help Design**; nada sobre atendimento humano; nenhum artigo cujo título comece com 🔒 ou 🔍.
- **Tickets de exemplo (obrigatório para o que o painel mostra):** em cada oportunidade, em cada causa de `contencao.causas` e em cada item de `artigos`, informe até 3 `ticket_id` reais que exemplifiquem o problema (do `output_contencao`, `output_fluxo`, `output_kb`); nunca invente. Em `pontos_atencao` de casos críticos, inclua `tickets` quando o ponto descrever um padrão.
- **Oportunidades acionáveis (quem revisa precisa saber o que mudar):** `titulo` = onde + o que mudar (ex.: "Prompt do Agente Geral: corrigir prazos que contradizem o artigo"), nunca só o sintoma. `proposta` diz o que escrever ou alterar, em texto ou regra; `no` aponta o nó, artigo ou campo (ou "nó a confirmar pelo Produto CX"); `antes` e `depois` mostram a resposta atual e a esperada; `como_medir` diz o indicador que prova o ajuste. O painel exibe esses campos em "Principais ações"; `titulo_curto` (≤ 12 palavras) é o texto da linha do Slack.
- Em `artigos`, só títulos exatos que vieram do `output_kb`; nunca invente título, ID ou URL (a URL costuma chegar redigida: omita).
- Nomes internos do prompt → contrato: `bqs_final` → `bqs`, `n_ok_final` → `n_ok`, `pct_recontato_24h` → `pct_recontato_24h`, `n_transbordo_sem_pedido`/`pct_transbordo_sem_pedido`/`sinalizados_transbordo` → `sinalizados.transbordo_sem_pedido`, `n_hp_degradado`/`pct_degradado` → `qualidade_dado.n_sem_boas_vindas`/`pct_sem_boas_vindas`. Não grave `bqs_original`, `bqs_pleno`, `bqs_degradado` nem colunas fora do contrato.
- `dimensoes`: copie as linhas do SQL (só as colunas do contrato); se `n < 30` mantenha a linha (o painel marca "amostra pequena").
- Sem classificação/auditoria/oportunidades nesta rodada: omita `contencao`, use `auditoria` com `auditados: 0` e `oportunidades: []`. O painel mostra o estado vazio.
**`history.json`** (array ordenado por `fim`; **só cresce**: acrescente o item desta rodada e, se já houver um item com o mesmo `fim`, substitua apenas esse; nunca descarte os demais; mantenha os 104 mais recentes). Mesmo `bqs` do `latest.json` (já com a nota revisada):
`{ "inicio": "AAAA-MM-DD", "fim": "AAAA-MM-DD", "periodo_label": "…", "bqs": 0.0, "bqs3_otimo": 0.0, "bqs3_bom": 0.0, "bqs3_regular": 0.0, "bqs3_ruim": 0.0, "bqs3_n": 0, "bqs3_provisorio": false, "bqs3_motivo_provisorio": "só quando provisório", "tfc": 0.0, "ce_pct_total": 0.0, "n_total": 0, "n_avaliaveis": 0, "calibracao_amostra": 0, "calibracao_revertidos": 0, "n_sinalizados": 0, "n_sem_porta": 0, "cobertura_baixa": true|false, "prompt_version": "…" | null, "pct_recontato_24h": 0.0 }`
Os campos `n_avaliaveis`, `calibracao_amostra`, `calibracao_revertidos` e `n_sinalizados` alimentam a visão mensal acumulada (itens antigos sem eles usam `n_total` e ficam fora da calibração somada).
Os campos planos `bqs3_*` copiam o objeto `metricas.bqs3` desta rodada (nas rodadas sem Passo 6.3 omita-os; itens antigos sem eles são válidos e o painel usa só `bqs`). **O histórico só cresce:** ao acrescentar `bqs3_*` não apague nem reescreva os itens anteriores (os itens de antes de 26/10/2026 seguem como BQS 2.0, sem as 4 palavras); a série `bqs3` é a soma por semana, então não recalcule semanas já gravadas.
O painel marca na linha do tempo, sozinho, toda mudança de `prompt_version` entre pontos seguidos. Itens antigos sem `prompt_version` ou com a chave `bqs_final` continuam válidos.

### Backlog de ações (`data/backlog/backlog.json`)

**Um único arquivo para os três fluxos** (`cartao-hp`, `aleatorio` e `criticos`, este alimentado pela rotina `criticos-semanal`). Cada tarefa é uma **mudança concreta**, não um fluxo: o mesmo insight visto em mais de um fluxo é UMA tarefa, que lista de quais fluxos ele veio (`fluxos`). É um array de itens que **acumula todas as rodadas** (as demais abas mostram só a rodada mais recente). Quem define o status é quem pode editar o painel, direto na caixinha de cada tarefa (Não iniciado, Em andamento, Concluído ou Cancelado, com nota opcional): ele fica no banco de dados do próprio artefato (coleção `backlog_status`, um documento por `id` do item, com `status`, `status_em`, `nota`, `por` e `atualizado_em`; escrita só para quem edita) e vale por cima do `status` deste arquivo. As rotinas nunca o alteram nem o leem.

**Formato de gravação (economia de tokens, decidido em 03/11/2026):** grave `backlog.json` (e `arquivo.json`) **compactos**, em uma linha, sem indentação nem espaços entre `:` e `,` (o arquivo indentado pesava 322 KB; compacto, 182 KB). O conteúdo é o mesmo e o painel lê igual. Não peça nem imprima o arquivo inteiro: leia só o que precisa, altere os itens e regrave.

```
{
  "id": "CC-001 (tarefas antigas) ou BK-NNN (novas)", "fluxos": ["cartao-hp", "aleatorio", "criticos"],   // um ou mais fluxos de onde o insight veio
  "consolida": ["ids antigos que esta tarefa absorveu"],
  "situacao": "ativa | observacao | arquivada",    // regra de entrada: ver "Regras de atualização"
  "titulo": "…", "frente": "…", "causa": "…", "classe": "A|B|C|D", "dono": "Produto CX | Help Design", "prioridade": "alta | media | baixa",
  "problema": "…", "proposta": "…", "no": "…", "antes": "…", "depois": "…", "como_medir": "…", "dependencias": "…",
  "criada_em": "AAAA-MM-DD", "ultima_vez": "AAAA-MM-DD", "origem": "rotina | teste",
  "status": "aberta | em_andamento | concluida | cancelada", "status_em": "AAAA-MM-DD ou null", "nota": "texto livre (motivo, link do ajuste)",
  "reapareceu_em": ["AAAA-MM-DD"],                 // datas em que o problema voltou depois de concluído ou cancelado
  "ocorrencias": [ { "fluxo": "cartao-hp | aleatorio | criticos", "fim": "AAAA-MM-DD", "periodo_label": "…", "rotina": "chave da rotina", "contatos_estimados": 0, "tickets": ["ticket_id", "até 3"] } ]
}
```

**Filtro por equipe (aba Backlog, 03/11/2026):** a página agrupa as tarefas pelo campo `dono`, em uma linha de botões entre o filtro de fluxo e o de status: **Todas as equipes**, **Produto CX**, **Help Design** e **Tarefas compartilhadas**. Cada tarefa cai em um só grupo, para os números somarem o total: `dono` igual a `Produto CX` ou `Help Design` vai para a equipe; `dono` que cita as duas (separadas por `|`, por exemplo `Produto CX | Help Design`) vai para "Tarefas compartilhadas". Por isso, as rotinas devem preencher `dono` com **uma** equipe sempre que um lado só resolve, e com as duas somente quando as duas equipes precisam agir. Valor vazio ou diferente aparece só em "Todas as equipes". O filtro é feito na página; não há campo novo nos JSON.

**Regras de atualização (a cada rodada):**
- **Mesma mudança, em qualquer fluxo:** compare pela mudança (dono + nó, prompt ou artigo + gatilho ou regra), com o sentido e não o texto, contra o backlog INTEIRO (qualquer fluxo e rodada). Se já existir, não abra id novo: acrescente a `ocorrencia` com o `fluxo` desta rodada, inclua o fluxo em `fluxos` e atualize a descrição com a versão mais recente.
- **Problema novo:** item `BK-NNN` sequencial, `aberta`, com a primeira ocorrência.
- **Contatos:** por fluxo, na última janela semanal comparável; nunca some entre fluxos como se fosse um número só (as amostras podem repetir conversas).
- **Entrada no backlog ativo (`situacao`):** `ativa` se a última janela de algum fluxo tem **10 ou mais contatos**, OU a mudança apareceu em **2 ou mais fluxos** (uma tarefa só), OU tem 2 ou mais ocorrências em períodos diferentes, OU a gravidade é alta (regulatório, fraude, segurança, perda financeira), OU a correção é trivial (texto, link, template). Senão `observacao`. Classe D não entra por volume: é risco ou handoff, priorizada por gravidade.
- **Saída:** `observacao` ou `ativa` sem ocorrência há **4 semanas** vira `arquivada`; nunca se apaga nada. `arquivada` que reaparece volta a `observacao` ou `ativa` pela mesma regra.
- **Status:** **nunca** mude `status`, `status_em` ou `nota`; item `concluida` ou `cancelada` que reaparece só ganha a data em `reapareceu_em`, e nunca é fundido com tarefa aberta.
- **Dono e entrega:** uma equipe por tarefa; artigo (Help Design) e prompt ou fluxo (Produto CX) viram duas tarefas ligadas. Trecho repetido em 3 ou mais tarefas vira uma tarefa central.
- **Política de transbordo (decidida):** pediu atendente, transfere; só não vale depois do CSAT, que é campo livre. Nenhuma tarefa propõe sondagem antes de transferir nesse caso.

### Abandono (`data/abandono/`)

Chave fora do contrato `bqs-run/1`: não tem BQS. O agente `bqs-abandono` grava `latest.json` (`schema:"abandono/2"`, desde 10/11/2026) e acrescenta a semana em `history.json` (array por `fim`, só cresce, até 104). **Mudança de regra (abandono/1 → abandono/2):** recontato em 72 horas (antes 7 dias), contado a partir do fim da sessão abandonada (`creation_ts + resolution_seconds`); 3 fatias por stage (mesmo / outro / não voltou); instabilidade fora da base geral e em bloco próprio. Campos `*_7d` foram renomeados para `*_72h` (o painel só lê os novos). `pct_recontato_7d` continua existindo só em `periodo_total` e `instabilidade.periodo_total`, para o texto de prazo.

- **`latest.json`:** `gerado_em`; `eixo:"stage"`; `regra` (texto); `periodo{inicio,fim,semanas}`; `semana_atual` e `periodo_total` com `abandonos`, `usuarios`, `pct_sessoes`, `recontato_72h`, `pct_recontato_72h`, `recontato_mesmo_stage_72h`, `pct_mesmo_stage_72h`, `recontato_outro_stage_72h`, `pct_outro_stage_72h`, `nao_voltou_72h`, `nunca_voltam_pct` (= não voltou), `retorno_so_instab` (abandonos que só voltaram em instabilidade, não contam), `nota_amostra`, `n_amostra`; só em `periodo_total`: `pct_recontato_24h`, `pct_recontato_48h`, `pct_recontato_7d`, `voltou_em_instab`, `voltou_antes_do_fim_da_sessao`, `sessoes_total`; `stages[]` (todos com mín. 100 abandonos, ordenados por volume, mais "(sem stage)" com `recontato_mesmo_stage_72h` 0; cada item: `stage, abandonos, usuarios, pct_abandono_no_stage, recontato_72h, pct_recontato_72h, recontato_mesmo_stage_72h, pct_mesmo_stage_72h, recontato_outro_stage_72h, pct_outro_stage_72h, nao_voltou_72h, pct_nao_voltou_72h, nota_amostra, n_amostra`; mesmo + outro + não voltou = abandonos); `stages_semanal{}` (evolução semanal por stage: `"<stage>": [["AAAA-MM-DD fim da semana", abandonos, recontato_72h, recontato_mesmo_stage_72h], ...]`, outro = recontato − mesmo; só stages de `stages`); `instabilidade{}` (base separada: `periodo_total`, `semana_atual`, `semana_parcial{inicio,fim,abandonos}`, `historico[]` com linhas `["fim da semana", abandonos, recontato_72h, mesmo_stage_72h]`, `stages[]` mesmo formato de `stages`, `nota`; aqui qualquer nova sessão conta como retorno); `melhorar[]` (`stage`, `pct_mesmo_stage_72h`, `abandonos`, `assunto`, `causa`, `acao`, `dono` = Produto CX ou Help Design, `amostra`); `notas{}` (`definicao, prazo, recontato, observacao, coorte, instabilidade`, exibidas no "Como ler"; `prazo` também vira o aviso azul do topo: "Recontato = novo contato no bot em até 72h após o abandono. Em 7 dias ~X% voltam, mas ~Y% já voltam nas 72h; ...", com X/Y vindos de `periodo_total`); `diario[]` (opcional): linhas `["AAAA-MM-DD", abandonos, recontato_72h, recontato_mesmo_stage_72h]` dos últimos 120 dias, base geral, só abandonos com janela de 72h fechada; sem o campo o painel mostra só as semanas do `history.json`. O campo antigo `temas` (entry_theme) foi substituído por `stages`.
- **`semana_parcial`** (em `latest.json`, opcional): semana em andamento, fora do histórico e da tendência. `inicio`, `fim`, `abandonos`, `usuarios`, `pct_sessoes`, `recontato_72h_parcial`, `pct_recontato_72h_parcial`, `pct_mesmo_stage_parcial` (observados até agora), `n_janela_completa` e `pct_recontato_janela_completa` (só abandonos com 72h já fechadas desde o fim da sessão), `fecha_em` (data em que a última janela fecha), `abandonos_instab`, `parcial:true`. O painel não mostra o bloco se o campo faltar.
- **`history.json`:** por semana, `inicio`, `fim`, `abandonos`, `usuarios`, `pct_sessoes`, `recontato_72h`, `pct_recontato_72h`, `pct_mesmo_stage_72h`, `pct_outro_stage_72h`, `nunca_voltam_pct`. Base geral (sem instabilidade). As 8 semanas anteriores (regra de 7 dias) foram regravadas pela nova regra em 10/11/2026.
- **Rótulos:** todo texto visível diz "tema da conversa no bot" no lugar de `stage` ("Volta no mesmo tema"); os nomes de campo continuam `stage`. Semanas ISO: "W44 · 26/10–01/11" (número da semana ISO + segunda a domingo).
- **Regras:** só abandono ativo (sessão fecha após 8h sem resposta do usuário; cada sessão conta; mostrar usuários distintos); recontato = nova sessão do mesmo `user_id` em até 72h do fim da sessão abandonada (`creation_ts + resolution_seconds`; a duração já inclui as ~8h de inatividade), só coortes completas (fim + 72h passado); semanas completas = domingo até hoje menos 4 dias; stage = fluxo/agente do bot (`stage` de `fat_botmaker_metrics`); 3 fatias: mesmo stage (não nulo) / outro stage / não voltou; stage com "instabilidade": volta em instabilidade não conta como recontato no geral, abandono originado em instabilidade sai do geral e vai para `instabilidade`; nota média só da amostra, sempre com N. A métrica se chama "Recontato em 72h", diferente do "recontato no dia" do dashboard Bot & IA Agent. Faixas de cor do ranking (mesmo tema): vermelho > 6%, âmbar 3–6%, verde < 3%.
