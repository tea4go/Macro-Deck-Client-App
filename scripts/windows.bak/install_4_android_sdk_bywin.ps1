param(
  [string]$SdkRoot
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '_common.ps1')

Enable-AutoConfirm

<#
.SYNOPSIS
  在 Windows 上安装/修复 Android SDK，并配置当前会话及用户级环境变量。
.DESCRIPTION
  主要流程：
  1) 定位或自举安装 sdkmanager（cmdline-tools）
  2) 校验 Java 17 环境
  3) 安装 platform-tools / platform / build-tools 等组件
  4) 写入 ANDROID_HOME，并把 platform-tools 加入用户 PATH
.PARAMETER SdkRoot
  优先使用的 SDK 根目录。若为空，将依次回退到 ANDROID_HOME 或默认路径。
#>

<#
.SYNOPSIS
  下载并安装 Android commandline-tools（用于提供 sdkmanager）。
.PARAMETER SdkRootPath
  Android SDK 根目录（会在其下创建 cmdline-tools\latest）。
.OUTPUTS
  [bool] 是否安装成功。
.NOTES
  仅负责把 cmdline-tools 放到 <SdkRootPath>\cmdline-tools\latest，不安装具体 SDK 组件。
#>
function Install-SdkManagerBootstrap {
  param([string]$SdkRootPath)

  $zipName = 'commandlinetools-win-11076708_latest.zip'
  $urls = @(
    "https://mirrors.huaweicloud.com/android/repository/$zipName",
    "https://mirrors.cloud.tencent.com/AndroidSDK/$zipName",
    "https://dl.google.com/android/repository/$zipName"
  )

  # cmdline-tools 的标准目录结构：<SDK>\cmdline-tools\latest\bin\sdkmanager.bat
  New-DirectoryIfMissing (Join-Path $SdkRootPath 'cmdline-tools')

  # 使用临时目录下载/解压，避免污染 SDK 目录；用 guid 避免并发/重入时冲突
  $tmpZip = Join-Path $env:TEMP ("cmdline-tools_{0}.zip" -f ([guid]::NewGuid().ToString('N')))
  $tmpExtract = Join-Path $env:TEMP ("cmdline-tools_extract_{0}" -f ([guid]::NewGuid().ToString('N')))
  New-DirectoryIfMissing $tmpExtract

  try {
    if (-not (Save-WebFile -Urls $urls -OutFile $tmpZip)) {
      Write-Fail "所有镜像源下载失败"
      return $false
    }

    Write-Host "  解压到临时目录 ..." -ForegroundColor Cyan
    try {
      Expand-Archive -LiteralPath $tmpZip -DestinationPath $tmpExtract -Force
    } catch {
      Write-Fail "Expand-Archive 解压失败"
      return $false
    }

    $extracted = Join-Path $tmpExtract 'cmdline-tools'
    if (-not (Test-Path -LiteralPath $extracted)) {
      Write-Fail "解压后未找到 cmdline-tools 目录"
      return $false
    }

    # 统一写入到 latest：如果目录已存在则先清理，确保脚本可重复执行
    $latest = Join-Path $SdkRootPath 'cmdline-tools\latest'
    if (Test-Path -LiteralPath $latest) {
      Remove-Item -LiteralPath $latest -Recurse -Force -ErrorAction SilentlyContinue
    }
    Move-Item -LiteralPath $extracted -Destination $latest -Force

    $sdkmanager = Join-Path $latest 'bin\sdkmanager.bat'
    if (Test-Path -LiteralPath $sdkmanager) {
      Write-Ok "SDKManager 已安装：$sdkmanager"
      return $true
    }
    Write-Fail "安装后仍未找到 SDKManager.bat"
    return $false
  } finally {
    # 保证清理临时文件，即使下载/解压/移动过程中失败也不留下垃圾
    Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue
  }
}

<#
.SYNOPSIS
  打印 sdkmanager 的版本信息（用于快速判断 cmdline-tools 是否可运行）。
.PARAMETER SdkManagerPath
  sdkmanager.bat 的路径。
#>
function Show-SdkManagerVersion([string]$SdkManagerPath) {
  $ver = Invoke-NativeText -FilePath $SdkManagerPath -Arguments @('--version') |
    Where-Object { $_ -match '^[0-9]' } |
    Select-Object -First 1
  if ($ver) {
    Write-Ok "    版本：$ver"
  } else {
    Write-Warn "    无法读取 SDKManager 版本（可能 Java 未就绪，下一步会校验）"
  }
}

<#
.SYNOPSIS
  调用 sdkmanager 安装指定 Android SDK 组件，并自动接受 license。
.DESCRIPTION
  sdkmanager 在 Windows 下与管道/终端交互有兼容性问题，这里通过：
  - 生成大量 y 的临时文件以自动回答 license 提示
  - 使用 cmd.exe /c 执行管道命令，避免 PowerShell 管道行为差异
.PARAMETER SdkManagerPath
  sdkmanager.bat 的路径。
.PARAMETER AndroidHome
  Android SDK 根目录（会传入 --sdk_root=...）。
.PARAMETER Packages
  需要安装的包列表（如 platform-tools、platforms;android-xx）。
.OUTPUTS
  [bool] 是否安装成功。
#>
function Invoke-SdkManager {
  param(
    [string]$SdkManagerPath,
    [string]$AndroidHome,
    [string[]]$Packages
  )
  $sdkRootArg = "--sdk_root=$AndroidHome"
  $pkgArgs = ($Packages | ForEach-Object { '"{0}"' -f $_ }) -join ' '

  $yesFile = Join-Path $env:TEMP ("sdkmanager_yes_{0}.txt" -f ([guid]::NewGuid().ToString('N')))
  (1..2500 | ForEach-Object { 'y' }) | Set-Content -LiteralPath $yesFile -Encoding ASCII
  try {
    $cmd_str = "type `"$yesFile`" 2>nul| `"$SdkManagerPath`" `"$sdkRootArg`" $pkgArgs"
    Write-Host "  运行命令：`"$SdkManagerPath`" `"$sdkRootArg`" $pkgArgs" -ForegroundColor Cyan
    Invoke-NativeStream -Block {& cmd.exe /c $cmd_str }
  } finally {
    Remove-Item -LiteralPath $yesFile -Force -ErrorAction SilentlyContinue
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Fail "Android SDK 组件安装失败"
    return $false
  }
  return $true
}

Write-Host ""
Write-Banner -Title 'Android SDK 自动安装脚本（Windows PowerShell）       ' -Color Cyan -Width 55
Write-Host ""

$sdkRootDefault = $SdkRoot
# 目录优先级：参数 > 环境变量 ANDROID_HOME > 脚本默认路径
if ([string]::IsNullOrWhiteSpace($sdkRootDefault)) { $sdkRootDefault = $env:ANDROID_HOME }
if ([string]::IsNullOrWhiteSpace($sdkRootDefault)) { $sdkRootDefault = 'C:\DevDisk\DevTools\AndroidSDK' }
$sdkRootDefault = $sdkRootDefault.Trim('"')

Write-Host "[1/6] 定位 SDKManager" -ForegroundColor Cyan
$sdkmanager = Find-SdkManager -PreferredRoot $sdkRootDefault
if ($sdkmanager) {
  Write-Ok "SDKManager 已找到：$sdkmanager"
  Show-SdkManagerVersion $sdkmanager
} else {
  # 常见期望路径：<SDK>\cmdline-tools\latest\bin\sdkmanager.bat
  $expected = Join-Path $sdkRootDefault 'cmdline-tools\latest\bin\sdkmanager.bat'
  Write-Warn "SDKManager 未找到：$expected"
  New-DirectoryIfMissing $sdkRootDefault
  if (-not (Install-SdkManagerBootstrap -SdkRootPath $sdkRootDefault)) {
    Write-Fail "命令行工具包下载/安装失败"
    Write-Fail "请手动下载：https://developer.android.com/studio#command-tools"
    exit 1
  }
  $sdkmanager = Find-SdkManager -PreferredRoot $sdkRootDefault
  if (-not $sdkmanager) {
    Write-Fail "安装后仍未找到 sdkmanager.bat"
    exit 1
  }
}

# 通过 sdkmanager 反推真实 SDK 根目录，避免用户传入/环境变量指向错误位置
$androidHome = Get-AndroidHomeFromSdkManager -SdkManagerPath $sdkmanager
Write-Ok "ANDROID_HOME 推导为：$androidHome"
$env:ANDROID_HOME = $androidHome

Write-Host "[2/6] 检查 Java 环境" -ForegroundColor Cyan
if (-not (Assert-Java17)) { exit 1 }

Write-Host "[3/5] 准备安装的 Android SDK 组件" -ForegroundColor Cyan
$api = Get-AndroidSdkApi
$buildToolsVersion = "$api.0.0"
$packages = @(
  'platform-tools',
  "platforms;android-$api",
  "build-tools;$buildToolsVersion"
)
$sdkmanagerOnDisk = Join-Path $androidHome 'cmdline-tools\latest\bin\sdkmanager.bat'
if (-not (Test-Path -LiteralPath $sdkmanagerOnDisk)) {
  # 若当前 SDK 目录里还没有 cmdline-tools，则先让 sdkmanager 自己安装 cmdline-tools;latest
  $packages = @('cmdline-tools;latest') + $packages
}

$latest2 = Join-Path $androidHome 'cmdline-tools\latest-2'
if (Test-Path -LiteralPath $latest2) {
  # 某些历史脚本/手工操作会留下 latest-2，可能干扰 Find-SdkManager/升级逻辑，直接清理
  Write-Warn "检测到遗留目录 cmdline-tools\latest-2，正在清理 ..."
  Remove-Item -LiteralPath $latest2 -Recurse -Force -ErrorAction SilentlyContinue
  Write-Ok "已清理 cmdline-tools\latest-2"
}

foreach ($p in $packages) { Write-Host "    $p" }
Write-Host ""

Write-Host "[4/5] 安装 Android SDK 组件" -ForegroundColor Cyan
if (-not (Invoke-SdkManager -SdkManagerPath $sdkmanager -AndroidHome $androidHome -Packages $packages)) {
  exit 1
}

Write-Host ""
Write-Ok "Android SDK 组件安装完成！"
Write-Host ""

Write-Host "[5/5] 配置环境变量" -ForegroundColor Cyan
$platformTools = Join-Path $androidHome 'platform-tools'

# 写入用户级环境变量（需要新开终端窗口才会影响新的 shell）
if ($androidHome) {
  Set-UserEnvIfChanged -Name 'ANDROID_HOME' -Value $androidHome
} else {
  Write-Warn "未检测到 ANDROID_HOME 版本，跳过 ANDROID_HOME 设置"
}

if (-not (Add-UserPathSegment -Segment $platformTools)) {
  Write-Warn "set PATH = $env:Path;$platformTools (失败)"
}

# 同步到当前会话环境变量，便于脚本后续步骤/当前终端立即可用
$env:ANDROID_HOME = $androidHome
$env:Path = "$platformTools;$env:Path"
Write-Ok "当前 shell 环境变量变更已生效（export）"

Write-Host ""
Write-Banner -Title 'Android SDK 安装 & 配置完成！                         ' -Color Cyan -TitleColor Green -Width 55
Write-Host ""
Write-Host "  注意：写入的用户环境变量需要新开终端窗口才会生效" -ForegroundColor Yellow
Write-Host ""
