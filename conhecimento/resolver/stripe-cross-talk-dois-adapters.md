## Dois produtos na MESMA conta Stripe → todo webhook chega nos dois; discrimine por preço {#stripe-cross-talk-dois-adapters}

`tags: stripe, webhook, checkout.session.completed, dois produtos, mesma conta, cross-talk, provisionou no lugar errado, metadata identica, price id, endpoint nao registrado, assinatura cancelada, remove, direito de uso, entitlement`

**Sintoma:** cliente paga, o painel volta pra tela de pagamento e nada é provisionado — mas o Stripe mostra `succeeded` e a assinatura ativa.

**Causa raiz:** não havia endpoint de webhook registrado para o serviço novo. O **único** endpoint registrado na conta era o do serviço legado, que consumiu o `checkout.session.completed` e provisionou **no banco dele**. O serviço novo nunca soube do pagamento.

**Solução:**
1. Confira `GET /v1/webhook_endpoints` **antes** de culpar o código — o evento pode estar sendo entregue a outro serviço da mesma conta.
2. Registrar o endpoint **não basta**: com dois produtos na mesma conta, os dois passam a receber **todos** os eventos. A metadata da sessão costuma ser idêntica entre produtos, então **o `price` é o único discriminador confiável** — filtre por ele no handler dos dois lados.
3. ⚠️ **Nunca deixe "remover recurso" cancelar a assinatura.** A assinatura é o **direito** a uma instância: remover o recurso deve liberar o slot, não encerrar o contrato. Um cliente clicou "Remove" para religar e perdeu, sem refund, o que pagara 40 minutos antes. Cancelar assinatura é ação separada e explícita.
4. Remediação sem cobrar de novo: assinatura nova com `trial_end` cobrindo o período já pago, **reaplicando o cupom** (o desconto não migra sozinho, e cancelamento no Stripe é terminal).

**Ref:** GHL-GOWA-WhatsApp, 2026-07-16. Commit `5e796c2`.
