## Árvore obsoleta no dir de deploy do VPS reprova `next build` — `docker builder prune` NÃO é o fix {#docker-context-stale-tree-recorrencia}

`tags: docker, dockerfile, COPY . ., build context, next build, typecheck, arvore obsoleta, stale tree, dockerignore, buildkit cache, docker builder prune, vps deploy`

**Sintoma.** `next build` no VPS reprova com um type error real, num arquivo real, apontando um trecho que bate com o que você acabou de mudar — mas a mudança JÁ está correta no seu commit (confirmado lendo `git show HEAD:<arquivo>` e o mtime do arquivo extraído). Rodar `docker builder prune -a -f` (limpar TODO o cache do BuildKit, dezenas de GB) e buildar de novo reproduz **o mesmo erro, idêntico**.

**Causa raiz.** O `Dockerfile` faz `COPY . .` no build context (`/opt/<projeto>` no VPS), e esse diretório acumula **árvores obsoletas de deploys anteriores** — uma pasta de extração de uma rodada de dias/semanas atrás que ninguém apagou. `next build` faz typecheck de TUDO que está em `/app` depois do `COPY`, incluindo essas sobras. Uma cópia antiga de um arquivo que você mudou (ou de um arquivo que consome esse arquivo, com tipos incompatíveis entre a versão velha e a nova) reprova o build com erro em código que **não está no git e nunca roda**.

**Por que `docker builder prune` não resolve — e por que isso é o sinal, não o fix.** `--mount=type=cache` (cache do `npm run build`) e a árvore obsoleta são duas coisas diferentes: a árvore obsoleta é um **arquivo real sentado no build context**, não um cache do BuildKit. Limpar o cache e reproduzir o erro idêntico é justamente a prova de que NÃO é problema de cache — é hora de olhar o **prefixo do path** no erro, não a linha.

**Diagnóstico rápido (mais rápido que rebuildar Docker toda vez).** Se o VPS tem `node`/`npm` fora do Docker (`which node`), rode `npm ci` direto no build context do host e depois `npx tsc --noEmit -p .` ali — isola em segundos se o erro é do Docker context (árvore obsoleta/`.dockerignore` incompleto) ou do código de verdade, sem esperar um build completo (~2min) a cada tentativa.

**Padrão: isto SEMPRE volta com um nome novo.** Primeira ocorrência documentada (2026-07-30): `build-src/`. Segunda (2026-08-11): `src-extract/`. Cada rodada de deploy que usa uma convenção de extração diferente (ou um humano/agente que testou manualmente e nomeou a pasta do jeito que quis) planta uma bomba-relógio nova. `.dockerignore` com uma lista de nomes conhecidos (`build-src`, `build`, `src-extract`, `src.tgz`) ajuda mas **nunca fecha definitivamente** — é uma lista que só cresce reativamente.

**Solução:**
1. Achar e apagar a árvore obsoleta especificamente (não um `rm -rf` amplo — ver [[reference_vps_deploy_dir_rm_rf_deletes_untracked_env]] pro motivo).
2. Adicionar o nome ao `.dockerignore` como defesa-em-profundidade pro futuro.
3. Rebuildar.

**Ref:** 2026-07-30 (`build-src/`, ads4agencies-site) + recorrência 2026-08-11 (`src-extract/`, mesmo projeto, sessão scraper-prospeccao). R23. Memória do projeto: `reference_docker_context_stale_tree_fails_build`.
