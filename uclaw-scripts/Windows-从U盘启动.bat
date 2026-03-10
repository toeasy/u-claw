@echo off
chcp 65001 >nul 2>&1
title U-Claw 虾盘 - OpenClaw 一键启动

echo.
echo   ╔══════════════════════════════════════╗
echo   ║     U-Claw 虾盘 v1.1                ║
echo   ║     OpenClaw 一键启动 (Windows)      ║
echo   ╚══════════════════════════════════════╝
echo.
echo   推荐场景：老电脑 / 临时电脑 / 不想改本机环境
echo.

set "UCLAW_DIR=%~dp0"
set "OPENCLAW_DIR=%UCLAW_DIR%openclaw"
set "NODE_DIR=%UCLAW_DIR%runtime\node-win-x64"
set "NODE_BIN=%NODE_DIR%\node.exe"
set "NPM_BIN=%NODE_DIR%\npm.cmd"
set "PORTABLE_HOME=%UCLAW_DIR%portable-home"
set "PORTABLE_STATE_DIR=%PORTABLE_HOME%\.openclaw"
set "PORTABLE_CONFIG_PATH=%PORTABLE_STATE_DIR%\openclaw.json"

set "OPENCLAW_HOME=%PORTABLE_HOME%"
set "OPENCLAW_STATE_DIR=%PORTABLE_STATE_DIR%"
set "OPENCLAW_CONFIG_PATH=%PORTABLE_CONFIG_PATH%"

if not exist "%PORTABLE_STATE_DIR%" mkdir "%PORTABLE_STATE_DIR%"

if not exist "%NODE_BIN%" (
    echo   [错误] 找不到 Node.js 运行环境
    echo   请确保 runtime\node-win-x64 目录完整
    echo.
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('"%NODE_BIN%" --version') do set NODE_VER=%%v
echo   Node.js 版本: %NODE_VER%
echo.

set "PATH=%NODE_DIR%;%NODE_DIR%\node_modules\.bin;%PATH%"

if not exist "%OPENCLAW_DIR%\node_modules" (
    echo   首次运行，正在安装依赖...
    echo   （使用淘宝镜像，请稍等）
    echo.
    cd /d "%OPENCLAW_DIR%"
    call "%NPM_BIN%" install --registry=https://registry.npmmirror.com
    echo.
    echo   依赖安装完成!
    echo.
)

if not exist "%OPENCLAW_DIR%\dist" (
    echo   首次运行，正在构建...
    cd /d "%OPENCLAW_DIR%"
    call "%NPM_BIN%" run build
    echo.
)

cd /d "%OPENCLAW_DIR%"

REM 首次运行：自动写入最小配置（跳过 onboard）
if not exist "%PORTABLE_CONFIG_PATH%" (
    echo   首次运行，正在初始化配置...
    if not exist "%PORTABLE_STATE_DIR%" mkdir "%PORTABLE_STATE_DIR%"
    echo {"gateway":{"mode":"local","auth":{"token":"uclaw"}}} > "%PORTABLE_CONFIG_PATH%"
    echo   配置已初始化
    echo.
)

echo   正在启动 OpenClaw...
echo   此窗口不要关闭，关闭后服务会停止。
echo.
echo   ────────────────────────────────────
echo   启动后浏览器会自动打开控制台
echo   首次使用请在控制台中配置：
echo     1. 设置 AI 模型（DeepSeek / Kimi / 通义千问）
echo     2. 接入聊天平台（QQ / 飞书 / 钉钉）
echo   ────────────────────────────────────
echo.

start "" http://127.0.0.1:18789/#token=uclaw
"%NODE_BIN%" openclaw.mjs gateway run --allow-unconfigured --force

echo.
echo   OpenClaw 已退出。拔掉 U 盘后，本次便携运行就会结束。
pause
