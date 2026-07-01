<#
.SYNOPSIS
  只同步版本号，不构建。以 android/app/build.gradle 为源，把 versionCode/versionName
  同步到 iOS 与 Web。
.DESCRIPTION
  版本号唯一权威是 android/app/build.gradle。本脚本读取它并写入：
    - iOS：project.pbxproj 的 CURRENT_PROJECT_VERSION(=versionCode)、
      MARKETING_VERSION(=versionName)
    - Web：4 个 environment*.ts 的 version(=versionName)、versionCode(=versionCode)
  与构建解耦，适合“只想让三端版本对齐、暂不打包”的场景。
  （build_android / build_web 已内置同步，无需再手动跑；本脚本用于单独对齐。）
.EXAMPLE
  .\sync_version_bywin.ps1
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

Write-Banner '同步版本号（build.gradle -> iOS / Web）'
Sync-AppVersion
Write-Host ''
Write-Ok '版本同步完成'
