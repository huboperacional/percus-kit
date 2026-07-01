# Como Fazer — padrões-base / procedimentos (cross-projeto)

> Procedimentos recorrentes que valem pra qualquer projeto Percus. Não é troubleshooting (isso é o
> [`COMO_RESOLVER.md`](COMO_RESOLVER.md)) — é "qual é a forma canônica de fazer X". Fonte da verdade =
> git; sincroniza via `git pull`. Skill de consulta: `percus-review:consult-knowledge`.
>
> **Formato de cada entrada:** `## <objetivo>` · `tags:` · **Quando** · **Passos** · **Comando** ·
> **Armadilhas**. Mantenha curto; linke pro doc canônico em vez de duplicar.

---

## Índice

- [Commitar no canon / projeto (com review obrigatório R11)](#commit-com-review)
- [Consultar o conselho (consult / pre-mortem / analyze)](#rodar-conselho)
- [Subir uma migration Alembic](#migration-alembic)
- [Deploy na VPS Percus](#deploy-vps) — cadência R24 + playbook `comandos/DEPLOY.md`
- [Decompor trabalho grande em frentes](#decompor-frentes) — retomada barata + paralelismo real
- [Build Docker frio/lento (Next.js): cache incremental + fontes self-hosted](#deploy-build-cache) — opt-in, pilotar antes de adotar

---

## Commitar no canon / projeto (com review obrigatório R11) {#commit-com-review}

`tags: git, commit, review, R11, pre-commit, push, canon, co-authored`

**Quando:** qualquer commit que toca código ou docs do canon.

**Passos:**
1. Rode o review **antes** do commit (R11 — hook bloqueia se não houver review nos últimos 5 min):
   `pwsh -File "${env:PERCUS_CANON_DIR}\scripts\percus-review-auto.ps1"` (ou `.sh` no Unix).
2. Se o stderr trouxer `__PERCUS_NEEDS_CROSS_CLAUDE__`, dispare o subagent Sonnet e salve em
   `.deepseek/reviews/<ts>-cross-claude.jsonl`.
3. Trate findings de bug/regressão antes de commitar; "preferência de estilo" pode ignorar (declare).
4. Commit com trailer de autoria. Multi-linha em PowerShell: here-string single-quoted `@'...'@`.

**Comando (trailer canônico):**
```
Co-Authored-By: Claude <noreply@anthropic.com>
```
Se aplicou saída do wrapper DeepSeek (R13): adicione `Co-implemented-by: deepseek-v4`.
Se marcou `[5-T]`: adicione `CRUD-verified: YYYY-MM-DD HH:MM`.

**Armadilhas:** nunca `--no-verify`; nunca commitar sem review fresco; em `main` do canon, branch antes
se for mudança grande. Ver `COMO_RESOLVER.md#origin-stale-resume` (fetch+compare origin antes).

---

## Consultar o conselho (consult / pre-mortem / analyze) {#rodar-conselho}

`tags: council, conselho, consult, pre-mortem, analyze, orchestrator, temp file, stale`

**Quando:** decisão reversível de baixo risco (`consult`), validar plano antes de ExitPlanMode
(`pre-mortem`), ou validar spec de feature antes do `[0]` (`analyze`).

**Passos:**
1. Escreva o prompt num **arquivo temp único** (nunca nome fixo — ver `COMO_RESOLVER.md#conselho-prompt-stale`).
2. Rode o orchestrator com o `-Mode` certo e os providers (2 default; +cross-claude se sensível).
3. Se `__PERCUS_NEEDS_CROSS_CLAUDE__`: dispatch subagent, salve em temp único, re-invoque com `-CrossClaudeFile`.
4. Leia o log em `.deepseek/council-log/<ts>-<mode>.jsonl` e sintetize.

**Comando:**
```powershell
$Q = Join-Path $env:TEMP "council-$([guid]::NewGuid().ToString('N')).txt"
Set-Content -LiteralPath $Q -Value $prompt -Encoding utf8
pwsh -File "${CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.ps1" -PromptFile $Q -Mode <consult|pre-mortem|analyze> -Providers "deepseek,groq-llama"
Remove-Item -LiteralPath $Q -Force
```

**Armadilhas:** nome de arquivo fixo → prompt stale; escalar finding não-verificado pro conselho sem
fact-check (R20). Ver `06_CONSELHO_PERCUS.md` (5 modos).

---

## Subir uma migration Alembic {#migration-alembic}

`tags: alembic, migration, schema, postgres, banco, upgrade, R6`

**Quando:** criar/alterar tabela (gate `[0]→[1-S]` do feature-flow).

**Passos:**
1. Gere a revision: `alembic revision -m "descricao"` (ou `--autogenerate` se os models batem).
2. Revise o `upgrade()`/`downgrade()` gerado — autogenerate erra em índices/enums.
3. Aplique: `alembic upgrade head`.
4. Verifique a tabela existe: `psql -c "\d nova_tabela"`.
5. Atualize o PLANO → `[1-S]`.

**Armadilhas:** SQL bruto sem Alembic = violação R6 (CRITICAL no review); sempre ter `downgrade`
rastreável; rodar em pasta sensível (`migrations/`) escala o review pra duplo/triplo.

---

## Deploy na VPS Percus {#deploy-vps}

`tags: deploy, vps, traefik, docker, swarm, portainer, stack, rollback, producao, cadencia`

**Quando:** **fim de milestone**, **fim do dia**, ou **sob demanda** do operador — **nunca a cada
feature** (R24). Sempre com confirmação (R5) + smoke + rollback pronto.

**Passos (resumo — playbook completo em `comandos/DEPLOY.md`):**
1. Gate pré-deploy: o que vai está `[5-T]`; milestone passou no `milestone-review`; HANDOFF reflete; confirmação R5; sei a versão atual (rollback).
2. Atualizar a stack via **Portainer** (`https://painel.huboperacional.com.br`): `PUT /api/stacks/{ID}?endpointId=1`
   com `stackFileContent` + `prune:true` (+ `pullImage:true` se imagem nova). Detalhe CSRF/swarmId em `02_INFRA` §10.
   - Só mudou config/secret? `ForceUpdate++` no serviço (restart sem rebuild).
3. **Smoke:** `curl -I https://<sub>.huboperacional.com.br` (não 5xx/520) + `docker service logs <stack>_<svc> --tail 50` + rota crítica.
4. Registrar no HANDOFF "deployado {data} — {o quê}".

**Comando (rollback Swarm — tenha pronto antes):**
```bash
docker service rollback <stack>_<servico>    # reverte pro spec anterior
# migration envolvida? testar `alembic downgrade -1` em dev ANTES de deployar.
```

**Armadilhas:** deploy per-feature (R24); 520 no curl = DNS "Proxied" no Cloudflare (tem que ser **DNS
only**, `02_INFRA` §8); pular smoke; migration sem `downgrade` testado; deployar o que não é `[5-T]` sem o
operador autorizar o risco.

**Ref:** `comandos/DEPLOY.md` (playbook), `02_INFRA_E_STACK_PERCUS.md` §6-10, R24.

---

## Decompor trabalho grande em frentes {#decompor-frentes}

`tags: frentes, decompor, cascata, retomada, contexto, checkpoint, paralelismo, worktree, plano`

**Quando:** um milestone/épico grande demais pra tocar numa aba só, ou que gargala na retomada de sessão.

**Passos:**
1. **Precisa só retomar barato** (perder menos contexto entre sessões)? Já é nativo: escreva o estado em
   frentes no `templates/PLANO.template.md` (frente é conceito de 1ª classe lá) + use `/checkpoint` e o
   hook PreCompact (v6.19). Não crie estrutura de arquivos nova.
2. **As frentes são genuinamente independentes e você quer rodá-las em paralelo** (2-4 abas, wall-clock)?
   Use `comandos/COMANDO_FRENTES_PARALELAS.md` (worktrees + aba-diretora + writer-unique). Requer fundação
   `[5-T]` merged antes.
3. **Nenhum dos dois** (é serial e cabe numa aba)? Fluxo normal (`feature-flow`), sem cerimônia.

**Armadilhas:** **não** invente um mecanismo "cascata" separado (arquivos aninhados
`docs/plans/<milestone>/<frente>.md` com métrica de retomada) — foi avaliado e **aposentado na v6.27.0**:
o eixo retomada já é checkpoint/PreCompact, o eixo decomposição já é o `PLANO.template`, e o paralelismo
é o `COMANDO_FRENTES_PARALELAS`. Reintroduzir seria duplicar (viola R25).

**Ref:** `CANON_VERSION.md` changelog v6.27.0; `comandos/COMANDO_FRENTES_PARALELAS.md`; skill `checkpoint`.

---

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

---

> **Nova entrada?** Copie o bloco-modelo, preencha e adicione no Índice.
>
> ```
> ## <objetivo> {#ancora-kebab}
> `tags: termo1, termo2, componente`
> **Quando:** situação que dispara.
> **Passos:** 1. ... 2. ...
> **Comando:** `...`
> **Armadilhas:** o que costuma dar errado.
> ```
