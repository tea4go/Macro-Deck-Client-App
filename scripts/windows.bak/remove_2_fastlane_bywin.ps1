<#
.SYNOPSIS
  在 Windows 上卸载 fastlane gem（install_3 的逆操作）。
.DESCRIPTION
  主要流程：
  1) 检测 gem / fastlane 是否可用，未安装则提前退出
  2) 通过 gem uninstall 卸载 fastlane 及其可执行文件（全部版本）
  3) 输出卸载结束摘要
.PARAMETER Yes
  自动确认（静默模式），跳过卸载前的二次确认。
.NOTES
  - fastlane 由 install_3 经 bundle install 安装为全局 gem，这里用 gem uninstall 卸载。
  - bundle install 顺带安装的依赖 gem 不在此处单独清理；执行 remove_3_ruby 卸载 Ruby
    时会随 Ruby 一并移除。
  - 若 Ruby 已先被卸载（gem 不可用），本脚本无事可做并直接退出。
#>
param(
  [Alias('y')]
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$Failed = $false

. (Join-Path $PSScriptRoot '_common.ps1')

if ($Yes) { Enable-AutoConfirm }

<#
.SYNOPSIS
  检测 fastlane gem 是否已安装。
.OUTPUTS
  [bool] 已安装返回 true。
.NOTES
  使用 gem list -i 精确匹配 ^fastlane$，输出 true/false。
#>
function Test-FastlaneGem {
  if (-not (Get-ExePath 'gem')) { return $false }
  $probe = & gem list -i '^fastlane$' 2>$null
  return ("$probe".Trim() -eq 'true')
}

Write-Host ""
Write-Banner -Title 'fastlane 卸载（Windows PowerShell）' -Color Red
Write-Host ""

# ─── 当前安装状态检测 ────────────────────────────────────────────────────────
Write-Banner -Title '当前安装状态检测' -Color Cyan
if (-not (Get-ExePath 'gem')) {
  Write-Warn "未检测到 gem（Ruby 可能已卸载）"
  Write-Host ""
  Write-Host "  无 Ruby/gem 环境，fastlane 无需单独卸载。" -ForegroundColor Green
  exit 0
}

$fastlane = Get-FastlaneCommand
if ($fastlane) { Write-Ok "fastlane 调用方式：$($fastlane.Display)" } else { Write-Warn "未解析到 fastlane 调用方式" }

if (-not (Test-FastlaneGem)) {
  Write-Warn "未检测到已安装的 fastlane gem"
  Write-Host ""
  Write-Host "  未检测到 install_3_fastlane_bywin 装过的 fastlane gem，无需卸载。" -ForegroundColor Green
  exit 0
}
Write-Ok "fastlane gem 已安装"

Write-Host ""
if (-not (Confirm-Remove "fastlane gem（全部版本及其可执行文件）")) {
  Write-Warn "已取消卸载"
  exit 0
}
Write-Host ""

# ─── 执行卸载 ────────────────────────────────────────────────────────────────
Write-Host "  运行命令：gem uninstall fastlane --all --ignore-dependencies --executables" -ForegroundColor Cyan
Invoke-NativeStream -Block { & gem uninstall fastlane --all --ignore-dependencies --executables }
if ($LASTEXITCODE -eq 0) { Write-Ok "fastlane gem 已卸载" } else { Write-Fail "gem uninstall fastlane 失败（exit code $LASTEXITCODE）" }

# ─── 卸载结束摘要 ────────────────────────────────────────────────────────────
Write-Host ""
Write-Banner -Title '卸载结束摘要' -Color Cyan
Write-RemovedStatus -Label 'fastlane gem' -NotPresent (-not (Test-FastlaneGem))

Write-Host ""
if (-not $Failed) { Write-Host "  卸载完成！" -ForegroundColor Green }
else { Write-Host "  卸载流程已结束，但部分步骤失败或未完成，请查看上方日志手动处理。" -ForegroundColor Yellow }
