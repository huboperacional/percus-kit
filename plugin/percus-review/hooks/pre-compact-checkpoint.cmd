@echo off
if "%PERCUS_HOOKS_DISABLED%"=="1" exit /b 0
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pre-compact-checkpoint.ps1"
