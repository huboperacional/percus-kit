@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0types-check-pre-commit.ps1\"; exit $LASTEXITCODE"
