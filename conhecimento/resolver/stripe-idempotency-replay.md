## Guard anti-dupla-cobrança com idempotency do Stripe não dispara (a key REPLICA a resposta cacheada) {#stripe-idempotency-replay}

`tags: stripe, idempotency, idempotencyKey, checkout session, dupla cobranca, double charge, webhook lag, replay, retrieve, url null, expired, complete, 409`

**Sintoma:** você guarda contra dupla cobrança fazendo `sessions.create(params, { idempotencyKey })` e depois `if (!session.url) return 409 /* já pagou */`. O ramo do 409 **nunca dispara** — e o teste dele passa, porque mocka `url: null` (mocka a conclusão).

**Causa raiz:** **idempotency do Stripe é cache de resposta, não re-avaliação.** A doc é explícita: ele **salva o status+body da 1ª requisição** e devolve **o mesmo resultado** nas seguintes. Como a Checkout Session **nasce ativa**, o body cacheado tem `url` preenchida — então o replay devolve essa **`url` velha e não-nula mesmo depois do cliente pagar**. O `url: null` vale pro **`retrieve` ao vivo** (o SDK documenta: *"This value is only present when the session is active"*), **não pro replay do `create`**.

**O que a key resolve de fato:** o replay devolve **a mesma sessão**, e **Checkout Session é de uso único** — o Stripe não deixa pagar duas vezes a mesma sessão. **É isso** que barra a 2ª cobrança, não o `url`.

**Solução:** usar o `create` idempotente só pra obter a mesma sessão, e perguntar o status **ao vivo**:

    const session = await stripe.checkout.sessions.create(params, { idempotencyKey });
    const live = await stripe.checkout.sessions.retrieve(session.id);
    if (live.status === 'complete') return 409;                    // pagou de verdade
    if (live.url) return { url: live.url };                        // aberta
    const fresh = await stripe.checkout.sessions.create(params);   // expirada = NINGUÉM pagou
    return { url: fresh.url };

**Gotchas:**
- ⚠️ **`expired` NÃO é `complete`.** 409 numa sessão expirada **bloqueia um comprador disposto** — erro tão caro quanto cobrar 2×. Trate os dois status separadamente.
- **Params entram na key:** replay com a mesma key e **params diferentes** faz o Stripe **rejeitar a requisição**. Se o preço muda, a key tem que mudar → embutir os price ids na key.
- **Key derivada de input opcional colide:** montar a key com `niche ?? ''` / `slug ?? ''` faz um body vazio virar `offer:::…` — **key compartilhada entre requisições distintas** → o Stripe entrega a sessão de um comprador a outro. **Validar a entrada (400) antes de compor a key.**
- **Duas chamadas concorrentes** com a mesma key → erro de *concurrent idempotent request* (não duplicata). Sem `try/catch` vira 500.
- **O 409 do guard precisa de UI própria.** Se o cliente cair no `catch` genérico, quem **acabou de pagar** lê "Something went wrong, please try again" — o convite exato pra 2ª cobrança. E não trate **qualquer** 409 como "já pagou": um 409 de WAF/rate-limit diria "tudo certo" a quem não pagou. Gate no **seu próprio marcador** (`error === 'already_paid'`).

**Ref:** ads4agencies-site `app/api/checkout/route.ts`, commit `ad1c0ef` (2026-07-15); memória `reference_stripe_idempotency_replica_resposta_cacheada`. Achado pelo review Cross-Claude **depois** de a 1ª versão do fix ir pro tree apoiada na premissa errada.
