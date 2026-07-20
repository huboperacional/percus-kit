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
viciado: quem escreveu os loops é quem roda. Sessão fria de verdade = piloto-2.

## Piloto-2 — Plexco Tasks (planejado)

O caso *best-case*: sessão 142, 10 ADRs, CI verde, git limpo — e ainda assim HANDOFF de
2.943 linhas (49× `## Sessão`). Prova que o inchaço é estrutural, não indisciplina. Se o V2
melhorar até o projeto já saudável, a promoção se justifica; se só consertar bagunça, não.

## Critério de promoção

O V2 só substitui o V1 se ganhar em número **e** em revisão:

1. **Custo de boot** por-projeto (critério revisto acima)
2. **Retrabalho** — commits `fix`/revert sobre código recente
3. **Revisão do conselho** sobre cada piloto, antes e depois — a parte que número não captura

Sem ganho medido, o V2 é churn e o V1 volta a ser o canon.
