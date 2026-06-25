@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0pre-compact-checkpoint.ps1\"; exit $LASTEXITCODE"
