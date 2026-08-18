## `NEXT_PUBLIC_*` não aparece no bundle client em prod {#next-public-baked-build}

`tags: next.js, next_public, env, build arg, dockerfile, inline, bundle, client, ga4, gtag, compose runtime`

**Contexto:** setei `NEXT_PUBLIC_GA_ID` no bloco `environment:` do docker-compose (runtime) e a feature (banner/GA) ficou **inerte em prod** — o componente client leu `undefined`. (Falha *safe*, mas a feature não funciona.)

**Causa raiz:** `NEXT_PUBLIC_*` é **inlined no bundle em BUILD time** (`next build`), não lido em runtime. Uma env var só presente no compose/runtime nunca chega ao bundle client já compilado.

**Solução:** passar a var no **build** — no `Dockerfile`, `ARG NEXT_PUBLIC_FOO` + `ENV NEXT_PUBLIC_FOO=$NEXT_PUBLIC_FOO` ANTES do `RUN npm run build` (default no ARG pra valores públicos como um GA Measurement ID; `--build-arg NEXT_PUBLIC_FOO=` vazio pra desabilitar em staging). Sintoma de detecção: `curl <chunk _next/static>.js | grep <valor>` — se não achar, não foi baked.

**Ref:** huboperacional-site GA4 (2026-07-14); achado de code-review; memória `deploy-vps-gotchas`.
