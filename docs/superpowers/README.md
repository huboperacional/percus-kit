# docs/superpowers/ — specs e planos versionados (registro histórico)

> **⚠️ Estes documentos são registros point-in-time, NÃO o estado atual.** A fonte da verdade do que
> está vigente é sempre `CANON_VERSION.md` (raiz) + os docs canônicos (`01_REGRAS`, `02_INFRA`, `PADRAO_*`).
> Leia o que está aqui como **história de como o canon chegou onde chegou**, não como instrução corrente.

## O que mora aqui (convenção — ver `README.md` da raiz §"Specs")

- `specs/YYYY-MM-DD-<topic>-design.md` — design docs de uma frente/sprint, na data em que foram escritos.
- `plans/YYYY-MM-DD-<topic>.md` — planos de execução correspondentes.

Quando uma nova frente significativa for desenhada, o spec/plano dela nasce aqui com a data. Os que já
existem são de sprints **concluídas**:

| Doc | Sprint | Estado |
|---|---|---|
| `*-2026-05-03-percus-fase5-*` | Adoção Superpowers (Fase 5) | Concluída — absorvida no canon |
| `*-2026-05-19-sprint-v6.8-*` | Canonização de auth (Fase 7 / v6.8.0) | Concluída — ver `PADRAO_AUTH_SERVICE.md` + `CANON_VERSION` v6.8.0 |

## Por que não foram arquivados/movidos

São referenciados por entradas **históricas** de changelog (`CANON_VERSION.md` v6.8.0) e por docs ativos
(`01_REGRAS`, `comandos/UPGRADE_PARA_FASE7.md`). Mover quebraria esses links e exigiria reescrever
registros históricos — custo alto, valor baixo. Ficam aqui, marcados como história por este README.
