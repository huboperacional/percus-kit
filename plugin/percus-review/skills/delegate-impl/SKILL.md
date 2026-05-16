---
name: delegate-impl
description: Use ANTES de escrever codigo mecanico/boilerplate em volume. Calcula score heuristico (cardinalidade + keyword + arquivos + sensitive penalty) e sugere delegar pro wrapper deepseek-impl.ps1 se score>=4 — com dry-run de 1 arquivo primeiro pra validar qualidade. Operador sempre tem ultima palavra via AskUserQuestion.
---

# Percus — Delegate Impl (R13)

Skill de guidance pro agente decidir QUANDO sugerir delegacao da implementacao mecanica pro DeepSeek em vez de escrever direto. Formato escolhido (Opcao C heuristica combinada + Opcao E dry-run) validado por conselho 3-membros (consult `Painel/.deepseek/council-log/20260516-175220-consult.jsonl`).

## Quando rodar (auto-trigger pelo agente)

ANTES de comecar tarefa que envolva escrever codigo NOVO em volume:
- `crie 5 endpoints CRUD pra <model>` (cardinalidade explicita)
- `adicione 10 testes pytest pra <modulo>` (cardinalidade + repetitividade)
- `migre 8 arquivos do estilo X pro estilo Y` (boilerplate massivo)
- `gere scaffold/stub de <feature>` (keyword mecanico)

**NAO rodar pra:**
- Bug fix de 1-3 linhas.
- Refactor pequeno (rename, extrair funcao).
- Decisao arquitetural (escolher pattern, desenhar API).
- Pasta sensivel (auth/payment/migrations) — sempre Claude direto (veto R13).

## Calculo do score (heuristica combinada)

Antes de codar, calcule mentalmente:

| Sinal | Peso | Como detectar |
|---|---|---|
| Cardinalidade explicita no prompt | +3 | Numero ≥ 3 ("crie 5...", "10 testes...") |
| Keyword mecanico v1 | +2 | `crud`, `endpoint`, `teste/test + para cada/each`, `boilerplate`, `scaffold`, `stub` |
| Arquivos identificados > 3 | +2 | Voce sabe quais arquivos vai criar/editar e sao >3 |
| Pasta sensivel envolvida | **-10** | Veto. auth/, payment*/, migrations/, credentials/, .env |

**Acao:**
- Score >= 4 → **sugira delegacao via AskUserQuestion** com default = delegar.
- Score < 4 → escreva voce mesmo direto (default).
- Score < 0 → escreva voce mesmo direto (pasta sensivel SEMPRE Claude).

**LOG OBRIGATORIO** (risco de opacidade apontado pelo CC): registre o breakdown do score no commit log ou em comentario do plano:

```
[delegate-impl] score breakdown:
  cardinalidade(5 endpoints CRUD) = +3
  keyword(crud, endpoint) = +2
  arquivos(~6 esperados) = +2
  sensitive = 0
  TOTAL = 7 (>=4 -> sugerir delegacao)
```

Sem este log o operador nao consegue auditar se o trigger foi correto apos 2-3 sugestoes erradas.

## Dry-run obrigatorio (Opcao E)

Quando operador autoriza delegacao, **NAO delegue tudo de uma vez**. Faca dry-run de 1 unidade primeiro:

### Passo 1: Delegue UMA unidade representativa
Ex.: pra "criar 5 endpoints CRUD", delegue so o endpoint do primeiro recurso.

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.ps1" `
    -Task "<descricao da unidade UNICA, com contexto suficiente>" `
    -OutputFile /tmp/deepseek-dryrun.diff
```

### Passo 2: Voce (Claude) revisa o output
- Codigo segue padroes do projeto (imports, naming, estilo)?
- Integra com utilitarios existentes (auth middleware, error handlers)?
- Tem implicacao arquitetural sutil que DeepSeek perdeu? (ex.: migration mecanica que exige escolha de index strategy)

### Passo 3: Reporte ao operador

```
[delegate-impl] dry-run:
  Unidade: <descricao>
  Output em: /tmp/deepseek-dryrun.diff
  Linhas: X (esperadas ~Y)
  Qualidade: <"OK, padroes seguidos" | "FAIL, motivo concreto">

Posso delegar as <N-1> unidades restantes? (sim/nao/ajustar)
```

### Passo 4: Operador decide
- `sim` → delegue o resto em batch via deepseek-impl.ps1.
- `nao` → voce escreve as restantes direto.
- `ajustar` → operador descreve o que ajustar no prompt, voce re-dry-run.

## Commit trailer obrigatorio (R13)

Quando codigo delegado entra no commit, adicione trailer:
```
Co-implemented-by: deepseek-v4
```

Permite rastreabilidade (auditavel em git log) + ativa router R11 pra Cross-Claude revisar (DeepSeek nao revisa proprio output).

## Anti-padroes

- ❌ Delegar SEM dry-run primeiro — risco de receber 200 linhas erradas que nao se encaixam no projeto.
- ❌ Delegar em pasta sensivel mesmo com score >= 4 — veto R13 absoluto.
- ❌ Calcular score em silencio — log obrigatorio (transparencia auditavel).
- ❌ Aceitar dry-run "mais ou menos OK" pra acelerar — se dry-run falha, escreva voce mesmo, nao force.
- ❌ Delegar refactor — refactor frequentemente exige decisao de design contextual. v1 NAO inclui `refactor` em keywords.
- ❌ Delegar migration mecanica — armadilha apontada pelo DeepSeek no consult: "migration mecanica que exige escolha de index strategy". v1 NAO inclui `migration` em keywords.

## Keywords v1 (NAO incluir refactor/migration)

| Categoria | Keywords |
|---|---|
| CRUD obvio | `crud`, `endpoint`, `route`, `controller`, `handler` |
| Testes em volume | `teste`/`test` + (`para cada`/`each`/`todos os`/`all`) |
| Boilerplate | `boilerplate`, `scaffold`, `stub`, `template`, `generate` |

**Excluidos v1 (alta taxa de armadilha):**
- `refactor`, `refatorar` — frequentemente exige decisao arquitetural.
- `migration`, `migrate` — armadilha apontada pelo conselho (index strategy etc).
- `auth`, `payment`, `security` — pasta sensivel, veto absoluto.

## Custo / latencia

- Tipica delegacao 5-10 arquivos: ~30s DeepSeek vs ~3-5min Claude direto.
- Custo: ~10x menor que Claude direto.
- Dry-run sobre 1 unidade: ~5s, evita waste de delegar 10 unidades erradas.

## Wrapper existente

`scripts/deepseek-impl.{ps1,sh}` ja existe e funciona. Aceita `-Task <descricao>` + `-OutputFile <path>` + variaveis de contexto via env (DEEPSEEK_CONTEXT_*). Ver docstring do script pra detalhes.

## Referencias

- Wrapper: `D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.{ps1,sh}`.
- Spec R13: `_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md`.
- Decisao Opcao C+E: `Painel Gestao e Afiliados/.deepseek/council-log/20260516-175220-consult.jsonl`.
- Skill irma: `feature-flow` (orquestra R1-R13, decide quando delegar como step 3).
