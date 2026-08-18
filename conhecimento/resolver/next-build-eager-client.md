## Next `next build` quebra ("Failed to collect page data") com client instanciado no top-level {#next-build-eager-client}

`tags: next, nextjs, app router, build, docker, stripe, collect page data, useContext, standalone, route handler, env, secret, lazy, getStripe`

**Sintoma:** `next build` (produção/container) falha com `Failed to collect page data for /api/<rota>` (às vezes acompanhado de stack em `webpack-runtime`). O `next dev` funciona normal, e por isso "verifiquei no dev, tá 200" **não** garante que o build passa. Frequente em deploy de container (1º build real).

**Causa raiz:** o `next build` **avalia (importa) os módulos das rotas** na fase "collect page data" — **sem os secrets de runtime**. Se uma lib importada pela rota **instancia no top-level** um client que **joga quando falta credencial**, o import explode e o build morre. Caso clássico: `export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)` — no build `STRIPE_SECRET_KEY` é undefined e o construtor do Stripe joga. Vale pra qualquer SDK que exija credencial no construtor (Stripe, alguns clients GHL/AWS/etc.).

**Solução:** **lazy-init** — construir sob demanda, nunca no import.
```ts
let _stripe: Stripe | null = null;
export function getStripe(): Stripe {
  if (!_stripe) _stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '...' });
  return _stripe;
}
```
e trocar `stripe.x` → `getStripe().x` nos call-sites. Constantes que só **leem** env (`const PRICES = process.env.X!`) não jogam no import → não precisam de lazy. **Não confundir** com o outro modo de falha ("useContext null" no prerender sob Node ≥22/24 — esse resolve buildando em Node 20; ver memória `reference_next14_node24_build_usecontext`). Se der "collect page data", suspeite primeiro de client eager, não de versão de Node.

**Ref:** ads4agencies-site 1º build de container 2026-07-12 (`lib/stripe.ts` → `getStripe()`); commit `ee8b7d6`; memória `reference_next_build_eager_stripe_client`.
