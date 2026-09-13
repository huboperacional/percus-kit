@echo off
setlocal EnableExtensions
REM ============================================================================
REM Dispatcher PreToolUse -- CAMADA 1 (triagem burra em cmd.exe, ~61 ms).
REM
REM Substitui os 8 .cmd da cadeia `Bash|PowerShell`, que custavam ~420 ms CADA
REM (startup do Windows PowerShell 5.1), mesmo todos em no-op: 3 357 ms em todo
REM comando Bash. Os 8 .cmd continuam no disco e sao a rota de fallback.
REM
REM Esta camada so sabe dizer "NINGUEM poderia disparar". Ela NUNCA e a fonte de
REM verdade de QUAL check roda -- isso e da camada 2, onde e testavel e gratis.
REM Falso positivo custa ~425 ms; falso negativo seria buraco calado.
REM
REM Spec: docs/superpowers/specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md
REM ============================================================================

if "%PERCUS_HOOKS_DISABLED%"=="1" exit /b 0

set "PDIR=%~dp0"
if not defined PERCUS_CANON_DIR goto :dir_ok
if not exist "%PERCUS_CANON_DIR%\plugin\percus-review\hooks\percus-dispatch-pre.ps1" goto :dir_ok
set "PDIR=%PERCUS_CANON_DIR%\plugin\percus-review\hooks\"
:dir_ok

REM --- Captura de stdin. `findstr "^"` e NAO `more`: medido em 2026-09-12, o
REM     `more` ja CORROMPE payload de 80 KB (80055 != 80053) enquanto o findstr
REM     e exato ate la. Acima de ~80 KB os dois truncam -- e truncam saindo 0.
REM     Payload cortado e JSON invalido, cada check cai no proprio catch e sai 0,
REM     e a cadeia passa CALADA no comando maior. Por isso a camada 2 valida o
REM     JSON e falha ALTO: stdin ja foi consumido, nao ha recuperacao possivel,
REM     entao a escolha real e entre barrar avisando e passar calado.
REM     O nome do temp e reservado com `md`, e NAO montado so com %RANDOM%. Medido em
REM     2026-09-12: 12 cmd.exe simultaneos produziram 4 nomes distintos de 12 -- o seed
REM     do %RANDOM% vem do relogio, com granularidade grossa. O harness dispara tool
REM     calls em paralelo, entao dois dispatchers dividiriam o mesmo arquivo: um avalia
REM     o comando do outro, ou o `del` de um apaga durante a leitura do irmao. `md`
REM     falha de forma ATOMICA se o alvo ja existe, o que resolve a corrida de verdade.
REM     A retentativa e por `goto`, e nao por `for`: dentro de um bloco `for` o %RANDOM%
REM     e expandido UMA vez, na hora de parsear o bloco, entao as 20 iteracoes usariam
REM     o mesmo numero. Com goto, cada volta reparseia a linha e sorteia de novo.
set "PTRY=0"
:reserva_box
set /a PTRY+=1
set "PBOX=%TEMP%\percus-pre-%RANDOM%%RANDOM%-%PTRY%"
md "%PBOX%" 2>nul
if errorlevel 1 (
  if %PTRY% LSS 20 goto :reserva_box
  goto :legado_sem_payload
)
set "PAYLOAD=%PBOX%\p.json"
findstr "^" > "%PAYLOAD%"

REM     Se o payload NAO existe (TEMP inexistente, sem permissao, disco cheio), o findstr
REM     da triagem devolveria rc=1 -- indistinguivel de "nenhum gatilho casou" -- e a
REM     cadeia sairia 0 com ZERO checks rodados, deixando so um "O sistema nao pode
REM     encontrar o caminho" sem assinatura [percus:]. Medido com TEMP=Z:\nao\existe.
REM     O fail-open do `rc GEQ 2` nao cobre este caso, que e o mais provavel dos dois.
if not exist "%PAYLOAD%" goto :legado_sem_payload

if "%PERCUS_DISPATCHER_BYPASS%"=="1" goto :legado

REM --- Tripwire de integridade (herdado dos 8 .cmd, que checavam o proprio .ps1
REM     em TODO comando). Aqui cobre o dispatcher; os 8 checks sao conferidos
REM     pela camada 2, e um .ps1 sumido e pego no launch pelo enforcement-health.
set "TAM=0"
for %%A in ("%PDIR%percus-dispatch-pre.ps1") do if not "%%~zA"=="" set "TAM=%%~zA"
if %TAM% LSS 200 goto :legado

if not exist "%PDIR%gatilhos-pre.txt" goto :legado

REM --- Triagem: UM findstr sobre a uniao dos gatilhos de todos os checks.
REM     /I e OBRIGATORIO: o -match do PowerShell e case-insensitive, entao um
REM     payload em MAIUSCULA dispara os checks mas nao casaria a triagem sem /I.
REM     Medido em 2026-09-12 -- sem /I, buraco silencioso.
REM     /L = literal: os gatilhos sao substrings, nunca regex.
findstr /L /I /G:"%PDIR%gatilhos-pre.txt" "%PAYLOAD%" >nul 2>&1
set "RC=%ERRORLEVEL%"

REM Ordem importa: `if errorlevel N` e VERDADE para >= N.
REM rc>=2 e ERRO do findstr (nao "nao casou"). Fail-OPEN: roda tudo. Tratar erro
REM como "nao casou" faria a cadeia sumir calada sempre que o findstr tropecasse.
if %RC% GEQ 2 goto :camada2
if %RC% EQU 1 goto :sai_limpo

:camada2
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PDIR%percus-dispatch-pre.ps1" "%PAYLOAD%"
set "EC=%ERRORLEVEL%"
if "%EC%"=="0" goto :sai_limpo
if "%EC%"=="2" goto :sai_bloqueia
REM Qualquer outro codigo = PowerShell nao subiu, ou morreu antes de decidir.
REM Defesa 1: lento e correto > rapido e mudo.
goto :legado

:sai_limpo
rd /s /q "%PBOX%" >nul 2>&1
endlocal
exit /b 0

:sai_bloqueia
rd /s /q "%PBOX%" >nul 2>&1
endlocal
exit /b 2

REM --- Fallback: a cadeia antiga, em serie, com o payload re-alimentado em cada
REM     um. Roda TODOS e so entao decide -- mesma agregacao da camada 2, pelo
REM     mesmo motivo: quase todo check e warn-only e parar no primeiro bloqueio
REM     apagaria o aviso dos seguintes.
:legado
set "VEREDITO=0"
call :roda pre-commit-check
call :roda mock-scan-pre-commit
call :roda auth-import-pre-commit
call :roda migration-check-pre-commit
call :roda types-check-pre-commit
call :roda external-action-guard
call :roda crud-evidence-warn
call :roda spec-analyze-check
rd /s /q "%PBOX%" >nul 2>&1
if "%VEREDITO%"=="2" ( endlocal & exit /b 2 )
endlocal
exit /b 0

:legado_sem_payload
REM Sem lugar pra gravar o payload (TEMP inexistente, sem permissao, disco cheio) nao ha
REM como rodar check nenhum: stdin so pode ser lido UMA vez, e a cadeia antiga precisa dele
REM oito vezes. Sair 0 aqui seria a cadeia inteira sumindo com um erro de caminho como unico
REM rastro -- exatamente a falha silenciosa que o findstr rc=1 produzia antes. Falha alto.
echo [percus:dispatch-pre] BLOCK: nao consegui reservar arquivo temporario em "%TEMP%". 1>&2
echo   Nenhum check de PreToolUse pode rodar, e passar em silencio esconderia isso. 1>&2
echo   Contorno: PERCUS_HOOKS_DISABLED=1 (desliga tudo) ou conserte %%TEMP%%. 1>&2
REM Este caminho tambem e alcancado quando o `md` DEU certo e a captura falhou depois,
REM entao a pasta reservada precisa sair aqui como sai em todos os outros caminhos.
rd /s /q "%PBOX%" >nul 2>&1
endlocal
exit /b 2

:roda
REM Wrapper ausente NAO pode ser pulado em silencio: este caminho so roda quando o
REM dispatcher ja falhou, que e o pior momento possivel pra perder um check calado --
REM contradiria a propria defesa 1 ("lento e correto > rapido e mudo"). E o
REM enforcement-health confere .ps1 em disco, nao .cmd, entao ninguem mais veria.
if exist "%PDIR%%~1.cmd" goto :roda_existe
echo [percus:dispatch-pre] AVISO: wrapper de fallback ausente: %~1.cmd -- este check NAO rodou. 1>&2
goto :eof
:roda_existe
call "%PDIR%%~1.cmd" < "%PAYLOAD%"
if not "%ERRORLEVEL%"=="0" set "VEREDITO=2"
goto :eof
