<#
.SYNOPSIS
  在 Windows 上卸载 Android SDK，并清理相关用户环境变量（install_4 的逆操作）。
.DESCRIPTION
  主要流程：
  1) 展示当前安装状态（SDK 目录组件、ANDROID_HOME、用户 PATH 中的 platform-tools），无内容则提前退出
  2) 结束可能占用 SDK 的进程（adb / Android Studio / Gradle）
  3) 删除 Android SDK 根目录
  4) 从用户环境变量移除 ANDROID_HOME，并清理用户 PATH 中的 platform-tools 段
  5) 输出卸载结束摘要
.PARAMETER SdkRoot
  优先卸载的 SDK 根目录。若为空，将依次回退到 ANDROID_HOME / ANDROID_SDK_ROOT / 项目默认路径。
.PARAMETER Yes
  自动确认（静默模式），跳过卸载前的二次确认。
.NOTES
  本项目（Ionic + Capacitor）不使用 NDK / Rust Android 交叉编译目标，故不涉及其卸载。
#>
param(
  [string]$SdkRoot,

  [Alias('y')]
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$Failed = $false

. (Join-Path $PSScriptRoot '_common.ps1')

if ($Yes) { Enable-AutoConfirm }

<#
.SYNOPSIS
  结束可能占用 Android SDK 的进程（adb / Android Studio / Gradle 等），降低删除失败概率。
.NOTES
  该步骤只用于“删除 SDK 目录”前的清理，失败不会阻止后续尝试。
#>
function Stop-AndroidProcess {
  Write-Warn "正在结束 adb / Android Studio / Gradle 相关进程 ..."
  $names = @('adb', 'studio64', 'studio', 'gradle', 'gradlew', 'fsnotifier')
  foreach ($n in $names) {
    $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
    if (-not $procs) { continue }
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Ok "已结束 $n"
  }
  Start-Sleep -Seconds 1
  Write-Ok "进程清理完成"
}

<#
.SYNOPSIS
  删除 Android SDK 根目录（ANDROID_HOME 指向的目录）。
.PARAMETER SdkPath
  已解析出的 SDK 根目录。
.NOTES
  删除前会先结束占用进程；目录被占用时给出手动删除提示。
#>
function Remove-AndroidSdkDir([string]$SdkPath) {
  Write-Warn "删除 SDK 目录将移除以下组件：cmdline-tools / platform-tools / platforms / build-tools"
  Stop-AndroidProcess
  try {
    Remove-Item -LiteralPath $SdkPath -Recurse -Force -ErrorAction Stop
    Write-Ok "Android SDK 目录已删除：$SdkPath"
  } catch {
    Write-Fail "删除 $SdkPath 失败（可能仍有文件被占用）"
    Write-Fail "请关闭相关程序后手动删除（PowerShell）：Remove-Item -Recurse -Force `"$SdkPath`""
  }
}

<#
.SYNOPSIS
  清理用户级环境变量：移除 ANDROID_HOME，并从用户 PATH 中删除 platform-tools 段。
.NOTES
  仅影响用户环境变量（User scope），需新开终端窗口才会对新会话生效。
#>
function Remove-AndroidEnvVar {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User'))) {
    Write-Warn "用户环境变量 ANDROID_HOME 未设置，跳过"
  } elseif (Set-UserEnv -Name 'ANDROID_HOME' -ValueOrNull $null) {
    Write-Ok "ANDROID_HOME 已从用户环境变量移除"
  } else {
    Write-Fail "移除 ANDROID_HOME 失败"
  }

  $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
  if ([string]::IsNullOrWhiteSpace($userPath)) {
    Write-Warn "用户 PATH 为空，跳过"
  } elseif ($userPath -notmatch 'platform-tools') {
    Write-Warn "用户 PATH 中未发现 platform-tools 段，跳过"
  } else {
    $kept = ($userPath -split ';' | Where-Object { $_ -and ($_ -notmatch 'platform-tools') }) -join ';'
    if (Set-UserEnv -Name 'PATH' -ValueOrNull $kept) {
      Write-Ok "用户 PATH 中的 platform-tools 段已清理"
    } else {
      Write-Fail "清理用户 PATH 失败，请手动到「环境变量」中编辑 PATH"
    }
  }

  Write-Ok "环境变量清理完成（新开终端窗口后生效）"
}

Write-Host ""
Write-Banner -Title 'Android SDK 卸载（Windows PowerShell）' -Color Red
Write-Host ""

# ─── 当前安装状态检测 ────────────────────────────────────────────────────────
Write-Banner -Title '当前安装状态检测' -Color Cyan
$sdk = Resolve-AndroidHome -PreferredRoot $SdkRoot
$envAh = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User')
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
$hasPathSeg = (-not [string]::IsNullOrWhiteSpace($userPath)) -and ($userPath -match 'platform-tools')

Write-Host "[1/2] Android SDK 目录" -ForegroundColor Cyan
if ($sdk) {
  Write-Ok "SDK 根目录：$sdk"
  foreach ($c in @('cmdline-tools', 'platform-tools', 'platforms', 'build-tools')) {
    if (Test-Path -LiteralPath (Join-Path $sdk $c)) { Write-Ok "  $c" } else { Write-Warn "  $c（未装）" }
  }
} else {
  Write-Warn "未检测到 Android SDK 根目录"
}

Write-Host "[2/2] 用户环境变量" -ForegroundColor Cyan
if ($envAh) { Write-Ok "ANDROID_HOME=$envAh" } else { Write-Warn "ANDROID_HOME 未设置" }
if ($hasPathSeg) { Write-Ok "用户 PATH 含 platform-tools 段" } else { Write-Warn "用户 PATH 不含 platform-tools 段" }

if (-not $sdk -and [string]::IsNullOrWhiteSpace($envAh) -and -not $hasPathSeg) {
  Write-Host ""
  Write-Host "  未检测到 install_4_android_sdk_bywin 装过的内容，无需卸载。" -ForegroundColor Green
  exit 0
}

Write-Host ""
if (-not (Confirm-Remove "Android SDK + ANDROID_HOME + 用户 PATH 段")) {
  Write-Warn "已取消卸载"
  exit 0
}
Write-Host ""

# ─── 执行卸载 ────────────────────────────────────────────────────────────────
if ($sdk) { Remove-AndroidSdkDir -SdkPath $sdk } else { Write-Warn "无 SDK 目录可删除，跳过" }
Remove-AndroidEnvVar

# ─── 卸载结束摘要 ────────────────────────────────────────────────────────────
Write-Host ""
Write-Banner -Title '卸载结束摘要' -Color Cyan

$sdkNow = Resolve-AndroidHome -PreferredRoot $SdkRoot
Write-RemovedStatus -Label 'Android SDK ' -NotPresent (-not ($sdkNow -and (Test-Path -LiteralPath $sdkNow))) -Detail $sdkNow

$envAhNow = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User')
Write-RemovedStatus -Label 'ANDROID_HOME' -NotPresent ([string]::IsNullOrWhiteSpace($envAhNow)) -Detail $envAhNow

$userPathNow = [Environment]::GetEnvironmentVariable('PATH', 'User')
$hasPathSegNow = (-not [string]::IsNullOrWhiteSpace($userPathNow)) -and ($userPathNow -match 'platform-tools')
Write-RemovedStatus -Label 'PATH 段     ' -NotPresent (-not $hasPathSegNow)

Write-Host ""
if (-not $Failed) { Write-Host "  卸载完成！" -ForegroundColor Green }
else { Write-Host "  卸载流程已结束，但部分步骤失败或未完成，请查看上方日志手动处理。" -ForegroundColor Yellow }
