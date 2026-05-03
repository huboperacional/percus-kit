@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0pre-commit-check.ps1\"; exit $LASTEXITCODE"
