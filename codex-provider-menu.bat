@echo off
setlocal
cd /d "%~dp0"

:menu
echo.
echo Codex Provider Switcher
echo 1. Switch to APIMaster and sync history
echo 2. Switch to official subscription and sync history
echo 3. Show status
echo 4. Test APIMaster /v1/models
echo 5. Save current profile as official
echo 6. Repair Desktop history list
echo 0. Exit
echo.
set /p choice=Choose: 

if "%choice%"=="1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" apimaster -Lang en
  goto menu
)
if "%choice%"=="2" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" official -Lang en
  goto menu
)
if "%choice%"=="3" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" status -Lang en
  goto menu
)
if "%choice%"=="4" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" test -Lang en
  goto menu
)
if "%choice%"=="5" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" save-official -Lang en
  goto menu
)
if "%choice%"=="6" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" repair-history -Lang en
  goto menu
)
if "%choice%"=="0" exit /b 0
goto menu
