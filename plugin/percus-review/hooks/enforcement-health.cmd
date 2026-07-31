@echo off
if "%PERCUS_HOOKS_DISABLED%"=="1" exit /b 0
set "PERCUS_HOOK_PS1=%~dp0enforcement-health.ps1"
if not defined PERCUS_CANON_DIR goto :percus_roda
if not exist "%PERCUS_CANON_DIR%\plugin\percus-review\hooks\enforcement-health.ps1" goto :percus_roda
set "PERCUS_HOOK_PS1=%PERCUS_CANON_DIR%\plugin\percus-review\hooks\enforcement-health.ps1"
:percus_roda
set "PERCUS_HOOK_TAM=999999"
for %%A in ("%PERCUS_HOOK_PS1%") do if not "%%~zA"=="" set "PERCUS_HOOK_TAM=%%~zA"
if %PERCUS_HOOK_TAM% LSS 200 exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PERCUS_HOOK_PS1%"
