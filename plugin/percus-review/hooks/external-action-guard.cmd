@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0external-action-guard.ps1\"; exit $LASTEXITCODE"
