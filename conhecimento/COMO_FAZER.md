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
- [Smoke de fluxo de cartão Pagar.me em PROD sem browser/OTP](#smoke-pagarme-card-sem-browser) — tokenização direta + `docker exec` atento ao `load_dotenv()`
- [Decompor trabalho grande em frentes](#decompor-frentes) — retomada barata + paralelismo real
- [Build Docker frio/lento (Next.js): cache incremental + fontes self-hosted](#deploy-build-cache) — opt-in, pilotar antes de adotar
- [Antes de construir andaime de login, veja se o MCP de browser já está logado](#mcp-browser-perfil-persistente) — 2 navegações no lugar de magic-link server-side
- [Preencher os gatilhos S/N no dia 1 de projeto novo](#gatilhos-dia-1) — transforma silêncio em decisão datada
- [Priorizar perguntas no `grilling` com P0-P4 e camadas](#priorizacao-grilling-p0-p4) — P0/P1 antes de acabamento
- [Rodar checkpoint no próprio percus-kit (canon/tooling, sem PLANO/HANDOFF)](#checkpoint-no-canon-tooling)
- [Fechar subagent-driven-development num worktree nativo do harness (`EnterWorktree`)](#subagent-driven-worktree-nativo) — merge não é `cd` livre; plano tem que estar commitado
- [Negativar concorrentes em conta de mídia paga sem fogo amigo](#negativas-sem-fogo-amigo) — cruze com o catálogo do cliente ANTES; ampla de 2 palavras salva marca ambígua
- [Escapar o mock-scan sem sujar o assunto do commit](#mock-ok-no-corpo) — `MOCK-OK:` casa em QUALQUER linha, não só no assunto
- [Deploy do auth-service com migration nova (`auth-service-deploy.sh`)](#auth-service-deploy-migration-nova) — o script só CHECA divergência, não roda a migration; puxa do `origin/main`, não do working tree local
- [Migration de BACKFILL (versionar row que já existe em prod)](#migration-backfill) — `downgrade` simétrico APAGA row que a migration não criou; leia os valores da row real, não dos defaults

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
rastreável; rodar em pasta sensível (`migrations/`) escala o review pra duplo/triplo. Se a row **já
existe em prod** (inserida à mão num incidente), veja [migration de backfill](#migration-backfill) —
a regra do `downgrade` simétrico se INVERTE ali.

---

## Migration de BACKFILL (versionar row que já existe em prod) {#migration-backfill}

`tags: alembic, migration, backfill, incidente, downgrade, idempotente, ON CONFLICT`

**Quando:** algo foi inserido **direto no banco** pra destravar um incidente (`docker exec`, `psql`
na mão) e nunca virou migration. O banco de prod está certo, mas um rebuild a partir do histórico do
Alembic não teria a row — e o incidente volta.

**Passos:**
1. **Leia a row REAL de produção**, não os defaults do schema nem o que o doc do incidente diz.
   Campo que divergiu do default costuma ser exatamente o que resolveu o incidente.
2. `INSERT ... ON CONFLICT (chave) DO NOTHING` — em prod tem que ser no-op.
3. **`downgrade` = `pass`**, com docstring explicando. Isto é uma **exceção consciente e restrita à
   R6** ("sempre ter `downgrade` rastreável"): a rastreabilidade que a R6 quer está na docstring, não
   num `DELETE` que aqui seria destrutivo. Vale **só** pra backfill de row pré-existente — declare o
   motivo no próprio arquivo pra não virar precedente solto no review. (Detalhe abaixo.)
4. Valide o SQL contra o banco de prod **dentro de transação revertida**: `begin()` → roda o INSERT
   com a chave real (espera `rowcount=0`) → roda com uma chave fake (espera `rowcount=1`) →
   `rollback()`. Depois **releia** e confirme que não sobrou nada. Prova sem mutar prod.

**🔴 A armadilha principal — o `downgrade` simétrico apaga o que você não criou.** A regra normal
("sempre ter `downgrade` rastreável") assume que o `upgrade` criou a coisa. Num backfill isso é
falso: em prod o `upgrade` é no-op porque a row **já estava lá**. Um `DELETE` simétrico então remove
uma row pré-existente, e um rollback de deploy **recria o incidente original**. O Alembic não
consegue distinguir "eu criei esta row" de "ela já estava aqui" — então a escolha segura é não
deletar nunca. O custo é cosmético (num banco de dev do zero, o downgrade deixa a row pra trás); a
alternativa é um caminho automatizado capaz de derrubar o login de um produto em produção.

**Caso real (auth-service, 2026-08-14):** audience `ads4pros-site` inserida à mão em 2026-07-31 pra
matar um `422 invalid_audience`. O backfill `024` nasceu com `DELETE` no `downgrade`; o review
DeepSeek pegou. Os valores certos (`origins=[]`, `otp_require_existing_account=false`) só apareceram
lendo a row de prod — `otp_require_existing_account` no default `true` teria trocado o `422` visível
por um **drop silencioso**, que é pior de diagnosticar.

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

## Smoke de fluxo de cartão Pagar.me em PROD sem browser/OTP {#smoke-pagarme-card-sem-browser}

`tags: pagarme, billing, smoke, cartao, tokenizacao, docker exec, dotenv, prod, cobranca`

**Quando:** validar que um fix no fluxo de cartão (`createCustomer`/`updateCustomer`/`createCard`)
funciona de verdade contra a API real do Pagar.me em produção, sem precisar de uma sessão de
browser autenticada (OTP) nem reimplementar a UI de tokenização.

**Passos:**
1. Confirme `PAGARME_ENV=test` no `.env` de prod (`grep '^PAGARME_ENV=' .env`) — sem isso qualquer
   chamada real vira cobrança de verdade.
2. **Tokenize o cartão direto**, sem browser: `POST {PAGARME_API_BASE_URL}/tokens?appId={PAGARME_PUBLIC_KEY_TEST}`
   com `{"type":"card","card":{"number":"4000000000000010","holder_name":...,"holder_document":...,
   "exp_month":...,"exp_year":...,"cvv":...}}` — cartão de teste aprovado do Pagar.me v5. Isso é
   exatamente o que o JS do form faria no browser; rodar server-side com a chave pública TEST é
   equivalente e evita orquestrar um Playwright autenticado só pra pegar um token.
3. Escreva um script Python curto que importe as funções do client (`pagarmeClient.updateCustomer`/
   `createCard`) e chame com o token do passo 2 + CPF sintético (`123.456.789-09`) + endereço
   fake — replica a lógica exata da rota HTTP sem precisar da sessão/cookie de auth.
4. **Copie o script pro container rodando** (`docker cp script.py <cid>:/tmp/`) e rode com
   `docker exec <cid> python /tmp/script.py` — **não** `docker exec <cid> env` pra checar as vars
   primeiro, ele não mostra nada carregado via `load_dotenv()` (ver
   `feedback-docker-exec-env-hides-dotenv`). O script precisa importar o módulo que dispara o
   `load_dotenv()` (ex. `execution.database.connection`) ANTES de ler `os.environ`, senão
   `PAGARME_PUBLIC_KEY_TEST` etc. vêm `None`/`KeyError` mesmo estando no `.env`.
5. Aponte pra um tenant de teste já existente com `pagarme_customer_id` real (evita `createCustomer`
   novo) e **não persista** o resultado no banco de prod — o smoke só precisa confirmar que a
   chamada de API sucede (`status=active`), não mutar o tenant real.

**Armadilhas:** confundir "está em test mode" com "pode usar dado de terceiro real" — sempre CPF
sintético/cartão de teste documentado, nunca dado de cliente real, mesmo em `PAGARME_ENV=test`;
esquecer o import que dispara `load_dotenv()` faz o script "funcionar" localmente (fora do
container, onde a env já está no shell) e falhar silenciosamente dentro dele.

**Ref:** tiatendo, sessão 2026-08-07 (fechamento do smoke `PAGARME_ENV=test` de O4b, PROD `0.294.0`);
`feedback-docker-exec-env-hides-dotenv`; `#pagarme-erro-rotativo-antifraude` acima (COMO_RESOLVER.md).

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

## Fechar subagent-driven-development num worktree nativo do harness (`EnterWorktree`) {#subagent-driven-worktree-nativo}

`tags: subagent-driven-development, worktree, EnterWorktree, ExitWorktree, merge, plano commitado, harness nativo`

**Quando:** você rodou `superpowers:subagent-driven-development` isolado num worktree criado via
tool nativo do harness (`EnterWorktree`, não `git worktree add` cru) e chegou no fim do plano
(`superpowers:finishing-a-development-branch`, opção "merge local").

**Passos:**
1. **Commite o arquivo do plano ANTES de despachar o 1º subagent.** `writing-plans` salva em
   `docs/superpowers/plans/<data>-<tema>.md` mas não commita por padrão — se você só escreveu com
   `Write` no diretório original e depois entrou no worktree, o arquivo **não existe lá** (worktrees
   nativos compartilham histórico do git, não arquivos não-commitados do checkout de origem).
   Subagents revisores que tentam ler o plano por path vão reportar "arquivo não existe" e cair pra
   avaliar só contra o texto colado no prompt — funciona, mas quebra a rastreabilidade e é fácil de
   só notar no meio da Task 4. `git add` + commit do plano é o passo 0, junto com o `git merge main
   --ff-only` de sincronização.
2. Dentro de uma sessão isolada em worktree nativo, `cd` pro checkout compartilhado é **bloqueado
   pelo próprio harness** (erro explícito: "session isolated... refusing to run"). Isso invalida o
   `MAIN_ROOT=$(...); cd "$MAIN_ROOT"; git merge <branch>` que `finishing-a-development-branch`
   assume — não existe esse `cd` livre aqui.
3. Pra fazer o merge local: `ExitWorktree(action: "keep")` primeiro (preserva branch+worktree em
   disco, sessão volta pro diretório original) → rode `git merge <branch> --ff-only` (ou merge
   normal) de lá → rode a suíte no resultado → só então `git worktree remove <path>` +
   `git worktree prune` + `git branch -d <branch>`.
4. Se o merge falhar ou você quiser voltar a iterar no worktree, `EnterWorktree(path: <path
   original>)` reentra nele — não precisa recriar.

**Armadilhas:** tentar seguir `finishing-a-development-branch` ao pé da letra sem o `ExitWorktree`
primeiro — todo comando `cd`+git fora do worktree vai ser recusado pelo harness, não é erro de
git. Esquecer o commit do plano é sutil: os primeiros subagents (Task 1-2) não notam porque você
colou o texto completo no prompt deles; só aparece quando um revisor tenta `git show`/ler o path
por conta própria pra checar algo que o prompt não cobriu.

**Ref:** sessão tiatendo 2026-08-06 (reconciliação de billing, `worktree-billing-reconciliacao`) —
achado pelo revisor de code-quality da Task 4 ("plan file não existe em lugar nenhum na história
deste worktree"), corrigido commitando o plano no meio da execução; o bloqueio de `cd` foi pego
direto pela mensagem de erro do harness ao tentar `finishing-a-development-branch` sem
`ExitWorktree`.

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

---

## Negativar concorrentes em conta de mídia paga sem fogo amigo {#negativas-sem-fogo-amigo}

`tags: negativas concorrentes google ads palavra-chave conta campanha fogo amigo catalogo`

tags: lista de negativas, negativar concorrente, nível de conta, ampla de 2 palavras, marca ambígua, cruzar com catálogo do cliente, tráfego que deixou de acontecer, erro silencioso

**Quando.** Antes de subir qualquer lista de palavras negativas — em especial em **nível de conta**,
que vale pra todas as campanhas, inclusive as que ainda não existem. Erro aqui é silencioso: você
não vê o tráfego que deixou de acontecer.

### 1. Levante o catálogo real do cliente ANTES de escrever a lista

Nome de concorrente colide com nome de bairro, empreendimento, linha de produto. O cliente é a
fonte da verdade, não a sua intuição. No Paid Media dá pra extrair do próprio rastreamento:

```sql
SELECT DISTINCT regexp_replace(split_part(event_source_url,'?',1),
       '^https?://[^/]+/imovel/','') AS slug
FROM tracking.event_log
WHERE tenant_id = :t AND event_source_url LIKE '%/imovel/%'
  AND created_at >= now() - interval '60 days';
```

Sem tracking, sirva-se do sitemap ou de `landing_page_view` na API do Google Ads.

### 2. Rode uma guarda automática, não uma revisão de olho

Monte a lista de termos-núcleo do negócio e **aborte o script** se algum negativo de uma palavra
cair nela. De-olho não escala e falha justo quando a lista é longa:

```python
PROIBIDO = {"apartamento","terreno","condominio","casa","comercial","venda", ...}  # + bairros
viol = [t for t in TERMOS if PROIBIDO & set(t.lower().split())]
if viol: sys.exit(f"ABORTADO — colide com catálogo do cliente: {viol}")
```

### 3. Marca ambígua entra QUALIFICADA, em ampla de 2 palavras

Negativa **ampla exige TODOS os termos presentes**, em qualquer ordem. Isso é a ferramenta:

| Concorrente | ❌ errado | ✅ certo | Por quê |
|---|---|---|---|
| Imobiliária América | `américa` | `imobiliária américa` | bairro "Jardim América" tem imóvel anunciado |
| Imobiliária Terra | `terra` | `imobiliária terra` | genérico demais |
| Casa Dourada | `casa dourada` | `dourada` | contém "casa"; a palavra rara sozinha já isola |

A regra do meio-termo: **prefira a palavra RARA sozinha** a um par que carregue termo-núcleo.
`dourada` pega os mesmos resultados que `casa dourada` e não encosta em "casa".

### 4. Duas grafias, com e sem acento

Negativa **não casa variação** — nem plural, nem acento, nem erro de digitação. `imobiliaria` e
`imobiliária` são dois critérios. Vale pro par inteiro.

### 5. Confira o inverso: o que a lista ANTIGA já está bloqueando

Auditar o que existe costuma render mais que adicionar. Cruze as negativas atuais com o catálogo —
na UNI achei `[FRASE] central` matando "jardim central" e `[AMPLA] america` matando "jardim américa",
ambos com imóvel anunciado. E **não migre listas herdadas sem ler**: a campanha pausada da UNI
tinha 645 negativas que pareciam patrimônio e continham `apartamento`, `terreno`, `condominio`,
`casa` — aplicá-las teria desligado a conta.

**Ref:** Paid Media Automation, Imobiliária UNI, 2026-08-10. Mecânica de API:
`COMO_RESOLVER.md#google-ads-negativa-conta-sharedset-tipo-proprio`.

## Escapar o mock-scan sem sujar o assunto do commit {#mock-ok-no-corpo}

`tags: mock-scan, MOCK-OK, commit message, git log --oneline, hook pre-commit, escape, assunto limpo`

**Quando:** o hook `mock-scan-pre-commit` bloqueia o commit por achar `TODO`/`todo` no diff, e é
falso positivo — em português "todo/toda" é palavra comum ("roda em TODO turno", "toda linha").

**A crença que estava errada:** que o escape `MOCK-OK:` precisa ser o **prefixo da 1ª linha**. Isso
levou um projeto a ter assuntos de commit como `MOCK-OK: "TODO turno" e portugues -- fix(x): ...`,
e depois a uma operação de reescrita de 7 assuntos pra limpar.

🔴 **CORRIGIDO em 2026-08-11 (plugin v6.35.0) — o escape só é visto DENTRO de um argumento `-m`.**
A versão anterior desta entrada dizia que o hook casa `(?i)\bMOCK-OK:` "sem âncora, em qualquer
linha", e que isso fora verificado passando a mensagem por stdin. **Medido de novo: bloqueia.** O
hook lê a **string do comando Bash** e procura `MOCK-OK:` apenas dentro de `-m "..."` ou `-m '...'`
(`mock-scan-pre-commit.ps1`, as duas linhas de `[regex]::Match($command, '-m\s+…')`). Consequência
prática: mensagem por **stdin/heredoc ou por arquivo (`-F`) NUNCA passa** — não há `-m` na linha de
comando, então o escape é invisível por melhor que esteja escrito.

⚠️ **`PERCUS_SKIP_MOCK_SCAN=1` prefixado no seu comando também não resolve:** o hook roda em
processo separado, e o env do seu Bash não chega nele. Só serve exportado no ambiente do agente.

**Como fazer:** um `-m` por parágrafo, com o **MOCK-OK no segundo** — assim ele vira a 1ª linha do
CORPO e o assunto (`git log --oneline`) continua limpo. Aspas SIMPLES nos parágrafos e aspas DUPLAS
só no do MOCK-OK: o regex casa a **primeira** ocorrência com aspas duplas, então a alternância
garante que ele leia o parágrafo certo.

```bash
git commit \
 -m 'fix(restaurant): evento grava valor literal (C18)' \
 -m "MOCK-OK: o scanner casa TODO turno em portugues (every/all) como placeholder de mock. Nao ha mock no diff." \
 -m 'corpo explicando o que o commit faz' \
 -m 'Co-Authored-By: ...'
```

Motivo em ASCII (o regex mangia acento). Sem aspas simples DENTRO dos parágrafos (bash não deixa) e
sem aspas duplas dentro do parágrafo do MOCK-OK (o `[^"]+` para na primeira).

🪤 **Ao EDITAR esta entrada:** escrever a receita via heredoc no Bash tool dispara o hook
`pre-commit-check`, porque o texto contém a string `git commit` e a guarda casa a MENSAGEM, não a
ação (ver `COMO_RESOLVER.md#guarda-casa-a-mensagem-nao-a-acao`). Use a ferramenta de edição de
arquivo, não `cat`/heredoc.

**Ref:** tiatendo, frente C18 (2026-08-11) e correção na frente C20 (mesmo dia, plugin v6.35.0). R23.

---

## Deploy do auth-service com migration nova (`auth-service-deploy.sh`) {#auth-service-deploy-migration-nova}

`tags: auth-service, deploy, alembic, migration, skip-migration-check, git pull, origin main, rollout, health 502, health 504, rolling restart, secret reconcile`

**Quando:** commit que adiciona código E uma migration Alembic nova ao mesmo tempo (ex.: registrar
uma audience nova) e o deploy vai por `auth-service-deploy` (symlink pro script versionado em
`D:\Claud Automations\auth-service\deploy\scripts\`).

**O que o script NÃO faz (armadilha #1):** ele só **compara** o head esperado (maior arquivo em
`alembic/versions/`) contra `alembic_version` no banco, lido via `docker exec` no container **que
já está rodando** (a imagem VELHA). Se divergir, ele **aborta** com `FATAL: migration head
divergence` e sugere `docker exec "$C" python -m alembic upgrade head` — mas essa sugestão só
funciona se o container atual **já tiver** o arquivo da migration nova no disco, o que não é o caso
na primeira vez (a migration só existe na imagem NOVA, ainda não buildada).

**Armadilha #2:** o script começa com `git pull --ff-only origin main` — ele deploya o que está no
**GitHub remoto**, não o seu working tree local. Um commit local sem `push` simplesmente não entra
no deploy (o script segue em frente com o código antigo, sem avisar que "ignorou" seu commit).

**Passos corretos, nessa ordem:**
1. `git push origin main` (o commit com código + migration precisa estar no remoto).
2. `auth-service-deploy --skip-migration-check` — deixa o script **buildar e fazer o rollout** da
   imagem nova mesmo com o head divergente. Seguro **só se a migration for puramente aditiva**
   (`INSERT ... ON CONFLICT DO NOTHING`, sem DDL que quebre queries do código velho ainda em voo
   durante o rolling update).
3. **Depois** do rollout convergir, rode a migration contra o container **novo**:
   ```bash
   C=$(docker ps --filter name=auth_service_api --format '{{.Names}}' | head -1)
   docker exec "$C" python -m alembic upgrade head
   ```
   Confira o log: tem que aparecer `Running upgrade <de> -> <para>, <mensagem>` — se não aparecer
   nada além das duas linhas de `Context impl`/`transactional DDL`, a migration **não rodou**
   (alembic achou que já estava em head porque leu o arquivo errado) — verifique direto no banco
   (`SELECT version_num FROM alembic_version`) antes de seguir.
4. Reconfirme com o critério de pronto do seu pedido (query da row, `cors-smoke.sh`, endpoint real).

**🔴 Armadilha #2b — `alembic_version.version_num` é `VARCHAR(32)`.** Nome de revision com mais de
32 caracteres passa em tudo (arquivo criado, imagem buildada, rollout OK) e só explode no **UPDATE
final** do `upgrade`, com `StringDataRightTruncation`. A transação reverte inteira — banco fica no
head anterior, sem aplicação parcial —, mas você já queimou um build+rollout. **Conte os caracteres
antes**, e se precisar renomear, mude o **nome do arquivo e o campo `revision` juntos**: o script
deriva o head esperado do nome do arquivo, então mudar só um faz o head check comparar coisas
diferentes. Caso real: `024_ads4pros_site_audience_backfill` (35) → `024_ads4pros_site_backfill`
(26), auth-service 2026-08-14. A convenção `NNN_nome_descritivo` do projeto já roça o teto —
`023_empresa_milionaria_audience` tem 31.

**Armadilha #3 (não entre em pânico):** logo após `docker service update --force --image ...`, o
smoke do PRÓPRIO script (`sleep 3` + `curl /health`) costuma pegar a janela do rolling restart —
**502/504 nos primeiros ~30-60s são normais**, os dois replicas ainda estão de pé/derrubando.
Antes de tratar como outage: `docker service ps auth_service_api` (replicas `Running` há segundos =
janela normal) + `curl /health` de novo depois de meio minuto. Só é incidente real se continuar
falhando depois disso.

**Ref:** registro da audience `empresa-milionaria`, auth-service 2026-08-14 (commit `b66b306`,
deploy `deploy-1786709899`). Script: `deploy/scripts/auth-service-deploy.sh` (comentário no topo do
próprio arquivo documenta o fluxo, mas não a ordem skip-check→build→migrate-pós-rollout).
