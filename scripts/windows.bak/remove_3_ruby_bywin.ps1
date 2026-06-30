<#
.SYNOPSIS
  在 Windows 上卸载 Ruby + Devkit（含 Bundler 与全部 gem，install_2 的逆操作）。
.DESCRIPTION
  主要流程：
  1) 检测 Ruby / Bundler 当前状态，未安装则提前退出
  2) 通过 winget 卸载 RubyInstaller 的 Ruby+Devkit 包（按 4.0 / 3.4 / 3.3 依次检测）
  3) 输出卸载结束摘要
.PARAMETER Yes
  自动确认（静默模式），跳过卸载前的二次确认。
.NOTES
  - 卸载 Ruby 会一并移除其下所有 gem（包括 Bundler 与 fastlane），并影响系统中其它 Ruby 项目，请确认后再执行。
  - 仅卸载经 winget（install_2）安装的 RubyInstaller 包；手动安装的 Ruby 需自行卸载。
  - winget 对 PATH 的改动需新开终端窗口才会对新会话生效。
#>
param(
  [Alias('y')]
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$Failed = $false

. (Join-Path $PSScriptRoot '_common.ps1')

if ($Yes) { Enable-AutoConfirm }

# install_2 用过的 RubyInstaller winget 包 Id（与安装顺序一致）
$RubyWingetIds = @(
  'RubyInstallerTeam.RubyWithDevKit.4.0',
  'RubyInstallerTeam.RubyWithDevKit.3.4',
  'RubyInstallerTeam.RubyWithDevKit.3.3'
)

<#
.SYNOPSIS
  检测指定 winget 包 Id 是否已安装。
.PARAMETER Id
  winget 包 Id。
.OUTPUTS
  [bool] 已安装返回 true。
#>
function Test-WingetInstalled([string]$Id) {
  if (-not (Get-ExePath 'winget.exe')) { return $false }
  $out = & winget list --id $Id --exact --accept-source-agreements 2>$null | Out-String
  return ($out -match [regex]::Escape($Id))
}

Write-Host ""
Write-Banner -Title 'Ruby 卸载（Windows PowerShell）' -Color Red
Write-Host ""

# ─── 当前安装状态检测 ────────────────────────────────────────────────────────
Write-Banner -Title '当前安装状态检测' -Color Cyan

$rubyExe = Get-ExePath 'ruby'
$bundleExe = Get-ExePath 'bundle'
Write-Host "[1/2] Ruby / Bundler" -ForegroundColor Cyan
if ($rubyExe) {
  $rubyVer = & ruby -v 2>$null
  Write-Ok "Ruby：$rubyExe（$rubyVer）"
} else {
  Write-Warn "未检测到 ruby"
}
if ($bundleExe) { Write-Ok "Bundler：$bundleExe" } else { Write-Warn "未检测到 bundle" }

Write-Host "[2/2] winget 安装包" -ForegroundColor Cyan
$installedIds = @()
if (Get-ExePath 'winget.exe') {
  foreach ($id in $RubyWingetIds) {
    if (Test-WingetInstalled $id) { Write-Ok "  $id"; $installedIds += $id } else { Write-Warn "  $id（未装）" }
  }
} else {
  Write-Warn "未检测到 winget，无法自动卸载 RubyInstaller 包"
}

if (-not $rubyExe -and $installedIds.Count -eq 0) {
  Write-Host ""
  Write-Host "  未检测到 install_2_ruby_bywin 装过的 Ruby，无需卸载。" -ForegroundColor Green
  exit 0
}

Write-Host ""
if (-not (Confirm-Remove "Ruby + Devkit（含 Bundler 与全部 gem，包括 fastlane）")) {
  Write-Warn "已取消卸载"
  exit 0
}
Write-Host ""

# ─── 执行卸载 ────────────────────────────────────────────────────────────────
if (-not (Get-ExePath 'winget.exe')) {
  Write-Fail "缺少 winget，无法自动卸载 Ruby"
  Write-Fail "请到「设置 → 应用」或控制面板手动卸载 Ruby+Devkit。"
} elseif ($installedIds.Count -eq 0) {
  Write-Warn "winget 中未发现 RubyInstaller 包；若 Ruby 为手动安装，请自行卸载。"
} else {
  foreach ($id in $installedIds) {
    Write-Host "  运行命令：winget uninstall --id $id --exact --silent" -ForegroundColor Cyan
    Invoke-NativeStream -Block { & winget uninstall --id $id --exact --silent --accept-source-agreements }
    if ($LASTEXITCODE -eq 0) { Write-Ok "已卸载 $id" } else { Write-Fail "winget uninstall $id 失败（exit code $LASTEXITCODE）" }
  }
}

# ─── 卸载结束摘要 ────────────────────────────────────────────────────────────
Write-Host ""
Write-Banner -Title '卸载结束摘要' -Color Cyan
Write-RemovedStatus -Label 'ruby   ' -NotPresent (-not (Get-ExePath 'ruby'))
Write-RemovedStatus -Label 'bundle ' -NotPresent (-not (Get-ExePath 'bundle'))

$remainIds = @()
foreach ($id in $RubyWingetIds) { if (Test-WingetInstalled $id) { $remainIds += $id } }
Write-RemovedStatus -Label 'winget 包' -NotPresent ($remainIds.Count -eq 0) -NotOkText "仍存在 $($remainIds -join ', ')"

Write-Host ""
Write-Warn "若上面 ruby/bundle 仍显示存在，多为当前会话 PATH 缓存，新开终端窗口即可。"
if (-not $Failed) { Write-Host "  卸载完成！" -ForegroundColor Green }
else { Write-Host "  卸载流程已结束，但部分步骤失败或未完成，请查看上方日志手动处理。" -ForegroundColor Yellow }
