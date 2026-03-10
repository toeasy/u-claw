@echo off
chcp 65001 >/dev/null 2>&1
title U-Claw - Full Menu

set "UCLAW_DIR=%~dp0"
set "CORE_DIR=%UCLAW_DIR%app\core"
set "DATA_DIR=%UCLAW_DIR%data"
set "STATE_DIR=%DATA_DIR%\.openclaw"
set "NODE_DIR=%UCLAW_DIR%app\runtime\node-win-x64"
set "NODE_BIN=%NODE_DIR%\node.exe"
set "NPM_BIN=%NODE_DIR%\npm.cmd"

set "OPENCLAW_HOME=%DATA_DIR%"
set "OPENCLAW_STATE_DIR=%STATE_DIR%"
set "OPENCLAW_CONFIG_PATH=%STATE_DIR%\openclaw.json"
set "PATH=%NODE_DIR%;%NODE_DIR%\node_modules\.bin;%PATH%"

if not exist "%STATE_DIR%" mkdir "%STATE_DIR%"
if not exist "%DATA_DIR%\memory" mkdir "%DATA_DIR%\memory"
if not exist "%DATA_DIR%\backups" mkdir "%DATA_DIR%\backups"

:menu
cls
echo.
echo   ========================================
echo     U-Claw v1.1 - Full Menu
echo   ========================================
echo.

if exist "%NODE_BIN%" (
    for /f "tokens=*" %%v in ('"%NODE_BIN%" --version') do echo   Node.js: %%v
) else (
    echo   [!] Node.js not found
)
if exist "%CORE_DIR%\node_modules" (echo   Dependencies: OK) else (echo   Dependencies: NOT INSTALLED)
if exist "%CORE_DIR%\dist" (echo   Build: OK) else (echo   Build: NOT BUILT)
if exist "%STATE_DIR%\openclaw.json" (echo   Config: OK) else (echo   Config: NOT SET)
echo.
echo   -- Start --
echo   [1] Quick start (gateway + browser)
echo   [2] Setup wizard (choose model, API key)
echo.
echo   -- China Platforms --
echo   [3] QQ Bot setup (Tencent official)
echo   [4] Feishu / DingTalk / WeChat
echo.
echo   -- Skills --
echo   [5] Browse pre-installed skills (52)
echo   [6] Install skill from ClawHub
echo.
echo   -- Maintenance --
echo   [7] Diagnostics (openclaw doctor)
echo   [8] Backup config and memory
echo   [9] Restore backup
echo   [10] Reset (factory default)
echo.
echo   -- Other --
echo   [11] Open web dashboard
echo   [12] System info
echo   [13] Set China mirror
echo   [0] Exit
echo.
set /p choice="  Choose [0-13]: "

if "%choice%"=="1" goto :start
if "%choice%"=="2" goto :onboard
if "%choice%"=="3" goto :qqbot
if "%choice%"=="4" goto :channels
if "%choice%"=="5" goto :skills
if "%choice%"=="6" goto :install_skill
if "%choice%"=="7" goto :doctor
if "%choice%"=="8" goto :backup
if "%choice%"=="9" goto :restore
if "%choice%"=="10" goto :reset
if "%choice%"=="11" goto :dashboard
if "%choice%"=="12" goto :sysinfo
if "%choice%"=="13" goto :mirror
if "%choice%"=="0" exit /b 0
echo   Invalid choice
pause
goto :menu

:start
call "%UCLAW_DIR%start.bat"
goto :end

:onboard
cd /d "%CORE_DIR%"
"%NODE_BIN%" openclaw.mjs onboard
pause
goto :menu

:qqbot
echo.
echo   === QQ Bot Setup (Tencent Official) ===
echo.
echo   1. Register: http://q.qq.com/qqbot/openclaw/login.html
echo   2. Create bot, get AppID and AppSecret
echo   3. Run these commands:
echo.
echo   openclaw plugins install @sliverp/qqbot@latest
echo   openclaw channels add --channel qqbot --token "AppID:AppSecret"
echo   openclaw config set channels.qqbot.allowFrom "your_qq_number"
echo   openclaw gateway restart
echo.
set /p qqinstall="  Install QQ plugin now? (y/n): "
if /i "%qqinstall%"=="y" (
    cd /d "%CORE_DIR%"
    "%NODE_BIN%" openclaw.mjs plugins install @sliverp/qqbot@latest
    echo.
    set /p qqid="  AppID: "
    set /p qqsecret="  AppSecret: "
    if not "%qqid%"=="" if not "%qqsecret%"=="" (
        "%NODE_BIN%" openclaw.mjs channels add --channel qqbot --token "%qqid%:%qqsecret%"
        set /p qqallow="  Your QQ number (allowlist): "
        if not "%qqallow%"=="" "%NODE_BIN%" openclaw.mjs config set channels.qqbot.allowFrom "%qqallow%"
        echo   QQ Bot configured!
    )
)
pause
goto :menu

:channels
echo.
echo   === Chat Platforms ===
echo.
echo   [a] Feishu - https://open.feishu.cn/app
echo   [b] WeChat - openclaw plugins install @icesword760/openclaw-wechat
echo   [c] DingTalk - built-in
echo   [d] Telegram / Discord / WhatsApp / Slack - built-in
echo.
echo   Use [2] Setup wizard to configure these platforms.
pause
goto :menu

:skills
echo.
echo   === Pre-installed Skills (52) ===
echo.
echo   Productivity: github, coding-agent, summarize, nano-pdf, clawhub
echo   Notes: apple-notes, obsidian, notion, trello, bear-notes
echo   AI: openai-image-gen, openai-whisper, gemini, sherpa-onnx-tts
echo   Social: himalaya (email), discord, slack, wacli (WhatsApp)
echo   System: weather, peekaboo, tmux, healthcheck, 1password
echo   IoT: openhue, sonoscli, eightctl, camsnap
echo.
echo   Use "openclaw skills list" for full list.
pause
goto :menu

:install_skill
echo.
set /p skillname="  Skill name: "
if not "%skillname%"=="" (
    cd /d "%CORE_DIR%"
    "%NODE_BIN%" openclaw.mjs skills install %skillname%
)
pause
goto :menu

:doctor
cd /d "%CORE_DIR%"
"%NODE_BIN%" openclaw.mjs doctor --repair
pause
goto :menu

:backup
echo.
set "TIMESTAMP=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"
set "BACKUP_PATH=%DATA_DIR%\backups\backup_%TIMESTAMP%"
mkdir "%BACKUP_PATH%" 2>/dev/null
if exist "%STATE_DIR%\openclaw.json" copy "%STATE_DIR%\openclaw.json" "%BACKUP_PATH%\" >/dev/null
if exist "%DATA_DIR%\memory" xcopy /s /q "%DATA_DIR%\memory" "%BACKUP_PATH%\memory\" >/dev/null 2>/dev/null
echo   Backup saved to: %BACKUP_PATH%
pause
goto :menu

:restore
echo.
echo   Backups:
dir /b "%DATA_DIR%\backups\" 2>/dev/null
echo.
set /p restorename="  Backup folder name: "
if exist "%DATA_DIR%\backups\%restorename%\openclaw.json" (
    copy "%DATA_DIR%\backups\%restorename%\openclaw.json" "%STATE_DIR%\" >/dev/null
    echo   Config restored!
)
pause
goto :menu

:reset
echo.
echo   WARNING: This will reset your config!
set /p confirm="  Type YES to confirm: "
if "%confirm%"=="YES" (
    del "%STATE_DIR%\openclaw.json" 2>/dev/null
    echo {"gateway":{"mode":"local","auth":{"token":"uclaw"}}} > "%STATE_DIR%\openclaw.json"
    echo   Reset complete.
)
pause
goto :menu

:dashboard
echo.
echo   Starting gateway...
set PORT=18789
:find_port
netstat -an | findstr ":%PORT% " | findstr "LISTENING" >/dev/null 2>&1
if %errorlevel%==0 (
    set /a PORT+=1
    if %PORT% gtr 18799 (echo No available port & pause & goto :menu)
    goto :find_port
)
cd /d "%CORE_DIR%"
if not exist "%STATE_DIR%\openclaw.json" (
    echo {"gateway":{"mode":"local","auth":{"token":"uclaw"}}} > "%STATE_DIR%\openclaw.json"
)
start "" http://127.0.0.1:%PORT%/#token=uclaw
"%NODE_BIN%" openclaw.mjs gateway run --allow-unconfigured --force --port %PORT%
pause
goto :menu

:sysinfo
echo.
echo   OS: Windows
echo   Node: 
"%NODE_BIN%" --version
echo   U-Claw: %UCLAW_DIR%
echo   Data: %DATA_DIR%
pause
goto :menu

:mirror
echo.
cd /d "%CORE_DIR%"
"%NODE_BIN%" "%NPM_BIN%" config set registry https://registry.npmmirror.com --location=project
echo   npm mirror set to: registry.npmmirror.com
pause
goto :menu

:end
