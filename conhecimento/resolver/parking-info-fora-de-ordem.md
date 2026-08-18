## Bot conversacional re-pergunta info que o cliente já deu FORA DE ORDEM (checkout/wizard) {#parking-info-fora-de-ordem}

`tags: conversa, checkout, wizard, maquina de estados, info fora de ordem, re-pergunta, parking, customer_context, lock por-conversa, WhatsApp, restaurante, tiatendo, forma de pagamento, retirada entrega, endereco adiantado`

**Sintoma:** o cliente manda a resposta de um passo ANTES do bot perguntar ("vai ser no cartão", "rua X 560") e o bot (a) ignora → re-pergunta depois; (b) trata a msg como resposta do passo CORRENTE (ex.: "vai ser no cartão" vira o NOME do cliente); (c) cai num fallback espúrio ("Pode me dizer: retirada ou entrega?").

**Causa raiz (diagnóstico):** o fluxo é uma **máquina de estados determinística** (não LLM) e há **lock por-conversa** → NÃO é race concorrente, é **ordem**: cada mensagem é processada contra o estado que existe quando ela é desenfileirada. Info dada cedo bate no gate errado.

**Solução — parking-and-reuse (cirúrgico, preferível a debounce):**
1. **Estaciona** a info reconhecida no contexto que PERSISTE entre os passos (não no `pending`, que é substituído a cada gate) — no tiatendo, `session.customer_context`. Escaneia TODA msg do fluxo (menos o gate que já trata aquele input) com o detector correspondente (`_matchPaymentMethod`/`detectDeliveryPref`/detector de endereço) e grava `parked_<x>`.
2. **Consome no gate certo:** o gate lê+LIMPA o park (`_consumeParkedPayment`) — se presente, pula a pergunta e usa o valor (com ack "como você tinha dito…"). Limpar é obrigatório senão vaza pro próximo pedido da mesma conversa.
3. **Gate corrente não mis-consome:** o passo atual precisa REJEITAR a msg que é claramente info de outro gate (ex.: `awaiting_name`: se `_matchPaymentMethod(text)` casa, NÃO vira nome → reconhece o park e re-pergunta o nome). Muitos gates aceitam "qualquer coisa" (o de nome aceitava 4 palavras) — esse é o bug real por trás de (b).
4. Muitos fluxos JÁ têm um "skip se já sei" (no tiatendo o P0-C de `_awaitConfirm` consulta `delivery_pref`/`customer_address`) — o parking só precisa POPULAR esse contexto quando a info vem fora de ordem, e o skip existente reaproveita de graça.

**Gotchas:** (a) blast-radius alto (fluxo `[5-T]`) → TDD por peça, uma info de cada vez; (b) o consume adiciona 1 read de sessão no gate → atualizar os testes existentes do gate pra mockar `getOrCreateSession` (senão `TypeError`/DB real); (c) `_matchPaymentMethod` etc. devem casar só TOKENS ("dinheiro"/"cartão"), nunca frases genéricas, pra não estacionar lixo.

**Ref:** tiatendo prints 2026-07-15 B3 (`restaurantOrderFlow._parkPaymentIfMentioned`/`_consumeParkedPayment`); devolutiva `docs/devolutivas/2026-07-15-smoke-conversa-loja-prints.md`. Continuação B4/B6 = mesmo padrão pra endereço/entrega.
