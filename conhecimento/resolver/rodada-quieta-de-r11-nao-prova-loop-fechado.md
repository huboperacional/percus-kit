## Uma rodada quieta de R11 não prova que o loop de review fechou {#rodada-quieta-de-r11-nao-prova-loop-fechado}

`tags: R11, review loop, spec-analyze, writing-plans, quando parar, falso floor, diminishing returns, DeepSeek, revisao de plano, achado real, taxa de achado`

**Contexto:** revisando um plano de implementação (não código já escrito — o próprio texto do plano
de `writing-plans`, antes de disparar `subagent-driven-development`) via `/percus-review:review`
repetido em loop manual. Depois de cada rodada com achados reais, a tentação é declarar "achados
diminuindo, fechando o loop" assim que UMA rodada volta limpa.

**Causa raiz do erro:** uma rodada limpa depois de N rodadas com achado real **não é evidência
suficiente** de que o documento está sem defeito — é só evidência de que aquele reviewer, naquele
momento, não achou mais nada NA PASSADA ATUAL. Num caso real (plano de ~1900 linhas cobrindo schema,
migration, função compartilhada reusada por dois callers, response schema consumida por múltiplas
telas), a declaração de "fechando o loop" foi feita e desfeita **duas vezes seguidas**: a rodada 6
declarou fechado, a rodada 7 achou o bug mais severo de todo o processo (uma função de side-effect
que nunca materializava o dado que deveria — o form salvaria "com sucesso" sem criar nada real). A
rodada 7 declarou fechado de novo; a rodada 8 achou mais dois reais. Só na rodada 11 (a 11ª!) veio
uma passada genuinamente limpa — e mesmo essa foi seguida por mais 3 rodadas (12-14) que não acharam
NOVA classe de defeito, mas ainda produziram mudança real (um ADR pra fechar um ponto reaberto 4x, e
o fix do próprio rule-table que fazia esse ponto reabrir).

**Por que isso não é só "má sorte" — é estrutural:** um plano que toca (a) um índice único
compartilhado por múltiplos caminhos de escrita, (b) uma função reusada por dois callers com
contratos de transação diferentes (commit síncrono vs. loop em lote), e (c) um schema de resposta
que outras telas já consomem, tem uma superfície de interação maior que uma revisão de "o que este
código faz sozinho" cobre. Cada rodada tende a achar um ângulo NOVO de interação, não repetir o
mesmo. Um reviewer LLM não tem memória de "já bati nisso de todo jeito que consigo pensar" — ele só
sabe que não achou nada NESTA leitura.

**Heurística prática (validada neste caso, não teórica):**
- Não declare "fechando o loop" na PRIMEIRA rodada limpa. Rode pelo menos mais uma, especificamente
  pra checar se a rodada limpa foi real ou um "false floor".
- Uma segunda rodada limpa seguida (ou uma rodada que só reabre pontos JÁ dispensados com
  justificativa nova, sem achado de classe nova) é o sinal real de platô.
- Se o documento revisado é grande e cross-cutting (toca índice compartilhado, função reusada,
  schema consumido por múltiplos lugares), espere uma taxa de achado mais alta e mais rodadas antes
  do platô — não aplique o mesmo orçamento de rodadas que funcionaria pra uma mudança isolada de 1
  arquivo.
- Pare de verdade quando: (a) duas rodadas seguidas não acham classe nova de defeito, E (b) o
  próximo passo real é revisão contra um DIFF de código de verdade (task-a-task em
  `subagent-driven-development`, ou `/percus-review:review` normal) — não mais uma N-ésima rodada
  do mesmo reviewer contra o mesmo texto de plano ainda não implementado. Revisão contra prosa é
  estruturalmente mais fraca que revisão contra diff; delegar pro estágio certo é a saída honesta,
  não "mais uma rodada resolve".

**Ref:** Família Milionária, plano `2026-09-12-mesada-recorrente-fatia2a.md` — 14 rounds de R11
documentados inline no próprio plano (convenção também usada no `§8 — Conselho` das specs deste
projeto), achados reais nas rodadas 1, 2, 4, 5, 7, 8, 10 (parcial), 12, 13, 14 (parcial).
