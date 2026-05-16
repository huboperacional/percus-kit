---
tipo: comando-pronto-para-colar
fase-destino: Fase 6
prevalecido-por: [01_REGRAS_INEGOCIAVEIS Fase 6+]
quando-usar: levar um projeto Percus existente (Fase 4 ou 5) pra Fase 6
leitura: 3 min (uso) · execução típica 30-90 min
ultima-atualizacao: 2026-05-15
---

# Comando — Upgrade de Projeto pra Fase 6

> **Objetivo:** levar um projeto Percus existente (Fase 4 estável ou Fase 5 em adopção) pra Fase 6: feature tracking + conselho expandido + hooks/skills novas + ambiente local sanitizado.
>
> **Pré-requisitos:**
> - Repo do projeto-alvo aberto no Claude Code.
> - `_Novo_Projeto` na versão v6.0.0+ (verificar git tag).
> - Plugin `percus-review` v6.0.0+ instalado globalmente.

---

## Cole no chat do Claude Code do projeto-alvo

```
Aplique upgrade Fase 6 neste projeto seguindo `D:\Claud Automations\_Novo_Projeto\comandos\UPGRADE_PARA_FASE6.md`.

Comece pelo Passo 0 (diagnóstico) e mostre o resultado antes de executar Passos 1-5. Aguarde minha confirmação.
```

---

## Passos (Claude executa)

### Passo 0 — Diagnóstico

1. Determinar fase atual do projeto:
   - Procurar plugin instalado: `percus-review` versão.
   - Verificar presença de `AGENTS.md`, `CLAUDE.md`, hooks Layer 2 (`.git/hooks/pre-commit`).
   - Verificar `.env` tem `DEEPSEEK_API_KEY`, `GROQ_API_KEY` (Fase 6 nova).
   - Verificar se já tem `catalog-info.yaml` (Fase 6).
2. Listar o que falta pra Fase 6:
   - Plugin precisa bump? (Fase 5 → 6)
   - `GROQ_API_KEY` ausente?
   - Sem `catalog-info.yaml`?
   - Sem `docs/adrs/`?
   - Env vars locais não setadas (`PIP_CACHE_DIR`, etc.)?
3. Reportar ao operador com plano de execução. Não avançar sem confirmação.

### Passo 1 — Ambiente local do operador (Eixo E)

Apenas se for primeira vez nesta máquina:

```powershell
[Environment]::SetEnvironmentVariable('PIP_CACHE_DIR', 'D:\caches\pip', 'User')
[Environment]::SetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH', 'D:\caches\ms-playwright', 'User')
[Environment]::SetEnvironmentVariable('HF_HOME', 'D:\caches\huggingface', 'User')
npm config set cache 'D:\caches\npm-cache' --global
```

Detalhe completo em `AMBIENTE_LOCAL_OPERADOR.md`.

### Passo 2 — Plugin `percus-review` bump pra v6.0.0

```
/plugin install percus-review@latest
```

Confirmar versão:
```powershell
Get-ChildItem "$env:CLAUDE_CONFIG_DIR\plugins\cache\percus-tools\percus-review" -Directory | Sort-Object Name -Descending | Select-Object -First 1
```

Esperado: `6.0.0` (ou maior).

### Passo 3 — Configurar conselho 3-membros

1. Obter `GROQ_API_KEY` em https://console.groq.com (free tier 30 req/min).
2. Adicionar no `.env` do projeto:
   ```
   GROQ_API_KEY=gsk_<sua-chave>
   ```
3. Smoke test:
   ```
   /council:consult "Renomear isso pra aquilo. Faz sentido?"
   ```
   Esperado: 3 outputs (DeepSeek + Cross-Claude + Llama) + síntese. Custo < $0.01.

Detalhes em `06_CONSELHO_PERCUS.md`.

### Passo 4 — Feature catalog

Seguir `comandos/SETUP_CATALOG.md`:

1. Criar `catalog-info.yaml`.
2. Criar `docs/adrs/0001-percus-feature-tracking-adopted.md`.
3. Rodar `/catalog-publish` pra smoke test.

### Passo 5 — Atualizar `AGENTS.md` e `CLAUDE.md` do projeto

Adicionar referência às novas docs:

- `05_FEATURE_TRACKING.md`
- `06_CONSELHO_PERCUS.md`
- `AMBIENTE_LOCAL_OPERADOR.md`

Bloco padrão a adicionar (no fim do `CLAUDE.md`):

```markdown
## Fase 6 — Feature tracking e conselho expandido (2026-05-15+)

Este projeto adota Fase 6 do canon Percus:
- Feature catalog em `catalog-info.yaml` + `docs/adrs/`.
- Conselho 3-membros: DeepSeek + Cross-Claude + Llama (Groq).
- Hooks novos: mock-scan, types-check, migration-check, auth-import.

Detalhes em:
- `D:\Claud Automations\_Novo_Projeto\05_FEATURE_TRACKING.md`
- `D:\Claud Automations\_Novo_Projeto\06_CONSELHO_PERCUS.md`
- `D:\Claud Automations\_Novo_Projeto\_AUDIT_2026-05-15.md`
```

### Passo 6 — Validação

1. Rodar `/percus-review:review` num diff de teste — confirmar 3 outputs (Fase 6 review).
2. Tentar commitar arquivo com `TODO:` em pasta sensível — hook mock-scan deve bloquear.
3. Abrir `https://gestao.ads4pros.com/gestao/features.html` — projeto deve aparecer com features declaradas.

### Passo 7 — Commit do upgrade

```bash
git add catalog-info.yaml docs/adrs/ CLAUDE.md .env.example
git commit -m "feat(percus): upgrade para Fase 6 do canon Percus

- Feature catalog adopted (ADR-0001)
- Conselho 3-membros configurado (DeepSeek + Cross-Claude + Llama)
- AGENTS.md / CLAUDE.md atualizados pra Fase 6

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Passo 8 — Reportar

```
[Upgrade Fase 6] CONCLUÍDO

Projeto: <slug>
Plugin: percus-review v6.0.0 ✓
Conselho: 3 membros ativos ✓
Feature catalog: adotado, N features declaradas ✓
Smoke tests: todos OK ✓

Diferenças observadas vs Fase 5:
- /percus-review:review agora retorna 3 outputs (era 2)
- /council:consult disponível pra reduzir AskUserQuestion
- /council:drift-detect <feature> compara cross-projeto
- Hooks novos bloqueiam mock/types/migration/auth-import

Próximos passos:
- Quando aplicar feature global: atualizar catalog-info.yaml + ADR
- Monitorar custo conselho (.deepseek/council-log/) — alvo: ≤$10/mês
```

---

## Anti-padrões

- ❌ Pular Passo 0 — diagnóstico revela inconsistências antes de tentar upgrade.
- ❌ Aplicar upgrade em pasta sensível sem `AGENTS.md` atualizado — hooks ainda passam, mas conselho revisa cego.
- ❌ "Vou colocar GROQ_API_KEY depois" — sem ela, conselho fica 2 membros (degrada pra Fase 5).
- ❌ Esquecer de bump `_Novo_Projeto` git tag pra `v6.0.0` ao concluir adoção em projetos suficientes.

---

## Referências

- Auditoria base: `_AUDIT_2026-05-15.md`
- Feature tracking: `05_FEATURE_TRACKING.md`
- Conselho: `06_CONSELHO_PERCUS.md`
- Ambiente local: `AMBIENTE_LOCAL_OPERADOR.md`
- Setup catalog: `comandos/SETUP_CATALOG.md`
- Plano: `D:\Claud Automations\.claude-home\plans\criei-a-pasta-d-claud-warm-patterson.md`
