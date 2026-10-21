### Contrato de dados do painel (`bqs-run/1`)

O painel (`artifact/painel.html`) é uma página fixa que lê arquivos JSON publicados ao lado dela. Cada rotina publica **dois arquivos próprios** e nunca mexe nos das outras:
- `data/<chave>/latest.json` — a rodada atual completa;
- `data/<chave>/history.json` — a série da linha do tempo (array, até 104 itens ≈ 2 anos de semanas).
Chaves das rotinas: `cartao-hp` (Agente de Cartão de Crédito, semanal), `aleatorio`, `criticos-diario`, `criticos-semanal`. Chaves das visões mensais: `cartao-hp-mensal` (alimentada por `cartao-hp`), `aleatorio-mensal` (por `aleatorio`) e `criticos-mensal` (**só por `criticos-diario`**; a rotina `criticos-semanal` não escreve nela, para não contar o mesmo ticket duas vezes); `periodo.tipo = "mensal"`.
**Regra de ouro do histórico: ele só cresce.** Nunca recrie `history.json` do zero: leia o arquivo publicado, acrescente (ou, se já existir um item com o mesmo `fim`, atualize só esse item) e publique o conjunto completo. Se a leitura falhar, tente de novo uma vez; se falhar de novo, **não publique** `history.json` (deixe-o fora de `files`, o publicado se mantém) e avise no resultado da rotina.
**Painel principal x mensal:** `latest.json` de cada rotina **substitui** o anterior e mostra o resultado mais recente (semana, dia). A visão **mensal acumula**: `data/<chave>-mensal/latest.json` e o seu `history.json` (um ponto por mês, atualizado a cada rodada) consolidam **todas as rodadas do mês até agora** a partir dos pontos do `history.json` da rotina (a rodada pertence ao mês do seu `fim`): `n_total` e `n_avaliaveis` = soma; `bqs` = média de `bqs` ponderada por `n_avaliaveis`; `tfc` e `pct_recontato_24h` = médias ponderadas por `n_total`; `calibracao.n_amostra` e `n_revertidos` = soma, e `taxa_falso_aprovado` = revertidos ÷ amostra (calibrado se a amostra somada for 5 ou mais); `sinalizados` = soma. `periodo`: `inicio` = dia 1 do mês, `fim` = `fim` da última rodada; `cobertura.texto` diz quantas rodadas e dias com dado entraram. A visão mensal não traz oportunidades nem tabelas por tema (essas ficam nas rodadas e no Backlog).
O arquivo `data/eventos.json` (marcos manuais, como o hiato do BQS) é **global e mantido por humanos**: nenhuma rotina escreve nele.

**Regras do JSON:** válido (aspas duplas, sem comentários, sem vírgula final); números como número (nunca `"72,2%"`); `null` quando o dado não existir; textos em português; **nenhum dado pessoal** (nome, e-mail, telefone, CPF, cartão) e **nenhuma transcrição** — conversas só por `ticket_id`; percentuais com 1 casa decimal; todos os números vêm do prompt do orquestrador (SQL), nunca calculados por você, exceto `ic95`, `pct_total` e `estimado` das oportunidades, que você calcula como descrito abaixo. Existe **um único BQS, o BQS 2.0** (conduta boa e desfecho aceitável, já com a nota revisada pelo auditor): não grave "BQS original" nem "BQS legado".

```
{
  "schema": "bqs-run/1",
  "chave": "cartao-hp | aleatorio | criticos-diario | criticos-semanal | cartao-hp-mensal | aleatorio-mensal | criticos-mensal",
  "rotina": "nome legível da rotina",
  "meta": { "origem": "rotina" },                     // "teste" só em rodadas de validação manual; "nota" opcional
  "periodo": { "tipo": "semanal | diario | mensal", "inicio": "AAAA-MM-DD", "fim": "AAAA-MM-DD", "label": "12/10 a 18/10/2026" },
  "gerado_em": "AAAA-MM-DDThh:mm:ss-03:00",
  "cobertura": { "baixa": true|false, "comparacao_indisponivel": true|false, "texto": "frase curta (dias com dado, buracos, ingestão atrasada)" },
  "metricas": {
    "n_total": 0, "n_avaliaveis": 0, "n_ok": 0,
    "bqs": 0.0, "bqs_avaliador": 0.0, "bqs_anterior": null, "ultimo_ponto_anterior": { "bqs": 0.0, "fim": "AAAA-MM-DD" },   // ultimo_ponto_anterior: só quando não há período anterior comparável (ex.: depois de um hiato); senão null
    "calibracao": { "calibrado": true, "n_amostra": 0, "n_revertidos": 0, "taxa_falso_aprovado": 0.0, "calibrado_reprovados": true, "n_amostra_reprovados": 0, "n_revertidos_reprovados": 0, "taxa_falso_reprovado": 0.0, "faixa": [0.0, 0.0] },   // a faixa NÃO é exibida; `bqs` é o BQS 2.0 calibrado (um número só)
    "prompt_version": "versão do prompt do bot dominante no período (Pacote V) ou null",
    "tfc": 0.0, "pct_pediu_humano": 0.0, "pct_transbordo": 0.0, "n_transbordo_nota_ok": 0,
    "labels": { "excelente": 0, "bom": 0, "regular": 0, "ruim": 0, "critico": 0 },
    "retention": { "resolutiva": 0, "abandono": 0, "transbordo": 0, "loop": 0 },
    "criterios": { "understanding": 0.0, "resolution": 0.0, "clarity": 0.0, "tone": 0.0, "efficiency": 0.0, "escalation": 0.0 },
    "pct_recontato_24h": 0.0,                        // indicador de acompanhamento; NÃO entra no BQS 2.0
    "sinalizados": { "transbordo_sem_pedido": { "n": 0, "pct": 0.0, "tickets": ["até 3 ticket_id de exemplo"] } },   // reprovam o BQS 2.0 e vão para análise
    "qualidade_dado": { "n_sem_boas_vindas": 0, "pct_sem_boas_vindas": 0.0 }   // só no cartao-hp; indicador em revisão, informativo
  },
  "auditoria": { "auditados": 0, "revisados": 0, "aprovado_para_reprovado": 0, "reprovado_para_aprovado": 0, "divergencias": ["frase sem dados pessoais"] },
  "dimensoes": {                                        // top 12 do Passo 3.2, valores ORIGINAIS (sem auditoria)
    "effective_vertical": [ { "valor": "", "rotulo": "nome legível (opcional)", "n": 0, "pct_volume": 0.0, "bqs": 0.0, "tfc": 0.0, "pct_pediu_humano": 0.0 } ],
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
- **Oportunidades acionáveis (quem revisa precisa saber o que mudar):** `titulo` = onde + o que mudar (ex.: "Prompt do Agente CC Produção: corrigir prazos que contradizem o artigo"), nunca só o sintoma. `proposta` diz o que escrever ou alterar, em texto ou regra; `no` aponta o nó, artigo ou campo (ou "nó a confirmar pelo Produto CX"); `antes` e `depois` mostram a resposta atual e a esperada; `como_medir` diz o indicador que prova o ajuste. O painel exibe esses campos em "Principais ações"; `titulo_curto` (≤ 12 palavras) é o texto da linha do Slack.
- Em `artigos`, só títulos exatos que vieram do `output_kb`; nunca invente título, ID ou URL (a URL costuma chegar redigida: omita).
- Nomes internos do prompt → contrato: `bqs_final` → `bqs`, `n_ok_final` → `n_ok`, `pct_recontato_24h` → `pct_recontato_24h`, `n_transbordo_sem_pedido`/`pct_transbordo_sem_pedido`/`sinalizados_transbordo` → `sinalizados.transbordo_sem_pedido`, `n_hp_degradado`/`pct_degradado` → `qualidade_dado.n_sem_boas_vindas`/`pct_sem_boas_vindas`. Não grave `bqs_original`, `bqs_pleno`, `bqs_degradado` nem colunas fora do contrato.
- `dimensoes`: copie as linhas do SQL (só as colunas do contrato); se `n < 30` mantenha a linha (o painel marca "amostra pequena").
- Sem classificação/auditoria/oportunidades nesta rodada: omita `contencao`, use `auditoria` com `auditados: 0` e `oportunidades: []`. O painel mostra o estado vazio.
**`history.json`** (array ordenado por `fim`; **só cresce**: acrescente o item desta rodada e, se já houver um item com o mesmo `fim`, substitua apenas esse; nunca descarte os demais; mantenha os 104 mais recentes). Mesmo `bqs` do `latest.json` (já com a nota revisada):
`{ "inicio": "AAAA-MM-DD", "fim": "AAAA-MM-DD", "periodo_label": "…", "bqs": 0.0, "tfc": 0.0, "ce_pct_total": 0.0, "n_total": 0, "n_avaliaveis": 0, "calibracao_amostra": 0, "calibracao_revertidos": 0, "n_sinalizados": 0, "cobertura_baixa": true|false, "prompt_version": "…" | null, "pct_recontato_24h": 0.0 }`
Os campos `n_avaliaveis`, `calibracao_amostra`, `calibracao_revertidos` e `n_sinalizados` alimentam a visão mensal acumulada (itens antigos sem eles usam `n_total` e ficam fora da calibração somada).
O painel marca na linha do tempo, sozinho, toda mudança de `prompt_version` entre pontos seguidos. Itens antigos sem `prompt_version` ou com a chave `bqs_final` continuam válidos.

### Backlog de ações (`data/backlog/<fluxo>.json`)

Um arquivo por fluxo: `cartao-hp`, `aleatorio` e `criticos` (as rotinas `criticos-diario` e `criticos-semanal` compartilham o mesmo). É um array de itens que **acumula todas as rodadas** (as demais abas mostram só a rodada mais recente). Quem define o status é a Leticia, em conversa; as rotinas nunca o alteram.

```
{
  "id": "CC-001", "fluxo": "cartao-hp | aleatorio | criticos",
  "titulo": "…", "frente": "…", "causa": "…", "classe": "A|B|C|D", "dono": "Produto CX | Help Design", "prioridade": "alta | media | baixa",
  "problema": "…", "proposta": "…", "no": "…", "antes": "…", "depois": "…", "como_medir": "…", "dependencias": "…",
  "criada_em": "AAAA-MM-DD", "ultima_vez": "AAAA-MM-DD", "origem": "rotina | teste",
  "status": "aberta | em_andamento | concluida | cancelada", "status_em": "AAAA-MM-DD ou null", "nota": "texto livre (motivo, link do ajuste)",
  "reapareceu_em": ["AAAA-MM-DD"],                 // datas em que o problema voltou depois de concluído ou cancelado
  "ocorrencias": [ { "fim": "AAAA-MM-DD", "periodo_label": "…", "rotina": "chave da rotina", "contatos_estimados": 0, "tickets": ["ticket_id", "até 3"] } ]
}
```

**Regras de atualização (a cada rodada):** problema já existente (mesmo fluxo, causa e tema/nó, comparado pelo sentido) ganha uma `ocorrencia` e a descrição mais recente; problema novo vira item `aberta`; **nunca** mude `status`, `status_em` ou `nota`; item `concluida` ou `cancelada` que reaparece só ganha a data em `reapareceu_em`; nada é apagado.
