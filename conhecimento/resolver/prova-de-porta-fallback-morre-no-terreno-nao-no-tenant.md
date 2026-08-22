## Prova de porta que é FALLBACK morre no TERRENO, não no tenant — higienize antes de disparar {#prova-de-porta-fallback-morre-no-terreno-nao-no-tenant}

`tags: fallback, LLM na frente, prova em producao, turno real, terreno sujo, pendencia viva, assinatura previsivel, crc32, baseline zero, quality_event ausente, ADR-0015, R23`

**Sintoma:** uma guarda determinística está em PROD, com mutação matando 100% dos alvos, e mesmo
assim o turno real **não a alcança** — o LLM responde antes. A conclusão fácil, e ERRADA, é
*"preciso de um tenant sem LLM para provar"*.

**Causa raiz:** quando a guarda é **fallback**, quem decide se ela roda não é o tenant, é o
**estado da conversa**. Uma pendência viva (oferta de upsell, disambiguação, rascunho aberto) dá ao
LLM um referente barato, ele resolve o turno e a porta nunca é consultada. Medido no projeto **tiatendo**
(2026-08-22, frente N33), nas duas direções, com **a mesma frase, a mesma versão e o mesmo tenant**:

- com `upsell_offer` viva → o LLM leu *"uma coca gelada"* como aceite da oferta e **adicionou o item**;
- com o pedido **fechado pelo checkout** (pendência e rascunho mortos) → o turno **deferiu** e a
  porta determinística respondeu.

É o único A/B controlado que a frente teve, e ele isola o TERRENO como a variável.

**A saída "use um tenant sem o LLM" costuma não existir** — verifique antes de planejar em cima
dela. No caso medido havia 2 tenants com a flag ligada, mas **só um era do nicho certo**; o outro
nem entrava no pipeline. Virar a flag seria mutação de config em bind mount de produção.

**Procedimento:**
1. **Leia o estado ANTES de disparar** — pendência (`restaurantPending.load` ou equivalente),
   rascunho aberto, `customer_context`. Não confie na sua memória do turno anterior.
2. **Higienize pela porta do PRÓPRIO PRODUTO**, não por `UPDATE` no banco: conclua o fluxo aberto
   (checkout), não "marque como cancelado". Assim o estado morre do jeito que morre em produção.
3. ⚠️ **Cuidado com o atalho aparente:** pedir ao bot para *cancelar* pode **escalar para humano e
   PAUSAR o bot** — no caso medido isso matou a janela e exigiu desfazer pela rota de "devolver à
   IA" do painel. Fechar é mais lento e mais seguro que cancelar.
4. Só então dispare a frase.

**Irmãos:** [[guarda-sem-evento-torne-a-fala-previsivel-e-preveja-a-antes]] (como provar quando a
porta finalmente roda) · [[funcao-que-responde-duas-perguntas-tem-status-load-bearing]] ·
[[golden-de-regressao-que-guarda-caminho-morto]]
