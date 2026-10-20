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

Decisões pendentes (Leticia): qual regra adotar; se o transbordo deve exigir resolução mínima; se o BQS oficial passa a incluir penalidade por falha de condução.

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

## 7. Alinhamento do cálculo do BQS (20/10/2026)

**Regra de nomenclatura (Leticia):** BQS é o nome do resultado final da qualidade do atendimento do bot, igual em todos os fluxos. O que se ajusta é **como o BQS é calculado**, e isso precisa ser alinhado antes de implementar. Não criar outras "notas" com nomes diferentes: indicadores de apoio (TFC, contatos evitáveis, recontato) explicam o BQS, não o substituem.

Dados que sustentam a conta (join com `prod.cx.fat_botmaker_metrics` por `id_ticket`): recontato em 24h existe e discrimina pouco, mas discrimina (abandono aprovado 6,4% × reprovado 11,1%; resolutiva 12,9% × 18,5%). O CSAT quase não vem nesses fluxos (poucas dezenas de respostas). `flg_fcr_bot` não discrimina (85% a 90% em tudo). A retenção oficial do Botmaker conta abandono passivo como retido (99,8%), então o BQS estrito vai divergir dela de propósito.

Variantes simuladas (ago / out até 20/10):

| Variante | Cartão | Aleatório | Críticos |
|---|---|---|---|
| Atual | 67,2 / 72,3 | 80,4 / 80,0 | 50,5 / 54,0 |
| V1: aprova só resolutiva ou transbordo pedido pelo cliente | 45,1 / 49,2 | 71,9 / 77,5 | 49,9 / 50,0 |
| V2: V1 + abandono aprovado se resolução ≥ 7 | 58,5 / 63,8 | 71,9 / 77,5 | 49,9 / 54,0 |
| V3: V2 + sem recontato em 24h | 52,3 / 57,6 | 60,1 / 69,2 | 37,6 / 40,0 |
| V4: só resolvida pelo bot | 22,0 / 26,7 | 0 / 0 | 49,4 / 46,0 |

Decisões a alinhar: (1) transbordo pedido pelo cliente conta como sucesso de qualidade? (2) abandono sem pedido de atendente: reprova sempre ou aprova se o bot entregou a resposta (resolução ≥ 7)? (3) recontato em 24h entra na conta? (4) transbordo não pedido: reprova sempre ou só quando a contenção o classifica como evitável (A, B ou C)?

## 8. Definição oficial: BQS 2.0 (decidida em 20/10/2026)

Nome: **BQS 2.0** (o formato evoluiu; dashboards e histórico recomeçam em 20/10/2026; não comparar com números anteriores). Objetivo: dar insights valiosos do que e como melhorar no fluxo do bot, facilitando a vida de quem faz os ajustes.

Uma conversa conta como boa quando passa nas duas verificações:
1. **Conduta:** nota geral ponderada ≥ 7, resolução > 2 e transbordo > 2 (com a nota revisada pelo auditor quando houver). "Regular" reprova.
2. **Desfecho aceitável:**
   - resolvida pelo bot: ok;
   - transbordo **pedido pelo cliente**: ok, desde que bem conduzido (o bot é programado para transferir quando o humano é pedido, então é fluxo esperado);
   - abandono: ok se a resposta do bot foi boa (resolução ≥ 7), porque o cliente pode sair satisfeito;
   - loop: reprova;
   - transbordo **sem pedido do cliente**: reprova **e é sinalizado** para análise (pode ser erro do bot).

Indicadores de acompanhamento, fora da conta: **recontato em 24h** (`prod.cx.fat_botmaker_metrics`), TFC e contatos evitáveis.

Primeiros números (rodada de teste, sem a revisão do auditor): Agente de Cartão de Crédito 64,4% (semana 12 a 18/10) e 63,8% (outubro até 20/10); Aleatório 76,9% e 77,5%; Casos críticos 66,7% (semana), 54,0% (mês) e 45,8% (dia 19/10, onde nada muda porque não há transbordo pedido). Transbordos sem pedido sinalizados: 32 no cartão na semana (8,0%), 2 no Aleatório.

## 9. Fluxo Aleatório: por que o BQS 2.0 continua alto (20/10/2026)

BQS 2.0 do Aleatório: 76,9% (semana 12 a 18/10) e 77,5% (outubro até 20/10). Em outubro, 100% das conversas terminam em transbordo, 95,8% a pedido do cliente.

- **A nota de transbordo não discrimina.** Média 9,79; 92% das conversas recebem 9 ou 10. Como pesa 20%, soma cerca de 2 pontos fixos à nota geral de toda conversa transferida a pedido do cliente.
- **Auditoria de calibração (12 aprovados sorteados em outubro, lidos pela transcrição):** 8 dos 12 passariam a reprovados (67%; intervalo de confiança de 95% de Wilson: 39% a 86%). Médias originais × revisadas: resolução 8,08 × 4,58; eficiência 8,00 × 5,58; transbordo 10,00 × 6,25; entendimento 8,33 × 6,00; clareza 8,08 × 6,33; tom 8,67 × 7,58. O bot ajudou de verdade antes de transferir em apenas 2 dos 12.
- **Padrões de erro do avaliador:** (1) dá transbordo 10 a qualquer transferência pedida pelo cliente, mesmo evitável, tardia ou depois de pedido ignorado (um ticket teve 5 pedidos ignorados); (2) dá resolução e entendimento altos a respostas de template que não tratam a dúvida real; (3) não penaliza loops e pedidos de reformulação em eficiência e trata o "Não" do cliente como transbordo bem feito.
- **Estimativa do BQS real:** 77,5% × (1 − 67%) ≈ 26%, com faixa de 11% a 47% (amostra pequena).

Simulações só com as notas do avaliador (outubro): atual 77,5% · exigir resolução ≥ 7: 75,8% · resolução ≥ 7 e eficiência ≥ 7: 57,5% · ignorar a nota de transbordo e exigir resolução ≥ 7: 63,3% · ignorar transbordo com limiar 8: 40,8%. Nenhuma regra baseada só nas notas chega perto do resultado da auditoria, porque a resolução e o entendimento também estão inflados.

Proposta em análise: **calibrar o BQS 2.0 com auditoria aleatória dos aprovados** (BQS = taxa de aprovação × (1 − taxa de falsos aprovados medida na auditoria), com faixa), aplicável a todos os fluxos, e exigir que o transbordo pedido pelo cliente só conte se o bot tentou ajudar antes.
