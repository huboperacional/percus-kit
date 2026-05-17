---
tipo: comando-DEPRECATED
quando-usar: NÃO USE — substituído por SETUP_REVIEW_ROUTING.md em 2026-05-03
nao-toca-codigo: true
leitura: arquivo histórico
ultima-atualizacao: 2026-05-03 (deprecated)
---

> # ⛔ DEPRECATED desde 2026-05-03
>
> Este comando configurava **Codex CLI** como revisor cross-provider (R11 da Fase 1/2).
> **Codex foi descontinuado** no kit Percus por custo (~$200-400/mês projetado vs budget $20-30/mês).
>
> **Use no lugar:** [`SETUP_REVIEW_ROUTING.md`](SETUP_REVIEW_ROUTING.md) — instala plugin `@percus/review` (DeepSeek + Cross-Claude) com custo agregado $2-5/mês.
>
> Conteúdo abaixo mantido como referência histórica para projetos que ainda não migraram.

---

# Setup — Codex como Reviewer (Fase 1) [DEPRECATED]

> Cole este prompt no agente Claude Code do projeto onde quer ativar a revisão Codex.
> O agente vai **detectar o que falta**, **pedir para você instalar** e só prosseguir após confirmação.
> Não toca código de negócio. Só configura ferramentas.

---

## Objetivo

Habilitar o **Codex (OpenAI)** como **revisor automático** antes de cada commit, rodando em paralelo ao Claude Code no VS Code. Cobertura cross-provider de bugs reduz "sycophancy bias" — Claude e GPT erram em coisas diferentes.

**Escopo da Fase 1:** Codex **NÃO** escreve código. Só revisa.

---

## O que o agente vai fazer (na ordem)

### Passo 1 — Detectar o que está instalado

Rodar verificações silenciosas, e **PARAR + INSTRUIR** para qualquer item faltando:

```bash
# 1. VS Code instalado?
which code || command -v code
# Se não: PARE e instrua: "Instale VS Code de https://code.visualstudio.com/download"

# 2. Node.js 18.18+ instalado?
node --version
# Se < 18.18 ou não existe: PARE e instrua: "Instale Node.js 18.18+ de https://nodejs.org/"

# 3. Extensão Codex no VS Code?
code --list-extensions | grep -i "openai.chatgpt"
# Se ausente: PARE e ofereça instalar com: code --install-extension openai.chatgpt

# 4. Codex CLI global?
which codex || codex --version
# Se ausente: PARE e ofereça instalar com: npm install -g @openai/codex

# 5. Plugin Codex for Claude Code?
# Verificar se "/codex:setup" responde algo no Claude Code (presença do plugin)
# Se ausente: instruir o usuário a instalar via marketplace do Claude Code
# Repo oficial: https://github.com/openai/codex-plugin-cc

# 6. Login Codex (autenticação)
codex --version 2>&1 | grep -i "logged"
# Verificar se já está logado. Se não, oferecer 2 opções (ver Passo 3)
```

**REGRA OPERACIONAL:** o agente não pode "tentar continuar" se algo faltar. Cada item ausente é um **gate** que bloqueia até o usuário confirmar instalação.

---

### Passo 2 — Instalar plugin Codex no Claude Code

> ℹ️ **IMPORTANTE — onde rodar `/plugin`:** o slash `/plugin` **NÃO funciona no chat da extensão VS Code do Claude Code** (a extensão expõe a UI Manage Plugins, mas não o slash). `/plugin marketplace add` e `/plugin install` só rodam no **chat do Claude Code CLI standalone**, aberto no terminal via comando `claude`. Após instalar plugin pelo CLI, ele fica disponível em qualquer canal (CLI ou extensão) porque vive em config a nível de usuário (`~/.claude/plugins/`).
>
> **Não confundir com GitHub Copilot Chat** — Copilot interpreta `/plugin` como busca de extensão VS Code e responde "No extensions found...". Sempre confirme que está no chat **Claude Code**, não Copilot.
>
> Detecção rápida (terminal):
> ```powershell
> # CLI standalone instalado?
> Get-Command claude -ErrorAction SilentlyContinue
> ```
> Se vazio: rode `npm i -g @anthropic-ai/claude-code` antes de prosseguir.

#### Caminho A — CLI standalone via terminal (canal correto pra `/plugin`)

**1.** Abre PowerShell (qualquer pasta serve como cwd).

**2.** Inicia Claude Code no terminal:
```powershell
claude
```

Vai abrir um chat interativo **dentro do terminal** (interface ASCII, não a extensão VS Code). Você verá o welcome do Claude Code com `>` como prompt.

**3.** Cola os 2 slash commands, um de cada vez:
```
/plugin marketplace add openai/codex-plugin-cc
```
Esperado: `Successfully added marketplace: openai-codex`

```
/plugin install codex@openai-codex
```
Esperado: confirmação de instalação.

**4.** Sai do chat (`/exit` ou Ctrl+C 2x) e fecha+reabre todas as janelas VS Code pra reload completo.

**5.** Em qualquer chat Claude Code (CLI ou extensão), valida:
```
/codex:status
```
Deve responder com a tabela de status do Codex. Se responder = plugin global instalado, funciona em todos os projetos pra sempre.

#### Caminho B — Extensão VS Code via UI Manage Plugins (alternativa GUI)

Se preferir não usar terminal, dá pra instalar pela UI da extensão (mesmo resultado, mais cliques):

1. No chat da extensão Claude Code, digita `/plu` e clica em "Manage plugins" no dropdown
2. Aba **"Marketplaces"** → botão "Add" → cola `openai/codex-plugin-cc`
3. Aba **"Plugins"** → search "codex" → seção AVAILABLE → clica em `codex@openai-codex` → Install
4. **Fecha e reabre o VS Code** (reload completo)
5. No chat: `/codex:status` — deve responder OK

#### Caminho C — Plugin não instalável (fallback CLI Codex direto)

Se nem A nem B funcionarem (versão muito antiga, ambiente restrito, etc.), o fluxo continua viável **sem o plugin** — usa o Codex CLI direto do terminal:

| Ação | Comando (em vez de slash) |
|---|---|
| Review de mudanças não commitadas | `codex review --uncommitted` |
| Review de marco (escopo agregado) | `codex review --base <branch>` |
| Review de commit específico | `codex review --commit <sha>` |

R11 segue valendo — só muda o canal (terminal em vez de chat). Documentar essa escolha no `CLAUDE.md` do projeto: "neste projeto, codex review é via CLI no terminal (slash command indisponível)".

---

**Após qualquer um dos 3 caminhos:** confirma que Codex responde antes de prosseguir pro Passo 3.

---

### Passo 3 — Login do Codex CLI

Duas opções, agente pergunta ao usuário qual:

**Opção A — ChatGPT account (default da OpenAI)**
```bash
codex login
```
Abre browser pra autenticar com conta ChatGPT.

**Opção B — OpenAI API key (recomendado para Percus, já que `OPENAI_API_KEY` está em todos os `.env`)**
```bash
# Carregar do .env do projeto atual
export OPENAI_API_KEY=$(grep ^OPENAI_API_KEY= .env | cut -d= -f2)
codex login --api-key "$OPENAI_API_KEY"
```

> **Nota Percus:** Opção B é mais robusta porque sobrevive a sessões e não depende de browser login. Mas consome créditos da API key (não da assinatura ChatGPT). Confirmar com o usuário se faz sentido para o projeto.

---

### Passo 4 — Configurar modelo e reasoning effort

Criar `.codex/config.toml` na raiz do projeto:

```toml
# Configuração do Codex Plugin para este projeto
model = "gpt-5.4-mini"
model_reasoning_effort = "high"

# Modo só-revisor (Fase 1 do padrão Percus)
# O plugin não escreve código; só revisa diffs e propõe alterações como sugestões.
```

Adicionar `.codex/` ao `.gitignore` se não estiver:

```gitignore
.codex/
```

---

### Passo 5 — Criar `AGENTS.md` na raiz do projeto

Espelha as regras Percus do `CLAUDE.md` em formato que o Codex lê. **Sem isso, o Codex revisa sem conhecer R1-R12.**

Usar o template `${env:PERCUS_CANON_DIR}\templates\AGENTS.template.md` como base.

Conteúdo mínimo:
- Stack do projeto
- Critério de "pronto" (R1)
- Regra de mock (R3)
- Tracking `[0]→[5-T]` (R2)
- Stack vetada (R7 — GoTrue/PostgREST/Supabase)
- Convenções de código

**Nota sobre espelho-3:** se o projeto **já tem `GEMINI.md`** (convenção interna pra também alimentar Gemini CLI com mesmas regras), aplique a mesma criação/atualização lá também — `cp CLAUDE.md GEMINI.md` ou edite manualmente os 3 em paralelo. Não é convenção Percus, é por-projeto: se `Test-Path GEMINI.md` for true, manter espelho-3 ativo. Senão, ignore (espelho-2 padrão CLAUDE.md + AGENTS.md basta).

---

### Passo 6 — Smoke test

Garantir que existe `git diff` no working tree (faça uma mudança trivial em qualquer arquivo se o repo estiver limpo). Então rodar (depende do canal):

```
/codex:review
```

Slash sem args — **sempre revisa working tree diff**. Codex deve:
1. Ler o diff
2. Apontar pelo menos 1 observação (positiva ou crítica)
3. Sugerir melhoria ou confirmar OK

Se Caminho C (sem plugin), CLI equivalente:
```bash
codex review --uncommitted
```

Se sair vazio ou erro: voltar e checar Passo 1-3.

### Catálogo de slash commands `/codex:*` (plugin 1.0.4)

| Slash | Aceita argumento? | O que faz |
|---|---|---|
| `/codex:review` | NÃO | Revisa working tree diff (default reviewer) |
| `/codex:adversarial-review FILE` | FILE = pista de contexto, NÃO escopo | Revisa working tree diff com revisão crítica focada na área indicada |
| `/codex:setup` | NÃO | Confirma plugin acessível e sessão Codex viva |
| `/codex:status` | NÃO | Status da sessão/queue do Codex |
| `/codex:result` | NÃO | Mostra resultado do último review/operação |
| `/codex:cancel` | NÃO | Cancela operação Codex em andamento |
| `/codex:rescue` | NÃO | Recupera estado/contexto após falha |

> **Importante:** **nenhum slash aceita escopo parametrizado** (`--base`, `--commit`, arquivo). Quem quer review focado por flag → CLI no terminal: `codex review --uncommitted | --base <branch> | --commit <sha>`.

---

### Passo 7 — Atualizar `CLAUDE.md` do projeto

Adicionar na seção "Workflow obrigatório":

```markdown
## Code review cross-provider (R11)

`/codex:review` é obrigatório em DOIS momentos:

1. **Antes de cada commit** que muda código
2. **Ao concluir cada marco** de um plano (fim de fase numerada, fim de feature dentro de épico, ou qualquer "pronto, próxima etapa")

Em ambos:
- Tratar findings que forem bugs reais ou inconsistências de regra
- Findings de "preferência de estilo" podem ser ignorados, mas declarar em voz alta

Sem `/codex:review` rodado:
- nos últimos 5 minutos antes do commit → não pode commitar
- no escopo do marco antes da próxima fase → marco não está concluído

Detalhes em `01_REGRAS_INEGOCIAVEIS.md` R11 e `checklists/CHECKLIST_FEATURE_NOVA.md` G1 + G-MARCO.
```

---

### Passo 8 — Reportar ao usuário

Mensagem final estruturada:

```
SETUP CODEX REVIEWER CONCLUÍDO — {Nome do Projeto}

✅ VS Code Extension Codex instalada
✅ Codex CLI global instalado (versão X.Y.Z)
✅ Plugin codex@openai-codex no Claude Code
✅ Login: {Opção A ChatGPT | Opção B API key}
✅ .codex/config.toml criado (modelo: gpt-5.4-mini)
✅ AGENTS.md criado na raiz
✅ Smoke test /codex:review executado e respondeu

Próximo commit obrigatoriamente passa por /codex:review.
Regra ativa: R12 do 01_REGRAS_INEGOCIAVEIS.md.

Para testar: faça uma mudança qualquer e rode /codex:review antes de git commit.
```

---

## Anti-padrões durante o setup

- ❌ Pular Passo 1 e tentar instalar tudo "no escuro" — se Node faltar, npm install vai quebrar
- ❌ Continuar após erro em qualquer Passo "achando que dá certo no próximo"
- ❌ Não criar `AGENTS.md` — Codex revisa cego, sem conhecer regras Percus
- ❌ Esquecer `.codex/` no `.gitignore` — vaza config local pro repo

---

## Pegadinhas conhecidas

| Sintoma | Causa | Solução |
|---|---|---|
| Windows: `codex` não roda | Suporte Windows é experimental | Rodar via WSL conforme orientação OpenAI |
| `/codex:setup` retorna "not found" no Claude Code | Plugin não instalado ou Claude Code não reiniciado | Reload completo do VS Code após `/plugin install` |
| Login pede senha repetidamente | Conta ChatGPT sem 2FA | Usar Opção B (API key) que é mais estável |
| `/codex:review` retorna vazio | Sem `git diff` na branch atual | Fazer pelo menos 1 mudança antes de testar |
| Codex sugere algo contra as regras Percus | `AGENTS.md` ausente ou desatualizado | Criar/atualizar AGENTS.md (Passo 5) |

---

## Pré-requisitos resumidos (lista que o agente vai verificar)

- [ ] VS Code instalado (`code --version`)
- [ ] Node.js 18.18+ (`node --version`)
- [ ] Extensão `openai.chatgpt` no VS Code
- [ ] Codex CLI global (`@openai/codex` via npm)
- [ ] Plugin `codex@openai-codex` no Claude Code (via `/plugin install`)
- [ ] Login Codex (ChatGPT account ou OPENAI_API_KEY)
- [ ] `.codex/config.toml` na raiz do projeto
- [ ] `AGENTS.md` na raiz do projeto
- [ ] `.codex/` no `.gitignore`

---

## Referências

- **Repo oficial do plugin:** https://github.com/openai/codex-plugin-cc
- **Extensão VS Code (Marketplace):** https://marketplace.visualstudio.com/items?itemName=openai.chatgpt
- **Codex IDE docs (OpenAI):** https://developers.openai.com/codex/ide
- **Anúncio plugin Claude Code:** https://community.openai.com/t/introducing-codex-plugin-for-claude-code/1378186
