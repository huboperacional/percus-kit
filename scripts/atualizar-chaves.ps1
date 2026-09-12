<#
.SYNOPSIS
  Atualiza DEEPSEEK_API_KEY / ANTHROPIC_API_KEY do .env do projeto ATUAL, lendo os
  valores da fonte unica (percus-kit\.env). A chave NUNCA e digitada, colada nem
  impressa -- por isso nao entra no historico do shell nem no scrollback.

.NOTES
  Regras de seguranca embutidas:
   - RECUSA gravar se o .env estiver rastreado no git (gravar seria vazar no proximo commit).
   - AVISA se o .env estiver untracked mas NAO ignorado (entra num `git add -A`), e oferece corrigir.
   - So ATUALIZA variavel que ja existe; nunca ADICIONA. Chave nova num projeto pode
     LIGAR caminho pago que so roda quando a variavel existe.
   - Backup .env.bak-<timestamp> antes de escrever; preserva CRLF e aspas.
#>
[CmdletBinding()]
param(
  [string]$Fonte = 'D:\Claud Automations\percus-kit\.env',
  [string]$Projeto = (Get-Location).Path,
  [switch]$CorrigirGitignore
)
$ErrorActionPreference = 'Stop'
function Hash8([string]$v){
  $b=[Text.Encoding]::UTF8.GetBytes($v)
  ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($b))).Replace('-','').ToLower().Substring(0,8)
}

$dst = Join-Path $Projeto '.env'
if (-not (Test-Path -LiteralPath $Fonte)) { throw "fonte nao encontrada: $Fonte" }
if (-not (Test-Path -LiteralPath $dst))   { Write-Host "  (sem .env em $Projeto -- nada a fazer)" -ForegroundColor DarkGray; return }

# --- Guarda 1: .env rastreado no git = gravar aqui vaza no proximo commit ---
Push-Location $Projeto
$dentroRepo = $false
# O catch NAO pode ser mudo: "nao e um repo" (exit 128) e esperado, mas "git ausente do PATH" cai
# no mesmo lugar e pularia as Guardas 1 e 2 -- justo as que o .NOTES promete como incondicionais.
# Guarda pulada em silencio e pior que guarda ausente: o .NOTES continua prometendo.
$gitErro = $null
try   { git rev-parse --is-inside-work-tree *>$null; $dentroRepo = ($LASTEXITCODE -eq 0) }
catch { $gitErro = $_.Exception.Message }
if ($gitErro) {
  Write-Warning "git indisponivel ($gitErro) -- as guardas de .env rastreado/ignorado NAO rodaram."
}
if ($dentroRepo) {
  $rastreado = $false
  try { git ls-files --error-unmatch .env *>$null; $rastreado = ($LASTEXITCODE -eq 0) } catch { $rastreado = $false }
  if ($rastreado) {
    Pop-Location
    $nl  = [Environment]::NewLine
    $msg = '.env esta RASTREADO no git. Gravar a chave aqui = vazamento. Corrija antes:' + $nl +
           '    git rm --cached .env' + $nl +
           '    Add-Content .gitignore ".env"' + $nl +
           '    Add-Content .gitignore ".env.*"'
    throw $msg
  }
  # --- Guarda 2: untracked mas NAO ignorado -> entra num `git add -A` ---
  $ignorado = $false
  try { git check-ignore -q .env *>$null; $ignorado = ($LASTEXITCODE -eq 0) } catch { $ignorado = $false }
  if (-not $ignorado) {
    if ($CorrigirGitignore) {
      foreach($p in '.env','.env.*','!.env.example'){
        # Linha INTEIRA, nao substring: com -SimpleMatch um '.env.example' ja no .gitignore fazia
        # o teste dar 'presente' para o padrao '.env', que entao NUNCA era adicionado -- e o .env
        # real seguia exposto com o script dizendo 'corrigido'. Achado do review cross-provider.
        $jaTem = (Test-Path .gitignore) -and (Select-String -Path .gitignore -Pattern ('^\s*' + [regex]::Escape($p) + '\s*$') -Quiet)
        if (-not $jaTem) {
          Add-Content -Path .gitignore -Value $p -Encoding utf8
        }
      }
      Write-Host "  .gitignore corrigido (.env deixou de ser exposto)" -ForegroundColor Green
    } else {
      Write-Host "  AVISO: .env nao esta no .gitignore -- entra num 'git add -A'." -ForegroundColor Yellow
      Write-Host "         rode de novo com -CorrigirGitignore para fechar isso." -ForegroundColor Yellow
    }
  }
}
Pop-Location

$src = [IO.File]::ReadAllText($Fonte)
$txt = [IO.File]::ReadAllText($dst)
$orig = $txt
foreach ($v in @('DEEPSEEK_API_KEY','ANTHROPIC_API_KEY')) {
  $m = [regex]::Match($src, "(?m)^$v=(.*)$")
  if (-not $m.Success) { continue }
  $val = $m.Groups[1].Value.Trim().Trim('"').Trim("'")
  if (-not [regex]::IsMatch($txt, "(?m)^$v=")) {
    Write-Host "  $v : ausente neste projeto -- NAO adicionado (proposital)" -ForegroundColor DarkGray
    continue
  }
  $ev = [Text.RegularExpressions.MatchEvaluator]{ param($mm) $mm.Groups[1].Value + $val }
  $txt = [regex]::Replace($txt, "(?m)^($v=)[^\r\n]*", $ev)
  Write-Host "  $v : atualizada -> hash $(Hash8 $val)" -ForegroundColor Green
}
if ($txt -eq $orig) { Write-Host "  (nada mudou -- ja estava atualizado)" -ForegroundColor DarkGray; return }
# Backup FORA do repositorio, de proposito. Gravar `.env.bak-*` dentro do projeto foi
# exatamente o que criou o vazamento de 2026-08-26: o .gitignore cobria `.env` mas nao
# `.env.*`, entao o backup ficava untracked-e-nao-ignorado e entrava num `git add -A`.
# Arquivo de credencial nunca nasce dentro de arvore versionada.
$bkpDir = Join-Path $env:TEMP 'percus-env-backups'
New-Item -ItemType Directory -Path $bkpDir -Force | Out-Null
$slug = ($Projeto -replace '[\\/:]','_').TrimStart('_')
Copy-Item -LiteralPath $dst -Destination (Join-Path $bkpDir "$slug.env.bak-$(Get-Date -Format yyyyMMddTHHmmss)") -Force
[IO.File]::WriteAllText($dst, $txt, (New-Object Text.UTF8Encoding($false)))
Write-Host "  OK: $dst" -ForegroundColor Green
