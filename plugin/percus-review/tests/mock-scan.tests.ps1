#requires -Version 5.1
# Regressao do hook mock-scan (R3).
# Foco principal: falso-positivo em palavras acentuadas que contem "todo" como
# substring (ex: portugues "metodo" -> "me'todo'") — causado por (a) decode OEM
# do output do git mojibakando o "e" acentuado em 2 bytes nao-word, criando uma
# word-boundary falsa, e (b) match case-insensitive de TODO/FIXME/XXX/HACK.

Describe "mock-scan hook — falso-positivo em palavras acentuadas + markers reais" {
    BeforeAll {
        $script:hook = Join-Path $PSScriptRoot ".." "hooks" "mock-scan-pre-commit.ps1"

        function New-StagedRepo {
            param([string]$FileName, [string]$Content)
            $repo = Join-Path ([IO.Path]::GetTempPath()) "mockscan-test-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $repo | Out-Null
            & git -C $repo init -q
            & git -C $repo config user.email "t@t.t"
            & git -C $repo config user.name "t"
            # Escreve em UTF-8 (sem BOM) — replica como arquivos reais sao salvos
            $path = Join-Path $repo $FileName
            [System.IO.File]::WriteAllText($path, $Content, (New-Object System.Text.UTF8Encoding($false)))
            & git -C $repo add $FileName
            return $repo
        }

        function Invoke-MockScan {
            param([string]$Repo)
            $cmd = "cd `"$Repo`" && git commit -m teste"
            $stdin = @{ tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            $stdin | & pwsh -NoProfile -File $script:hook *>$null
            return $LASTEXITCODE
        }
    }

    Context "Regressao — palavra acentuada com 'todo' embutido NAO bloqueia" {
        It "1. aria-label PT com 'Metodo' acentuado nao dispara TODO (incidente Frente B v6.8)" {
            $repo = New-StagedRepo -FileName "method-toggle.tsx" -Content @'
export function MethodToggle() {
  return <div role="radiogroup" aria-label="Método de login" />;
}
'@
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0 -Because "'Método' (PT) contem 'todo' mas NAO e um TODO marker"
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }

        It "2. identificador camelCase 'metodoTodo' nao dispara" {
            $repo = New-StagedRepo -FileName "x.ts" -Content 'const metodoTodoListado = 1;'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }

        It "3. 'hackathon' (contem 'hack' minusculo) nao dispara" {
            $repo = New-StagedRepo -FileName "x.ts" -Content 'const hackathonScore = 10;'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Markers reais continuam sendo bloqueados" {
        It "4. comentario '// TODO: ...' real bloqueia" {
            $repo = New-StagedRepo -FileName "x.ts" -Content 'const a = 1; // TODO: corrigir isso'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 2 -Because "TODO maiusculo seguido de ':' e marker real (R3)"
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }

        It "5. comentario 'FIXME ' real bloqueia" {
            $repo = New-StagedRepo -FileName "x.py" -Content '# FIXME esta logica esta errada'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 2
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Arquivo limpo nao bloqueia" {
        It "6. codigo sem markers nem mocks passa" {
            $repo = New-StagedRepo -FileName "x.ts" -Content 'export const soma = (a: number, b: number) => a + b;'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }
    }
}
