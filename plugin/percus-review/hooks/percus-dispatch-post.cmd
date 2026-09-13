@echo off
setlocal EnableExtensions
REM ============================================================================
REM Dispatcher PostToolUse -- CAMADA 1 (porta por timestamp em cmd.exe).
REM
REM O context-budget-guard custa ~458 ms (MEDIDO 2026-09-12, 10 chamadas) e roda
REM em TODA tool call -- matcher vazio de proposito, porque contexto cresce com
REM Read/Edit tanto quanto com Bash. Nao ha substring que o trie: a triagem aqui
REM e uma PORTA POR TIMESTAMP -- ela limita QUANTAS VEZES o PowerShell sobe, e
REM nao QUAIS tools sao observadas. Essa distincao e o pacote inteiro: foi por
REM perder cobertura de tools que a "opcao D" (estreitar o matcher pra
REM Bash|Edit|Write) foi descartada por medicao.
REM
REM MEDIDO contra 11 679 invocacoes reais de PostToolUse (40 transcripts):
REM   porta 30 s -> 63,0% dormem; atraso do aviso de limiar: mediana 0,9 chamada
REM   (1 235 tokens), p95 4 359, max 17 040. Maior janela cega: 14 chamadas/29 s.
REM   Baseline SEM porta (guard em toda call): o maior salto de contexto de UM
REM   passo ja e 104 664 tokens -- ou seja, em todo N testado o crescimento nao
REM   observado fica ABAIXO do que o guard ja nao ve rodando sempre. A porta nao
REM   cria uma cegueira nova; ela so espaca a medicao. (A opcao D criava: ate 130
REM   chamadas consecutivas, e justo as de Read/snapshot, que mais inflam.)
REM
REM POR QUE A PORTA E FIXA, e nao adaptativa ao percentual de contexto: a politica
REM adaptativa dependeria do denominador da janela, e ele NAO esta disponivel --
REM medido em 40 transcripts, NENHUM declara o marcador [1m]/-1m no campo `model`
REM (24x 'claude-opus-5' puro, 8x 'claude-sonnet-5'). Simulada, a adaptativa dormia
REM 8,8% porque quase toda sessao parece estar acima de 75% do piso de 200k.
REM Porta fixa, medida, com o numero em porta-post.txt.
REM
REM ESTA CAMADA NAO CAPTURA STDIN, e a diferenca importa. O payload de PostToolUse
REM carrega `tool_response`: medido em 60 476 tool_results reais, mediana 344 B,
REM p99 26 KB, MAX 681 KB, com 0,59% acima de 80 KB -- que e onde a captura do
REM dispatcher `pre` (findstr "^") trunca, saindo 0. Copiar aquela captura traria
REM truncagem ROTINEIRA, e no PostToolUse isso viraria erro espurio em toda tool
REM call grande. Como a porta nao precisa ler o payload, stdin e REPASSADO DIRETO
REM ao PowerShell -- exatamente como o .cmd antigo ja fazia. Sem temp, sem limite.
REM
REM Spec: docs/superpowers/specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md
REM ============================================================================

if "%PERCUS_HOOKS_DISABLED%"=="1" exit /b 0

set "PDIR=%~dp0"
if not defined PERCUS_CANON_DIR goto :dir_ok
if not exist "%PERCUS_CANON_DIR%\plugin\percus-review\hooks\percus-dispatch-post.ps1" goto :dir_ok
set "PDIR=%PERCUS_CANON_DIR%\plugin\percus-review\hooks\"
:dir_ok

if "%PERCUS_DISPATCHER_BYPASS%"=="1" goto :legado

REM --- Tripwire de integridade (herdado do .cmd antigo, que checava o proprio
REM     .ps1 em toda chamada). .ps1 truncado/ausente = instalacao corrompida:
REM     cai na cadeia antiga em vez de sumir calado.
set "TAM=0"
for %%A in ("%PDIR%percus-dispatch-post.ps1") do if not "%%~zA"=="" set "TAM=%%~zA"
if %TAM% LSS 200 goto :legado

REM ---------------------------------------------------------------- PORTA -----
REM Toda validacao abaixo cai em FAIL-OPEN (roda o guard). A porta e uma
REM otimizacao; duvida sobre ela custa 458 ms, enquanto fechar por engano custa a
REM medicao de contexto -- que e a unica coisa que este hook existe pra dar.

set "PORTA_OK=1"

REM Agora em segundos do dia. `%TIME: =0%` normaliza a hora de 1 digito (" 9:05"
REM -> "09:05"); o `1%%..%%-100` evita que "08"/"09" sejam lidos como octal, que e
REM o erro classico do set /a. Posicoes fixas 0-1/3-4/6-7 valem tanto pra "," como
REM pra "." de separador decimal.
REM LIMITE CONHECIDO: locale de 12 horas daria hora ambigua. O sintoma seria uma
REM porta errada, nunca uma ausencia de medicao -- na virada o delta fica negativo
REM e cai no fail-open logo abaixo.
set "T=%TIME: =0%"
set "NOW=-1"
set /a NOW=(1%T:~0,2%-100)*3600+(1%T:~3,2%-100)*60+(1%T:~6,2%-100) 2>nul
if %NOW% LSS 0 set "PORTA_OK=0"
if %NOW% GEQ 86400 set "PORTA_OK=0"
if "%PORTA_OK%"=="0" goto :abre_sem_marcar

REM A porta e POR SESSAO. Global faria a sessao B segurar a porta da sessao A: A
REM poderia estourar a janela enquanto as chamadas de B mantem o guard fechado --
REM degradacao silenciosa, e o operador roda 2+ sessoes na mesma arvore.
REM
REM SEM chave de sessao NAO existe porta. A versao anterior caia num balde fixo
REM ("sem-sessao") e o review R11 provou o estrago com dois processos reais: a
REM sessao B teve o guard SILENCIADO pela porta que a sessao A abriu. Um balde
REM compartilhado e pior que nenhuma porta -- perde medicao de contexto de uma
REM sessao inteira, calado, que e o oposto do que este hook existe pra fazer.
REM Sem SID a gente paga o custo antigo e mede sempre; o enforcement-health avisa
REM UMA vez por sessao, que e o lugar certo pra esse aviso (aqui seria ruido em
REM toda tool call).
set "SID=%CLAUDE_CODE_SESSION_ID%"
if not defined SID goto :abre_sem_marcar
set "STAMP=%TEMP%\percus-post-gate-%SID%.txt"

REM ⚠️ SID e STAMP sao resolvidos ANTES da validacao de N, e a ordem e o conserto
REM de um defeito real (achado 1 do review R11): havia TRES `goto :abre` aqui
REM embaixo -- N indefinido, N malformado e N<=0 -- e todos pulavam o bloco do
REM STAMP. O `:abre` grava incondicionalmente, entao com STAMP vazio virava `>""`,
REM redirecionamento invalido, e o cmd.exe cuspia "O sistema nao pode encontrar o
REM caminho especificado." em TODA tool call -- sem prefixo [percus:], sem
REM atribuicao, indistinguivel de problema do sistema. O `2>nul` nao cobre isso:
REM ele suprime o stderr do `echo`, nao o do parser de redirecionamento.
REM O caminho mais provavel era `PERCUS_POST_PORTA_SEGUNDOS=0` -- valor que o
REM proprio teste do pacote usa e aprova.

REM Duracao da porta: env explicito vence o arquivo (o env e o que os testes usam
REM pra exercitar porta fechada e porta 0 sem depender do valor publicado).
set "N="
if defined PERCUS_POST_PORTA_SEGUNDOS set "N=%PERCUS_POST_PORTA_SEGUNDOS%"
if not defined N if exist "%PDIR%porta-post.txt" set /p N=<"%PDIR%porta-post.txt"
if not defined N goto :abre

REM Lixo no arquivo (BOM, texto, vazio) nao pode virar porta silenciosa: compara o
REM valor com ele mesmo passado pelo parser aritmetico. Zero a esquerda ("030")
REM tambem cai aqui, porque `set /a` le como octal e o valor deixa de bater.
set "NCHK=-999"
set /a NCHK=N+0 2>nul
if not "%NCHK%"=="%N%" goto :abre
if %N% LEQ 0 goto :abre

if not exist "%STAMP%" goto :abre
set "LAST="
set /p LAST=<"%STAMP%"
if not defined LAST goto :abre
set "LCHK=-999"
set /a LCHK=LAST+0 2>nul
if not "%LCHK%"=="%LAST%" goto :abre

set /a DELTA=NOW-LAST
REM Delta negativo = virada de meia-noite (ou relogio pra tras). Fail-open: no
REM maximo o guard roda uma vez a mais por dia.
if %DELTA% LSS 0 goto :abre
if %DELTA% GEQ %N% goto :abre

REM ---- PORTA FECHADA: o PowerShell nao sobe. E aqui que o ganho acontece. ----
endlocal
exit /b 0

:abre
REM Marca ANTES de rodar, nao depois: duas tool calls concorrentes da mesma sessao
REM nao podem subir dois PowerShell. Se a gravacao falhar (TEMP ruim, SID estranho),
REM a porta simplesmente nunca fecha -- caro e correto.
REM
REM A guarda abaixo e cinto-e-suspensorio: hoje todo caminho que chega aqui ja
REM resolveu o STAMP (ver o bloco da porta). Ela existe porque a versao anterior
REM NAO tinha essa propriedade e o sintoma foi lixo no stderr em toda tool call --
REM um `goto :abre` novo, acrescentado antes do bloco do STAMP, reintroduziria o
REM defeito exatamente do mesmo jeito. Aqui isso vira no-op, nao vira lixo.
if not defined STAMP goto :abre_sem_marcar
REM As DUAS redirecoes vem ANTES do echo de proposito. Escrito como
REM `echo %NOW% 2>nul`, o cmd deixa o espaco que separa o argumento do `2>` DENTRO
REM do texto: o arquivo ganha "81234 " e, na chamada seguinte, a validacao
REM `"%LCHK%"=="%LAST%"` compara "81234" com "81234 ", falha, e cai no fail-open.
REM A porta nunca fechava e o ganho sumia CALADO -- o dispatcher seguia correto, so
REM caro. Pego pelo teste "segunda chamada dentro da janela DORME".
>"%STAMP%" 2>nul echo %NOW%

:abre_sem_marcar
REM stdin e HERDADO pelo powershell.exe -- nada foi lido aqui. Ver o cabecalho.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PDIR%percus-dispatch-post.ps1"
set "EC=%ERRORLEVEL%"
if "%EC%"=="0" ( endlocal & exit /b 0 )
if "%EC%"=="2" ( endlocal & exit /b 2 )
REM Qualquer outro codigo = o PowerShell nao subiu, ou a camada 2 decidiu que nao
REM tinha como decidir (exit 9), e nesses dois casos ela NAO consumiu stdin.
REM Defesa 1: lento e correto > rapido e mudo.
goto :legado

REM --- Fallback: a cadeia antiga, com stdin ainda intacto.
REM     Um so check hoje, mas a lista e conferida contra o manifesto por teste --
REM     um check novo que entrasse na camada 2 e nao aqui sumiria CALADO justo
REM     quando o PowerShell nao sobe, que e o pior momento pra descobrir.
:legado
set "VEREDITO=0"
call :roda context-budget-guard
if "%VEREDITO%"=="2" ( endlocal & exit /b 2 )
endlocal
exit /b 0

:roda
if exist "%PDIR%%~1.cmd" goto :roda_existe
echo [percus:dispatch-post] AVISO: wrapper de fallback ausente: %~1.cmd -- este check NAO rodou. 1>&2
goto :eof
:roda_existe
call "%PDIR%%~1.cmd"
if not "%ERRORLEVEL%"=="0" set "VEREDITO=2"
goto :eof
