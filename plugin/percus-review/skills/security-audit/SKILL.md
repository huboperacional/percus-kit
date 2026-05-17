---
name: security-audit
description: Use when reviewing/auditing auth-related code (auth/, auth_service/, middleware/, login, JWT, magic links, cookies, rate limits). Roda checklist YAML declarativo cobrindo R14-R19 (observabilidade, rate limit IPv6, SSO multi-domain, magic links centralizados, tracking separado, identidade canonica via auth-service).
---

# Percus — Security Audit (R14-R19)

Runner deterministic de checklist de seguranca canon Percus. **Formato: YAML declarativo + runner Python**. Decisao validada por conselho 3-membros (consult `Painel/.deepseek/council-log/20260516-175328-consult.jsonl`).

## Quando usar

- Antes de commitar em pasta auth/, auth_service/, middleware/auth*, login/, payment/, admin/.
- Auditoria mensal (rodar em todos projetos com auth-service).
- Pre-deploy de feature de auth.
- Suspeita de regressao R14-R19 apos refactor grande.

## Pre-requisitos

- Python 3.10+ no PATH.
- `pyyaml` instalado (`pip install pyyaml`).
- (Opcional) `jsonschema` pra validar schema do checklist (`pip install jsonschema`).
- Repo do projeto-alvo como CWD ao rodar.

## Como rodar

```bash
python "${env:PERCUS_CANON_DIR}/plugin/percus-review/scripts/security_audit.py"
```

Opcoes:
```bash
# Override do path do checklist (default: skills/security-audit/checklist.yaml do plugin)
python scripts/security_audit.py --checklist /path/to/custom.yaml

# JSON output (pra parse programatico em CI/hook)
python scripts/security_audit.py --json

# Filtra por severidade (so reporta items >= medium)
python scripts/security_audit.py --min-severity medium

# Filtra por eixo (so R15)
python scripts/security_audit.py --eixo R15
```

## Output (modo human, default)

```
[security-audit] checklist v1, 12 items, projeto: <slug>

R14 — Observabilidade tier-1
  ✓ R14-otel-import (PASS)
  ✗ R14-audit-log (FAIL high): Endpoints sensiveis sem audit log hash-chained
    paths_scanned: 8
    fix: Use lib audit-chain-py ou implemente prev_hash + content_hash

R15 — Rate limit canonico
  ✓ R15-rate-limit-ipv6 (PASS)
  ✗ R15-email-normalize (FAIL high): Rate limit por email cru permite bypass
    fix: Normalize lowercase + strip plus-tag + colapse dots gmail.com

... (R16-R19)

RESUMO: 12 items, 8 PASS, 4 FAIL (2 critical, 1 high, 1 medium)
Exit 0 = todos PASS. Exit 1 = FAIL (any severity). Exit 2 = erro de schema/IO.
```

## Output (modo --json)

```json
{
  "version": 1,
  "checklist_path": "...",
  "project_cwd": "...",
  "summary": {"total": 12, "pass": 8, "fail": 4, "by_severity": {"critical": 2, "high": 1, "medium": 1}},
  "items": [
    {"id": "R14-otel-import", "eixo": "R14", "status": "PASS", "severity": "medium"},
    {"id": "R14-audit-log", "eixo": "R14", "status": "FAIL", "severity": "high", "fail_msg": "...", "fix_hint": "..."}
  ]
}
```

## Schema do checklist.yaml

```yaml
- id: R<N>-<slug-kebab>              # unique, obrigatorio
  eixo: R<N>                          # R14|R15|R16|R17|R18|R19
  desc: "frase em PT-BR"
  check:
    type: grep                        # MVP so suporta grep; futuro: ast, http
    pattern: 'regex'                  # POSIX ERE
    paths: ["glob1", "glob2"]         # paths relativos ao CWD do projeto
  fail_msg: "frase explicando o que falhou"
  fix_hint: "comando ou padrao concreto pra corrigir"
  severity: critical|high|medium|low
```

Schema validado pelo runner via jsonschema (se disponivel). Chave desconhecida -> exit 2 com erro especifico (evita schema drift silencioso — risco apontado pelo CC no consult).

## Cobertura inicial v1 (12 items)

| Eixo | Items | Severidade |
|---|---|---|
| R14 (observabilidade) | otel-import, audit-log | medium, high |
| R15 (rate limit) | ipv6, email-normalize | high, high |
| R16 (SSO multi-domain) | cookie-domain, redirect-fragment | high, medium |
| R17 (magic links) | endpoint, no-local-token | high, high |
| R18 (tracking separado) | no-fbclid-in-auth | medium |
| R19 (identidade canonica) | jwt-source, no-localStorage-jwt | high, critical |

## Adicionar items novos

Edite `checklist.yaml`. Schema validado em build. NAO modifique runner pra adicionar items — separacao data/logic e o ponto inteiro de Opcao D.

## Anti-padroes

- ❌ Editar runner pra "skip" item que da FAIL — corrija o codigo do projeto, nao a regra.
- ❌ Adicionar `severity: ignore` no YAML — use `--min-severity` no comando se quer filtrar temporariamente. Severity ignore nao existe.
- ❌ Falso positivo persistente em item -> abrir issue do kit, nao silenciar no projeto.
- ❌ Auto-fix de items FAIL — runner so REPORTA. Operador decide o que/como fixar.

## Limitacoes v1 (Sprint 4 do B?)

- `check.type` so suporta `grep`. Futuro: `ast` (parse Python/TS pra evitar falso-negativo de nome dinamico), `http` (probe endpoint de auth + valida headers).
- `paths` usa Python pathlib glob — nao suporta `!negation`. Workaround: use `.gitignore` ou regex no pattern.
- Sem cache — re-grep em tudo cada run. Tipicamente <2s em projeto medio.

## Referencias

- Spec: `_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md` R14-R19.
- Decisao de formato: `Painel Gestao e Afiliados/.deepseek/council-log/20260516-175328-consult.jsonl` (3/3 conselho voto Opcao D).
- Skill irma: `cookie-audit` (subset R7), `tracking-audit` (R2 contra-parte).
- Runner: `scripts/security_audit.py`.
