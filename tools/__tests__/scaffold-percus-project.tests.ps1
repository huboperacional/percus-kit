#requires -Version 7.0
Describe "scaffold-percus-project.ps1" {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot ".." "scaffold-percus-project.ps1"
        $script:canonRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
        $env:PERCUS_CANON_DIR = $script:canonRoot

        $script:tmpRoot = Join-Path ([IO.Path]::GetTempPath()) "scaffold-test-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path $script:tmpRoot | Out-Null
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpRoot -ErrorAction SilentlyContinue
    }

    It "rejeita audience com underscore (R7)" {
        $project = Join-Path $script:tmpRoot "p-underscore"
        New-Item -ItemType Directory -Force -Path $project | Out-Null
        '{}' | Out-File (Join-Path $project "package.json")

        { & $script:scriptPath -ProjectPath $project -AudienceFallback "plexco_tickets" } |
            Should -Throw -ExpectedMessage "*kebab-case*"
    }

    It "rejeita projeto sem package.json nem pyproject.toml" {
        $project = Join-Path $script:tmpRoot "p-empty"
        New-Item -ItemType Directory -Force -Path $project | Out-Null

        { & $script:scriptPath -ProjectPath $project -AudienceFallback "test-audience" } |
            Should -Throw -ExpectedMessage "*package.json nem pyproject.toml*"
    }

    It "copia componentes pra src/components/auth em projeto Next.js" {
        $project = Join-Path $script:tmpRoot "p-nextjs"
        New-Item -ItemType Directory -Force -Path $project | Out-Null
        '{}' | Out-File (Join-Path $project "package.json")

        & $script:scriptPath -ProjectPath $project -AudienceFallback "test-tenant" 2>&1 | Out-Null

        Test-Path (Join-Path $project "src/components/auth/login-card.tsx") | Should -Be $true
        Test-Path (Join-Path $project "src/lib/phone-mask.ts") | Should -Be $true
        Test-Path (Join-Path $project "src/app/api/auth/request/route.ts") | Should -Be $true
    }

    It "cria .env.local com audience fallback substituido" {
        $project = Join-Path $script:tmpRoot "p-envfile"
        New-Item -ItemType Directory -Force -Path $project | Out-Null
        '{}' | Out-File (Join-Path $project "package.json")

        & $script:scriptPath -ProjectPath $project -AudienceFallback "minha-aud" 2>&1 | Out-Null

        $env = Get-Content (Join-Path $project ".env.local") -Raw
        $env | Should -Match "PERCUS_AUTH_AUDIENCE_FALLBACK=minha-aud"
    }

    It "e idempotente (segunda execucao nao mexe nos arquivos)" {
        $project = Join-Path $script:tmpRoot "p-idem"
        New-Item -ItemType Directory -Force -Path $project | Out-Null
        '{}' | Out-File (Join-Path $project "package.json")

        & $script:scriptPath -ProjectPath $project -AudienceFallback "test" 2>&1 | Out-Null
        $hash1 = (Get-FileHash (Join-Path $project "src/components/auth/login-card.tsx")).Hash

        & $script:scriptPath -ProjectPath $project -AudienceFallback "test" 2>&1 | Out-Null
        $hash2 = (Get-FileHash (Join-Path $project "src/components/auth/login-card.tsx")).Hash

        $hash1 | Should -Be $hash2
    }
}
