@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0auth-import-pre-commit.ps1\"; exit $LASTEXITCODE"
