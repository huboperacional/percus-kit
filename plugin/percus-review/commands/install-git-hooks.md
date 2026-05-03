---
description: Instala .git/hooks/pre-commit nativo (defesa em profundidade vs bypass do PreToolUse)
disable-model-invocation: false
allowed-tools: Read, Write, Bash
---

# /install-git-hooks — Instalar git hook nativo do Percus

Instala `.git/hooks/pre-commit` no repo atual. Hook nativo do git roda no momento real do `git commit`, fechando a brecha do `PreToolUse:Bash` (que avalia estado **antes** do bash rodar e é burlado por comandos compostos tipo `rm -rf .deepseek/reviews && git commit`).

**Idempotente.** Roda quantas vezes precisar — atualiza versão Percus existente, aborta se detectar hook custom não-Percus.

## Passo 1 — Verificar repo git

Verifique que `.git/` existe na cwd. Se não existir, **PARE** e reporte ao usuário: "Diretório atual não é um repositório git (não tem `.git/`). Abortando — `/install-git-hooks` precisa rodar dentro de um repo git inicializado."

## Passo 2 — Detectar hook existente

Leia `.git/hooks/pre-commit` (se existir). Categorize:

- **Ausente** — vai criar do zero (Passo 3).
- **Versão Percus** — primeiras 5 linhas contêm `percus-review pre-commit hook`. Vai sobrescrever com versão atual do template (Passo 3).
- **Custom não-Percus** — qualquer outro conteúdo. **PARE** e reporte:

  > Já existe um `.git/hooks/pre-commit` que não é versão Percus. Não vou sobrescrever pra não perder a lógica custom.
  >
  > Opções:
  > 1. Faça backup do hook atual (`cp .git/hooks/pre-commit .git/hooks/pre-commit.backup`) e rode `/percus-review:install-git-hooks` de novo
  > 2. Edite o hook custom e adicione manualmente a checagem de review (referência: `${CLAUDE_PLUGIN_ROOT}/git-hooks/pre-commit.template.sh`)
  > 3. Se quiser combinar lógicas, me peça pra fazer merge — você descreve o que o custom faz e eu monto a versão híbrida

  Aguarde decisão do usuário. Não force.

## Passo 3 — Instalar/atualizar

Copie o conteúdo de `${CLAUDE_PLUGIN_ROOT}/git-hooks/pre-commit.template.sh` pra `.git/hooks/pre-commit` (sobrescrevendo se for Percus, criando se ausente).

Em seguida, marque executável (no-op em Windows; necessário em Unix). Detecte plataforma:

- **Unix (bash, zsh):**
  ```bash
  chmod +x .git/hooks/pre-commit
  ```
- **Windows (PowerShell):** sem ação — git em Windows respeita o shebang sem flag de execução.

## Passo 4 — Reportar

Reporte ao usuário no formato:

```
✅ Git hook nativo instalado em .git/hooks/pre-commit (v5.0.8)

O que mudou:
- Defesa em profundidade pre-commit: agora dois layers bloqueiam commit sem /percus-review:review fresco
  • Layer 1 (UX): hook PreToolUse:Bash do plugin -- mensagem PT-BR formatada dentro do Claude Code
  • Layer 2 (anti-bypass): .git/hooks/pre-commit nativo -- dispara no momento real do commit, pega bash composto

Smoke test sugerido (custo ~$0.01 em DeepSeek):
1. /percus-review:review              # gera review fresco
2. git commit -m "smoke"               # ESPERADO: passa silenciosamente
3. rm -rf .deepseek/reviews && git commit -m "tentativa de bypass"
   # ESPERADO: hook nativo BLOCK com stderr "[percus:hook pre-commit native] BLOCK..."

Escape (declare em voz alta): PERCUS_HOOKS_DISABLED=1 git commit -m "..."
```

## Notas

- O template canônico é versionado no plugin (`${CLAUDE_PLUGIN_ROOT}/git-hooks/pre-commit.template.sh`). Atualizações futuras do plugin invalidam a versão local — rode `/percus-review:install-git-hooks` depois de cada `/plugin update percus-review` pra propagar fixes.
- Hook nativo é POSIX sh self-contained — não depende de path do plugin, funciona mesmo se plugin for desinstalado (ainda bloqueia até alguém remover o hook manualmente).
- Cobertura cross-projeto: cada repo precisa rodar `/install-git-hooks` uma vez. Comandos de upgrade do kit (`UPGRADE_PARA_FASE4.md`) instruem rodar isso automaticamente.
