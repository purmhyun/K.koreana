@echo off
rem Double-click to run scripts\setup.ps1 (no admin rights needed).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1" %*
pause
