@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0state-drift-check.ps1\"; exit $LASTEXITCODE"
