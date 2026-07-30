@echo off
if "%PERCUS_HOOKS_DISABLED%"=="1" exit /b 0
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0state-drift-check.ps1"
if %ERRORLEVEL%==0 exit /b 0
exit /b 2
