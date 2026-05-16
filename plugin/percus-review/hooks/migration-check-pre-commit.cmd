@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0migration-check-pre-commit.ps1\"; exit $LASTEXITCODE"
