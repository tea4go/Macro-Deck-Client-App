<#
.SYNOPSIS
  在 Windows 上构建 Ionic + Capacitor 的 Android 发布产物（release APK/AAB），并完成签名环境校验。
.DESCRIPTION
  主要流程：
  1) 加载 scripts\local\android-signing.ps1 中的本地签名变量（keystore 密码等）
  2) 校验签名环境：未设置的 BUILD_NUMBER/VERSION_NUMBER 自动从 android\app\build.gradle 读取 versionCode/versionName
  3) 用 Ionic production 配置构建 Web 资源，再执行 Capacitor Android sync
  4) 在 android 目录下按 fastlane 官方推荐执行 bundle exec fastlane build 产出 APK/AAB
.PARAMETER Check
  只检查签名变量、npx、fastlane 是否可用，不执行 Web/Android 构建。
.NOTES
  本脚本只负责 Android release 构建；Ruby、fastlane、Android SDK 安装分别由
  install_2_ruby_bywin.ps1、install_3_fastlane_bywin.ps1、install_4_android_sdk_bywin.ps1 处理。
.EXAMPLE
  .\build_android_bywin.ps1 -Check
.EXAMPLE
  .\build_android_bywin.ps1
#>
param(
  [switch]$Check
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

$signingFile = Join-Path $script:RootDir 'scripts\local\android-signing.ps1'
$defaultKeystore = Join-Path $env:USERPROFILE 'keystore\macro-deck-client-keystore.jks'
$defaultAlias = 'macro-deck-client'

<#
.SYNOPSIS
  检查 fastlane 命令是否可用。
.OUTPUTS
  [bool] 可用返回 true；不可用时输出安装提示并返回 false。
.NOTES
  Get-FastlaneCommand 会优先返回 bundle exec fastlane，只有找不到 Bundler/Gemfile 时才回退全局 fastlane。
#>
function Require-Fastlane {
  if (Get-FastlaneCommand) { return $true }

  $hint = @'

Install fastlane before building Android release artifacts.

Recommended on Windows:
  1. Run scripts\windows.bak\install_2_ruby_bywin.ps1
  2. Run scripts\windows.bak\install_3_fastlane_bywin.ps1
  3. Reopen PowerShell if Ruby was just installed

Manual setup:
  1. Install Ruby 3.0+ from https://rubyinstaller.org/
  2. gem install bundler
  3. bundle install
'@
  Write-Fail 'Missing required command: fastlane'
  Write-Host $hint
  return $false
}

<#
.SYNOPSIS
  准备 Android release 构建所需签名环境变量。
.OUTPUTS
  [bool] 所需变量与 keystore 文件齐全返回 true。
.NOTES
  BUILD_NUMBER / VERSION_NUMBER 默认来自 android\app\build.gradle；
  KEYSTORE_FILE_PATH / KEYSTORE_FILE_ALIAS 使用本地默认值；
  KEYSTORE_FILE_PASSWORD 必须由用户在 scripts\local\android-signing.ps1 中提供。
#>
function Require-AndroidReleaseEnv {
  if ([string]::IsNullOrWhiteSpace($env:BUILD_NUMBER)) {
    $env:BUILD_NUMBER = Read-AndroidGradleValue 'versionCode'
  }
  if ([string]::IsNullOrWhiteSpace($env:VERSION_NUMBER)) {
    $env:VERSION_NUMBER = Read-AndroidGradleValue 'versionName'
  }
  if ([string]::IsNullOrWhiteSpace($env:KEYSTORE_FILE_PATH)) {
    $env:KEYSTORE_FILE_PATH = $defaultKeystore
  }
  if ([string]::IsNullOrWhiteSpace($env:KEYSTORE_FILE_ALIAS)) {
    $env:KEYSTORE_FILE_ALIAS = $defaultAlias
  }

  $ok = $true
  foreach ($name in @('BUILD_NUMBER', 'VERSION_NUMBER', 'KEYSTORE_FILE_PASSWORD')) {
    if (-not (Require-Env $name)) { $ok = $false }
  }

  if (-not $ok) {
    Print-AndroidSigningHelp -SigningFile $signingFile -DefaultKeystore $defaultKeystore -DefaultAlias $defaultAlias
    return $false
  }

  if (-not (Test-Path -LiteralPath $env:KEYSTORE_FILE_PATH)) {
    Write-Fail "Keystore file does not exist: $env:KEYSTORE_FILE_PATH"
    Print-AndroidSigningHelp -SigningFile $signingFile -DefaultKeystore $defaultKeystore -DefaultAlias $defaultAlias
    return $false
  }

  return $true
}

Write-Banner 'Build Android release'

Load-AndroidSigningPs1 -FilePath $signingFile

$ready = $true
if (-not (Require-AndroidReleaseEnv)) { $ready = $false }
if (-not (Require-Command 'npx')) { $ready = $false }
if (-not (Require-Fastlane)) { $ready = $false }

if (-not $ready) {
  exit 1
}

Write-Ok "BUILD_NUMBER=$env:BUILD_NUMBER"
Write-Ok "VERSION_NUMBER=$env:VERSION_NUMBER"
Write-Ok "KEYSTORE_FILE_PATH=$env:KEYSTORE_FILE_PATH"
Write-Ok "KEYSTORE_FILE_ALIAS=$env:KEYSTORE_FILE_ALIAS"

if ($Check) {
  Write-Ok 'Android release environment checks passed'
  exit 0
}

Invoke-IonicBuild 'production'
Invoke-CapSync 'android'

$androidDir = Join-Path $script:RootDir 'android'
$fastlane = Get-FastlaneCommand
Write-Host "  $($fastlane.Display) build" -ForegroundColor Cyan
$fastlaneCommand = $fastlane.Command
$fastlaneArguments = @($fastlane.Arguments + @('build'))
$code = Invoke-NativeIn -Path $androidDir -Block { & $fastlaneCommand @fastlaneArguments }
if ($code -ne 0) { exit $code }

Write-Ok "Android release APK: $script:RootDir\android\app\build\outputs\apk\release\app-release.apk"
Write-Ok "Android release AAB: $script:RootDir\android\app\build\outputs\bundle\release\app-release.aab"
exit 0
