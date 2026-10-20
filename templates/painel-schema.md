### Contrato de dados do painel (`bqs-run/1`)

O painel (`artifact/painel.html`) é uma página fixa que lê arquivos JSON publicados ao lado dela. Cada rotina publica **dois arquivos próprios** e nunca mexe nos das outras:
- `data/<chave>/latest.json` — a rodada atual completa;
- `data/<chave>/history.json` — a série da linha do tempo (array, até 104 itens ≈ 2 anos de semanas).
Chaves das rotinas: `cartao-hp` (Agente de Cartão de Crédito, semanal), `aleatorio`, `criticos-diario`, `criticos-semanal`. Chaves das visões mensais (`cartao-hp-mensal`, `aleatorio-mensal`, `criticos-mensal`, `periodo.tipo = "mensal"`) são geradas depois, consolidando as rodadas semanais; o painel já as lê quando existirem.
O arquivo `data/eventos.json` (marcos manuais, como o hiato do BQS) é **global e mantido por humanos**: nenhuma rotina escreve nele.

**Regras do JSON:** válido (aspas duplas, sem comentários, sem vírgula final); números como número (nunca `"72,2%"`); `null` quando o dado não existir; textos em português; **nenhum dado pessoal** (nome, e-mail, telefone, CPF, cartão) e **nenhuma transcrição** — conversas só por `ticket_id`; percentuais com 1 casa decimal; todos os números vêm do prompt do orquestrador (SQL), nunca calculados por você, exceto `ic95`, `pct_total` e `estimado` das oportunidades, que você calcula como descrito abaixo. Existe **um único BQS** (o que inclui a nota revisada pelo auditor): não grave "BQS original" nem "BQS legado".

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
    "bqs": 0.0, "bqs_anterior": null, "ultimo_ponto_anterior": { "bqs": 0.0, "fim": "AAAA-MM-DD" },   // ultimo_ponto_anterior: só quando não há período anterior comparável (ex.: depois de um hiato); senão null
    "prompt_version": "versão do prompt do bot dominante no período (Pacote V) ou null",
    "tfc": 0.0, "pct_pediu_humano": 0.0, "pct_transbordo": 0.0, "n_transbordo_nota_ok": 0,
    "labels": { "excelente": 0, "bom": 0, "regular": 0, "ruim": 0, "critico": 0 },
    "retention": { "resolutiva": 0, "abandono": 0, "transbordo": 0, "loop": 0 },
    "criterios": { "understanding": 0.0, "resolution": 0.0, "clarity": 0.0, "tone": 0.0, "efficiency": 0.0, "escalation": 0.0 },
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
    "titulo": "…", "vertical_tema": "…", "problema": "…", "evidencia": "…", "tickets": ["ticket_id"],
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
- Em `artigos`, só títulos exatos que vieram do `output_kb`; nunca invente título, ID ou URL (a URL costuma chegar redigida: omita).
- Nomes internos do prompt → contrato: `bqs_final` → `bqs`, `n_ok_final` → `n_ok`, `n_hp_degradado`/`pct_degradado` → `qualidade_dado.n_sem_boas_vindas`/`pct_sem_boas_vindas`. Não grave `bqs_original`, `bqs_pleno`, `bqs_degradado` nem colunas fora do contrato.
- `dimensoes`: copie as linhas do SQL (só as colunas do contrato); se `n < 30` mantenha a linha (o painel marca "amostra pequena").
- Sem classificação/auditoria/oportunidades nesta rodada: omita `contencao`, use `auditoria` com `auditados: 0` e `oportunidades: []`. O painel mostra o estado vazio.

**`history.json`** (array ordenado por `fim`; substitua o item de mesmo `fim`; mantenha os 104 mais recentes). Mesmo `bqs` do `latest.json` (já com a nota revisada):
`{ "inicio": "AAAA-MM-DD", "fim": "AAAA-MM-DD", "periodo_label": "…", "bqs": 0.0, "tfc": 0.0, "ce_pct_total": 0.0, "n_total": 0, "cobertura_baixa": true|false, "prompt_version": "…" | null }`
O painel marca na linha do tempo, sozinho, toda mudança de `prompt_version` entre pontos seguidos. Itens antigos sem `prompt_version` ou com a chave `bqs_final` continuam válidos.
