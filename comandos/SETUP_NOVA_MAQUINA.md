---
tipo: comando-pronto
quando-usar: bootstrap inicial do kit Percus em máquina nova (operador que vai trabalhar em projetos Percus, ou novo computador do operador principal)
nao-toca-codigo: true
leitura: 3 min · execução típica: 5-10 min
ultima-atualizacao: 2026-05-17
fase-introducao: v6.5.0
---

# Setup Nova Máquina — bootstrap do kit Percus

> **Quando rodar:** primeira vez que o kit Percus é configurado numa máquina (PC novo do operador, PC de colaborador, VM, etc). Sem esse setup, qualquer comando do canon que referencie `${env:PERCUS_CANON_DIR}/...` falha com "path não existe".

---

## Pré-requisitos

- Windows com PowerShell 5.1+ (vem com Windows) ou PowerShell 7+ (`pwsh`)
- Git instalado e `git --version` funciona no terminal
- Pelo menos 2 GB livres no drive escolhido pro canon
- Acesso ao repo `huboperacional/percus-kit` no GitHub (público — sem auth necessário)

---

## Bootstrap — colar no PowerShell local (não no chat Claude)

```powershell
# 1. Escolher onde clonar o canon. Defaults sugeridos:
#    - Operador principal (D: dedicado a projetos): D:\Claud Automations\_Novo_Projeto
#    - Outras máquinas: $env:USERPROFILE\percus-kit (= C:\Users\<você>\percus-kit)
$canonDir = "$env:USERPROFILE\percus-kit"   # ajuste se quiser outro path

# 2. Clonar o canon (se já existe, atualiza)
if (Test-Path $canonDir) {
    Write-Host "Canon já existe em $canonDir. Atualizando via git pull..."
    Set-Location $canonDir
    git pull origin main
} else {
    git clone https://github.com/huboperacional/percus-kit.git $canonDir
}

# 3. Apontar PERCUS_CANON_DIR pra esse path (User-scope persistente)
[Environment]::SetEnvironmentVariable('PERCUS_CANON_DIR', $canonDir, 'User')

# 4. Caches em D: (opcional, mas recomendado — ver AMBIENTE_LOCAL_OPERADOR.md)
#    Pula se você usa C: pra tudo (não-Percus default).
[Environment]::SetEnvironmentVariable('PIP_CACHE_DIR', 'D:\caches\pip', 'User')
[Environment]::SetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH', 'D:\caches\ms-playwright', 'User')
[Environment]::SetEnvironmentVariable('HF_HOME', 'D:\caches\huggingface', 'User')
npm config set cache 'D:\caches\npm-cache' --global

# 5. API keys do kit Percus (User-scope). SUBSTITUA OS PLACEHOLDERS pelas keys reais.
#    Pra onde obter cada key: ver `AMBIENTE_LOCAL_OPERADOR.md` seção "API keys do kit Percus".
[Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY',   'sk-...',                    'User')
[Environment]::SetEnvironmentVariable('GROQ_API_KEY',       'gsk_...',                   'User')
[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY',  'sk-ant-...',                'User')
[Environment]::SetEnvironmentVariable('PAINEL_API_URL',     'https://api.ads4pros.com',  'User')
[Environment]::SetEnvironmentVariable('CATALOG_INGEST_KEY', '...',                       'User')

# 6. Instalar plugin percus-review (no chat 'claude' standalone OU via UI Manage Plugins do VS Code)
#    Comando interativo no chat 'claude':
#      /plugin marketplace add huboperacional/percus-kit
#      /plugin install percus-review@percus-tools
#    OU via VS Code: digitar /plu no chat -> Manage plugins -> aba Marketplaces -> add huboperacional/percus-kit -> aba Plugins -> install percus-review
#    NÃO é colável aqui — precisa ser feito interativamente na UI do Claude Code.
Write-Host ""
Write-Host "===== Bootstrap quase completo ====="
Write-Host ""
Write-Host "FALTA fazer manualmente:"
Write-Host "  1. REABRIR TODOS OS TERMINAIS + VS Code (env vars persistentes carregam só em processos novos)"
Write-Host "  2. Instalar plugin percus-review via UI Manage Plugins do VS Code (passo 6 acima)"
Write-Host "  3. Após reload, rodar VERIFICAÇÃO abaixo no PowerShell pra confirmar tudo"
```

---

## Verificação pós-bootstrap (rodar APÓS reload de VS Code/PowerShell)

```powershell
# Confirmar env vars do kit Percus
@('PERCUS_CANON_DIR','DEEPSEEK_API_KEY','GROQ_API_KEY','ANTHROPIC_API_KEY','PAINEL_API_URL','CATALOG_INGEST_KEY') | ForEach-Object {
    $v = [Environment]::GetEnvironmentVariable($_, 'User')
    "$_ : $(if ($v) { 'OK' } else { 'MISSING' })"
}

# Confirmar canon clonado e versão
$canon = $env:PERCUS_CANON_DIR
if (Test-Path $canon) {
    "Canon OK em $canon"
    Get-Content (Join-Path $canon 'CANON_VERSION.md') -TotalCount 5
} else {
    "MISSING: PERCUS_CANON_DIR aponta pra $canon mas path não existe"
}

# Confirmar plugin instalado
$pluginRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
$pluginCache = Join-Path $pluginRoot 'plugins\cache\percus-tools\percus-review'
if (Test-Path $pluginCache) {
    $installedVersions = Get-ChildItem $pluginCache -Directory | Sort-Object Name -Descending
    "Plugin instalado: $($installedVersions[0].Name)"
} else {
    "MISSING: plugin percus-review não instalado. Rodar passo 6 do bootstrap."
}
```

**Esperado:** todas as 6 env vars OK, canon existe, plugin versão = versão canônica em `CANON_VERSION.md`.

Se alguma estiver `MISSING`, volte ao passo correspondente do bootstrap.

---

## Próximos passos depois do bootstrap

1. **Atualizar projetos existentes** (se houver): em cada projeto Percus, cole o comando de `comandos/REORGANIZAR_PROJETO.md` (umbrella).
2. **Criar projeto novo (greenfield)**: cole o comando de `00_LEIA_PRIMEIRO.md` (roteamento "Projeto NOVO greenfield").
3. **Manutenção mensal**: `cd $env:PERCUS_CANON_DIR; git pull origin main` pra puxar releases novos do canon.

---

## Quando o bootstrap precisa ser refeito

- Máquina formatada (env vars perdidas) → re-rodar tudo.
- Você moveu o canon pra outro path → atualizar só `PERCUS_CANON_DIR`.
- Plugin desinstalado → re-rodar só passo 6.
- API key rotacionada → atualizar só a env var correspondente.

---

## Anti-padrões

- ❌ **Skip do reload de VS Code/PowerShell.** Env vars persistentes só carregam em processos **novos**. Sem reload, qualquer comando de projeto continua falhando com `MISSING`.
- ❌ **Hardcode de `D:\Claud Automations\_Novo_Projeto` em comandos novos.** Todos os comandos do canon usam `${env:PERCUS_CANON_DIR}` desde v6.5.0 — siga o padrão.
- ❌ **Comitar `.env` com as keys** em qualquer repo. Keys ficam no User-scope, não em arquivos versionados.
- ❌ **Esquecer de `git pull`** mensalmente — canon evolui, projetos consumidores ficam com refs antigas se você não atualiza.

---

## Referências

- API keys: `${env:PERCUS_CANON_DIR}/AMBIENTE_LOCAL_OPERADOR.md` seção "API keys do kit Percus"
- Versão atual: `${env:PERCUS_CANON_DIR}/CANON_VERSION.md`
- Upgrade de projeto existente: `${env:PERCUS_CANON_DIR}/comandos/REORGANIZAR_PROJETO.md`
- Greenfield: `${env:PERCUS_CANON_DIR}/00_LEIA_PRIMEIRO.md`
