<#
.SYNOPSIS
  在 Windows 上检测并安装 Ruby + Devkit 与 Bundler（fastlane 的运行环境）。
.DESCRIPTION
  主要流程：
  - fastlane 需要 Ruby 运行环境，RubyInstaller 当前推荐 Ruby+Devkit 4.0.x (x64)
  - 优先检测/安装 Ruby 4.0+；若 winget 暂无 4.0 包，则按 3.4、3.3 顺序降级尝试
  - 安装 Bundler，用于按 Gemfile 固定 fastlane 依赖，避免依赖全局 fastlane
.PARAMETER CheckOnly
  只检查 Ruby/Bundler 状态，不执行安装。
.EXAMPLE
  .\install_2_ruby_bywin.ps1
.EXAMPLE
  .\install_2_ruby_bywin.ps1 -CheckOnly
#>
param(
  [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

<#
.SYNOPSIS
  读取当前 ruby.exe 的语义化版本号。
.OUTPUTS
  [version] Ruby 版本；未找到 ruby 或无法解析时返回 null。
#>
function Get-RubyVersion {
  if (-not (Get-CommandPath 'ruby')) { return $null }
  $line = & ruby -v
  if ($line -match 'ruby\s+(\d+)\.(\d+)\.(\d+)') {
    return [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])"
  }
  return $null
}

<#
.SYNOPSIS
  确保 Ruby+Devkit 可用。
.OUTPUTS
  [bool] Ruby 满足要求或安装流程已启动成功返回 true。
.NOTES
  RubyInstaller 推荐 4.0.x；fastlane 官方要求 Ruby 3.0+，因此 3.4/3.3 仅作为 winget 降级兜底。
#>
function Ensure-Ruby {
  $version = Get-RubyVersion
  if ($version -and $version -ge [version]'4.0.0') {
    Write-Ok "Ruby $version"
    return $true
  }

  if ($version) {
    Write-Warn "Ruby $version was found; RubyInstaller recommends Ruby+Devkit 4.0.x (x64)"
  } else {
    Write-Warn 'Ruby was not found'
  }

  if ($CheckOnly) { return $false }

  $packages = @(
    @{ Id = 'RubyInstallerTeam.RubyWithDevKit.4.0'; Name = 'Ruby with DevKit 4.0' },
    @{ Id = 'RubyInstallerTeam.RubyWithDevKit.3.4'; Name = 'Ruby with DevKit 3.4' },
    @{ Id = 'RubyInstallerTeam.RubyWithDevKit.3.3'; Name = 'Ruby with DevKit 3.3' }
  )

  foreach ($pkg in $packages) {
    if (Install-WingetPackage -Id $pkg.Id -Name $pkg.Name) {
      Write-Warn 'If ruby is still unavailable, reopen PowerShell and rerun this script.'
      return $true
    }
    Write-Warn "$($pkg.Name) was not installed; trying next RubyInstaller package."
  }

  Write-Host ''
  Write-Host 'Manual install: https://rubyinstaller.org/downloads/'
  return $false
}

<#
.SYNOPSIS
  确保 Bundler 可用。
.OUTPUTS
  [bool] bundle 命令可用返回 true。
.NOTES
  后续 install_3_fastlane_bywin.ps1 会通过 bundle install 安装 Gemfile 中的 fastlane。
#>
function Ensure-Bundler {
  if (Get-CommandPath 'bundle') {
    Write-Ok 'Bundler is installed'
    return $true
  }

  if ($CheckOnly) {
    Write-Warn 'Bundler was not found'
    return $false
  }

  if (-not (Require-Command 'gem')) { return $false }
  Invoke-Checked -Display 'gem install bundler' -Block { & gem install bundler }
  return (Require-Command 'bundle')
}

Write-Banner 'Ruby and Bundler'

$ready = $true
if (-not (Ensure-Ruby)) { $ready = $false }
if ($ready -and -not (Ensure-Bundler)) { $ready = $false }

if (-not $ready) { exit 1 }
Write-Ok 'Ruby and Bundler are ready'
