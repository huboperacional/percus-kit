---
tipo: routing-rules
prevalece-sobre: nenhum (regras inegociáveis vencem)
prevalecido-por: [01_REGRAS_INEGOCIAVEIS, CLAUDE.md do projeto]
quando-usar: SEMPRE — define qual modelo executa qual tipo de task
leitura: 4 min
ultima-atualizacao: 2026-05-02
---

# 04 — Roteamento de Modelos por Task

> **Por que existe:** consumir Claude Opus pra todo trabalho é caro e bate limite de produção. DeepSeek V4 e revisor cross-provider são bons o suficiente para faixas específicas — usá-los corta 60–80% do consumo Claude sem sacrificar qualidade quando combinados com revisão cruzada.

---

## Os três papéis

| Papel | Modelo | Provedor | Quando |
|---|---|---|---|
| **Arquiteto** | Claude Opus / Sonnet | Anthropic | Brainstorm, plano, decisão de arquitetura, revisão final, debug não-trivial, tasks em pasta sensível |
| **Implementador** | DeepSeek V4 (`deepseek-chat`) | DeepSeek | Execução de plano explícito, scaffolding, refactor mecânico, boilerplate, testes triviais |
| **Revisor cross-provider** | DeepSeek (`deepseek-chat`) + Cross-Claude (Sonnet subagent) | DeepSeek Inc + Anthropic | Pre-commit (R11) e marco (R11 ampliada) — router decide qual aciona |

Os papéis não se sobrepõem: cada modelo faz uma coisa, e a saída de cada um é validada por outro.

---

## Roteamento de revisores (R11)

Revisor não é mais um único modelo (Codex foi descontinuado em 2026-05-03 por custo). Hoje é **multi-modelo com router automático**:

| Cenário | Reviewer | Custo/call |
|---|---|---|
| Pre-commit rotineiro | DeepSeek apenas | ~$0.02 |
| Pre-commit em pasta sensível | DeepSeek + Cross-Claude duplo | ~$0.05 + $0 |
| Pre-commit de saída DeepSeek (trailer `Co-implemented-by: deepseek-v4`) | Cross-Claude apenas | $0 |
| Marco | DeepSeek + Cross-Claude duplo | ~$0.05 + $0 |

Canal: plugin `@percus/review` (instalar via `/plugin install percus-review`). Setup completo em `D:/Claud Automations/_Novo_Projeto/comandos/SETUP_REVIEW_ROUTING.md`.

**Por que sem Codex/OpenAI:** custo era ~$1.25/M input + reasoning effort não controlável + escopo de leitura amplo decidido pelo modelo. Em ritmo de uso real, projetava $200-400/mês. DeepSeek + Cross-Claude duplo cobre cross-provider (DeepSeek Inc ≠ Anthropic) com custo agregado $2-5/mês.

---

## Quando o Claude DEVE delegar para DeepSeek

Delegação é regra, não exceção, quando **todos** os critérios abaixo se aplicam:

- ✅ A task tem plano escrito (markdown), não só descrição verbal
- ✅ Os arquivos-alvo estão nomeados no plano
- ✅ Não há decisão de arquitetura pendente
- ✅ Não toca pasta sensível (ver matriz abaixo)
- ✅ Cabe em ≤3 arquivos OU é padrão repetido (rename, refactor mecânico em N arquivos)

**Casos de uso típicos:**

| Task | Por que delegar |
|---|---|
| Scaffolding de rota CRUD seguindo template Percus | Padrão fixo, sem decisão |
| Renomear símbolo em N arquivos | Mecânico |
| Dividir arquivo grande em 2-3 menores sem mudar lógica | Mecânico |
| Gerar teste vitest pra função pura existente | Padrão fixo |
| Adicionar getter/setter, validação de schema zod | Boilerplate |
| Migração de import (mudou caminho de pacote) | Mecânico em massa |

---

## Quando o Claude NÃO DEVE delegar

Mantenha localmente (Claude Opus/Sonnet) quando:

- ❌ Decisão arquitetural ou trade-off (escolha de abordagem, novo padrão)
- ❌ Debug onde a causa não está identificada
- ❌ Mudanças que cruzam >3 arquivos sem padrão claro
- ❌ Task em pasta sensível: `**/auth/**`, `**/payment*/**`, `**/migrations/**`, `**/credentials/**`, arquivos `.env*`
- ❌ Brainstorm ou exploração (`superpowers:brainstorming`, `Explore`)
- ❌ Code review de output de outro modelo (use revisor cross-provider via `/percus:review`)
- ❌ Tasks visuais (segue `comandos/DESIGN_WORKFLOW.md`)

Para tasks tão pequenas que não compensam orquestrar (ex.: trocar uma string em um arquivo), faça você mesmo via Edit. O custo de orquestrar (montar plano, invocar wrapper, validar) supera o ganho.

---

## Como delegar — playbook do Claude orquestrador

> Esta seção substitui a antiga abstração de "subagent". O Claude da sessão principal executa direto, sem registrar agente intermediário no harness.

### Pré-requisitos
- Estar dentro de um projeto Percus com `DEEPSEEK_API_KEY` no `.env` (wrapper auto-carrega)
- Wrapper presente em `D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.{ps1,sh}`
- `CLAUDE.md` e `AGENTS.md` do projeto existem (DeepSeek lê via `--rules` pra herdar regras Percus)

### Passo 1 — Validar elegibilidade

Aplique a checklist da seção "Quando o Claude DEVE delegar". Se algum critério falha, **não delegue**:
- Sem plano escrito → use `superpowers:writing-plans` antes
- Decisão arquitetural pendente → use `superpowers:brainstorming` antes
- Pasta sensível → implementação Claude direto
- Escopo > 3 arquivos sem padrão → divida em sub-tasks ou implemente direto

Comunique a decisão ao usuário em uma frase: *"Vou delegar pro DeepSeek (task mecânica, plano explícito)"* ou *"Vou implementar direto (decisão arquitetural envolvida)"*.

### Passo 2 — Verificar pré-condições no shell

```powershell
# Diretório atual tem .env com DEEPSEEK_API_KEY?
Test-Path .env
Select-String -Path .env -Pattern '^DEEPSEEK_API_KEY=' -Quiet

# Regras do projeto presentes?
Test-Path CLAUDE.md, AGENTS.md
```

Se faltar `AGENTS.md`, o DeepSeek implementaria sem regras Percus — pare e oriente o usuário a rodar `comandos/SETUP_REVIEW_ROUTING.md` primeiro.

### Passo 3 — Invocar o wrapper em DRY-RUN (sempre primeiro)

Windows / PowerShell:
```powershell
powershell -File "D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.ps1" `
  -Task "<plano.md>" `
  -Files "<arquivo1>","<arquivo2>" `
  -DryRun
```

Linux / Mac / WSL:
```bash
bash "D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.sh" \
  --task "<plano.md>" \
  --files "<arquivo1>,<arquivo2>" \
  --dry-run
```

### Passo 4 — Validar a saída do dry-run contra R1–R13

Antes de propor `--apply` ao usuário, cheque:

- [ ] Todos os blocos `===WRITE: <path>===` apontam pra arquivos **dentro** do escopo da task
- [ ] Nenhum arquivo está em pasta sensível (auth/payment/migrations/.env)
- [ ] Não veio `===REJECT===` (se veio, leia o motivo e devolva pro usuário decidir)
- [ ] Sem mock escondido em código de produção (R3)
- [ ] Frontend: sem `localStorage` pra JWT, sem import `@supabase/*` (R7)
- [ ] Backend: sem violação da stack (R7) — sem GoTrue/PostgREST

**Se algo falha**, não tente corrigir sozinho — devolva o diagnóstico pro usuário e pergunte: ajusta o plano e refaz, ou implementa direto?

### Passo 5 — Aplicar (apenas com autorização explícita do usuário)

```powershell
powershell -File "D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.ps1" `
  -Task "<plano.md>" `
  -Files "..." `
  -Apply
```

Após apply:
1. Rode `git status` pra confirmar o que mudou
2. **Avise o usuário:** *"Saída aplicada. Lembrar de incluir trailer `Co-implemented-by: deepseek-v4` no commit (R13). Antes de commit, rodar `/percus:review` — router detecta o trailer e roteia pra Cross-Claude (não-DeepSeek auto-revisão). Antes de fechar marco, `/percus:milestone-review --base <commit>`. R11."*

### Passo 6 — Marcar feature no PLANO + HANDOFF com `🤖`

Após apply autorizado, antes de reportar: editar `docs/PLANO.md` e `HANDOFF.md` adicionando o símbolo **`🤖`** na entrada da feature (R2 marcações visuais). Não é cosmético — é rastro de auditoria. Permite olhar o PLANO 6 meses depois e saber "essa parte foi feita por DeepSeek, log em `.deepseek/runs/`".

Exemplo de antes/depois:
```
- [3-H] {Feature X} — próxima: componente
  ↓ após delegação aplicada
- [3-H] 🤖 {Feature X} — próxima: componente (impl. via DeepSeek, log <ts>)
```

Se a feature já tem outras marcações (`🎨`, `🎨?`), adiciona `🤖` ao lado — marcações acumulam.

### Passo 7 — Reportar

Estrutura de report ao usuário:

```
[DeepSeek] CONCLUÍDO

Modelo: deepseek-chat (V3.1/V4)
Modo: <dry-run|apply>
Tokens: prompt=X completion=Y total=Z (custo ~$W)
Log: .deepseek/runs/<ts>.jsonl

Arquivos tocados:
  + <path1> (N linhas)
  + <path2> (N linhas)

Validações Percus:
  ✅ R1 (CRUD): [N/A | pendente — ciclo manual]
  ✅ R3 (sem mock escondido): OK | ALERTA: <...>
  ✅ R7 (auth Percus / stack): OK | ALERTA: <...>
  ✅ Pastas sensíveis intactas: OK

Próximo passo: /percus:review antes do commit OU /percus:milestone-review --base <branch> ao fechar marco (R11). Commit deve incluir trailer `Co-implemented-by: deepseek-v4` (R13).
```

---

## Verificação obrigatória pós-DeepSeek

Toda saída do DeepSeek é **rascunho** até passar por:

1. **Validação Claude (você, na sessão principal)**: confere contra R1–R13 antes de aceitar
2. **Review cross-provider (R11)**: gate de commit/marco via `/percus:review` — router escolhe reviewer (Cross-Claude obrigatório quando a saída é DeepSeek, evitando auto-revisão)
3. **Ciclo CRUD com F5 (R1)**: se a task afetou feature visível, ainda precisa rodar

Sem essas três camadas, output do DeepSeek **não vai pra produção**.

---

## Estimativa de economia

Premissas (preços públicos em 2026-05):
- Claude Opus 4.7: ~$15/M tokens input, ~$75/M output
- DeepSeek V4: ~$0.27/M input (cache hit ~$0.07/M), ~$1.10/M output

Para uma task de implementação de ~50k tokens (input plano+contexto, output código+diff):

| Cenário | Custo |
|---|---|
| Tudo no Claude Opus | ~$3.50 |
| Implementação no DeepSeek + revisão Claude (5k tokens) + revisor cross-provider | ~$0.30–0.50 |
| **Economia** | **~85%** |

Multiplicado pelo volume diário Percus, libera margem de cota Anthropic pra o que realmente precisa de Claude (arquitetura, brainstorm, debug).

---

## Anti-padrões

- ❌ Delegar pra DeepSeek e pular revisão Claude ("ele já é bom") — viola garantia cross-provider
- ❌ Pular `/percus:review` porque "DeepSeek + Claude já revisaram" — revisor cross-provider é gate independente, propósito é cobertura cross-provider sem auto-revisão
- ❌ Delegar tasks ambíguas e esperar que DeepSeek "se vire" — wrapper retorna `===REJECT===` corretamente, mas é desperdício de tokens
- ❌ Aplicar `--apply` direto sem dry-run — nunca confiar cego, mesmo em task simples
- ❌ Implementar direto algo que cabe no DeepSeek "porque é mais rápido" — defaulta a delegar quando elegível
- ❌ Usar DeepSeek pra task em pasta sensível "porque é só uma linha" — auth/payment/migration sempre Claude
- ❌ "Melhorar" output do DeepSeek na sessão principal — ou aceita inteiro, ou rejeita e refaz o plano

---

## Referências cruzadas

- Wrapper: `_Novo_Projeto/scripts/deepseek-impl.ps1` + `.sh`
- Regra: `01_REGRAS_INEGOCIAVEIS.md` R13
- Revisor cross-provider: `comandos/SETUP_REVIEW_ROUTING.md` + R11
- Design (não-DeepSeek): `comandos/DESIGN_WORKFLOW.md`
