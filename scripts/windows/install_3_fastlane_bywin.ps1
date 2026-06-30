<#
.SYNOPSIS
  在 Windows 上通过 Bundler 安装并检查 fastlane（基于仓库 Gemfile）。
.DESCRIPTION
  主要流程：
  - fastlane 官方 Android setup 推荐用 Gemfile + Bundler 管理 fastlane
  - 本仓库根目录 Gemfile 已声明 fastlane，这里执行 bundle install
  - 安装完成后，构建脚本通过 bundle exec fastlane build 调用
.PARAMETER CheckOnly
  只检查 Gemfile/Bundler/fastlane 命令解析，不执行 bundle install。
.EXAMPLE
  .\install_3_fastlane_bywin.ps1
.EXAMPLE
  .\install_3_fastlane_bywin.ps1 -CheckOnly
#>
param(
  [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

<#
.SYNOPSIS
  从注册表重新读取 机器级 + 用户级 PATH，合并注入当前 PowerShell 会话。
.NOTES
  install_2 刚装完的 Ruby/Bundler 把 ruby\bin 写入用户 PATH（注册表），但当前会话的
  $env:Path 是进程启动时的快照、不会自动刷新。调用本函数后，bundle 等命令即可在
  当前会话被 Get-Command 发现，无需重开窗口。
#>
function Sync-PathFromRegistry {
  $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $merged = @($machinePath, $userPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ';'
  if (-not [string]::IsNullOrWhiteSpace($merged)) {
    $env:Path = $merged
  }
}

<#
.SYNOPSIS
  确保 Gemfile 中声明的 fastlane 可通过 Bundler 使用。
.OUTPUTS
  [bool] fastlane 可解析返回 true。
.NOTES
  Get-FastlaneBundleRoot 会优先查找 android\Gemfile，再查找仓库根 Gemfile；
  只有包含 gem 'fastlane' 的 Gemfile 会被采用。
#>
function Ensure-FastlaneBundle {
  $bundleRoot = Get-FastlaneBundleRoot
  if ([string]::IsNullOrWhiteSpace($bundleRoot)) {
    Write-Fail '未找到声明 fastlane 的 Gemfile'
    return $false
  }

  # bundle 由 install_2 安装；若刚在同一会话装完，PATH 可能尚未刷新，先从注册表重读再判断。
  if (-not (Get-CommandPath 'bundle')) {
    Sync-PathFromRegistry
  }
  if (-not (Require-Command 'bundle')) {
    Write-Host '请先运行 scripts\windows\install_2_ruby_bywin.ps1 安装 Ruby 与 Bundler。'
    Write-Host '若刚安装完，请关闭并重新打开 PowerShell 后再运行本脚本。'
    return $false
  }

  $gemfile = Join-Path $bundleRoot 'Gemfile'
  Write-Ok "使用 Gemfile：$gemfile"

  if (-not $CheckOnly) {
    $code = Invoke-NativeIn -Path $bundleRoot -Block { & bundle install }
    if ($code -ne 0) {
      Write-Fail 'bundle install 执行失败'
      return $false
    }
  }

  $fastlane = Get-FastlaneCommand
  if ($fastlane) {
    Write-Ok "fastlane 命令：$($fastlane.Display)"
    return $true
  }

  Write-Fail 'bundle install 之后仍未找到 fastlane'
  return $false
}

Write-Banner 'Fastlane'

if (-not (Ensure-FastlaneBundle)) { exit 1 }
Write-Ok 'fastlane 已就绪'
