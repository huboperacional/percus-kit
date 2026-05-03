@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0on-stop-check.ps1" %*
