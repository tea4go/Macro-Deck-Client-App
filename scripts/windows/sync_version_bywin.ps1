<#
.SYNOPSIS
  同步版本号（可选先设置版本），不构建。以 android/app/build.gradle 为源，
  把 versionCode/versionName 同步到 iOS 与 Web。
.DESCRIPTION
  版本号唯一权威是 android/app/build.gradle。
  - 不带参数：读 build.gradle 现值，同步到 iOS 与 Web。
  - 带 -VersionName / -VersionCode：先写入 build.gradle，再同步（用于手动设定版本）。
  同步目标：
    - iOS：project.pbxproj 的 CURRENT_PROJECT_VERSION(=versionCode)、MARKETING_VERSION(=versionName)
    - Web：4 个 environment*.ts 的 version(=versionName)、versionCode(=versionCode)
  与构建解耦，适合“只想设定/对齐三端版本、暂不打包”的场景。
.PARAMETER VersionName
  要设置的版本名（如 3.1.0）。省略则沿用 build.gradle 现值。
.PARAMETER VersionCode
  要设置的版本号（正整数）。省略则沿用 build.gradle 现值。
.PARAMETER Help
  显示本帮助后退出，不执行任何操作。
.EXAMPLE
  .\sync_version_bywin.ps1
  读 build.gradle 现值同步到 iOS/Web。
.EXAMPLE
  .\sync_version_bywin.ps1 -VersionName 3.1.0 -VersionCode 5
  把版本设为 3.1.0(5) 写回 build.gradle，再同步三端。
.EXAMPLE
  .\sync_version_bywin.ps1 -Help
#>
param(
  [string]$VersionName,
  [int]$VersionCode,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

<#
.SYNOPSIS
  打印脚本用法。
#>
function Write-Usage {
  Write-Host ""
  Write-Banner -Title '同步版本号（build.gradle -> iOS / Web）' -Color Cyan
  Write-Host ""
  Write-Host "用法：" -ForegroundColor Cyan
  Write-Host "  .\sync_version_bywin.ps1                                  读 build.gradle 现值同步到 iOS/Web"
  Write-Host "  .\sync_version_bywin.ps1 -VersionName <名> -VersionCode <号>  设定版本后同步"
  Write-Host "  .\sync_version_bywin.ps1 -Help                            显示本帮助"
  Write-Host ""
  Write-Host "参数：" -ForegroundColor Cyan
  Write-Host "  -VersionName   版本名（如 3.1.0），省略则沿用 build.gradle 现值"
  Write-Host "  -VersionCode   版本号（正整数），省略则沿用 build.gradle 现值"
  Write-Host "  -Help          显示本帮助后退出"
  Write-Host ""
  Write-Host "示例：" -ForegroundColor Cyan
  Write-Host "  .\sync_version_bywin.ps1"
  Write-Host "  .\sync_version_bywin.ps1 -VersionName 3.1.0 -VersionCode 5"
  Write-Host ""
}

if ($Help) {
  Write-Usage
  exit 0
}

Write-Banner '同步版本号（build.gradle -> iOS / Web）'

# 可选：先把传入的版本写回 build.gradle（不传则保持现值）
if ($PSBoundParameters.ContainsKey('VersionName')) {
  if (-not (Set-AndroidGradleValue 'versionName' $VersionName)) { exit 1 }
}
if ($PSBoundParameters.ContainsKey('VersionCode')) {
  if ($VersionCode -lt 1) { Write-Fail "VersionCode 必须为正整数（当前：$VersionCode）"; exit 1 }
  if (-not (Set-AndroidGradleValue 'versionCode' $VersionCode)) { exit 1 }
}

Sync-AppVersion
Write-Host ''
Write-Ok '版本同步完成'
