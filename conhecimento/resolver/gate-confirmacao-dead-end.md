## Gate de confirmação/escolha nunca pode ter dead-end infinito (cancel-escape + retry→escala) {#gate-confirmacao-dead-end}

`tags: gate, confirmacao, escolha, dead-end, loop infinito, cancel-escape, retry counter, escalar humano, conversa burra, bot, readback, disambiguacao, tamanho, pizza`

**Sintoma:** um "micro-confirm" ou gate de escolha (bot pergunta "Confirma? sim/troca") trata como erro qualquer resposta que não seja o esperado — o usuário corrige/cancela/pergunta ("eu não pedi X, pedi Y") e leva um template "Não reconheci essa opção" em loop. É "conversa burra" nascida DA PRÓPRIA feature de confirmação.

**Causa raiz:** o gate tem só 2 saídas (sim | re-tentar a mesma extração) e a saída de falha é um `return template` sem estado — nenhum ramo pra cancelamento/correção-fora-de-banda, e nenhum contador que quebre o loop.

**Solução (padrão, tiatendo `restaurantOrderFlow.py` gate de sabor, smoke 2026-07-12):** todo gate de confirmação/escolha ganha 3 propriedades, espelhando um gate já-robusto do mesmo código se existir (aqui o disambig de tamanho):
1. **Cancel-escape** ANTES do match: regex de cancelamento ("cancela/deixa pra lá/não quero mais") tira o item/encerra o passo, em vez de re-extrair.
2. **Retry-counter que ESCALA** pro humano na Nª tentativa seguida (ex. 3), em vez de repetir o template pra sempre. Contador no estado persistido, zerado no sucesso.
3. **Re-ask que ECOA o contexto** (ex. o tamanho já escolhido) — dissolve o mal-entendido na origem, não só repete a pergunta.

Corolário de wording: em domínio com dimensões colidentes (pizza P/M/**G** onde M=Média), NUNCA use a mesma palavra ("média") pra outra coisa (método de preço) — o usuário lê como a dimensão. Ecoe sempre a dimensão fixada no readback.

**Ref:** smoke WhatsApp 2026-07-12 (Bug A/B); commit `ef74467`; memória `project-pizza-smoke-fixes-e-loja-web-2026-07-12`.
