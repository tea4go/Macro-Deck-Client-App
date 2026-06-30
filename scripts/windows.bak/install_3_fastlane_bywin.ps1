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
    Write-Fail 'No Gemfile containing fastlane was found'
    return $false
  }

  if (-not (Require-Command 'bundle')) {
    Write-Host 'Run scripts\windows.bak\install_2_ruby_bywin.ps1 first.'
    return $false
  }

  $gemfile = Join-Path $bundleRoot 'Gemfile'
  Write-Ok "Using Gemfile: $gemfile"

  if (-not $CheckOnly) {
    $code = Invoke-NativeIn -Path $bundleRoot -Block { & bundle install }
    if ($code -ne 0) {
      Write-Fail 'bundle install failed'
      return $false
    }
  }

  $fastlane = Get-FastlaneCommand
  if ($fastlane) {
    Write-Ok "fastlane command: $($fastlane.Display)"
    return $true
  }

  Write-Fail 'fastlane was not found after bundle install'
  return $false
}

Write-Banner 'Fastlane'

if (-not (Ensure-FastlaneBundle)) { exit 1 }
Write-Ok 'Fastlane is ready'
