# Migração V1 → V2 — o que já mudou de casa

> **Regra nº 1 do V2: aditivo, não paralelo.** O V2 nasce só com o núcleo novo.
> Tudo que ainda não migrou **aponta para o V1** (a raiz deste repo) — não se copia nada.
> Copiar é herdar a acumulação de 3.262 linhas que motivou o greenfield.

**Casa canônica (desde 2026-07-20): `percus-kit/v2/`** — dobrado pra dentro do percus-kit
pra pegar carona no `git pull` que já alcança as 10 máquinas. A pasta avulsa onde o
experimento nasceu foi apagada em 2026-07-30; a história dela (8 commits, repo sem remote)
está preservada em `.archive/v2-experimento-standalone.bundle` — ver `.archive/README.md`.

**Binding nos projetos:** `PERCUS_CANON_V2_DIR` → aponte pra `<clone>/v2` (ex.:
`D:/Claud Automations/percus-kit/v2`). A `PERCUS_CANON_DIR` continua na raiz.

**V1 está CONGELADO** durante o piloto: sem feature nova lá. Correção de bug crítico, sim.

---

## Estado

| Camada | Onde está | Situação |
|---|---|---|
| Constituição (invariantes) | `CONSTITUICAO.md` | ✅ V2 |
| Loops (**8**, incl. `tdd` — conselho 3/3 2026-07-20) | `loops/` | ✅ escritos; provados: `checkpoint`, `gate` (piloto-1) |
| Formatos de artefato (4) | `artefatos/` | ✅ escritos; provados: HANDOFF, CONTEXT, ADR (piloto-1) |
| Gates + instalador | `gates/` | ✅ **em produção no tiatendo** (hook híbrido, commit `70c9347`) |
| Roteador de loops | `templates/CLAUDE.template.md` (V1) §Roteador | ✅ entrega via template |
| Conhecimento (`COMO_FAZER` / `COMO_RESOLVER`) | **V1** | ⏸️ aponta — funciona bem, não migra agora |
| Infra e stack / tracking | **V1** (`02_…`, `03_…`) | ⏸️ aponta |
| Auditorias e skills pontuais do plugin | **V1** | ⏸️ ferramenta, não é loop |

## Quem manda em quê (por tema)

**V1 manda na obrigação** — o quê, o R-número e o enforcement (hook, gate). **V2 manda no
procedimento** — como fazer, os loops e o formato dos artefatos. Infra, stack, auth e tracking
são só V1: o V2 tem ponteiro, não texto próprio.

"Em conflito vence" diz qual texto seguir quando os dois lados divergem naquele tema. A
divergência não se resolve aqui: ela vira item em "Ponteiro que falta" até ser corrigida no dono.
Âncora de regra é o título (§ R11), nunca número de linha. Caminhos relativos à raiz do kit.
Teste: `plugin/percus-review/tests/migracao-quem-manda.tests.ps1`.

| Tema | Obrigação (V1, R-número e arquivo:âncora) | Procedimento (V2, arquivo) | Em conflito vence | Ponteiro que falta |
|---|---|---|---|---|
| Trilho P / M / G | R9 — `01_REGRAS_INEGOCIAVEIS.md` § R9, "Trilho P / M / G — critério único de tamanho" | `v2/CONSTITUICAO.md` §3 e §5 (aplicam o trilho, não o redefinem) | V1 | — |
| Grilling | R9 — `01_REGRAS_INEGOCIAVEIS.md` § R9, tabela de etapas, linha "Brainstorming" | `v2/loops/grilling.md` + `v2/referencia/discovery-camadas.md` | V2 | roteador de `templates/CLAUDE.template.md` carrega o grilling para "intenção vaga" sem citar o trilho |
| Spec | R9 — § R9, linha "Spec e spec-analyze"; `06_CONSELHO_PERCUS.md` § Modo 5; `templates/spec.template.md` | `v2/loops/spec.md` | V2 | `v2/loops/spec.md` não aponta `templates/spec.template.md` |
| Conselho | R9 — § R9, "Conselho automático no trilho G"; R13; R20; `06_CONSELHO_PERCUS.md` § 5 modos operacionais | `v2/loops/conselho.md` | V2 | `v2/loops/conselho.md` não aponta `06_CONSELHO_PERCUS.md`; provedores do modo `analyze` divergem entre os dois |
| TDD | R9 — § R9, "Skills do fluxo", linha "Testes" | `v2/loops/tdd.md` | V2 | R9 fala em "todo endpoint novo" e chama TDD opcional de anti-padrão; o loop cobre feature e bugfix e aceita pulo registrado |
| Review | R11 — `01_REGRAS_INEGOCIAVEIS.md` § R11 (+ R9, linha "R11" da tabela de etapas) | `v2/loops/review.md` | V1 | loop não cita as exceções declaráveis da R11, o `-NoFactCheck` dos trilhos P/M nem o `registrar-review` |
| Deploy | R24 — `01_REGRAS_INEGOCIAVEIS.md` § R24 (+ R5, autorização durável de deploy) | `v2/loops/deploy.md` | V1 | loop não aponta `comandos/DEPLOY.md` nem `conhecimento/fazer/deploy-vps.md` |
| Checkpoint e HANDOFF | R8 — `01_REGRAS_INEGOCIAVEIS.md` § R8 (+ R2, "Onde atualizar") | `v2/loops/checkpoint.md` + `v2/artefatos/HANDOFF-FORMAT.md` | V2 | R8 e `templates/HANDOFF.template.md` pedem tabela de status espelhando o PLANO; o formato V2 só leva o que não está em `[5-T]` |
| PLANO e status | R2 (+ R1, forma visual) — § R2; `05_FEATURE_TRACKING.md` § "Arquivos canônicos por projeto" | `v2/artefatos/PLANO-FORMAT.md` | V1 | formato V2 não cita a forma visual da R1 (`UI-verified`) |
| Drift | R2 (hook `state-drift-check`); `plugin/percus-review/commands/drift-detect.md` (canon × projeto); `05_FEATURE_TRACKING.md` § "Drift detector" | `v2/loops/drift.md` (auditoria interna do canon) | V2 | homônimos sem ponteiro entre si; a checagem de índice do loop ainda é a do monólito |
| Conhecimento | R23 — `01_REGRAS_INEGOCIAVEIS.md` § R23 | só ponteiro: `v2/referencia/conhecimento/README.md` | V1 | o ponteiro V2 ainda descreve o contrato do monólito (entrada manual no índice) |
| ADR | `05_FEATURE_TRACKING.md` § "Princípios não-negociáveis" (item 2) e § "Quando criar ADR" | `v2/artefatos/ADR-FORMAT.md` | V1 | critério de abertura diverge: o V2 exige os três critérios juntos, o V1 lista cada um como suficiente |
| CONTEXT (glossário) | — (só V2) | `v2/artefatos/CONTEXT-FORMAT.md` | V2 | — |
| Infra, stack, auth e tracking | R6, R7, R18, R22; `02_INFRA_E_STACK_PERCUS.md`; `03_TRACKING_ATTRIBUITION.md` | só ponteiro: `v2/referencia/infra.md`, `v2/referencia/auth.md` | V1 | `v2/referencia/auth.md` e `v2/CONSTITUICAO.md` §7 vetam `localStorage` sem a exceção de SPA pura da R7 |

## Piloto-1 — tiatendo (FECHADO 2026-07-20, commit `70c9347`)

| Métrica | Antes | Depois |
|---|---|---|
| **Custo de boot** (`CLAUDE` + `HANDOFF` + `PLANO`) | **7.612** | **1.297** (−83%) |
| `HANDOFF.md` | 6.185 | 56 (teto 150 ✅) |
| `docs/PLANO.md` | 1.207 | 1.021 (18 frentes encerradas → histórico) |
| `CONTEXT.md` / `docs/adrs/` | inexistentes | 9 termos / 10 ADRs |
| Retrabalho | ⏳ a levantar do git | ⏳ pendente |

**Meta revista (operador, 2026-07-20):** o alvo fixo "boot ≤400" morreu — plano legítimo pode
ser maior. Critério por-projeto: **HANDOFF dentro do teto** + **PLANO só com frente viva +
entregue-recente**. O gargalo real é o HANDOFF: é o que toda sessão lê primeiro.

**O que o piloto-1 NÃO provou:** os loops `grilling`/`spec`/`conselho`/`tdd`/`deploy`/`drift`
em uso real. Isso é o **teste vivo** (feature "anulação de venda manual") — e mesmo ele é
viciado: quem escreveu os loops é quem roda — e isso **não mudou no piloto-2**. Sessão fria
de verdade (outro agente, sem o autor) segue pendente; é o que falta pra promoção plena.

## Piloto-2 — Plexco Tasks (FECHADO 2026-07-20, commit `8f998c2`)

O caso *best-case*, escolhido pra ser o teste difícil:

| Métrica | Antes | Depois |
|---|---|---|
| **Boot** | **3.793** | **929** (−75%) |
| `HANDOFF.md` | 2.943 | 79 (teto 150 ✅) |
| `CONTEXT.md` / ADRs | ausente / 10 | criado / 10 |
| **Retrabalho (baseline)** | **15,1%** (217 fix/1.435) | régua pra frente |

**O achado central:** mesmo aqui — sessão 142, CI verde, git limpo, **menor retrabalho da
frota** — o HANDOFF tinha 49× `## Sessão` e **37 blocos `_Atualizado em_` empilhados**. A
disciplina impecável produziu o mesmo inchaço do projeto abandonado há 24 versões.
Se a causa fosse rigor, aqui não haveria 2.864 linhas pra remover.

Retrabalho do piloto-1 pra comparação: **18,2%** (381 fix/2.088). O projeto mais saudável
tem menos retrabalho — e o mesmo inchaço.

## Veredito do conselho (2026-07-20, 3/3)

**PROMOVER COM RESSALVA.** DeepSeek e Llama pelo ganho medido com cautela pela novidade.
Cross-Claude com a ressalva mais dura e mais útil:

- **Aceito e corrigido:** *Goodhart no gate* — teto por-arquivo sem teto agregado não elimina
  volume, **desloca**. O boot voltaria como custo de **roteamento** (acertar qual dos N loops
  carregar), que métrica nenhuma captura. → gate ganhou **teto agregado do núcleo (600)** e
  **contador de loops (10)**.
- **Refutado com dado:** *"é descarte, não compressão"* — nada foi descartado; a extração é
  verificada por soma nos dois pilotos (6.185 = 31+6.061+122 · 2.943 = 4+2.802+137). Procede
  a parte sutil: mudou a **acessibilidade**, não o conteúdo.
- **Parcialmente refutado:** *"cresceu ≠ inchou"* — valeria se o HANDOFF não fosse lido
  inteiro; o hook `SessionStart` manda lê-lo a cada sessão, então crescer **é** custo.
- **Aceito sem conserto:** a tese está **plausível, não demonstrada** (n=2, e quem escreveu
  os loops foi quem os rodou).

**Critério de promoção — 3/3 avaliados:** boot ✅ (−83% e −75%) · retrabalho ✅ (baseline
capturado; ganho ainda não medido — o V2 é novo demais) · revisão plural ✅ (3/3 com ressalva).

## Sessão fria — FECHADA 2026-07-20 (Plexco Tasks, feature A1)

A quarta prova (a que o conselho anexou): outro agente, **sem o autor dos loops**, usando o
V2 de verdade. A sessão do Plexco rodou o ciclo completo (grilling→spec→conselho→tdd→review→
deploy→checkpoint) na fatia A1 (barra de % na Lista), entregou em prod, verificou, e devolveu
uma **crítica** do canon. Veredito da própria sessão: **net-positivo** — *"mais rápido seria
pior"*: sem o canon teria errado o "% vs N/M" (pego pelo grilling) e shipado o título espremido
no Plexco (pego pelo E2E do deploy).

O que a crítica achou (e virou conserto, não elogio):
- **`conselho.md` sem regra de parada** → rodou 4 rounds numa barra de progresso. **Corrigido
  em v6.30.2** (teto 2 rounds; só HIGH/CRITICAL fact-checado bloqueia). *Este era o gate da
  propagação: a sessão fria acha o furo, conserta-se, então espalha.*
- Gate valida "review há <5min" (TTL), não "ESTE diff foi revisado" (hash) — fresta conhecida
  (verbete `#staging-pos-review-drift`), imaterial pra comentário. Aceito.
- Bug no `council-orchestrator.ps1` (Cross-Claude recebe `file:` vazio → bloqueio falso) —
  tooling, tem workaround, spawnado.

## Critério de promoção — 4/4 FECHADO → V2 PROMOVIDO

1. **Custo de boot** — ✅ tiatendo −83%, Plexco −75%
2. **Retrabalho** — ✅ baseline 18,2% / 15,1% (régua pra frente)
3. **Revisão do conselho** — ✅ 3/3 "promover com ressalva"
4. **Sessão fria** — ✅ net-positiva, com o defeito que achou já corrigido

**Liberado pra propagação:** Delta **Passo B3** nos projetos, quando o operador quiser.
O V1 continua como referência (auth, infra, tracking, conhecimento) — o V2 não o apaga.
