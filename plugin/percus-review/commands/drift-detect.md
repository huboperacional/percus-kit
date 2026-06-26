---
name: council:drift-detect
description: Detecta divergencia entre o canon Percus (_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md + 02-06) e como o projeto atual realmente implementa. Conselho 3-membros aponta drift, sem fazer fix automatico.
---

# /council:drift-detect

Use **mensalmente** OU ao adotar Fase nova em projeto legado. Conselho compara: "como o canon diz que deve ser" vs "como este projeto realmente esta".

## Quando rodar

- Auditoria mensal de saude (1x/mes por projeto).
- Apos upgrade de Fase (Fase 4 -> 5 -> 6) pra confirmar adocao real.
- Antes de iniciar feature grande em projeto legado.
- Quando operador suspeita que projeto saiu do padrao Percus.

## NAO usa pra

- Code review em PR especifica → use `/percus-review:review` em vez.
- Decisao de design pontual → use `/council:consult`.
- Pre-mortem de plano → use `/council:pre-mortem`.

## Fluxo (passo a passo do agente)

### 1. Coletar artefatos do projeto

Liste o que existe vs o que canon espera:

```bash
# Stack
ls package.json requirements.txt pyproject.toml Cargo.toml go.mod 2>/dev/null
cat AGENTS.md HANDOFF.md CLAUDE.md 2>/dev/null | head -200

# Auth
grep -rn "from supabase\|gotrue\|next-auth\|@auth/\|@supabase/" --include="*.py" --include="*.ts" --include="*.tsx" . 2>/dev/null | head -5

# Cookies
grep -rn "set_cookie\|setCookie\|res.cookie\|cookies()" --include="*.py" --include="*.ts" --include="*.tsx" . 2>/dev/null | head -10

# Migrations
ls alembic/versions/ migrations/ 2>/dev/null | tail -5
find . -path ./node_modules -prune -o -name "models" -print -o -name "schemas" -print 2>/dev/null | head -5

# Hooks/skills/plugin instalado
ls .claude/ 2>/dev/null
test -d .deepseek/reviews && echo "review-fresh: $(ls -t .deepseek/reviews/*.jsonl 2>/dev/null | head -1)"
test -f catalog-info.yaml && echo "catalog-info: presente"
```

### 2. Montar payload pro conselho

Monte o payload (⚠️ **NUNCA num nome fixo** tipo `/tmp/council-drift.txt` — no Windows vira `d:\tmp\...` e fica stale entre runs; bug 2026-05-30. Temp unico no passo 3):

```
PROJETO: <slug do projeto>
FASE DECLARADA NO HANDOFF: <Fase X.Y.Z>

STACK DETECTADA:
<output do passo 1 resumido>

AUTH:
<imports detectados>

CATALOG-INFO.YAML: <presente | ausente>
ULTIMO REVIEW: <timestamp do .deepseek/reviews/ mais recente | nunca>

CANON PERCUS (resumo):
- R1-R19 em ${env:PERCUS_CANON_DIR}\01_REGRAS_INEGOCIAVEIS.md
- Stack canonico em 02_INFRA_E_STACK_PERCUS.md
- Tracking em 03_TRACKING_ATTRIBUITION.md
- Feature tracking em 05_FEATURE_TRACKING.md
- Conselho em 06_CONSELHO_PERCUS.md

PERGUNTA: Liste exatamente 5 pontos de drift mais criticos entre como este projeto esta vs como canon Percus Fase X.Y.Z espera. Para cada ponto: 1 frase descrevendo o drift, 1 frase sugerindo correcao. Sem sugerir refactor fora de drift real.
```

### 3. Rode orchestrator em mode "review" com 3 providers

Arquivo temp **unico** por invocacao (nunca nome fixo):
```powershell
$Q = Join-Path $env:TEMP "council-drift-$([guid]::NewGuid().ToString('N')).txt"
@'
<payload do passo 2>
'@ | Set-Content -LiteralPath $Q -Encoding utf8
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.ps1" -PromptFile $Q -Mode review -Providers "deepseek,groq-llama,cross-claude"
Remove-Item -LiteralPath $Q -Force -ErrorAction SilentlyContinue
```

### 4. Cross-Claude marker

Se stderr `__PERCUS_NEEDS_CROSS_CLAUDE__`: dispatch Sonnet subagent. Salve num temp **unico** (`$CC = Join-Path $env:TEMP "council-cc-$([guid]::NewGuid().ToString('N')).txt"`; Unix `mktemp`). Re-invoque com `-CrossClaudeFile $CC`. **Nunca reuse `/tmp/council-cc.txt`.**

### 5. Sintese e ranking

Leia ultimo `.deepseek/council-log/<ts>-review.jsonl`. Cada provider deve ter retornado ~5 pontos. Agrupe pontos similares entre providers:

- **Drift consenso (>=2 providers):** prioridade alta. Liste primeiro.
- **Drift unico:** prioridade media. Liste depois com qual provider detectou.
- **Falso positivo / fora de escopo:** descarte explicito.

### 6. Reporte ao operador

```
[council:drift-detect] <slug>
Fase declarada: <X.Y.Z>

Drift critico (consenso N/M providers):
1. <drift>: <correcao sugerida> [providers: DS+Llama]
2. ...

Drift secundario:
- <drift>: <correcao> [provider: DS]
- ...

Recomendacoes:
- Atacar drift 1-2 em proxima sessao (custo: <estimativa>)
- Drift 3-N pode esperar marco
- <opcao>: rodar /percus-review:install-git-hooks se hooks ausentes
```

**Drift detect nao executa fix.** So reporta. Operador decide o que atacar.

### 7. Log + rastreio

Logue ranking em `docs/drift-audit-<YYYY-MM-DD>.md` no proprio projeto pra acompanhar evolucao ao longo do tempo.

## Custo / latencia

3 providers + 1 subagent Sonnet = ~$0.01 + assinatura. Latencia ~30-60s (subagent dominante).

Roda mensalmente, custo agregado < $0.20/projeto/ano.

## Anti-padroes

- ❌ Rodar drift-detect e nao fazer NADA com o resultado — vira teatro.
- ❌ Fix automatico de drift sem revisao humana — drift pode ser intencional (legado vs novo).
- ❌ Conselho indica drift, mas projeto tem ADR justificando — siga ADR, ignore drift.

## Referencias

- Canon: `${env:PERCUS_CANON_DIR}\01_REGRAS_INEGOCIAVEIS.md`
- ADR pattern: `_Novo_Projeto/templates/adr-0000-template.md`
