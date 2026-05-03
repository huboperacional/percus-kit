@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pre-commit-check.ps1" %*
