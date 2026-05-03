---
tipo: comando-pronto
quando-usar: aplicar Fase 4 num projeto em andamento — detecta automaticamente se é projeto legado (sem nada), Fase 2/3 (com Codex) ou já Fase 4
nao-toca-codigo: true
leitura: 3 min (execução: 3-15 min dependendo do estado detectado)
ultima-atualizacao: 2026-05-03
---

# Upgrade — Projeto em andamento → Fase 4

> **Cole o prompt abaixo no chat do Claude Code do projeto que você quer atualizar.**
>
> O agente vai **detectar automaticamente** qual estado o projeto está e seguir o caminho certo:
> - **Já em Fase 4** → reporta e encerra (nada pra fazer)
> - **Fase 2/3 (com Codex)** → migração (remove Codex, instala plugin novo, atualiza refs)
> - **Fase 0 (legado sem nada)** → upgrade completo (review + DeepSeek + design + regras)

---

## Prompt para colar

```
Aplique o upgrade Fase 4 neste projeto seguindo `D:\Claud Automations\_Novo_Projeto\comandos\UPGRADE_PARA_FASE4.md`.

Comece pelo Passo 0 (diagnóstico de estado). NÃO execute Passos 1-3 ainda — só me mostre o resultado do diagnóstico e qual caminho (A/B/C) será seguido. Aguarde minha confirmação antes de prosseguir.

Não toque em código de negócio. Só ferramentas, configs, CLAUDE.md, AGENTS.md, GEMINI.md (se espelho-3) e .gitignore.
```

---

## Passo 0 — Diagnóstico de estado (sempre rodar primeiro)

Detectar qual fase o projeto está. Não modificar nada.

```powershell
# === FASE 4 — plugin @percus/review já instalado? ===
$fase4_plugin = Get-ChildItem "$env:USERPROFILE\.claude\plugins" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'percus-review|@percus' }
$fase4_agents_slim = (Test-Path AGENTS.md) -and `
    (Select-String -Path AGENTS.md -Pattern 'revisor cross-provider|/percus-review:review' -Quiet -ErrorAction SilentlyContinue)
$fase4_claude = (Test-Path CLAUDE.md) -and `
    (Select-String -Path CLAUDE.md -Pattern '/percus-review:review' -Quiet -ErrorAction SilentlyContinue)

# === FASE 2/3 — Codex configurado? (legado a migrar) ===
$fase2_codex_dir = Test-Path .codex
$fase2_codex_plugin = Get-ChildItem "$env:USERPROFILE\.claude\plugins" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'codex@openai|codex-plugin-cc' }
$fase2_codex_refs = @(
    Test-Path AGENTS.md,
    Test-Path CLAUDE.md
) -contains $true -and `
    (Select-String -Path CLAUDE.md, AGENTS.md -Pattern '/codex:review|gpt-5\.4|SETUP_CODEX' -Quiet -ErrorAction SilentlyContinue)

# === FASE 0 — projeto legado sem nada? ===
$tem_qualquer_regra = (Test-Path AGENTS.md) -or `
    ((Test-Path CLAUDE.md) -and (Select-String -Path CLAUDE.md -Pattern 'R11|R13|01_REGRAS_INEGOCIAVEIS' -Quiet -ErrorAction SilentlyContinue))

# === Outros componentes (independente da fase) ===
$deepseek_key = (Test-Path .env) -and (Select-String -Path .env -Pattern '^DEEPSEEK_API_KEY=' -Quiet)
$gitignore_deepseek = (Test-Path .gitignore) -and (Select-String -Path .gitignore -Pattern '^\.deepseek/' -Quiet)
$espelho3 = Test-Path GEMINI.md
```

### Decidir caminho

| Sinais detectados | Estado | Caminho |
|---|---|---|
| `$fase4_plugin` AND `$fase4_agents_slim` AND `$fase4_claude` | **Já em Fase 4** | **Caminho A** (reportar e encerrar) |
| `$fase2_codex_dir` OR `$fase2_codex_plugin` OR `$fase2_codex_refs` (e NÃO Fase 4 completa) | **Fase 2/3 com Codex** | **Caminho B** (migração) |
| Nenhum sinal de Fase 4, nenhum sinal de Fase 2/3 | **Fase 0 (legado)** | **Caminho C** (upgrade completo) |
| Sinais mistos / parcial | **Inconsistente** | Reportar matriz e perguntar usuário |

### Reportar matriz ao usuário

```
DIAGNÓSTICO — {Nome do Projeto}

Fase 4 (estado alvo):
  Plugin @percus/review instalado     | ✅/❌
  AGENTS.md slim (cross-provider)     | ✅/❌
  CLAUDE.md menciona /percus-review:review   | ✅/❌

Fase 2/3 (legado a migrar):
  .codex/ no repo                     | ⚠️/—
  Plugin codex@openai-codex instalado | ⚠️/—
  Refs /codex:review em CLAUDE/AGENTS | ⚠️/—

Componentes Percus:
  DEEPSEEK_API_KEY no .env            | ✅/❌
  .gitignore com .deepseek/           | ✅/❌
  GEMINI.md (espelho-3)               | presente/ausente
  CLAUDE.md/AGENTS.md presentes       | ✅/❌

──────────────────────────────────────────
ESTADO DETECTADO: {A | B | C | INCONSISTENTE}
CAMINHO RECOMENDADO: {descrição curta}
TEMPO ESTIMADO: {3 / 8 / 15} min
──────────────────────────────────────────

Aguardando confirmação para prosseguir com Caminho {A/B/C}.
```

**PARAR aqui.** Aguardar usuário confirmar antes de executar qualquer mudança.

---

## Caminho A — Já em Fase 4 ✅

Nada a fazer. Reportar:

```
✅ PROJETO JÁ EM FASE 4 — {Nome}

Plugin @percus/review instalado, AGENTS.md slim, CLAUDE.md atualizado.
Nenhuma ação necessária.

Para validar saúde de uso (não só configuração), rode:
`comandos/HEALTHCHECK_FASE2.md`
```

---

## Caminho B — Migração Fase 2/3 → Fase 4

Projeto tem Codex configurado. Migrar pra plugin `@percus/review`.

### B.1 — Limpar resíduo Codex

```powershell
# Remover .codex/ do repo (config local Codex)
Remove-Item -Recurse -Force .codex -ErrorAction SilentlyContinue

# Sugerir desinstalação do plugin Codex global (1× por máquina, opcional)
# No chat claude no terminal:
#   /plugin uninstall codex@openai-codex
```

### B.2 — Instalar plugin `@percus/review`

Se não estiver instalado a nível de usuário, seguir [`SETUP_REVIEW_ROUTING.md`](SETUP_REVIEW_ROUTING.md) Passo 2.

Caminho rápido (CLI standalone):
```
/plugin marketplace add huboperacional/percus-kit
/plugin install percus-review
```

**Alternativo (kit local):** `/plugin marketplace add D:/Claud Automations/_Novo_Projeto` + `/plugin install percus-review
```

### B.3 — Validar `DEEPSEEK_API_KEY`

Se ausente do `.env`: PARAR. Instruir usuário a obter chave em https://platform.deepseek.com.

### B.4 — Substituir `AGENTS.md` (versão Codex-era → slim)

Recriar a partir de [`templates/AGENTS.template.md`](../templates/AGENTS.template.md) (~4.4 KB). Preservar seções "O que é este projeto" e "Stack" se já estavam preenchidas.

Se espelho-3 ativo (`GEMINI.md` presente): aplicar mesma reescrita lá.

### B.5 — Atualizar `CLAUDE.md` (refs Codex → Percus)

Substituir qualquer seção tipo:

```markdown
## Code review cross-provider (R11)

`/codex:review` é obrigatório em DOIS momentos:
...
```

Por:

```markdown
## Review cross-provider (R11)

`/percus-review:review` é obrigatório em DOIS momentos:
1. Antes de cada commit (router auto: DeepSeek/Cross-Claude/duplo)
2. Ao concluir cada marco: `/percus-review:milestone-review --base <commit-inicio-marco>` (DeepSeek + Cross-Claude duplo)

Matriz de routing detalhada: `D:/Claud Automations/_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md` R11.
Plugin Codex (`codex@openai-codex`) descontinuado em 2026-05-03 por custo.

## Routing de modelos (R13) — marker obrigatório

Ao aplicar saída DeepSeek via wrapper, commit message deve terminar com:

\`\`\`
Co-implemented-by: deepseek-v4
\`\`\`

O router de R11 detecta esse trailer e roteia revisão pra Cross-Claude (anti auto-revisão).
```

Aplicar em `CLAUDE.md`, `AGENTS.md` e `GEMINI.md` (se espelho-3).

### B.6 — `.gitignore`

Adicionar `.deepseek/` se ausente. Linha `.codex/` pode permanecer ou ser removida (não atrapalha).

### B.7 — Smoke test

```
git add -A  # se há mudanças no AGENTS.md/CLAUDE.md
/percus-review:review
```

Esperado: router decide DeepSeek (default), retorna findings em < 5s, custo ~$0.001-0.01.

### B.8 — HANDOFF.md

Adicionar nota:

```markdown
## Migração Fase 2/3 → Fase 4 aplicada em {data}

Removido:
- .codex/ (config local Codex)
- Plugin codex@openai-codex (uninstall opcional, fica órfão se mantido)
- Refs /codex:review em CLAUDE.md/AGENTS.md/GEMINI.md

Instalado:
- Plugin @percus/review (DeepSeek + Cross-Claude)
- AGENTS.md slim (~4.4 KB)
- CLAUDE.md com R11 nova + R13 trailer

Custo mensal estimado: $2-5 (vs $200-400 com Codex anterior).
```

### B.9 — Reportar

```
✅ MIGRAÇÃO FASE 2/3 → FASE 4 CONCLUÍDA — {Nome}

Removido:
✅ .codex/ apagado
✅ Refs /codex:review substituídas em CLAUDE/AGENTS/GEMINI
ℹ️ Plugin codex@openai-codex pode ser desinstalado manualmente: /plugin uninstall codex@openai-codex

Instalado:
✅ Plugin @percus/review
✅ AGENTS.md slim (~4.4 KB)
✅ CLAUDE.md com R11 nova
✅ /percus-review:review smoke test passou
✅ HANDOFF.md atualizado

Tempo total: ~5-8 min
Custo do upgrade: ~$0.01

Próximo commit: usar /percus-review:review (router auto).
Próximo marco: /percus-review:milestone-review --base <commit>.
```

---

## Caminho C — Upgrade completo (Fase 0 legado → Fase 4)

Projeto não tem nada do kit Percus. Aplicar tudo de uma vez.

Delegar pro fluxo completo de [`UPGRADE_PROJETO_FASE2.md`](UPGRADE_PROJETO_FASE2.md) (apesar do nome legado, o conteúdo já é Fase 4):

1. **Passo 1** — Plugin `@percus/review` (R11)
2. **Passo 1.5** — Pular (não tem Codex pra migrar nesse caminho)
3. **Passo 2** — DeepSeek implementador (R13)
4. **Passo 3** — Design workflow (R10) — só atualizar referências
5. **Passo 4** — Mesclar R10/R11/R13 em `CLAUDE.md` + `AGENTS.md` (+ `GEMINI.md` se espelho-3)
6. **Passo 5** — `.gitignore` com `.deepseek/`
7. **Passo 6** — Smoke test combinado (`/percus-review:review` + DeepSeek dry-run)
8. **Passo 7** — HANDOFF
9. **Passo 8** — Reportar

Tempo estimado: ~10-15 min.

Reportar ao final:
```
✅ UPGRADE COMPLETO FASE 4 APLICADO — {Nome}
(detalhes do Passo 8 do UPGRADE_PROJETO_FASE2.md)
```

---

## Anti-padrões

- ❌ Pular Passo 0 (diagnóstico) e tentar adivinhar o estado — vai duplicar trabalho ou quebrar config existente
- ❌ Executar Caminho B em projeto Fase 0 legado — vai falhar porque não tem Codex pra remover
- ❌ Executar Caminho C em projeto que tem Codex configurado — sobrescreve sem migrar; gera resíduo
- ❌ Não ler `GEMINI.md` (espelho-3) — quebra invariante interna do projeto silenciosamente
- ❌ Tocar em código de negócio — esse upgrade é só ferramentas/configs/regras

---

## Quando NÃO usar este comando

- **Projeto novo greenfield** → use `00_LEIA_PRIMEIRO.md` + `CHECKLIST_INICIO_SESSAO.md`. O kit já parte de Fase 4.
- **Quero auditar uso (não config)** → use [`HEALTHCHECK_FASE2.md`](HEALTHCHECK_FASE2.md).
- **Só preciso de uma peça** (review-routing isolado, ou só DeepSeek) → granulares: `SETUP_REVIEW_ROUTING.md`, `SETUP_DEEPSEEK.md`.

---

## Referências

- Setup isolado revisor: [`SETUP_REVIEW_ROUTING.md`](SETUP_REVIEW_ROUTING.md)
- Setup isolado DeepSeek: [`SETUP_DEEPSEEK.md`](SETUP_DEEPSEEK.md)
- Upgrade detalhado completo: [`UPGRADE_PROJETO_FASE2.md`](UPGRADE_PROJETO_FASE2.md) (mesmo conteúdo Fase 4 apesar do nome)
- Healthcheck: [`HEALTHCHECK_FASE2.md`](HEALTHCHECK_FASE2.md)
- Plugin: `D:/Claud Automations/_Novo_Projeto/plugin/percus-review/`
- Regras: `D:/Claud Automations/_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md` R11, R13
- Routing de modelos: `D:/Claud Automations/_Novo_Projeto/04_MODEL_ROUTING.md`
