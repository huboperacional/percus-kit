## Auditar SPA em produção de fora: bata na ROTA INTERNA, nunca em `/` {#auditar-spa-rota-interna}

`tags: SPA, deploy, 404, chunks, bundle, landing page, Next.js, Vite, auditoria externa, curl, falso alarme`

**Origem:** auth-service → Micro Investors, 2026-07-31 — quase virou alarme de "produção fora do ar".

Ao conferir se um fix está no ar, testei `https://app2.<produto>.com/` e achei **os 12 chunks JS
retornando 404**. Conclusão aparente: app quebrado. Errado — `/` era uma **landing Next.js** (SSR,
por isso o conteúdo aparecia) e o app é um **SPA Vite em `/dashboard`**, cujos 6 assets resolvem
`200` normalmente. Dois apps no mesmo host, roteados por path.

- **A regra:** o host raiz frequentemente não é o app. Bata em rota que só existe logado
  (`/dashboard`, `/app`) e confira o **shell** que volta (SPA costuma ser um HTML de ~1-2 KB com
  `<div id="root">`).
- **Sinal de que você está na página errada:** HTML grande com muito texto renderizado (SSR/marketing)
  + chunks que não resolvem; ou `_next/image` respondendo 200 enquanto `_next/static/*` dá 404.
- **Antes de alarmar outro time:** repita com User-Agent de browser, em coletas consecutivas, e
  cheque um segundo host/rota. Alarme falso custa credibilidade — ver [#alarme-falso-mata-o-alarme].
- **Complementar:** pra auditar o **código** de outro repo use a ref publicada
  ([#auditar-outro-repo-ref-publicada]); pra auditar o que está **no ar**, use a rota interna.
