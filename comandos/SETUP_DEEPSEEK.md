---
tipo: comando-pronto
quando-usar: 1ª vez configurando DeepSeek como implementador delegado num projeto Percus (Fase 2 do plano cross-provider)
nao-toca-codigo: true
leitura: 4 min (execução: ~5 min se .env já tem chave, ~10 min se faltar tudo)
ultima-atualizacao: 2026-05-02
---

# Setup — DeepSeek como Implementador Delegado (Fase 2)

> Cole este prompt no agente Claude Code do projeto onde quer ativar a delegação ao DeepSeek.
> O agente vai **detectar o que falta**, **pedir autorização antes de mexer em qualquer config**, e validar o fluxo com um smoke test em dry-run.
> Não toca código de negócio. Só configura ferramentas e testa.

---

## Objetivo

Habilitar o **DeepSeek V4** como **implementador delegado** para tarefas de implementação mecânica (scaffolding, refactor, boilerplate). Saída do DeepSeek é sempre revisada por Claude e por Codex (R11) antes de virar commit. Detalhes em `_Novo_Projeto/04_MODEL_ROUTING.md`.

**Escopo da Fase 2:** DeepSeek **NÃO** decide arquitetura, **NÃO** entra em pasta sensível (auth/payment/migrations). Só executa plano explícito em arquivos nomeados.

---

## O que o agente vai fazer (na ordem)

### Passo 1 — Detectar o que está instalado

Rodar verificações silenciosas e **PARAR + INSTRUIR** para cada item faltando:

```powershell
# 1. DEEPSEEK_API_KEY no .env do projeto?
Test-Path .env
Select-String -Path .env -Pattern '^DEEPSEEK_API_KEY=' -Quiet
# Se ausente: PARE e instrua o usuário a obter a chave em https://platform.deepseek.com/api_keys e adicionar no .env

# 2. Wrapper presente no kit Percus?
Test-Path "D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.ps1"
Test-Path "D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.sh"
# Se ausente: o kit Percus está incompleto. PARE e instrua a clonar/atualizar D:/Claud Automations/_Novo_Projeto/

# 3. PowerShell version (Windows)?
$PSVersionTable.PSVersion.Major
# 5.1 funciona (wrapper já tem fix UTF-8 byte array). 7+ é melhor mas opcional.

# 4. AGENTS.md do projeto presente?
Test-Path AGENTS.md
# Se ausente: PARE e ofereça rodar SETUP_REVIEW_ROUTING.md primeiro (cria AGENTS.md espelhando regras Percus)
```

**REGRA OPERACIONAL:** o agente não pode "tentar continuar" se algo faltar. Cada item ausente é um **gate** que bloqueia até o usuário confirmar correção.

---

### Passo 2 — Adicionar `.deepseek/` ao `.gitignore` do projeto

Confirmar que essas linhas estão no `.gitignore` (adicionar se faltar):

```gitignore
# Logs e artefatos do worker DeepSeek (R13)
.deepseek/
```

Se o projeto não tem `.gitignore`, criar um básico baseado em `templates/.gitignore.example` do kit Percus.

---

### Passo 3 — Smoke test em dry-run

Criar arquivo temporário `_smoke-deepseek.md` na raiz do projeto:

```markdown
# Smoke test DeepSeek

Crie uma função Python pura `somar(a: int, b: int) -> int` num arquivo `_smoke-deepseek.py`.
A função soma os dois argumentos e retorna o resultado. Type hints obrigatórios. Sem dependências externas.

Critério de aceitação: `python -c "from _smoke_deepseek import somar; assert somar(2, 3) == 5"` retorna sem erro.
```

Rodar wrapper em dry-run (ele auto-carrega o `.env`):

```powershell
powershell -File "D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.ps1" `
  -Task "_smoke-deepseek.md" `
  -DryRun
```

**Esperado:**
- Tokens consumidos < 1500
- 1 bloco `===WRITE: _smoke-deepseek.py===` no output
- Custo estimado < $0.001
- Log gerado em `.deepseek/runs/<timestamp>.jsonl`
- Sem `===REJECT===`

Se passou: deletar `_smoke-deepseek.md` (não aplicar). Smoke test serve só pra validar que o pipeline responde.

Se falhou:
- `DEEPSEEK_API_KEY ausente` → voltar Passo 1
- `invalid unicode code point` → wrapper PS está desatualizado, atualizar do kit Percus
- Timeout → checar conectividade com `curl https://api.deepseek.com/v1/models`

---

### Passo 4 — Atualizar `CLAUDE.md` do projeto

Adicionar (ou confirmar presença) na seção "Workflow obrigatório":

```markdown
## Routing de modelos (R13)

Tasks de implementação mecânica devem ser delegadas ao DeepSeek V4 via wrapper `D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.{ps1,sh}`. Saída do DeepSeek é tratada como rascunho — sempre revisada por Claude (validação contra R1–R12) e por revisor cross-provider via `/percus-review:review` (R11) antes de virar commit. Commit message deve incluir trailer `Co-implemented-by: deepseek-v4`.

**Quando delegar (TODOS os critérios):**
- Plano explícito em markdown, com arquivos-alvo nomeados
- Sem decisão arquitetural pendente
- Não toca pasta sensível (auth/, payment*/, migrations/, credentials/, .env*)
- Cabe em ≤3 arquivos OU é padrão repetido em N arquivos

**Quando NÃO delegar:** brainstorm, decisão arquitetural, debug de causa desconhecida, pasta sensível.

Playbook completo: `D:/Claud Automations/_Novo_Projeto/04_MODEL_ROUTING.md` seção "Como delegar".
```

E em `AGENTS.md` (Codex precisa saber pra revisar saída do DeepSeek com critério):

```markdown
## R13 — Routing de modelos

Tarefas de implementação mecânica delegadas ao DeepSeek. Saída do DeepSeek **deve** ser revisada antes do commit (router roteia pra Cross-Claude se trailer `Co-implemented-by: deepseek-v4` presente). Revisor foca em:
- Detectar bugs ou regressões introduzidas pelo código gerado
- Confirmar que o output respeita R1–R12 (CRUD, mock, credenciais, auth Percus, etc)
- Sinalizar se DeepSeek tocou pasta fora do escopo da task
```

---

### Passo 5 — Reportar ao usuário

Mensagem final estruturada:

```
SETUP DEEPSEEK CONCLUÍDO — {Nome do Projeto}

✅ DEEPSEEK_API_KEY presente em .env
✅ Wrapper acessível em D:/Claud Automations/_Novo_Projeto/scripts/
✅ .deepseek/ no .gitignore do projeto
✅ Smoke test em dry-run passou (X tokens, ~$Y de custo)
✅ CLAUDE.md atualizado com R13
✅ AGENTS.md atualizado com R13

Próximos passos:
1. Quando aparecer task elegível (plano explícito, mecânica, sem ambiguidade), siga playbook em 04_MODEL_ROUTING.md "Como delegar"
2. Toda saída do DeepSeek passa por /percus-review:review antes de commit (R11). Adicionar trailer `Co-implemented-by: deepseek-v4` ao commit message — router roteia pra Cross-Claude (anti auto-revisão)
3. Logs auditáveis em .deepseek/runs/ a cada chamada
```

---

## Anti-padrões durante o setup

- ❌ Pular Passo 1 e tentar rodar smoke test "no escuro" — sem chave o wrapper falha em exit 2
- ❌ Continuar após erro em qualquer passo "achando que dá certo no próximo"
- ❌ Não criar `AGENTS.md` antes — Codex revisa saída do DeepSeek sem conhecer R13
- ❌ Esquecer `.deepseek/` no `.gitignore` — vaza logs com prompts/respostas pro repo
- ❌ Aplicar smoke test (`-Apply`) em vez de só dry-run — polui o repo com `_smoke-deepseek.py` que tem que apagar depois

---

## Pegadinhas conhecidas

| Sintoma | Causa | Solução |
|---|---|---|
| `DEEPSEEK_API_KEY nao encontrada` | `.env` ausente ou chave não tem prefixo `DEEPSEEK_API_KEY=` | Conferir formato exato no `.env` |
| `invalid unicode code point` | PS 5.1 + wrapper desatualizado (sem fix UTF-8 byte array) | Atualizar `deepseek-impl.ps1` do kit Percus (tem fix desde 2026-05-02) |
| Wrapper retorna `===REJECT===` | Task ambígua ou plano sem arquivos nomeados | Reformular task com arquivos explícitos OU implementar direto no Claude |
| Output sem blocos `===WRITE===` | DeepSeek devolveu prosa em vez de blocos formatados | Pode acontecer com modelos diferentes; reformular system prompt no wrapper |
| Custo passou de $0.10 numa task pequena | `--files` com arquivos enormes empurrando contexto | Reduzir lista de `-Files` ou dividir task em sub-tasks |

---

## Pré-requisitos resumidos (lista que o agente vai verificar)

- [ ] `.env` do projeto contém `DEEPSEEK_API_KEY=...` (chave válida em https://platform.deepseek.com/api_keys)
- [ ] Wrapper presente: `D:/Claud Automations/_Novo_Projeto/scripts/deepseek-impl.ps1` + `.sh`
- [ ] PowerShell 5.1+ (Windows) ou Bash 4+ (Linux/Mac/WSL)
- [ ] `AGENTS.md` do projeto existe (rodar `SETUP_REVIEW_ROUTING.md` primeiro se faltar)
- [ ] `.deepseek/` no `.gitignore`
- [ ] Smoke test em dry-run executado e passou

---

## Referências

- **Playbook operacional:** `_Novo_Projeto/04_MODEL_ROUTING.md` (matriz + 6 passos do "Como delegar")
- **Regra:** `_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md` R13
- **Wrapper:** `_Novo_Projeto/scripts/deepseek-impl.ps1` + `.sh`
- **Revisor cross-provider (DeepSeek+Cross-Claude):** `_Novo_Projeto/comandos/SETUP_REVIEW_ROUTING.md` + R11
- **API DeepSeek:** https://api.deepseek.com (modelo: `deepseek-chat` = V3.1/V4)
