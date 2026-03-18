# ============================================================
# U-Claw 一键安装脚本 (Windows PowerShell)
# 用法: irm https://u-claw.org/install.ps1 | iex
#       或: powershell -ExecutionPolicy Bypass -File install.ps1
# ============================================================

# 编码 + 执行策略
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
try { chcp 65001 | Out-Null } catch {}
Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

$ErrorActionPreference = "Stop"

# ---- 常量 ----
$UCLAW_DIR = "$env:USERPROFILE\.uclaw"
$RUNTIME_DIR = "$UCLAW_DIR\runtime"
$CORE_DIR = "$UCLAW_DIR\core"
$DATA_DIR = "$UCLAW_DIR\data"
$CONFIG_PATH = "$DATA_DIR\.openclaw\openclaw.json"
$NODE_VERSION = "v22.14.0"
$MIRROR = "https://registry.npmmirror.com"
$NODE_MIRROR = "https://npmmirror.com/mirrors/node"

# ---- 颜色函数 ----
function Write-Green($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Cyan($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Yellow($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Red($msg) { Write-Host $msg -ForegroundColor Red }

# ============================================================
# Step 1: Banner + 系统检测
# ============================================================
Clear-Host
Write-Host ""
Write-Cyan "  ╔══════════════════════════════════════════╗"
Write-Cyan "  ║  🦞 U-Claw 一键安装 (Windows)            ║"
Write-Cyan "  ║  让 AI 助手一行命令装好                    ║"
Write-Cyan "  ╚══════════════════════════════════════════╝"
Write-Host ""

# 系统检测
$ARCH = $env:PROCESSOR_ARCHITECTURE
if ($ARCH -eq "AMD64" -or $ARCH -eq "x86_64") {
    $PLATFORM = "win-x64"
    Write-Green "  系统: Windows x64 ✓"
} elseif ($ARCH -eq "ARM64") {
    $PLATFORM = "win-arm64"
    Write-Green "  系统: Windows ARM64 ✓"
} else {
    Write-Red "  不支持的架构: $ARCH"
    exit 1
}

Write-Host "  安装目录: $UCLAW_DIR" -ForegroundColor Cyan
Write-Host ""

# 检查已有安装
if (Test-Path "$CORE_DIR\node_modules\openclaw") {
    Write-Yellow "  检测到已有安装: $UCLAW_DIR"
    $overwrite = Read-Host "  覆盖安装？(y/n) [y]"
    if ($overwrite -eq "n" -or $overwrite -eq "N") {
        Write-Host "  已取消" -ForegroundColor DarkGray
        exit 0
    }
    Write-Host ""
}

# 创建目录
New-Item -ItemType Directory -Force -Path $RUNTIME_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $CORE_DIR | Out-Null
New-Item -ItemType Directory -Force -Path "$DATA_DIR\.openclaw" | Out-Null
New-Item -ItemType Directory -Force -Path "$DATA_DIR\memory" | Out-Null
New-Item -ItemType Directory -Force -Path "$DATA_DIR\backups" | Out-Null

# ============================================================
# Step 2: Node.js v22 安装
# ============================================================
Write-Host "  [1/7] 安装 Node.js $NODE_VERSION ..." -ForegroundColor White

$NODE_INSTALL_DIR = "$RUNTIME_DIR\node-$PLATFORM"
$INSTALL_NODE = ""
$NPM_CLI = ""
$USE_SYSTEM_NODE = $false

# 检查系统 Node.js
$sysNode = Get-Command node -ErrorAction SilentlyContinue
if ($sysNode) {
    $sysVer = & node --version 2>$null
    $major = [int]($sysVer -replace 'v','').Split('.')[0]
    if ($major -ge 20) {
        Write-Green "  ✓ 系统已有 Node.js $sysVer，复用"
        $INSTALL_NODE = "node"
        # 通过 npm.cmd 的位置找到 npm-cli.js
        $npmCmd = (Get-Command npm -ErrorAction SilentlyContinue).Source
        $npmRoot = Split-Path (Split-Path $npmCmd)
        $NPM_CLI = "$npmRoot\node_modules\npm\bin\npm-cli.js"
        if (-not (Test-Path $NPM_CLI)) {
            # fallback: 直接用 npm prefix 找
            $npmPrefix = & node -e "console.log(process.execPath.replace(/[\\\/]node\.exe$/i,''))" 2>$null
            $NPM_CLI = "$npmPrefix\node_modules\npm\bin\npm-cli.js"
        }
        $USE_SYSTEM_NODE = $true
    }
}

if (-not $USE_SYSTEM_NODE) {
    if (Test-Path "$NODE_INSTALL_DIR\node.exe") {
        Write-Green "  ✓ Node.js 已存在，跳过下载"
        $INSTALL_NODE = "$NODE_INSTALL_DIR\node.exe"
        $NPM_CLI = "$NODE_INSTALL_DIR\node_modules\npm\bin\npm-cli.js"
    } else {
        Write-Cyan "  ↓ 从国内镜像下载 Node.js $NODE_VERSION ($PLATFORM)..."
        $zipName = "node-$NODE_VERSION-$PLATFORM.zip"
        $url = "$NODE_MIRROR/$NODE_VERSION/$zipName"
        $tempZip = "$env:TEMP\$zipName"
        $tempExtract = "$env:TEMP\node-extract-uclaw"

        # 下载
        Write-Host "    $url"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing
        } catch {
            # 尝试 curl
            try {
                & curl.exe -# -L $url -o $tempZip
            } catch {
                Write-Red "  ✗ 下载失败！请检查网络连接"
                exit 1
            }
        }

        # 解压
        Write-Host "  解压中..."
        if (Test-Path $tempExtract) { Remove-Item -Recurse -Force $tempExtract }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        $extractedDir = Get-ChildItem $tempExtract | Select-Object -First 1
        New-Item -ItemType Directory -Force -Path $NODE_INSTALL_DIR | Out-Null
        Copy-Item -Recurse -Force "$($extractedDir.FullName)\*" $NODE_INSTALL_DIR

        # 清理
        Remove-Item -Force $tempZip -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $tempExtract -ErrorAction SilentlyContinue

        if (Test-Path "$NODE_INSTALL_DIR\node.exe") {
            Write-Green "  ✓ Node.js 安装完成"
            $INSTALL_NODE = "$NODE_INSTALL_DIR\node.exe"
            $NPM_CLI = "$NODE_INSTALL_DIR\node_modules\npm\bin\npm-cli.js"
        } else {
            Write-Red "  ✗ Node.js 下载失败"
            exit 1
        }
    }

    # npm-cli.js 内部可能需要通过 PATH 找到 node.exe
    $env:PATH = "$NODE_INSTALL_DIR;$env:PATH"
}

Write-Host ""

# ============================================================
# Step 3: OpenClaw 安装
# ============================================================
Write-Host "  [2/7] 安装 OpenClaw ..." -ForegroundColor White

if (Test-Path "$CORE_DIR\node_modules\openclaw") {
    Write-Green "  ✓ OpenClaw 已安装，跳过"
} else {
    if (-not (Test-Path "$CORE_DIR\package.json")) {
        $pkgJson = @'
{
  "name": "u-claw-core",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "openclaw": "latest"
  }
}
'@
        [IO.File]::WriteAllText("$CORE_DIR\package.json", $pkgJson, (New-Object System.Text.UTF8Encoding $false))
    }

    Write-Cyan "  ↓ 从国内镜像安装..."
    Write-Host "    node: $INSTALL_NODE" -ForegroundColor DarkGray
    Write-Host "    npm-cli: $NPM_CLI" -ForegroundColor DarkGray
    Write-Host "    prefix: $CORE_DIR" -ForegroundColor DarkGray
    if (-not (Test-Path $NPM_CLI)) {
        Write-Red "  ✗ npm-cli.js 不存在: $NPM_CLI"
        exit 1
    }
    if (-not (Test-Path "$CORE_DIR\package.json")) {
        Write-Red "  ✗ package.json 不存在: $CORE_DIR\package.json"
        exit 1
    }
    & $INSTALL_NODE $NPM_CLI install --prefix "$CORE_DIR" --registry=$MIRROR 2>&1 | Select-Object -Last 5
    if ($LASTEXITCODE -ne 0) {
        Write-Red "  ✗ OpenClaw 安装失败，请检查网络"
        exit 1
    }
    Write-Green "  ✓ OpenClaw 安装完成"
}

Write-Host ""

# ============================================================
# Step 4: QQ 插件
# ============================================================
Write-Host "  [3/7] 安装 QQ 插件 ..." -ForegroundColor White

if (Test-Path "$CORE_DIR\node_modules\@sliverp\qqbot") {
    Write-Green "  ✓ QQ 插件已安装，跳过"
} else {
    Write-Cyan "  ↓ 安装 QQ 插件..."
    try {
        & $INSTALL_NODE $NPM_CLI install "@sliverp/qqbot@latest" --prefix "$CORE_DIR" --registry=$MIRROR 2>&1 | Out-Null
        Write-Green "  ✓ QQ 插件安装完成"
    } catch {
        Write-Yellow "  ⚠ QQ 插件安装失败（不影响主功能）"
    }
}

Write-Host ""

# ============================================================
# Step 5: 写入 10 个中国技能
# ============================================================
Write-Host "  [4/7] 安装中国本地化技能 (10个) ..." -ForegroundColor White

$SKILLS_TARGET = "$CORE_DIR\node_modules\openclaw\skills"
if (-not (Test-Path $SKILLS_TARGET)) { New-Item -ItemType Directory -Force -Path $SKILLS_TARGET | Out-Null }

$skillCount = 0

$skills = @{
    "bilibili-helper" = @'
---
name: bilibili-helper
description: "B站内容助手 - 视频标题描述优化、标签策略、封面设计建议、分区选择、评论互动"
metadata: { "openclaw": { "emoji": "📺" } }
---

# B站内容助手

帮助 UP 主优化视频标题、描述、标签和封面，提升视频在 B 站的推荐和互动表现。

## 标题公式

1. **疑问式**: "为什么XX？看完你就懂了"
2. **教程式**: "XX教程｜从零开始手把手教学"
3. **测评式**: "花了XX元买了XX，值不值？"
4. **挑战式**: "挑战XX天只用XX"
5. **盘点式**: "XX年度十大XX盘点"

## 分区选择指南

| 内容类型 | 推荐分区 |
|---------|---------|
| 编程教程 | 科技 → 计算机技术 |
| 日常 vlog | 生活 → 日常 |
| 游戏实况 | 游戏 → 单机/网游 |
| 知识科普 | 知识 → 社科人文/科学科普 |
| AI/数码 | 科技 → 软件应用 |
'@

    "china-search" = @'
---
name: china-search
description: "国内搜索引擎 - 百度、搜狗、Bing中国搜索，绕过GFW限制"
metadata: { "openclaw": { "emoji": "🔍" } }
---

# 国内搜索引擎助手

通过 curl 调用百度、搜狗、Bing 中国等国内搜索引擎获取信息。

## 搜索命令

```bash
curl -s -L "https://www.baidu.com/s?wd=关键词" -H "User-Agent: Mozilla/5.0"
curl -s -L "https://weixin.sogou.com/weixin?query=关键词" -H "User-Agent: Mozilla/5.0"
curl -s -L "https://cn.bing.com/search?q=关键词" -H "User-Agent: Mozilla/5.0"
```
'@

    "china-translate" = @'
---
name: china-translate
description: "中英互译 + 本地化 - 技术翻译、UI本地化、文化适配、避免机翻腔"
metadata: { "openclaw": { "emoji": "🌐" } }
---

# 中英互译 + 本地化助手

专业的中英双向翻译工具，专注技术文档翻译、产品本地化和文化适配。

## 常见术语对照

| English | 中文 |
|---------|------|
| Deploy | 部署 |
| Repository | 仓库 |
| Container | 容器 |
| Middleware | 中间件 |
| Render | 渲染 |
| Token | Token / 令牌 |
| Prompt | 提示词 |
| Fine-tune | 微调 |
'@

    "china-weather" = @'
---
name: china-weather
description: "中国城市天气查询 - 支持中文城市名、wttr.in接口"
metadata: { "openclaw": { "emoji": "🌤️" } }
---

# 中国城市天气查询

```bash
curl -s "wttr.in/深圳?lang=zh"
curl -s "wttr.in/深圳?format=j1"
```
'@

    "deepseek-helper" = @'
---
name: deepseek-helper
description: "DeepSeek API 助手 - 编程辅助、模型选择、API调用指南、定价信息"
metadata: { "openclaw": { "emoji": "🤖" } }
---

# DeepSeek API 助手

## 模型对比

| 模型 | 适用场景 | 上下文 |
|------|---------|--------|
| deepseek-chat | 日常对话、文案 | 32K |
| deepseek-coder | 代码生成 | 16K |
| deepseek-reasoner | 复杂推理 | 64K |

- API 兼容 OpenAI 格式，base_url: https://api.deepseek.com
- 国内直连，API Key: https://platform.deepseek.com
'@

    "douyin-script" = @'
---
name: douyin-script
description: "抖音/快手短视频脚本 - 前3秒hook、脚本结构、话题标签策略"
metadata: { "openclaw": { "emoji": "🎬" } }
---

# 抖音/快手短视频脚本助手

## 前3秒 Hook 公式

1. 反常识: "你一直在做的XX其实是错的"
2. 数字冲击: "只花了100块，效果比1000块的还好"
3. 悬念提问: "猜猜这个东西是干什么的？"
4. 情绪共鸣: "打工人看完都沉默了..."
5. 结果前置: "最终效果太绝了！"

## 话题标签: 大+中+小话题，共5-8个
## 黄金时段: 早7-9、午12-14、晚18-22
'@

    "wechat-article" = @'
---
name: wechat-article
description: "微信公众号文章写作 - 文章结构、排版规范、阅读转化优化"
metadata: { "openclaw": { "emoji": "💚" } }
---

# 微信公众号文章写作助手

## 排版规范

- 正文字号 15-16px，行间距 1.75-2x
- 正文色 #3f3f3f，强调色 #007AFF
- 每段 3-5 行，每 300 字配一张图
- 标题 30 字以内，前 15 字抓眼球
'@

    "weibo-poster" = @'
---
name: weibo-poster
description: "微博内容创作 - 140字优化、话题热搜、配图描述、发布时机"
metadata: { "openclaw": { "emoji": "🔴" } }
---

# 微博内容创作助手

## 140字技巧: 先写后删，一条一观点，金句收尾
## 配图: 1张突出/3张对比/6张叙述/9张九宫格
## 发布: 工作日午休+下班后，周末上午+晚上
'@

    "xiaohongshu-writer" = @'
---
name: xiaohongshu-writer
description: "小红书笔记写作助手 - 标题优化、emoji策略、话题标签、笔记结构"
metadata: { "openclaw": { "emoji": "📕" } }
---

# 小红书笔记写作助手

## 标题公式

1. 数字法: "5个/10种/100元以内"
2. 反差法: "月薪3千 vs 月薪3万"
3. 测评法: "亲测有效！"
4. 合集法: "XX合集｜一篇搞定"

## 写作要点: 每段≤3行，emoji每段1-2个，标签3-8个
'@

    "zhihu-writer" = @'
---
name: zhihu-writer
description: "知乎回答/文章写作 - 回答结构、专业语气、引用规范"
metadata: { "openclaw": { "emoji": "📝" } }
---

# 知乎回答/文章写作助手

## 回答结构: 先说结论 → 分点论证 → 总结升华
## 风格: 自信不傲慢，专业但易懂，有态度但包容
## 盐值: 500-3000字，原创，回复评论，专注2-3个话题
'@
}

foreach ($skillName in $skills.Keys) {
    $skillDir = "$SKILLS_TARGET\$skillName"
    if (-not (Test-Path $skillDir)) {
        New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
        [IO.File]::WriteAllText("$skillDir\SKILL.md", $skills[$skillName], (New-Object System.Text.UTF8Encoding $false))
        $skillCount++
    }
}

Write-Green "  ✓ 中国技能安装完成 (+$skillCount 个)"
Write-Host ""

# ============================================================
# Step 6: 交互式模型配置
# ============================================================
Write-Host "  [5/7] 配置 AI 模型 ..." -ForegroundColor White
Write-Host ""

$hasConfig = (Test-Path $CONFIG_PATH) -and (Select-String -Path $CONFIG_PATH -Pattern "apiKey" -Quiet -ErrorAction SilentlyContinue)

if ($hasConfig) {
    Write-Green "  ✓ 已有模型配置，跳过"
} else {
    Write-Host "  请选择 AI 模型:" -ForegroundColor White
    Write-Host ""
    Write-Host "  ── 国内推荐（无需翻墙）──" -ForegroundColor White
    Write-Host "  1) DeepSeek      ⭐ 推荐，性价比最高" -ForegroundColor Green
    Write-Host "  2) Kimi/月之暗面"
    Write-Host "  3) 通义千问/阿里"
    Write-Host "  4) 智谱GLM"
    Write-Host "  5) MiniMax"
    Write-Host "  6) 豆包/火山引擎"
    Write-Host "  7) 硅基流动"
    Write-Host ""
    Write-Host "  ── 海外模型 ──" -ForegroundColor White
    Write-Host "  8) Claude    9) GPT"
    Write-Host ""
    Write-Host "  ── 本地 ──" -ForegroundColor White
    Write-Host "  10) Ollama 本地模型"
    Write-Host ""

    $choice = Read-Host "  请输入编号 [1]"
    if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }

    $modelConfigs = @{
        "1"  = @{ model="deepseek-chat"; baseUrl="https://api.deepseek.com/v1"; provider="custom"; label="DeepSeek API Key"; hint="获取: https://platform.deepseek.com/api_keys"; needKey=$true }
        "2"  = @{ model="moonshot-v1-auto"; baseUrl="https://api.moonshot.cn/v1"; provider="custom"; label="Moonshot API Key"; hint="获取: https://platform.moonshot.cn/console/api-keys"; needKey=$true }
        "3"  = @{ model="qwen-plus"; baseUrl="https://dashscope.aliyuncs.com/compatible-mode/v1"; provider="custom"; label="通义千问 API Key"; hint="获取: https://dashscope.console.aliyun.com/apiKey（有免费额度）"; needKey=$true }
        "4"  = @{ model="glm-4-plus"; baseUrl="https://open.bigmodel.cn/api/paas/v4"; provider="custom"; label="智谱 API Key"; hint="获取: https://open.bigmodel.cn/usercenter/apikeys"; needKey=$true }
        "5"  = @{ model="abab6.5s-chat"; baseUrl="https://api.minimax.chat/v1"; provider="custom"; label="MiniMax API Key"; hint="获取: https://platform.minimaxi.com/"; needKey=$true }
        "6"  = @{ model="doubao-pro-256k"; baseUrl="https://ark.cn-beijing.volces.com/api/v3"; provider="custom"; label="火山引擎 API Key"; hint="获取: https://console.volcengine.com/ark"; needKey=$true }
        "7"  = @{ model="deepseek-ai/DeepSeek-V3"; baseUrl="https://api.siliconflow.cn/v1"; provider="custom"; label="硅基流动 API Key"; hint="获取: https://cloud.siliconflow.cn/account/ak"; needKey=$true }
        "8"  = @{ model="claude-sonnet-4-20250514"; baseUrl=""; provider="anthropic"; label="Anthropic API Key"; hint="获取: https://console.anthropic.com/settings/keys（需翻墙）"; needKey=$true }
        "9"  = @{ model="gpt-4o"; baseUrl=""; provider="openai"; label="OpenAI API Key"; hint="获取: https://platform.openai.com/api-keys（需翻墙）"; needKey=$true }
        "10" = @{ model="llama3.2"; baseUrl="http://127.0.0.1:11434/v1"; provider="custom"; label=""; hint="先安装 Ollama (https://ollama.com)，运行: ollama run llama3.2"; needKey=$false }
    }

    $cfg = $modelConfigs[$choice]
    if (-not $cfg) {
        Write-Yellow "  未知选项，使用默认 DeepSeek"
        $cfg = $modelConfigs["1"]
    }

    Write-Host ""
    Write-Cyan "  $($cfg.hint)"
    Write-Host ""

    $apiKey = ""
    if ($cfg.needKey) {
        $apiKey = Read-Host "  请输入 $($cfg.label)"
        if ([string]::IsNullOrEmpty($apiKey)) {
            Write-Yellow "  ⚠ 未输入 API Key，稍后可通过 Config.html 配置"
        }
    }

    # 写配置
    if ($cfg.provider -eq "custom" -and $cfg.baseUrl) {
        $configJson = @"
{
  "gateway": {
    "mode": "local",
    "auth": { "token": "uclaw" }
  },
  "agent": {
    "model": "$($cfg.model)",
    "apiKey": "$apiKey",
    "baseUrl": "$($cfg.baseUrl)"
  }
}
"@
    } else {
        $configJson = @"
{
  "gateway": {
    "mode": "local",
    "auth": { "token": "uclaw" }
  },
  "agent": {
    "model": "$($cfg.model)",
    "apiKey": "$apiKey",
    "provider": "$($cfg.provider)"
  }
}
"@
    }

    [IO.File]::WriteAllText($CONFIG_PATH, $configJson, (New-Object System.Text.UTF8Encoding $false))
    Write-Green "  ✓ 模型配置完成: $($cfg.model)"
}

Write-Host ""

# ============================================================
# Step 7: 生成启动脚本 + 验证 + 摘要
# ============================================================
Write-Host "  [6/7] 生成启动脚本 ..." -ForegroundColor White

$startBat = @'
@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1
title U-Claw

set "DIR=%~dp0"
set "NODE_BIN=%DIR%runtime\node-win-x64\node.exe"
if not exist "%NODE_BIN%" set "NODE_BIN=node"

set "OPENCLAW_MJS=%DIR%core\node_modules\openclaw\openclaw.mjs"
set "OPENCLAW_HOME=%DIR%data"
set "OPENCLAW_STATE_DIR=%DIR%data\.openclaw"
set "OPENCLAW_CONFIG_PATH=%DIR%data\.openclaw\openclaw.json"

REM Find available port
set PORT=18789
:check_port
netstat -an | findstr ":%PORT% " | findstr "LISTENING" >nul 2>&1
if %errorlevel%==0 (
    set /a PORT+=1
    if !PORT! gtr 18799 (echo 没有可用端口 & pause & exit /b 1)
    goto :check_port
)

cd /d "%DIR%core"
start /B "" cmd /c "timeout /t 3 /nobreak >nul && start http://127.0.0.1:!PORT!/#token=uclaw"
"%NODE_BIN%" "%OPENCLAW_MJS%" gateway run --allow-unconfigured --force --port !PORT!
pause
'@

$startBat | Out-File -Encoding ascii "$UCLAW_DIR\start.bat"

Write-Green "  ✓ 启动脚本已生成"
Write-Host ""

# ============================================================
# 验证
# ============================================================
Write-Host "  [7/7] 验证安装 ..." -ForegroundColor White
Write-Host ""

# Node.js
try {
    $nodeVer = & $INSTALL_NODE --version 2>$null
    Write-Green "  [✓] Node.js $nodeVer"
} catch {
    Write-Red "  [✗] Node.js"
}

# OpenClaw
if (Test-Path "$CORE_DIR\node_modules\openclaw\openclaw.mjs") {
    Write-Green "  [✓] OpenClaw 已安装"
} else {
    Write-Red "  [✗] OpenClaw"
}

# QQ 插件
if (Test-Path "$CORE_DIR\node_modules\@sliverp\qqbot") {
    Write-Green "  [✓] QQ 插件"
} else {
    Write-Yellow "  [⚠] QQ 插件（未安装，不影响主功能）"
}

# 技能
$installedSkills = (Get-ChildItem -Directory $SKILLS_TARGET -ErrorAction SilentlyContinue).Count
Write-Green "  [✓] 中国技能 (${installedSkills}个)"

# 配置
if (Test-Path $CONFIG_PATH) {
    Write-Green "  [✓] 配置文件"
} else {
    Write-Yellow "  [⚠] 配置文件（需启动后配置）"
}

Write-Host ""

# ============================================================
# 摘要
# ============================================================
$installSize = "{0:N0} MB" -f ((Get-ChildItem -Recurse $UCLAW_DIR -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)

Write-Host ""
Write-Green "  ╔══════════════════════════════════════════╗"
Write-Green "  ║   ✅ U-Claw 安装成功！                    ║"
Write-Green "  ╚══════════════════════════════════════════╝"
Write-Host ""
Write-Host "  安装位置: $UCLAW_DIR" -ForegroundColor White
Write-Host "  大小:     $installSize" -ForegroundColor White
Write-Host ""
Write-Host "  启动方式:" -ForegroundColor White
Write-Host "    双击 $UCLAW_DIR\start.bat" -ForegroundColor Cyan
Write-Host ""
Write-Host "  打开后:" -ForegroundColor White
Write-Host "    浏览器自动打开 → 开始和 AI 对话" -ForegroundColor White
Write-Host ""
Write-Host "  如需重新配置模型，编辑 $CONFIG_PATH" -ForegroundColor DarkGray
Write-Host "  卸载: 删除 $UCLAW_DIR 文件夹" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  按回车关闭..." -ForegroundColor DarkGray
Read-Host
