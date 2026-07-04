@echo off
REM Dev helper: starts the aLima backend from its own directory regardless of where
REM it is invoked from. Launched automatically by the ServerLauncher autoload when the
REM game runs from the editor in online AI mode; you can also double-click it yourself.
cd /d "%~dp0"
echo [aLima] Starting backend (npm run start) in %CD% ...
call npm run start
