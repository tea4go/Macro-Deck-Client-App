<#
.SYNOPSIS
  在 Windows 上检测并安装 Ruby + Devkit 与 Bundler（fastlane 的运行环境）。
.DESCRIPTION
  主要流程：
  - fastlane 需要 Ruby 运行环境，RubyInstaller 当前推荐 Ruby+Devkit 4.0.x (x64)
  - 从国内 GitHub 镜像（gh-proxy / ghfast）直链下载 RubyInstaller-DevKit 并静默安装，
    绕开 winget——winget 仅镜像清单索引，安装包本体仍直连 github.com 导致国内下载慢/失败
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
  [bool] Ruby 满足要求或安装流程已完成返回 true。
.NOTES
  改用国内 GitHub 镜像直链下载 RubyInstaller-DevKit 并静默安装，
  绕开 winget——因为 winget 仅镜像清单索引，安装包本体仍直连 github.com。
  RubyInstaller 推荐 4.0.x；fastlane 官方要求 Ruby 3.0+。
#>
function Ensure-Ruby {
  $version = Get-RubyVersion
  if ($version -and $version -ge [version]'4.0.0') {
    Write-Ok "Ruby $version"
    return $true
  }

  if ($version) {
    Write-Warn "检测到 Ruby $version；RubyInstaller 推荐使用 Ruby+Devkit 4.0.x (x64)"
  } else {
    Write-Warn '未检测到 Ruby'
  }

  if ($CheckOnly) { return $false }

  # 要安装的 RubyInstaller-DevKit 版本（含 -N 构建号）。
  # 升级版本时改这里即可；文件名与 release tag 均由此派生。
  $rubyTag = 'RubyInstaller-4.0.5-1'
  $rubyFile = 'rubyinstaller-devkit-4.0.5-1-x64.exe'
  $relPath = "oneclick/rubyinstaller2/releases/download/$rubyTag/$rubyFile"

  # 多个下载源并行竞速：优先国内 GitHub 代理，github.com 原站兜底。
  $urls = @(
    "https://gh-proxy.com/https://github.com/$relPath",
    "https://ghfast.top/https://github.com/$relPath",
    "https://github.com/$relPath"
  )
  # 固定版本兜底
  $fixedUrl = 'http://nj.yj2025.icu:23432/update/winapp/rubyinstaller-devkit-4.0.5-1-x64.exe'
  $urls += $fixedUrl

  $installer = Join-Path $env:TEMP $rubyFile
  Write-Host "  从镜像下载 RubyInstaller-DevKit（$rubyTag）..." -ForegroundColor Cyan
  # MinSizeKB 防止代理返回错误页面被当作有效安装包（真实安装包约 140 MB）
  if (-not (Save-WebFile -Urls $urls -OutFile $installer -TimeoutSec 600 -MinSizeKB 51200)) {
    Write-Fail 'RubyInstaller 下载失败'
    Write-Host ''
    Write-Host '手动安装地址：https://rubyinstaller.org/downloads/'
    return $false
  }

  # 静默安装（Inno Setup 参数）：
  #   /VERYSILENT /NORESTART /SUPPRESSMSGBOXES 全静默
  #   /TASKS=defaultutf8,modpath  启用 UTF-8 并把 Ruby 加入用户 PATH
  Write-Host '  静默安装 RubyInstaller-DevKit ...' -ForegroundColor Cyan
  $proc = Start-Process -FilePath $installer `
    -ArgumentList '/VERYSILENT', '/NORESTART', '/SUPPRESSMSGBOXES', '/TASKS=defaultutf8,modpath' `
    -Wait -PassThru
  Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue

  if ($proc.ExitCode -ne 0) {
    Write-Fail "RubyInstaller 安装失败（exit code $($proc.ExitCode)）"
    return $false
  }

  Write-Ok 'RubyInstaller-DevKit 安装完成'
  Write-Warn '安装器已将 Ruby 写入用户 PATH；如当前窗口仍找不到 ruby，请重新打开 PowerShell 后再运行本脚本。'
  return $true
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
    Write-Ok 'Bundler 已安装'
    return $true
  }

  if ($CheckOnly) {
    Write-Warn '未检测到 Bundler'
    return $false
  }

  if (-not (Require-Command 'gem')) { return $false }
  Invoke-Checked -Display 'gem install bundler' -Block { & gem install bundler }
  return (Require-Command 'bundle')
}

Write-Banner 'Ruby 与 Bundler'

$ready = $true
if (-not (Ensure-Ruby)) { $ready = $false }
if ($ready -and -not (Ensure-Bundler)) { $ready = $false }

if (-not $ready) { exit 1 }
Write-Ok 'Ruby 与 Bundler 已就绪'
