@echo off
REM Start the aLima backend (Groq buyer banter + Portal proxy).
REM Run from anywhere: double-click this file, or in a terminal at the repo root:  .\server.cmd
REM cd /d ensures the server reads its own server\.env regardless of where you launch from.
cd /d "%~dp0server"
echo Starting aLima backend (Ctrl+C to stop)...
call npm start
