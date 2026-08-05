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
- [Antes de construir andaime de login, veja se o MCP de browser já está logado](#mcp-browser-perfil-persistente) — 2 navegações no lugar de magic-link server-side
- [Preencher os gatilhos S/N no dia 1 de projeto novo](#gatilhos-dia-1) — transforma silêncio em decisão datada
- [Priorizar perguntas no `grilling` com P0-P4 e camadas](#priorizacao-grilling-p0-p4) — P0/P1 antes de acabamento
- [Rodar checkpoint no próprio percus-kit (canon/tooling, sem PLANO/HANDOFF)](#checkpoint-no-canon-tooling)

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
2. **De onde vem a imagem** — isso decide o resto do passo; o canon **não presume registry**:
   - **Imagem em registry:** `PUT /api/stacks/{ID}?endpointId=1` no **Portainer**
     (`https://painel.huboperacional.com.br`) com `stackFileContent` + `prune:true` + `pullImage:true`.
     Detalhe CSRF/swarmId em `02_INFRA` §10.
   - **Imagem buildada no próprio nó** (sem registry): build na VPS com a **mesma tag** que está no spec
     do serviço, e `docker service update --force --no-resolve-image --image <tag> <stack>_<svc>` —
     `--no-resolve-image` usa a imagem **local** em vez de tentar resolver digest no registry.
     O arquivo de stack do projeto (`docker-compose.swarm.yml` ou equivalente) continua sendo o
     **estado desejado**: bumpe o `image:` e **commite**, senão o próximo `stack deploy` limpo volta
     pro sha antigo — e o serviço em `:latest` re-resolve pra imagem stale no primeiro reschedule.
   - Só mudou config/secret? `ForceUpdate++` no serviço (restart sem rebuild) — vale nos dois caminhos.

   > **2026-07-28:** o GH Actions da org `huboperacional` está **desativado por decisão de custo**
   > (`build-and-push.yml` em `disabled_manually`), então **build-no-nó é o caminho corrente** onde havia
   > registry. O GHCR guarda imagens antigas: serve de **rollback profundo**, não de estado atual.
   > O procedimento **específico** de cada projeto mora no runbook DELE (ex.:
   > `Paid Midia Automation/docs/RUNBOOK_DEPLOY.md`) — este verbete é a **regra de decisão**, não a cópia.
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
   frentes no `templates/PLANO.template.md` (frente é conceito de 1ª classe lá) + use a skill `checkpoint` e o
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

## Antes de construir andaime de login, veja se o MCP de browser já está logado {#mcp-browser-perfil-persistente}
`tags: chrome-devtools-mcp, playwright-mcp, sessao, autenticacao, perfil persistente, list_pages, OTP, magic-link, E2E, captura de tela`

**Quando:** você precisa navegar num app autenticado (o seu ou o de um concorrente) para capturar telas
ou exercitar fluxo, e o login é OTP/2FA — ou seja, "depende do operador".

**Passos:**
1. `list_pages` → se aparecer `about:blank`, o MCP subiu um Chrome **próprio**, não anexou ao teu.
2. **Mesmo assim, navegue para o app antes de concluir que não há sessão.** O Chrome do MCP costuma
   usar um **perfil persistente** — os cookies de sessões anteriores do operador podem estar lá.
3. O sinal de sucesso é a **URL final**: se `https://app/` redirecionou para `/dashboard` em vez de
   `/login`, a sessão está viva. Um snapshot que mostra o shell do app confirma.
4. Só se cair no `/login` monte o andaime (magic-link server-side, seed de org descartável, etc.).

**Comando:** `list_pages` → `navigate_page(url)` → conferir a URL devolvida.

**Armadilhas:** o caminho contrário custou caro numa sessão — eu já tinha lido o runbook de magic-link,
localizado o script, e estava a um passo de mintar credencial em produção para uma identidade
**adivinhada por e-mail** (o que criaria identidade nova em vez de logar como a pessoa). Duas
navegações resolveram o que o andaime não resolveria. Corolário: **org descartável semeada não serve
para revisão de densidade/estética** — tela vazia dá leitura falsa; para julgar layout você precisa da
org real, com dado real.

**Ref:** Plexco Tasks s156 (deep-dive ClickUp × Plexco, 28 capturas em 2 produtos autenticados).

---

## Preencher os gatilhos S/N no dia 1 de projeto novo {#gatilhos-dia-1}

`tags: gatilhos, discovery, multi-tenant, dado regulado, LGPD, persistencia, endpoint publico, CLAUDE.md, greenfield, MDS`

**Quando:** passo 2 de `comandos/COMANDO_PROJETO_NOVO.md`, ao gerar `CLAUDE.md` a partir do
template — antes de qualquer código.

**Passos:**
1. Responda as 4 linhas da mini-tabela "Gatilhos de projeto" em `CLAUDE.md` (herdada de
   `templates/CLAUDE.template.md`): persistência? multi-tenant? dado regulado (LGPD/HIPAA/PCI)?
   endpoint público?
2. Gatilho que não dispara **exige** "N/A, motivo em 1 linha" — nunca deixe em branco.
3. Use `v2/loops/grilling.md` (camada "Gatilhos estruturais", `v2/referencia/discovery-camadas.md`)
   se a resposta não for óbvia de cara.

**Armadilhas:** decidir de cabeça sem escrever — o valor inteiro do gatilho é a decisão **datada**,
não a decisão em si. Caso real que ancora o custo de mudar tenancy tarde (não de "decisão
silenciosa" — a decisão original foi deliberada, o caro foi mudar depois de já estar em
produção): Micro Investors precisou provisionar um 2º tenant por duplicação física de banco,
meses depois do produto já estar rodando single-tenant (ver
`COMO_RESOLVER.md#tenant-novo-cadeia-migrations-quebrada`). Não adicione gatilho novo à tabela
por especulação — só depois de retrabalho comprovado uma vez.

**Ref:** `06_CONSELHO_PERCUS.md` seção "Mapeamento MDS ↔ Percus".

---

## Priorizar perguntas no `grilling` com P0-P4 e camadas {#priorizacao-grilling-p0-p4}

`tags: grilling, elicitacao, discovery, prioridade, P0, P1, camadas, rodadas, cobertura, escopo`

**Quando:** qualquer sessão de `v2/loops/grilling.md` — feature não-trivial ou projeto novo.

**Passos:**
1. Antes de perguntar, classifique a categoria da pergunta usando o catálogo de 14 camadas em
   `v2/referencia/discovery-camadas.md` (Problema, Atores, Aposta/Horizonte, Escala/Porte,
   Gatilhos estruturais, Fluxo, Regras de negócio, Estados, Exceções, Integrações, Operação,
   Segurança, Critérios de aceite — mais Objetivo/Resultado).
2. Priorize por `Impacto × Incerteza × Risco ÷ Custo`: P0 (muda arquitetura) e P1 (pode causar
   retrabalho) sempre antes de P3/P4 (acabamento/preferência).
3. Agrupe em rodadas de 5-8 perguntas com objetivo de 1 frase declarado.
4. Pare quando: cobertura ≥85% das camadas relevantes, zero lacunas P0, riscos P1 com decisão ou
   mitigação registrada, fluxo principal descritível ponta-a-ponta.

**Armadilhas:** tratar "já perguntei bastante" como critério de parada — é sensação, não medida.
Pular P0/P1 pra chegar mais rápido nas perguntas de acabamento é o erro mais caro: uma pergunta
de alto impacto respondida por último custa retrabalho se a resposta já tiver sido pressuposta
em decisões anteriores da mesma conversa.

**Ref:** `v2/referencia/discovery-camadas.md`; framework de origem discutido pelo operador com
GPT, cross-validado contra o MDS na mesma sessão (2026-08-04).

---

## Rodar checkpoint no próprio percus-kit (canon/tooling, sem PLANO/HANDOFF) {#checkpoint-no-canon-tooling}

`tags: checkpoint, percus-kit, canon, tooling, PLANO.md, HANDOFF.md, resume prompt, clear, compact`

**Quando:** a skill `percus-review:checkpoint` é disparada dentro do próprio repo `percus-kit`
(não num projeto-produto que consome o canon).

**Passos:**
1. **Não procure `docs/PLANO.md`/`HANDOFF.md`/`docs/mock-audit.md` na raiz** — não existem aqui
   de propósito. O hook `SessionStart` do próprio kit já declara isso: "Se eh canon/lib/tooling,
   ignore" o gate de HANDOFF/PLANO. Confirme com `Test-Path`/`ls` antes de assumir drift.
2. O equivalente de "PLANO" aqui é a seção `## ESTADO DA EXECUÇÃO` dentro do
   `docs/superpowers/plans/<data>-<tema>.md` de cada iniciativa em andamento — sincronize essa
   seção, não um PLANO.md inexistente.
3. Capture conhecimento novo (R23) normalmente em `COMO_RESOLVER.md`/`COMO_FAZER.md`.
4. Commit com review (R11) normalmente.
5. O "prompt de retomada" do passo 4 do checkpoint ainda se aplica — só troca "RELEIA PRIMEIRO:
   HANDOFF.md → docs/PLANO.md" pelos planos/branches relevantes da sessão (com caminho absoluto).

**Armadilhas:** tratar a ausência de PLANO/HANDOFF como um problema a corrigir (criar os arquivos
"pra seguir o padrão") — é o oposto do que o hook e a Constituição pedem pro kit em si.

**Ref:** `.claude/settings.json` do próprio kit (hook `SessionStart` `[GATE INICIO]`, que declara
a exceção "Se eh canon/lib/tooling, ignore").

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
