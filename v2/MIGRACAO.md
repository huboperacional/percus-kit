# Migração V1 → V2 — o que já mudou de casa

> **Regra nº 1 do V2: aditivo, não paralelo.** O V2 nasce só com o núcleo novo.
> Tudo que ainda não migrou **aponta para o V1** (a raiz deste repo) — não se copia nada.
> Copiar é herdar a acumulação de 3.262 linhas que motivou o greenfield.

**Casa canônica (desde 2026-07-20): `_Novo_Projeto/v2/`** — dobrado pra dentro do percus-kit
pra pegar carona no `git pull` que já alcança as 10 máquinas. A pasta avulsa
`_Novo_Projeto_V2/` virou arquivo histórico do experimento; não edite lá.

**Binding nos projetos:** `PERCUS_CANON_V2_DIR` → aponte pra `<clone>/v2` (ex.:
`D:/Claud Automations/_Novo_Projeto/v2`). A `PERCUS_CANON_DIR` continua na raiz.

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

**Pendente pra promoção plena:** uma sessão fria (outro agente, sem o autor) rodando o V2.

## Critério de promoção

O V2 só substitui o V1 se ganhar em número **e** em revisão:

1. **Custo de boot** por-projeto (critério revisto acima)
2. **Retrabalho** — commits `fix`/revert sobre código recente
3. **Revisão do conselho** sobre cada piloto, antes e depois — a parte que número não captura

Sem ganho medido, o V2 é churn e o V1 volta a ser o canon.
