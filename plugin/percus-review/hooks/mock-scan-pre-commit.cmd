@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0mock-scan-pre-commit.ps1\"; exit $LASTEXITCODE"
