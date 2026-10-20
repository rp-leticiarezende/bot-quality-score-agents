# Revisão das regras e validações do BQS

Registrado em 20/10/2026 a pedido da Leticia. Nada aqui foi aplicado às rotinas oficiais: são pontos a decidir.

## 1. O BQS de Cartão HP (72%) é oficial?

**Não.** É o resultado de uma rodada de teste (semana 12 a 18/10, só 2 dos 7 dias com dado). O painel marca isso com o aviso "Rodada de teste". O número ainda parece alto e a causa provável é o avaliador automático ser brando (ver item 3).

## 2. Contexto da série

- **Hiato:** sem BQS de 10/09 a 13/10/2026; voltou ao normal em 14/10. Por isso a tabela não tem registros nesse intervalo (marcado na linha do tempo do painel).
- **Sem fim de semana:** a tabela não tem registros de sábado e domingo; uma "semana" tem no máximo 5 dias de dado. O painel marca como "cobertura baixa" as semanas com menos de 5 dias.
- **Mudança de fórmula:** até 09/09 a nota geral era média aritmética das 6 notas; desde 14/10 é ponderada (resolução 30%, eficiência 20%, transbordo 20%, entendimento 15%, clareza 10%, tom 5%). Decisão tomada: o SQL **sempre recalcula** a nota ponderada a partir das 6 notas, então a série inteira é comparável.
- **`approved` não é usado:** deixa as conversas "regular" fora da conta e infla o resultado. Existe um único BQS (aprovado = nota geral ≥ 7 e resolução > 2 e transbordo > 2; "regular" reprova).

## 3. Regras a revisar (simulação no Cartão HP, 12 a 18/10)

| Variação da regra | BQS resultante |
|---|---|
| Regra atual (nota ≥ 7, resolução > 2, transbordo > 2) | 72,4% |
| Limiar da nota geral em 8 | 64,7% |
| Exigir resolução ≥ 7 | 69,6% |
| Penalizar falha de condução | 52,1% |
| Transbordo só aprova com resolução ≥ 7 | 70,9% |
| Contar só conversas resolutivas | 28,9% |

Achados que sustentam a revisão:
- 88,5% dos transbordos saem aprovados e a resolução média nesses casos é 7,52: o avaliador premia o transbordo.
- Auditoria por transcrição (4 tickets): em todos a nota original estava inflada; 1 passou de aprovado para reprovado. O avaliador deu 10 de transbordo a conversas em que a régua aceita 4 a 6.
- TFC (falha de condução) é 42,5% enquanto o BQS é 72,2%: o BQS alto mascara falha real.

Decisões pendentes (Leticia): qual regra adotar; se o transbordo deve exigir resolução mínima; se o BQS oficial passa a incluir penalidade por falha de condução. Mudar a regra de transbordo exige validação do Produto CX e de Compliance/Jurídico (SAC).

## 4. Indicador "HP pleno × HP degradado"

Em revisão; **rebaixado a indicador informativo** (sem alerta, sem oportunidade). Evidência:
- `pages_fetched` nunca é 0 e cresce com o tamanho da conversa: não mede carga de contexto.
- `welcome_not_found = true` marca conversas mais curtas (provável efeito de como a transcrição é segmentada); nessas, 94% tinham as variáveis do Botmaker carregadas e 41% foram personalizadas.
- O alerta antigo ("degradado > 5%") disparava por esse proxy.

Recomendação: abandonar a segmentação como indicador de qualidade; manter `welcome_not_found` só como qualidade do dado; medir personalização lendo resumo e diagnóstico das conversas (proxy de uso das variáveis) ou pedir ao time de dados um campo que registre a carga do payload.

## 5. Cobertura e limitações

- `botmaker_chatbot_flow` está 0% preenchido e `botmaker_stage` 37%; `issues` e `improvement_suggestions` vazios; `approved` não é confiável.
- A aba Aleatório é 100% transbordo e 96% pediu atendente: o BQS dela mede a conduta até o transbordo, não a qualidade geral do bot.
- Limiares de alerta (BQS < 60% crítico, ≥ 80% saudável; TFC e pedido de atendente) são provisórios até haver 4 períodos de série.

## 6. Diagnóstico do cálculo por fluxo (20/10/2026, a pedido da Leticia: "não acho que temos 72% de qualidade")

Mesma conta do BQS atual (nota ≥ 7, resolução > 2, transbordo > 2) aberta por desfecho. Ago/2026 e out/2026 até 20/10.

| Fluxo | BQS atual | Sem falha de condução | Resolvida pelo bot com nota boa |
|---|---|---|---|
| Agente de Cartão de Crédito (ago) | 67,2% | 45,1% | 22,0% |
| Agente de Cartão de Crédito (out) | 72,3% | 49,4% | 26,7% |
| Aleatório (ago / out) | 80,4% / 80,0% | 71,9% / 77,5% | 0% (100% transbordo) |
| Casos críticos, CSAT 1 e 2 (ago / out) | 50,5% / 54,0% | 49,9% / 50,0% | 49,4% / 46,0% |

Por que o BQS atual infla (Ago a 09/09, Agente de Cartão de Crédito):
- **Abandono sem o cliente pedir atendente** (o maior grupo, 3.307 conversas, 35% do volume): 41% saem aprovados, com resolução média 5,1. O cliente desistiu e a conversa conta como boa.
- **Transbordo que o cliente não pediu** (969): 67% aprovados. Loop: 0% (ok).
- **Transbordo pedido pelo cliente** (2.640): 86% aprovados.
- **Casos críticos** (todos com CSAT 1 ou 2): 57,5% das conversas "resolutivas" são aprovadas. O avaliador discorda do cliente em mais da metade dos casos.
- O 49,4% "sem falha de condução" bate com a classificação de contatos evitáveis (evitáveis ≈ 51%, logo ≈ 49% sem falha evitável): duas medidas independentes chegam ao mesmo número.
