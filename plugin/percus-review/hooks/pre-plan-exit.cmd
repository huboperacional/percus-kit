@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0pre-plan-exit.ps1\"; exit $LASTEXITCODE"
