@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"%~dp0crud-evidence-warn.ps1\"; exit $LASTEXITCODE"
