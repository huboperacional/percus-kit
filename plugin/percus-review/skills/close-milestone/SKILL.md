---
name: close-milestone
description: Use when closing a milestone in Percus project — end of numbered phase, feature group in epic, or "ready for next step" transition. Runs /percus-review:milestone-review and marks ✓ in PLANO/HANDOFF.
---

# Percus Close Milestone

Quando declarar marco fechado (fim de Fase X numerada, fim de feature em épico, ou "pronto, próxima etapa"), use este fluxo antes de marcar ✓.

## Fluxo

### 1. Identificar commit-inicio-marco

- **Default:** último commit do PLANO.md que tem ✓ (= marco anterior). Use `git log --all -p -S "✓" -- docs/PLANO.md | head -20` pra encontrar.
- **Se não houver marco anterior:** usar branch base (main/master). Confirmar com usuário se inseguro.
- **Inseguro?** Perguntar usuário em voz alta antes de prosseguir.

### 2. Rodar milestone-review (R11 ampliada)

**Auto-trigger pelo agente (v5.1.0+) — sem paste manual:**

Via Bash tool, rode:

```
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\Claud Automations\_Novo_Projeto\scripts\percus-milestone-review-auto.ps1" -Base <commit-inicio-marco>
```

(ou `.sh` em Unix). Wrapper roda DeepSeek do escopo do marco e emite marker `__PERCUS_NEEDS_CROSS_CLAUDE__` no stderr. Você (agente) lê o marker e dispatch Sonnet subagent via Agent tool com prompt R11 cross-claude-review do mesmo escopo. Salva findings do Sonnet em `.deepseek/reviews/<ts>-cross-claude-milestone.jsonl`.

Apresente consolidado dos dois reviews ao usuário.

**Fallback manual (se wrapper falhar ou pra invocação humana):**

Usuário cola no chat:
```
/percus-review:milestone-review --base <commit-inicio-marco>
```

Custo total ~$0.05 (DeepSeek dual).

### 3. Tratar findings

- **Bug/regressão** → corrigir ANTES de fechar marco
- **Risco/violação Percus** → corrigir OU declarar em voz alta por que ignora
- **Preferência** → ignorar OK, declarar em voz alta

### 4. Marcar ✓ no PLANO + HANDOFF

Para cada feature afetada pelo marco, adicionar ✓ antes da tag de status:

```
- [5-T] Login OTP   →   - [5-T] ✓ Login OTP
```

Aplicar em `docs/PLANO.md` E `HANDOFF.md` (espelhos da R2).

### 5. Nota no HANDOFF.md

```markdown
## Marco {nome} fechado em {data}, milestone-review aprovado
- Features afetadas: {lista}
- Findings críticos tratados: {lista ou "nenhum"}
- Próximo marco: {descrição}
```

## Anti-padrões

- ❌ Marcar ✓ sem rodar milestone-review (R11 ampliada violada)
- ❌ Pular findings críticos
- ❌ Marcar ✓ retroativo em features já em [5-T] sem auditoria do escopo

## Referência
`D:/Claud Automations/_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md` R11 (Review cross-provider)
