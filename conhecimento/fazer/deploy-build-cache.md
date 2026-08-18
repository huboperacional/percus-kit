## Build Docker frio/lento (Next.js): cache incremental + fontes self-hosted {#deploy-build-cache}

`tags: deploy, docker, buildkit, cache, next, nextjs, next/font, fonte, build lento, build frio, ci`

> **Status: opt-in — pilotar antes de adotar como padrão.** Recipe comprovado em produção fora do canon;
> ainda não rodado dentro de um projeto Percus canônico. É **melhoria aditiva**, não muda a base/convenção.

**Quando:** app Next.js deployado como imagem Docker cujo `next build` refaz do zero (~7-8 min) a cada
deploy. Duas causas atacáveis: fetch de fonte no build + ausência de cache incremental.

**Passos:**
1. **Fontes self-hosted** (elimina fetch de rede no build, que quebra o cache/DNS do BuildKit): para cada
   fonte usada via `next/font/google`, baixe o woff2 **variável** (latin) pra `app/fonts/` (ou `src/fonts/`)
   de `https://cdn.jsdelivr.net/fontsource/fonts/<FONTE>:vf@latest/latin-wght-normal.woff2`. Troque os
   imports `next/font/google` → `next/font/local`, mantendo os **mesmos** `variable: '--...'`,
   `display:'swap'` e um `weight` em range (ex.: `'300 700'`).
2. **Cache incremental no Dockerfile** (BuildKit): `# syntax=docker/dockerfile:1` na 1ª linha; no estágio
   de deps `RUN --mount=type=cache,target=/root/.npm npm ci`; no estágio de build
   `RUN --mount=type=cache,target=/app/.next/cache npm run build` (ajuste `/app` ao WORKDIR).
3. **Build com BuildKit:** `DOCKER_BUILDKIT=1` no comando de build; `--network=host` se o DNS da bridge
   Docker estiver quebrado na VPS.
4. **Validar:** `npm run typecheck` (se existir) + `npm run build` local passam; fontes renderizam iguais.

**Comando (verificar o woff2 baixado):**
```bash
file app/fonts/*.woff2    # deve dizer "Web Open Font Format"
```

**Armadilhas:** pré-requisito é **BuildKit habilitado** (Docker ≥23 é default; a VPS Percus roda 28.5.2 —
confirmar). O **1º build ainda é frio** (popula o cache); a queda pra ~1-3 min vem do **2º** em diante.
Não altere lógica de página, só fontes + Dockerfile. Não canonize num projeto sem rodar o passo 4 primeiro.

**Ref:** recipe do operador (deploy em produção real); `comandos/DEPLOY.md` (anti-padrão `next/font/google`).
