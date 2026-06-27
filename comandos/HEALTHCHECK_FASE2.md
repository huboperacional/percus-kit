---
tipo: comando-pronto
quando-usar: auditar se um projeto Percus está realmente USANDO Fase 4 (DeepSeek + @percus/review), não só configurado
nao-toca-codigo: true
leitura: 3 min (execução: ~2 min auto + opcional ~30s teste comportamental)
ultima-atualizacao: 2026-05-03
---

# Healthcheck — a stack de tooling (review + DeepSeek) está sendo usada de verdade?

> ℹ️ **Auditoria de adoção de tooling** (função distinta da chain de upgrade — não atualiza nada, só audita).
> Para *atualizar* um projeto pro canon atual, use `comandos/REORGANIZAR_PROJETO.md` (umbrella). O nome "Fase 4"
> é histórico; o que se audita aqui é se o plugin de review + o DeepSeek estão de fato em uso.
>
> Cole o prompt abaixo no chat do Claude Code do projeto que você quer auditar.
>
> **Configuração ≠ Adoção.** Esse comando verifica os 2: arquivos no lugar certo (Nível 1 + 2) E comportamento do agente (Nível 3 opcional).

---

## Prompt para colar

```
Faça healthcheck Fase 4 deste projeto, conforme `${env:PERCUS_CANON_DIR}\comandos\HEALTHCHECK_FASE2.md`.

Execute os 3 níveis em sequência e me devolva relatório estruturado no fim. Não toque em código de negócio. Não tente "consertar" o que estiver errado — só reporta.

## Nível 1 — Configuração instalada (filesystem)

Verifique e reporte status (✅ OK / ❌ FALTA) pra cada item:

**Plugin @percus/review:**
- Plugin habilitado em `enabledPlugins` do settings.json do Claude Code? **Detecte o config dir real primeiro:** `$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }`. Procure `percus-review|@percus` em `$claudeHome\settings.json` (campo `enabledPlugins`) E como pasta em `$claudeHome\plugins\`. **Não use `~/.claude/` direto** — em máquinas Percus `CLAUDE_CONFIG_DIR` aponta pra `D:\Claud Automations\.claude-home\` e ler o path default dá falso-negativo.
- AGENTS.md existe na raiz?
- AGENTS.md tem versão slim (~4-5 KB) e menciona "revisor cross-provider"?

**DeepSeek:**
- `.env` contém `DEEPSEEK_API_KEY=...`?
- `.gitignore` contém linha `.deepseek/`?
- Wrapper acessível em `${env:PERCUS_CANON_DIR}/scripts/deepseek-impl.ps1`?

**CLAUDE.md (regras):**
- Menciona R10 (design v0/shadcn, NÃO Claude artifacts)?
- Menciona R11 (`/percus-review:review` cross-provider)?
- Menciona R13 (DeepSeek routing + trailer `Co-implemented-by: deepseek-v4`)?

**HANDOFF.md:**
- Existe?
- Menciona "Fase 4 aplicada" ou data do upgrade?

## Nível 2 — Uso histórico (rastros auditáveis)

**DeepSeek implementação (R13):**
- Conte arquivos `.jsonl` em `.deepseek/runs/`. Se 0 ou pasta inexistente: DeepSeek nunca foi invocado como implementador.
- Se houver, some `usage.total_tokens` de todos os logs e estime custo (~$0.0000005/token).
- Liste as 3 chamadas mais recentes (timestamp + task + tokens).

**DeepSeek revisão (R11):**
- Conte arquivos `.jsonl` em `.deepseek/reviews/`. Se 0 após 1+ semana de uso: review nunca foi invocado.
- Liste as 3 reviews mais recentes (timestamp + diff_lines).

**Commits com trailer DeepSeek (R13):**
- `git log --grep='Co-implemented-by: deepseek' --oneline | wc -l` — conte commits que vieram do wrapper.

**PLANO.md:**
- Conte features marcadas com `🤖` (delegadas pro DeepSeek)
- Conte features marcadas com `✓` (review aprovado no marco)
- Se 0 de cada após 1+ semanas pós-upgrade: sinal forte de não-adoção.

## Nível 3 — Teste comportamental (opcional, ~30s, ~$0.001)

**Só execute se o usuário autorizar explicitamente** — Nível 3 invoca o wrapper DeepSeek de verdade (custo ~$0.001).

Pergunte ao usuário: "Posso rodar teste comportamental DeepSeek? Custa ~$0.001."

Se SIM:
1. Crie `_healthcheck-task.md` temporário com:
   ```
   Crie helper Python puro `_healthcheck-out.py` com função `is_even(n: int) -> bool` que retorna True se n é par. Type hints, sem dependências externas.
   ```
2. Invoque dry-run:
   ```
   powershell -File "${env:PERCUS_CANON_DIR}/scripts/deepseek-impl.ps1" -Task "_healthcheck-task.md" -DryRun
   ```
3. Reporte:
   - Wrapper rodou sem erro? (✅/❌)
   - Tokens consumidos
   - Tempo total
   - Bloco `===WRITE===` foi gerado?
4. Apague `_healthcheck-task.md` e qualquer artefato gerado.

Se NÃO: pula Nível 3, anota no relatório que foi pulado.

## Relatório final (formato obrigatório)

```
=== HEALTHCHECK FASE 4 — {Nome do Projeto} ===
Data: {YYYY-MM-DD HH:MM}

[Nível 1 — Configuração]
Plugin @percus/review:    X/3 OK
DeepSeek (impl):          X/3 OK
CLAUDE.md regras:         X/3 OK
HANDOFF:                  X/2 OK
TOTAL CONFIG:             X/11

[Nível 2 — Uso histórico]
.deepseek/runs/      — N chamadas, M tokens (~$Y) implementação
.deepseek/reviews/   — N reviews
Commits com trailer  — N (Co-implemented-by: deepseek)
PLANO 🤖 (delegadas) — N features
PLANO ✓ (marco aprovado) — N features

[Nível 3 — Teste comportamental]
{Status: executado OK | pulado pelo usuário | falhou (motivo)}

[Diagnóstico]
{1-2 frases honestas: "configuração OK e ativo" | "configurado mas zero uso" | "config quebrada em X"}

[Ações sugeridas]
- {se nivel 1 falhou} → rodar UPGRADE_PROJETO_FASE2.md de novo
- {se nivel 2 zero} → reforçar G-DELEGA / G-REVIEW na próxima sessão
- {se nivel 3 falhou} → diagnosticar wrapper (.env, PowerShell version)
```

Não execute nenhuma das ações sugeridas. Só reporta. Usuário decide.
```

---

## Como interpretar o relatório

### Cenário A — "Tudo OK e ativo"
Config 14/14, `.deepseek/runs/` e `.deepseek/reviews/` com chamadas recentes, PLANO tem 🤖/✓, Nível 3 passou.
**Ação:** nada. Está funcionando como esperado.

### Cenário B — "Configurado mas não usado"
Config 14/14, mas `.deepseek/` vazio e PLANO sem 🤖/✓ semanas após upgrade.
**Causa provável:** as tasks que apareceram no projeto não foram elegíveis pra DeepSeek (decisões arquiteturais, debug, cross-cutting). Não é problema necessariamente.
**Ação:** na próxima feature mecânica (CRUD novo, refactor de rename, boilerplate), reforçar pro agente: "siga G-DELEGA estritamente". Pra review (R11), confirmar que `/percus-review:review` está sendo rodado pre-commit.

### Cenário C — "Configuração quebrada"
Config X/14 com X < 11.
**Causa:** upgrade não foi aplicado completo, ou alguém removeu manualmente.
**Ação:** rodar `UPGRADE_PROJETO_FASE2.md` de novo — ele detecta o que falta e completa.

### Cenário E — "Nível 3 falhou"
Wrapper retornou erro mesmo com config OK.
**Causa provável:** `DEEPSEEK_API_KEY` inválida, PowerShell muito antigo, encoding bug não corrigido.
**Ação:** rodar `comandos/SETUP_DEEPSEEK.md` Passo 1 (diagnóstico) pra identificar o gap.

### Cenário F — "PLANO sem ✓ mas commits frequentes"
Review por marco está sendo pulado (R11 ampliada).
**Ação:** reforçar G-MARCO no `CHECKLIST_FEATURE_NOVA.md` na próxima fase de plano. Lembrar: marco usa `/percus-review:milestone-review --base <commit>`, não `/percus-review:review` simples.

---

## Quando rodar

- **1 semana após upgrade Fase 4** — pega adoção precoce / não-adoção precoce
- **Mensalmente em projetos ativos** — confere se o uso continua
- **Antes de auditar custo DeepSeek mensal** — vê se está dentro do budget esperado ($2-5/mês)
- **Quando suspeitar que algo regrediu** — agente parou de seguir R11/R13 sem motivo claro

---

## Anti-padrões

- ❌ Rodar healthcheck e não agir nos cenários B/C/D — virou cerimônia sem consequência
- ❌ Tratar "Nível 1 OK" como sucesso — configuração não prova uso
- ❌ Não autorizar Nível 3 e depois reclamar que "não tem como saber se DeepSeek funciona"
- ❌ Rodar todo dia — desperdício; semanal/mensal já cobre

---

## Referências

- Configuração inicial: `comandos/SETUP_REVIEW_ROUTING.md`, `comandos/SETUP_DEEPSEEK.md`, `comandos/UPGRADE_PROJETO_FASE2.md`
- Regras: `01_REGRAS_INEGOCIAVEIS.md` R10, R11, R13
- Marcações 🤖/✓: `01_REGRAS_INEGOCIAVEIS.md` R2 (Marcações visuais)
- Playbook DeepSeek + matriz de routing: `04_MODEL_ROUTING.md`
- Plugin: `${env:PERCUS_CANON_DIR}/plugin/percus-review/`
