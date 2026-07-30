@echo off
if "%PERCUS_HOOKS_DISABLED%"=="1" exit /b 0
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0migration-check-pre-commit.ps1"
if %ERRORLEVEL%==0 exit /b 0
exit /b 2
