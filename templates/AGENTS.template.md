# {Nome do Projeto} — AGENTS.md

> Regras Percus deste projeto. Lido pelo **revisor cross-provider** (DeepSeek + Cross-Claude) durante `/percus-review:review` e `/percus-review:milestone-review`.
> Mantenha sincronizado com `CLAUDE.md`. Em conflito, `CLAUDE.md` prevalece (fonte canônica).

---

## Papel do revisor neste projeto

**Revisor é REVISOR, não desenvolvedor.**

- ✅ **Faz:** revisa diffs antes do commit, aponta bugs, regressões, violações de regras Percus, melhorias de clareza
- ❌ **Não faz:** escreve código novo, refatora, propõe arquiteturas, executa migrations

Quando review é disparado (manual via `/percus-review:review` OU auto-trigger via wrapper `scripts/percus-review-auto.ps1` chamado pelo agente):
1. Router lê `git diff` ativo + paths tocados + último commit message
2. Decide: DeepSeek apenas / Cross-Claude apenas / duplo
3. Reviewer(s) lê(em) este `AGENTS.md` para conhecer regras
4. Reporta findings com nível de severidade (bug / risco / preferência)
5. Sugere fix mas NÃO aplica

**Nota sobre auto-trigger (v5.1.0+):** o agente Claude Code chama o wrapper diretamente antes de cada commit que ele executa. Comportamento do reviewer é idêntico (mesmo prompt, mesmo formato de findings) — só a invocação muda. Não precisa adaptar nada deste lado.

**Nota sobre skills vs slash commands (v6.0+):** o plugin `percus-review` tem 2 tipos de extensão. **Slash commands** (`/percus-review:review`, `/council:pre-mortem`, etc) são digitados pelo user no chat. **Skills** (`feature-flow`, `close-milestone`, `delegate-impl`, `tracking-audit`, `security-audit`, `cookie-audit`, `pages-scan`, `catalog-publish`) são **auto-trigger pelo agente** via `Skill` tool — não existem como slash command. Se um agente pedir pro user "rodar `/percus-review:feature-flow`" ou similar, **ele errou** — ele mesmo deveria ter invocado via `Skill` tool. Referência completa: `${env:PERCUS_CANON_DIR}/comandos/SKILLS_VS_COMMANDS.md`.

---

## O que é este projeto

{2-3 linhas descrevendo propósito, público, problema que resolve}

## Stack

- **Frontend:** {Vite + React 19 + TS / Next.js 15 + RSC}
- **Backend:** FastAPI 0.115+ (Python 3.11+)
- **Banco:** PostgreSQL 17 — database `{slug_projeto}_v1`
- **Cache/OTP:** Redis 7.4 — namespace `{slug_projeto}:*`
- **Auth:** consumir auth-service Percus (estado Final, lib `percus-auth` validando JWT EdDSA local) **OU** OTP+JWT em sidecar FastAPI (estado Transição até auth-service v1) — ver `02_INFRA_E_STACK_PERCUS.md` Seção 2
- **Deploy:** Docker Swarm via Portainer no VPS `161.97.129.138`

---

## Regras Percus em cada review

Versão completa: `${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md`

| Regra | O que apontar |
|---|---|
| R1 — feito = ciclo CRUD | Diff que declara "feito" sem evidência de teste manual/automatizado do ciclo |
| R2 — tracking `[0]→[5-T]` | Endpoint adicionado sem update no `docs/PLANO.md`, ou pulou etapas |
| R3 — zero mock escondido | `toast.success("Salvo!")` sem `await` em chamada de API real; falta de banner MODO DEMO |
| R6 — banco novo por projeto | Hardcode de `DATABASE_URL` apontando pra DB de outro projeto; chave Redis sem prefixo |
| R7 — auth Percus | Import de `@supabase/*`, uso de `NextAuth`, refresh JWT stateless, HS256 cross-projetos, magic-link próprio fora de `/auth/magic/*`, admin com username+pwd sem TOTP |
| R14-R18 — auth/infra | Serviço tier-1 sem OTel (R14), rate limit sem canonicalização E.164/IPv6 /64 (R15), `SameSite=None` cross-site (R16), magic-link reimplementado (R17), tracking acoplado à auth (R18) |
| R10 — gate de design | Componente novo de tela inteira sem referência a draft v0/shadcn aprovado |
| R13 — output DeepSeek | Diff vindo de `.deepseek/runs/` que toca pasta sensível, mock escondido, ou auth não-Percus |

---

## Padrões de código

### TypeScript / React

- Funções e variáveis: `camelCase`
- Componentes: `PascalCase`
- Hooks com prefixo `use*`
- **Vetado:** `localStorage` para token (R7) → cookie `httpOnly` ou memória + refresh
- **Vetado:** Redux → Zustand
- **Vetado:** CSS-in-JS runtime → Tailwind

### Python (FastAPI)

- `snake_case.py` para arquivos
- Funções: `snake_case`; classes: `PascalCase`
- Async em tudo que toca I/O (DB, HTTP, fila)
- Endpoints REST explícitos por módulo (vetado: PostgREST e auto-API)
- Pydantic v2 para validação
- SQLAlchemy 2.x async ou asyncpg puro (vetado: Sequelize/Prisma estilo)
- Raise `HTTPException` com detail Pydantic, não string solta

### Comentários

- No código: **inglês**
- Em docs/markdown do projeto: **português**

---

## Formato dos findings

Para cada problema encontrado, usar:

```
[SEV: bug | risco | preferência]
Arquivo: caminho/relativo.ts:linha
Regra violada: R{N} (se aplicável)
Problema: descrição em 1-2 frases
Sugestão: código alternativo ou ação concreta
```

Exemplo:
```
[SEV: bug]
Arquivo: web/src/pages/produtos.tsx:42
Regra violada: R3 (zero mock escondido)
Problema: toast.success("Produto salvo!") chamado sem await na chamada de API real.
Sugestão: trocar para toast("Salvo localmente", { icon: "⚠️" }) OU implementar fetch real e await antes do toast.
```

---

## NÃO apontar

- Estilo subjetivo sem violação concreta de regra
- Refactor de código fora do diff
- Sugestões que contradigam stack canônico em `${env:PERCUS_CANON_DIR}/02_INFRA_E_STACK_PERCUS.md`

---

## Quando o revisor DEVE se recusar

Se o diff não está disponível, ou inclui binários, ou inclui `.env`/credenciais, **abortar e reportar** em vez de tentar revisar. Não suprima o aviso.

---

## Atualização deste arquivo

Sempre que `CLAUDE.md` mudar regras de codificação ou stack, **atualize aqui também**. Divergência = revisor opera com regra desatualizada.

Revisão sugerida: a cada release ou a cada 2 semanas, comparar `AGENTS.md` vs `CLAUDE.md` e sincronizar.
