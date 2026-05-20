#requires -Version 7.0
<#
.SYNOPSIS
Scaffold Percus auth pattern em projeto Next.js/FastAPI existente.

.DESCRIPTION
Idempotente. Copia templates/login-ui pro projeto, gera .env.local stub, instala lib percus-auth.
NAO acessa auth-service (audience + branding sao passos humanos do checklist).

.PARAMETER ProjectPath
Path absoluto do projeto target (onde tem package.json ou pyproject.toml).

.PARAMETER AudienceFallback
Slug kebab-case da audience deste tenant (ex: plexco-coach). Vai pro .env como fallback.

.PARAMETER Force
Sobrescreve arquivos existentes sem perguntar.

.EXAMPLE
pwsh ./tools/scaffold-percus-project.ps1 -ProjectPath "D:\Plexco Coach" -AudienceFallback plexco-coach
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$AudienceFallback,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if ($AudienceFallback -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    throw "AudienceFallback '$AudienceFallback' nao e kebab-case. R7 exige kebab-case."
}

$canonRoot = if ($env:PERCUS_CANON_DIR) { $env:PERCUS_CANON_DIR } else {
    Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
$templates = Join-Path $canonRoot "templates/login-ui"
if (-not (Test-Path $templates)) {
    throw "templates/login-ui nao encontrado em $templates. Frente B foi merged?"
}
$ProjectPath = (Resolve-Path $ProjectPath).Path

Write-Host "[scaffold] canon: $canonRoot" -ForegroundColor Cyan
Write-Host "[scaffold] target: $ProjectPath" -ForegroundColor Cyan
Write-Host "[scaffold] audience fallback: $AudienceFallback" -ForegroundColor Cyan

# Detectar tipo de projeto
$isNextJs = Test-Path (Join-Path $ProjectPath "package.json")
$isFastApi = Test-Path (Join-Path $ProjectPath "pyproject.toml")
if (-not $isNextJs -and -not $isFastApi) {
    throw "Nem package.json nem pyproject.toml em $ProjectPath. Projeto nao parece Next.js nem FastAPI."
}

function Copy-FileIfNeeded($src, $dst) {
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
    if ((Test-Path $dst) -and -not $Force) {
        $existing = Get-FileHash $dst -Algorithm SHA256
        $incoming = Get-FileHash $src -Algorithm SHA256
        if ($existing.Hash -eq $incoming.Hash) {
            Write-Host "  [skip] $dst (identico)" -ForegroundColor DarkGray
            return
        }
        Write-Host "  [diff] $dst ja existe e difere. Use -Force pra sobrescrever." -ForegroundColor Yellow
        return
    }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "  [copy] $dst" -ForegroundColor Green
}

if ($isNextJs) {
    Write-Host "[scaffold] tipo: Next.js" -ForegroundColor Cyan

    # Components
    Get-ChildItem (Join-Path $templates "components") -File | ForEach-Object {
        Copy-FileIfNeeded $_.FullName (Join-Path $ProjectPath "src/components/auth/$($_.Name)")
    }
    # Lib (phone-mask)
    Copy-FileIfNeeded (Join-Path $templates "lib/phone-mask.ts") (Join-Path $ProjectPath "src/lib/phone-mask.ts")

    # API routes (remover sufixo .template)
    $apiMap = @{
        "request.ts.template"  = "src/app/api/auth/request/route.ts"
        "validate.ts.template" = "src/app/api/auth/validate/route.ts"
        "refresh.ts.template"  = "src/app/api/auth/refresh/route.ts"
        "logout.ts.template"   = "src/app/api/auth/logout/route.ts"
        "me.ts.template"       = "src/app/api/auth/me/route.ts"
    }
    foreach ($k in $apiMap.Keys) {
        Copy-FileIfNeeded (Join-Path $templates "api/$k") (Join-Path $ProjectPath $apiMap[$k])
    }

    # .env.local stub
    $envFile = Join-Path $ProjectPath ".env.local"
    if (-not (Test-Path $envFile) -or $Force) {
        $envContent = Get-Content (Join-Path $templates ".env.example") -Raw
        $envContent = $envContent -replace 'PERCUS_AUTH_AUDIENCE_FALLBACK=.*', "PERCUS_AUTH_AUDIENCE_FALLBACK=$AudienceFallback"
        $envContent = $envContent -replace 'NEXT_PUBLIC_PERCUS_AUDIENCE_FALLBACK=.*', "NEXT_PUBLIC_PERCUS_AUDIENCE_FALLBACK=$AudienceFallback"
        [System.IO.File]::WriteAllText($envFile, $envContent)
        Write-Host "  [create] .env.local com audience=$AudienceFallback" -ForegroundColor Green
    }

    # Install lib
    Push-Location $ProjectPath
    try {
        Write-Host "[scaffold] npm install percus-auth@^0.4.0..." -ForegroundColor Cyan
        npm install percus-auth@^0.4.0 2>&1 | Out-String | Write-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [warn] npm install falhou (ok se lib nao publicada ainda)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [warn] npm install falhou: $_" -ForegroundColor Yellow
    } finally {
        Pop-Location
    }
}
elseif ($isFastApi) {
    Write-Host "[scaffold] tipo: FastAPI" -ForegroundColor Cyan
    Push-Location $ProjectPath
    try {
        Write-Host "[scaffold] pip install percus-auth>=0.4.0..." -ForegroundColor Cyan
        pip install "percus-auth>=0.4.0" 2>&1 | Out-String | Write-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [warn] pip install falhou (ok se lib nao publicada ainda)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [warn] pip install falhou: $_" -ForegroundColor Yellow
    } finally {
        Pop-Location
    }
    # .env stub
    $envFile = Join-Path $ProjectPath ".env"
    if (-not (Test-Path $envFile) -or $Force) {
        @"
AUTH_SERVICE_URL=https://auth.huboperacional.com.br
PERCUS_AUTH_AUDIENCE=$AudienceFallback
# INTERNAL_AUTH_KEY=<32B hex — set if this service calls /internal/* on auth-service>
"@ | Out-File -Encoding utf8 -NoNewline $envFile
        Write-Host "  [create] .env com audience=$AudienceFallback" -ForegroundColor Green
    }
}

# Gerar CHECKLIST_AUTH.md no projeto
$checklistTemplate = Join-Path $canonRoot "templates/CHECKLIST_AUTH.template.md"
if (Test-Path $checklistTemplate) {
    $content = Get-Content $checklistTemplate -Raw
    $content = $content -replace '\{\{AUDIENCE\}\}', $AudienceFallback
    [System.IO.File]::WriteAllText((Join-Path $ProjectPath "CHECKLIST_AUTH.md"), $content)
    Write-Host "  [create] CHECKLIST_AUTH.md (preencher na auth-service UI)" -ForegroundColor Green
}

Write-Host ""
Write-Host "[scaffold] OK. Proximos passos manuais (ver CHECKLIST_AUTH.md):" -ForegroundColor Green
Write-Host "  1. Criar audience '$AudienceFallback' em https://auth.huboperacional.com.br/admin/audiences/new" -ForegroundColor White
Write-Host "  2. Subir branding em /admin/audiences/$AudienceFallback/branding" -ForegroundColor White
Write-Host "  3. Smoke E2E: rodar dev server e testar fluxo OTP" -ForegroundColor White
