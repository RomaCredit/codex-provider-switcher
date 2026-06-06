@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

:menu
echo.
echo Codex Provider 切换器
echo 1. 切换到 APIMaster 并同步历史
echo 2. 切换到官方订阅并同步历史
echo 3. 查看状态
echo 4. 测试 APIMaster /v1/models
echo 5. 保存当前配置为官方配置
echo 6. 修复 Desktop 历史列表
echo 0. 退出
echo.
set /p choice=请选择: 

if "%choice%"=="1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" apimaster -Lang zh
  goto menu
)
if "%choice%"=="2" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" official -Lang zh
  goto menu
)
if "%choice%"=="3" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" status -Lang zh
  goto menu
)
if "%choice%"=="4" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" test -Lang zh
  goto menu
)
if "%choice%"=="5" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" save-official -Lang zh
  goto menu
)
if "%choice%"=="6" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-codex-provider.ps1" repair-history -Lang zh
  goto menu
)
if "%choice%"=="0" exit /b 0
goto menu
