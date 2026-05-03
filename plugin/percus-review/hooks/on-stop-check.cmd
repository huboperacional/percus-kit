@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0on-stop-check.ps1\"; exit $LASTEXITCODE"
