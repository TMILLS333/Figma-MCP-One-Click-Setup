@echo off
REM Double-clickable launcher for Windows.
REM Runs setup.ps1 from the same folder this file lives in.

setlocal
cd /d "%~dp0"

echo Figma MCP - One-Click Setup
echo.

REM Run PowerShell with ExecutionPolicy Bypass so unsigned scripts work
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"

echo.
echo Press any key to close this window.
pause >nul
endlocal
