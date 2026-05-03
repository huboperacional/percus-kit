---
description: Instala git hook nativo Percus (Layer 2 anti-bypass) com detecção de core.hooksPath e merge híbrido com hooks existentes
disable-model-invocation: false
allowed-tools: Read, Write, Bash
---

# /install-git-hooks — Instalar git hook nativo do Percus (v5.0.9)

Instala o hook nativo `pre-commit` no repo atual. Hook nativo do git roda no momento real do `git commit`, fechando a brecha do `PreToolUse:Bash` (que avalia estado **antes** do bash rodar e é burlado por comandos compostos tipo `rm -rf .deepseek/reviews && git commit`).

**v5.0.9:**
- Detecta `core.hooksPath` (suporta projetos com husky, lefthook, pre-commit Python, DevEx setup).
- Quando hook target já existe, oferece **3 opções**: hybrid merge (preserva lógica custom), replace (backup + sobrescreve), abort.
- Re-run: detecta hook Percus existente (puro ou híbrido) via markers `=== PERCUS-MERGED-HOOK BEGIN/END ===` e atualiza só o bloco Percus, preservando lógica custom após END.

## Passo 1 — Verificar repo git

Verifique que `.git/` existe na cwd. Se não existir, **PARE** e reporte: "Diretório atual não é um repositório git. `/install-git-hooks` precisa rodar dentro de um repo git inicializado."

## Passo 2 — Detectar hooks dir real (`core.hooksPath`)

Git lê hooks de `core.hooksPath` quando setado, senão de `.git/hooks/`. Detectar:

```bash
HOOKS_PATH=$(git config --local --get core.hooksPath 2>/dev/null)
if [ -z "$HOOKS_PATH" ]; then
    HOOKS_PATH=$(git config --global --get core.hooksPath 2>/dev/null)
fi
if [ -z "$HOOKS_PATH" ]; then
    HOOKS_PATH=".git/hooks"
fi
echo "hooks dir: $HOOKS_PATH"
```

PowerShell equivalente:
```powershell
$hooksPath = (git config --local --get core.hooksPath 2>$null)
if (-not $hooksPath) { $hooksPath = (git config --global --get core.hooksPath 2>$null) }
if (-not $hooksPath) { $hooksPath = ".git/hooks" }
Write-Host "hooks dir: $hooksPath"
```

`$TARGET = "$HOOKS_PATH/pre-commit"`. Reportar o path resolvido ao usuário.

Se `core.hooksPath` está setado e o diretório não existe, criar (`mkdir -p`).

## Passo 3 — Categorizar hook existente

Ler `$TARGET` (se existe). Detectar via markers:

| Conteúdo | Categoria | Ação no Passo 4 |
|---|---|---|
| Arquivo ausente | **NEW** | Escrever template puro |
| Contém `=== PERCUS-MERGED-HOOK BEGIN ===` E `=== PERCUS-MERGED-HOOK END ===` | **PERCUS-MANAGED** (puro ou híbrido v5.0.9+) | Splice: substituir só bloco Percus entre markers |
| Contém `# percus-review pre-commit hook` mas NÃO os markers BEGIN/END | **PERCUS-LEGACY** (instalado via v5.0.8) | Reescrever com format v5.0.9 (puro, sem custom body) |
| Qualquer outro conteúdo | **CUSTOM** | Prompt 3 opções (Passo 5) |

## Passo 4 — Aplicar (NEW / PERCUS-MANAGED / PERCUS-LEGACY)

### NEW (target ausente)

Copie `${CLAUDE_PLUGIN_ROOT}/git-hooks/pre-commit.template.sh` pra `$TARGET` literal.

### PERCUS-MANAGED (já tem markers)

Ler conteúdo atual. Localizar offsets dos markers. Estrutura:
```
[prefixo opcional, geralmente vazio]
=== PERCUS-MERGED-HOOK BEGIN ===
[bloco Percus -- substituir]
=== PERCUS-MERGED-HOOK END ===
[suffixo: lógica custom OU 'exit 0' do template puro]
```

Substituir o bloco entre BEGIN e END (inclusive) pelo bloco BEGIN..END do template novo. Preservar prefixo e suffixo intactos. Resultado preserva lógica custom após END (se for híbrido) ou mantém o `exit 0` (se for puro).

### PERCUS-LEGACY (v5.0.8)

Reescrever target inteiro com template v5.0.9 puro (mesmo path do NEW). Reportar: "Hook legado v5.0.8 detectado, atualizado pra format v5.0.9 com markers BEGIN/END."

## Passo 5 — CUSTOM detectado: oferecer 3 opções

Se o hook existente não é Percus, **PARE** e ofereça ao usuário:

```
Detectado hook custom existente em $TARGET (não-Percus). Como prosseguir?

1. **Hybrid merge** (recomendado) — Insiro o bloco Percus (entre markers BEGIN/END) ANTES do conteúdo atual. Seu hook custom (typecheck, lint, etc.) roda DEPOIS. Se Percus bloquear (review faltando), custom nem executa. Se Percus liberar, custom segue normal. Sem perda de funcionalidade.

2. **Replace** — Backup do hook atual em $TARGET.bak e sobrescreve com template Percus puro. Lógica custom fica preservada no .bak; você re-introduz manualmente se quiser híbrido depois.

3. **Abort** — Não toca em nada. Layer 2 fica inativo neste projeto. Layer 1 (PreToolUse:Bash) ainda cobre os casos isolados dentro do Claude Code.

Qual opção?
```

Aguarde resposta do usuário. Não force escolha.

### Se Hybrid merge escolhido

Construa novo target assim:
```
<bloco BEGIN..END do template, terminado com newline>
<conteúdo original do target completo, sem mexer>
```

Se o target original começa com `#!/bin/sh` ou `#!/bin/bash` ou similar, **mover esse shebang pra cima do bloco BEGIN** e omitir do início do conteúdo preservado (senão fica shebang duplicado e segundo é ignorado). Se não tem shebang, deixar como está (template já tem `#!/bin/sh`).

Confirme com usuário com diff antes de escrever:
```
Vou reescrever $TARGET assim:
- Linha 1: shebang (do template ou do hook custom)
- Linhas 2-N: bloco Percus (BEGIN ... END)
- Linhas N+1 até fim: conteúdo original do hook custom (preservado)

Confirma?
```

### Se Replace escolhido

```bash
cp $TARGET $TARGET.bak
cp ${CLAUDE_PLUGIN_ROOT}/git-hooks/pre-commit.template.sh $TARGET
```

Reporte ao usuário onde foi o backup.

### Se Abort escolhido

Sair sem mudanças. Reporte: "Layer 2 não instalado. Quando quiser instalar, re-rode `/percus-review:install-git-hooks` e escolha hybrid ou replace."

## Passo 6 — Marcar executável

Após escrever (NEW, PERCUS-MANAGED, PERCUS-LEGACY, ou Hybrid/Replace):

- **Unix (bash, zsh):** `chmod +x $TARGET`
- **Windows (PowerShell):** sem ação — git em Windows respeita o shebang sem flag de execução.

## Passo 7 — Reportar

Formato do relatório (adapte conforme caminho seguido):

```
✅ Git hook nativo Percus em $TARGET (v5.0.9)
   Modo: {NEW | PERCUS-MANAGED update | PERCUS-LEGACY upgrade | Hybrid merge | Replace}

Hooks dir resolvido: $HOOKS_PATH ({default .git/hooks | core.hooksPath custom})

Defesa em profundidade pre-commit -- dois layers bloqueiam commit sem /percus-review:review fresco:
  Layer 1 (UX): hook PreToolUse:Bash do plugin -- mensagem PT-BR formatada dentro do Claude Code
  Layer 2 (anti-bypass): $TARGET nativo -- dispara no momento real do commit, pega bash composto

Smoke test sugerido (custo ~$0.01 em DeepSeek):
1. /percus-review:review                              # gera review fresco
2. git commit -m "smoke"                              # ESPERADO: passa silenciosamente
3. rm -rf .deepseek/reviews && git commit -m "bypass" # ESPERADO: Layer 2 BLOCK com "[percus:hook pre-commit native]"

Escape (declare em voz alta): PERCUS_HOOKS_DISABLED=1 git commit -m "..."
```

Em modo **Hybrid merge**, adicionar nota:
```
Hook custom existente preservado. Sua lógica (typecheck, lint, etc.) roda DEPOIS do bloco Percus -- se review faltar, Percus bloqueia primeiro e custom nem executa.
```

## Notas

- Hook nativo é POSIX sh self-contained — não depende de path do plugin, funciona mesmo se plugin for desinstalado.
- Cobertura cross-projeto: cada repo precisa rodar `/install-git-hooks` uma vez. Comandos de upgrade (`UPGRADE_PARA_FASE4.md`) instruem rodar isso automaticamente.
- v5.0.9 fecha bug `core.hooksPath` aberto em v5.0.8: projetos com husky/lefthook/DevEx custom agora têm Layer 2 funcional.
- Re-rodar `/install-git-hooks` em hook v5.0.9 já instalado é **idempotente** — atualiza só o bloco Percus, preserva o resto.
