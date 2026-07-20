# Referência — o que ainda mora no V1

Regra do V2: **aditivo, não paralelo.** Nada é copiado do V1. O que não migrou é **apontado** daqui.

Raiz do V1: `${env:PERCUS_CANON_DIR}` → `_Novo_Projeto/`

| Assunto | Onde está (V1) | Migra quando |
|---|---|---|
| Auth (padrão, JWKS, refresh, cookie) | `02_INFRA_E_STACK_PERCUS.md` §2 | nunca — é referência de stack, não loop |
| Infra, VPS, Swarm, portas, Traefik | `02_INFRA_E_STACK_PERCUS.md` | idem |
| Tracking / attribution | `03_TRACKING_ATTRIBUITION.md` | idem |
| Conhecimento (problema → solução) | `conhecimento/COMO_RESOLVER.md`, `COMO_FAZER.md` | quando o piloto provar o V2; é a base que mais funciona hoje |
| Template de ADR | `templates/adr-0000-template.md` | nunca — é contrato do crawler do Painel |
| Template de PLANO / HANDOFF | `templates/` | já substituídos por `artefatos/` do V2 |
| Auditorias (security, tracking, cookie, pages, auth-consumer) | skills do plugin | nunca — ferramenta pontual, não é loop de sessão |
| `catalog-publish`, `port-allocate`, `delegate-impl` | skills do plugin | idem |

## Por que quase nada migra

Referência **não sofre** do problema que motivou o V2. O que inchou foi **procedimento misturado com invariante** em arquivo monolítico. Detalhe de stack pode ter 1.000 linhas sem prejuízo: ele é lido sob demanda, por quem já sabe o que procura.

**Migrar referência sem necessidade é o jeito mais rápido de o V2 virar o V1.**
