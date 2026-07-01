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

构建 Android release 产物前，请先安装 fastlane。

Windows 推荐方式：
  1. 运行 scripts\windows.bak\install_2_ruby_bywin.ps1
  2. 运行 scripts\windows.bak\install_3_fastlane_bywin.ps1
  3. 如果刚安装了 Ruby，请重新打开 PowerShell

手动安装：
  1. 从 https://rubyinstaller.org/ 安装 Ruby 3.0+
  2. gem install bundler
  3. bundle install
'@
  Write-Fail '缺少必需命令: fastlane'
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
    # 未显式指定 BUILD_NUMBER 时，读 build.gradle 当前 versionCode 再 +1 自动递增。
    # （versionCode 每次发布必须递增；fastlane 随后会把新值写回 build.gradle 持久化。）
    $currentCode = Read-AndroidGradleValue 'versionCode'
    $parsed = 0
    if ([int]::TryParse($currentCode, [ref]$parsed)) {
      $env:BUILD_NUMBER = ($parsed + 1).ToString()
      Write-Ok "versionCode 自动递增：$currentCode -> $env:BUILD_NUMBER"
    } else {
      Write-Warn "无法解析当前 versionCode（'$currentCode'），BUILD_NUMBER 回退为 1"
      $env:BUILD_NUMBER = '1'
    }
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
    Write-Fail "Keystore 文件不存在: $env:KEYSTORE_FILE_PATH"
    Print-AndroidSigningHelp -SigningFile $signingFile -DefaultKeystore $defaultKeystore -DefaultAlias $defaultAlias
    return $false
  }

  return $true
}

Write-Banner '构建 Android release'

Load-AndroidSigningPs1 -FilePath $signingFile

$ready = $true
if (-not (Assert-JavaForAndroid)) { $ready = $false }
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
  Write-Ok 'Android release 环境检查通过'
  exit 0
}

Invoke-IonicBuild 'production'
Invoke-CapSync 'android'

$androidDir = Join-Path $script:RootDir 'android'
$fastlane = Get-FastlaneCommand
Write-Host "  $($fastlane.Display) 构建" -ForegroundColor Cyan
$fastlaneCommand = $fastlane.Command
$fastlaneArguments = @($fastlane.Arguments + @('build'))
$code = Invoke-NativeIn -Path $androidDir -Block { & $fastlaneCommand @fastlaneArguments }
if ($code -ne 0) { exit $code }

# fastlane 已把（自增后的）versionCode/versionName 写回 build.gradle，
# 以它为源同步到 iOS 与 Web，保持三端版本一致。
Sync-AppVersion

$outName = "MacroDeckClient-$env:VERSION_NUMBER-$env:BUILD_NUMBER"
Write-Ok "Android release APK 产物: $script:RootDir\android\app\build\outputs\apk\release\$outName.apk"
Write-Ok "Android release AAB 产物: $script:RootDir\android\app\build\outputs\bundle\release\$outName.aab"
exit 0
