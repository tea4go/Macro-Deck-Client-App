<#
.SYNOPSIS
  在 Windows 上检查环境并构建 Ionic Web/PWA、预览构建产物，或启动开发服务器。
.DESCRIPTION
  主要流程：
  - [check] 仅做环境检查（Node.js 版本、npm）
  - [build] npm install（node_modules 缺失时）-> ajv 版本自愈 -> npx ionic build
  - [dev]   npm install（node_modules 缺失时）-> npx ionic serve（热重载）
  - [serve] 用 http-server 静态托管 www\ 构建产物（在 /client/ 路径下还原 baseHref）
.PARAMETER Command
  build=生产构建（产物在 www\），dev=开发服务器（热重载），serve=预览 www\ 产物，check=仅检查环境。
.PARAMETER Configuration
  Angular 构建配置（默认 web_production）。仅 build 命令使用。
  可用值：web_production | production | development。
.PARAMETER Clean
  构建前清除 Angular 构建缓存（.angular\cache）。遇到 TypeScript 编译缓存错误时使用。
.PARAMETER Port
  serve 命令的监听端口（默认 8080）。
.PARAMETER Yes
  自动确认（静默模式）。
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('dev', 'build', 'serve', 'check')]
  [string]$Command,

  [string]$Configuration = 'web_production',

  [switch]$Clean,

  [int]$Port = 8080,

  [Alias('y')]
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$Failed = $false

. (Join-Path $PSScriptRoot '_common.ps1')

if ($Yes) { Enable-AutoConfirm }

# Angular 19 要求 Node ^18.19.1 || ^20.11.1 || >=22
$MIN_NODE_MAJOR = 18

<#
.SYNOPSIS
  检查 Node.js 是否已安装且主版本 >= $MIN_NODE_MAJOR。
.OUTPUTS
  [bool]
#>
function Test-NodeJs {
  $nodeExe = (Get-ExePath 'node.exe'), (Get-ExePath 'node') |
    Where-Object { $_ } | Select-Object -First 1
  if (-not $nodeExe) {
    Write-Fail "未找到 Node.js"
    Write-Fail "请从 https://nodejs.org/ 下载并安装 Node.js 20 LTS 或 22 LTS"
    return $false
  }
  $vLine = (Invoke-NativeText -FilePath $nodeExe -Arguments @('--version') | Select-Object -First 1)
  $m = [regex]::Match($vLine, 'v(\d+)\.')
  if (-not $m.Success) {
    Write-Fail "Node.js 版本无法解析：$vLine"
    return $false
  }
  $major = [int]$m.Groups[1].Value
  if ($major -lt $MIN_NODE_MAJOR) {
    Write-Fail "检测到 Node.js $vLine，但需要 v18.19.1+ / v20.11.1+ / v22+"
    Write-Fail "请从 https://nodejs.org/ 安装 Node.js 20 LTS 或 22 LTS"
    return $false
  }
  Write-Ok "Node.js $vLine 已安装：$nodeExe"
  return $true
}

<#
.SYNOPSIS
  检查 npm 是否可用。
.OUTPUTS
  [bool]
#>
function Test-Npm {
  $npmExe = (Get-ExePath 'npm.cmd'), (Get-ExePath 'npm.exe') |
    Where-Object { $_ } | Select-Object -First 1
  if (-not $npmExe) {
    Write-Fail "未找到 npm（通常随 Node.js 一起安装）"
    return $false
  }
  $v = (Invoke-NativeText -FilePath $npmExe -Arguments @('--version') | Select-Object -First 1)
  Write-Ok "npm $v 已安装：$npmExe"
  return $true
}

<#
.SYNOPSIS
  检查顶层 node_modules/ajv 是否为 v8；若为 v6 则自动修复。
.DESCRIPTION
  Angular 19 + ajv-keywords 需要 ajv ^8。--legacy-peer-deps 有时把 ajv 6 提升到顶层，
  导致 `ionic build` 报 "Cannot find module 'ajv/dist/compile/codegen'"。
.PARAMETER ProjectRoot
  项目根目录。
.OUTPUTS
  [bool] 是否为 v8（修复后）。
#>
function Assert-AjvV8([string]$ProjectRoot) {
  $pkgJson = Join-Path $ProjectRoot 'node_modules\ajv\package.json'
  if (-not (Test-Path -LiteralPath $pkgJson)) {
    # node_modules 不存在或 ajv 尚未安装，npm install 后由 lockfile 自动安装 v8，跳过
    return $true
  }
  $content = Get-Content -LiteralPath $pkgJson -Raw -ErrorAction SilentlyContinue
  $m = [regex]::Match($content, '"version"\s*:\s*"(\d+)\.')
  if (-not $m.Success) {
    Write-Warn "无法解析 ajv 版本，跳过检查"
    return $true
  }
  $major = [int]$m.Groups[1].Value
  if ($major -ge 8) {
    Write-Ok "ajv v$major（已是 v8+）"
    return $true
  }
  # v6 被提升到顶层 —— 自动修复
  Write-Warn "检测到 ajv v$major 被提升到顶层（预期 v8+），正在自动修复 ..."
  Write-Host "  运行命令：npm install ajv@^8.20.0 --legacy-peer-deps" -ForegroundColor Cyan
  Invoke-NativeStreamIn -Path $ProjectRoot -Block { & npm install 'ajv@^8.20.0' --legacy-peer-deps }
  if ($LASTEXITCODE -ne 0) {
    Write-Fail "ajv 修复失败（exit code $LASTEXITCODE）"
    return $false
  }
  Write-Ok "ajv 已修复至 v8+"
  return $true
}

# ─── 无命令时输出用法 ─────────────────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($Command)) {
  Write-Host "用法：$($MyInvocation.MyCommand.Name) <build|dev|serve|check> [-Configuration <config>] [-Clean] [-Port <n>] [-y]" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "  build             构建 Web/PWA 产物（输出到 www\）"
  Write-Host "  dev               启动本地开发服务器（热重载，Ctrl+C 退出）"
  Write-Host "  serve             用 http-server 预览 www\ 构建产物（Ctrl+C 退出）"
  Write-Host "  check             仅检查环境，不执行构建"
  Write-Host "  -Configuration    Angular 构建配置（默认 web_production）"
  Write-Host "                    可选：web_production | production | development"
  Write-Host "  -Clean            构建前清除 Angular 缓存（.angular\cache）"
  Write-Host "                    遇到 TypeScript 编译缓存错误时使用"
  Write-Host "  -Port             serve 命令的监听端口（默认 8080）"
  Write-Host "  -y                自动确认（静默模式）"
  exit 1
}

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

Write-Host ""
Write-Banner -Title 'Web 构建环境检查（PowerShell）' -Color Cyan
Write-Host ""

# ─── [1/2] Node.js ───────────────────────────────────────────────────────────
Write-Host "[1/2] Node.js" -ForegroundColor Cyan
if (-not (Test-NodeJs)) { $Failed = $true }

# ─── [2/2] npm ───────────────────────────────────────────────────────────────
Write-Host "[2/2] npm" -ForegroundColor Cyan
if (-not (Test-Npm)) { $Failed = $true }

Write-Host ""
if ($Failed) {
  Write-Banner -Title '环境检查未通过，请修复以上问题后重试。' -Color Cyan -TitleColor Red
  exit 1
}

if ($Command -eq 'check') {
  Write-Banner -Title '所有检查通过！' -Color Cyan -TitleColor Green
  Write-Host ""
  exit 0
}

# ─── serve：用 http-server 预览 www\ 构建产物 ────────────────────────────────
# 产物里资源是绝对路径 /client/...（web_production 的 baseHref），所以在临时目录
# 用 junction 把 client 指向 www，再以临时目录为根托管，即可还原 /client/ 前缀。
if ($Command -eq 'serve') {
  $wwwDir = Join-Path $projectRoot 'www'
  if (-not (Test-Path -LiteralPath (Join-Path $wwwDir 'index.html'))) {
    Write-Fail "未找到构建产物 www\index.html，请先运行：.\$($MyInvocation.MyCommand.Name) build"
    exit 1
  }

  $serveRoot = Join-Path $env:TEMP ('mdc-serve-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Path $serveRoot -Force | Out-Null
  New-Item -ItemType Junction -Path (Join-Path $serveRoot 'client') -Target $wwwDir | Out-Null

  Write-Banner -Title "预览构建产物（Ctrl+C 退出）" -Color Cyan
  Write-Host ""
  Write-Ok "访问地址：http://localhost:$Port/client/"
  Write-Host "  运行命令：npx http-server <临时目录> -p $Port -c-1" -ForegroundColor Cyan
  Write-Host ""
  try {
    Invoke-NativeStreamIn -Path $projectRoot -Block { & npx -y http-server $serveRoot -p $Port -c-1 }
  }
  finally {
    # Ctrl+C 退出后清理临时目录与 junction（删 junction 不会影响 www 真实内容）
    Remove-Item -LiteralPath $serveRoot -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ""
    Write-Ok "已清理临时托管目录"
  }
  exit 0
}

# ─── 构建准备 ────────────────────────────────────────────────────────────────
Write-Banner -Title '构建准备                                ' -Color Cyan
Write-Host ""

# ─── [准备 1/2] npm 依赖（node_modules 缺失时安装）──────────────────────────
Write-Host "[准备 1/2] npm 依赖" -ForegroundColor Cyan
$didInstall = $false
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'node_modules'))) {
  Write-Warn "node_modules 不存在，正在安装依赖 ..."
  Write-Host "  运行命令：npm install --legacy-peer-deps" -ForegroundColor Cyan
  Invoke-NativeStreamIn -Path $projectRoot -Block { & npm install --legacy-peer-deps }
  if ($LASTEXITCODE -ne 0) { Write-Fail "npm install 失败（exit code $LASTEXITCODE）"; exit 1 }
  Write-Ok "npm install 完成"
  $didInstall = $true
}
else {
  Write-Ok "node_modules 已存在，跳过安装"
}

# ─── [准备 2/2] ajv 版本检查（自动修复 v6 被提升到顶层的问题）───────────────
Write-Host "[准备 2/2] ajv 版本检查" -ForegroundColor Cyan
if (-not (Assert-AjvV8 -ProjectRoot $projectRoot)) { exit 1 }

Write-Host ""
Write-Host "  构建准备完成！" -ForegroundColor Green
Write-Host ""

# ─── dev：启动本地开发服务器 ──────────────────────────────────────────────────
if ($Command -eq 'dev') {
  Write-Banner -Title '启动本地开发服务器（Ctrl+C 退出）' -Color Cyan
  Write-Host ""
  Write-Host "  运行命令：npx ionic serve" -ForegroundColor Cyan
  Write-Host ""
  Invoke-NativeStreamIn -Path $projectRoot -Block { & npx ionic serve }
  exit $LASTEXITCODE
}

# ─── 清除 Angular 构建缓存 ───────────────────────────────────────────────────
# 触发条件：显式 -Clean，或本次刚跑过 npm install（重装后 webpack 缓存里的
# TypeScript 程序状态会过期，导致 "main.ts is missing from the TypeScript
# compilation" 报错，故重装后必须清缓存）。
if ($Clean -or $didInstall) {
  $cacheDir = Join-Path $projectRoot '.angular\cache'
  $reason = if ($didInstall -and -not $Clean) { '（依赖刚重装，需清缓存避免编译报错）' } else { '' }
  Write-Host "[清缓存] 清除 Angular 构建缓存$reason" -ForegroundColor Cyan
  if (Test-Path -LiteralPath $cacheDir) {
    Write-Warn "正在删除 .angular\cache ..."
    Invoke-NativeStreamIn -Path $projectRoot -Block { & npx ng cache clean }
    if ($LASTEXITCODE -ne 0) { Write-Fail "ng cache clean 失败（exit code $LASTEXITCODE）"; exit 1 }
    Write-Ok "Angular 构建缓存已清除"
  }
  else {
    Write-Ok ".angular\cache 不存在，无需清除"
  }
  Write-Host ""
}

# ─── 版本同步：以 build.gradle 为源，写入 environment*.ts，使界面显示与 Android 一致 ───
Write-Host "[版本同步] 从 android/app/build.gradle 同步版本到 Web" -ForegroundColor Cyan
Sync-AppVersion
Write-Host ""

# ─── build：Web/PWA 生产构建 ─────────────────────────────────────────────────
Write-Banner -Title "Web/PWA 构建（-c $Configuration）" -Color Cyan
Write-Host ""
Write-Host "  运行命令：npx ionic build -c $Configuration" -ForegroundColor Cyan
Write-Host ""
Invoke-NativeStreamIn -Path $projectRoot -Block { & npx ionic build -c $Configuration }
$code = $LASTEXITCODE

if ($code -eq 0) {
  $wwwDir = Join-Path $projectRoot 'www'
  Write-Host ""
  Write-Banner -Title '构建成功！' -Color Cyan -TitleColor Green
  Write-Ok "Web 产物目录：$wwwDir"
  if (Test-Path -LiteralPath (Join-Path $wwwDir 'index.html')) {
    Write-Ok "index.html 已生成"
  }
}
else {
  Write-Host ""
  Write-Fail "ionic build 失败（exit code $code）"
  if (-not $Clean) {
    Write-Host "  提示：若报 TypeScript 编译缓存错误，请加 -Clean 参数重试：" -ForegroundColor Yellow
    Write-Host "    .\build_web_bywin.ps1 build -Clean" -ForegroundColor Yellow
  }
}

exit $code
