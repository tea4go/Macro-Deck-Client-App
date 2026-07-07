<#
.SYNOPSIS
  在 Windows 上构建 Ionic + Capacitor 的 Android 发布产物（release APK/AAB），并完成签名环境校验。
.DESCRIPTION
  主要流程：
  1) 加载 scripts\local\android-signing.ps1 中的本地签名变量（keystore 密码等）
  2) 校验签名环境：未设置的 BUILD_NUMBER/VERSION_NUMBER 自动从 android\app\build.gradle 读取 versionCode/versionName
  3) 用 Ionic production 配置构建 Web 资源，再执行 Capacitor Android sync
  4) 在 android 目录下按 fastlane 官方推荐执行 bundle exec fastlane build 产出 APK/AAB
.PARAMETER Build
  构建 release APK/AAB（不发布）。versionCode 自动递增。
.PARAMETER Check
  只检查签名变量、npx、fastlane 是否可用，不执行 Web/Android 构建。
.PARAMETER Publish
  仅发布：跳过构建，直接把已有 APK+AAB 发布到 Release。
  配合 -Platform 指定发布平台（github/gitee，默认 github）。
  版本号从 build.gradle 读取（不递增），release 说明取自 RELEASE_NOTES.md。
  如需先构建再发布，请先 -Build 构建，再单独 -Publish 发布。
.PARAMETER Platform
  发布平台，仅与 -Publish 搭配使用。可选值：github（默认）、gitee。
  - github：需已安装并登录 gh CLI
  - gitee：需在 scripts\local\android-signing.ps1 中设置 GITEE_TOKEN 环境变量
.PARAMETER Help
  显示本帮助（参数说明与用法示例）后退出，不执行任何构建。
.NOTES
  本脚本只负责 Android release 构建；Ruby、fastlane、Android SDK 安装分别由
  install_2_ruby_bywin.ps1、install_3_fastlane_bywin.ps1、install_4_android_sdk_bywin.ps1 处理。
  不带任何参数运行时，默认显示本帮助。
.EXAMPLE
  .\build_android_bywin.ps1 -Build
.EXAMPLE
  .\build_android_bywin.ps1 -Check
.EXAMPLE
  .\build_android_bywin.ps1 -Publish
.EXAMPLE
  .\build_android_bywin.ps1 -Publish -Platform gitee
.EXAMPLE
  .\build_android_bywin.ps1 -Help
#>
param(
  [switch]$Build,
  [switch]$Check,
  [switch]$Publish,
  [ValidateSet('github', 'gitee')]
  [string]$Platform = 'github',
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
  Write-Banner -Title 'Android release 构建（Windows）' -Color Cyan
  Write-Host ""
  Write-Host "用法：" -ForegroundColor Cyan
  Write-Host "  .\build_android_bywin.ps1 -Build                    构建 release APK/AAB（不发布）"
  Write-Host "  .\build_android_bywin.ps1 -Check                    只检查构建环境，不构建"
  Write-Host "  .\build_android_bywin.ps1 -Publish                  发布到 GitHub Release（默认）"
  Write-Host "  .\build_android_bywin.ps1 -Publish -Platform gitee  发布到 Gitee Release"
  Write-Host "  .\build_android_bywin.ps1 -Help                     显示本帮助"
  Write-Host ""
  Write-Host "参数：" -ForegroundColor Cyan
  Write-Host "  -Build     构建 release APK/AAB（不发布），versionCode 自动递增"
  Write-Host "  -Check     只检查签名变量、npx、fastlane、JDK 是否就绪，不执行构建"
  Write-Host "  -Publish   跳过构建，直接把已有 APK+AAB 发布到 Release"
  Write-Host "             (版本号从 build.gradle 读取，不递增；tag = v<versionName>+<versionCode>)"
  Write-Host "             (说明取自 RELEASE_NOTES.md)"
  Write-Host "  -Platform  发布平台（仅与 -Publish 搭配），可选：github（默认）、gitee"
  Write-Host "             - github：需已安装并登录 gh CLI"
  Write-Host "             - gitee：需在 android-signing.ps1 中设置 `$env:GITEE_TOKEN"
  Write-Host "  -Help      显示本帮助后退出"
  Write-Host ""
  Write-Host "不带参数运行时显示本帮助。" -ForegroundColor Yellow
  Write-Host ""
}

# -Help 或无参数：显示用法后退出
if ($Help -or (-not $Build -and -not $Check -and -not $Publish)) {
  Write-Usage
  exit 0
}

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
  # 版本号始终以 build.gradle 为准（忽略会话中可能残留的 $env:BUILD_NUMBER/VERSION_NUMBER，
  # 避免旧值覆盖）。versionCode 读当前值 +1 自动递增；versionName 用当前值。
  # 需手动设定版本时用 sync_version_bywin.ps1 -VersionName/-VersionCode 改 build.gradle。
  $currentCode = Read-AndroidGradleValue 'versionCode'
  $parsed = 0
  if ([int]::TryParse($currentCode, [ref]$parsed)) {
    $env:BUILD_NUMBER = ($parsed + 1).ToString()
    Write-Ok "versionCode 自动递增：$currentCode -> $env:BUILD_NUMBER"
  } else {
    Write-Warn "无法解析当前 versionCode（'$currentCode'），BUILD_NUMBER 回退为 1"
    $env:BUILD_NUMBER = '1'
  }
  $env:VERSION_NUMBER = Read-AndroidGradleValue 'versionName'

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

# ─── 仅发布模式：跳过构建，直接发布已有产物 ─────────────────────────────────
if ($Publish) {
  # 加载本地签名配置（包含 GITEE_TOKEN 等敏感凭据）
  Load-AndroidSigningPs1 -FilePath $signingFile

  $platformLabel = if ($Platform -eq 'gitee') { 'Gitee' } else { 'GitHub' }
  Write-Banner "发布到 $platformLabel Release（跳过构建）"

  # 从 build.gradle 读取版本号（不递增，沿用上次构建后的值）
  $env:BUILD_NUMBER = Read-AndroidGradleValue 'versionCode'
  $env:VERSION_NUMBER = Read-AndroidGradleValue 'versionName'
  if ([string]::IsNullOrWhiteSpace($env:BUILD_NUMBER) -or [string]::IsNullOrWhiteSpace($env:VERSION_NUMBER)) {
    Write-Fail '无法从 build.gradle 读取版本号，请先执行一次构建'
    exit 1
  }
  Write-Ok "BUILD_NUMBER=$env:BUILD_NUMBER"
  Write-Ok "VERSION_NUMBER=$env:VERSION_NUMBER"

  $outName = "MacroDeckClient-$env:VERSION_NUMBER-$env:BUILD_NUMBER"
  $apkPath = Join-Path $script:RootDir "android\app\build\outputs\apk\release\$outName.apk"
  $aabPath = Join-Path $script:RootDir "android\app\build\outputs\bundle\release\$outName.aab"

  # 检查产物与说明文件齐全
  $notesFile = Join-Path $script:RootDir 'RELEASE_NOTES.md'
  if (-not (Test-Path -LiteralPath $notesFile)) {
    Write-Fail "未找到更新说明文件：$notesFile（请先编辑它作为 release 说明）"
    exit 1
  }
  foreach ($f in @($apkPath, $aabPath)) {
    if (-not (Test-Path -LiteralPath $f)) {
      Write-Fail "产物不存在，无法发布：$f"
      Write-Fail '请先 -Build 执行一次完整构建'
      exit 1
    }
  }

  $tag = "v$env:VERSION_NUMBER+$env:BUILD_NUMBER"
  $title = "MacroDeck Client v$env:VERSION_NUMBER ($env:BUILD_NUMBER)"
  $notes = Get-Content -LiteralPath $notesFile -Raw -Encoding UTF8
  Write-Host "  发布 tag: $tag" -ForegroundColor Cyan
  Write-Host "  上传产物: $outName.apk, $outName.aab" -ForegroundColor Cyan
  Write-Host "  发布平台: $platformLabel" -ForegroundColor Cyan

  if ($Platform -eq 'gitee') {
    # ─── Gitee Release（通过 Gitee API v5）───────────────────────────────────
    $giteeOwner = 'tea4go'
    $giteeRepo  = 'Macro-Deck-Client-App'
    $giteeToken = $env:GITEE_TOKEN
    if ([string]::IsNullOrWhiteSpace($giteeToken)) {
      Write-Fail '未设置 GITEE_TOKEN 环境变量。请在 scripts\local\android-signing.ps1 中添加：'
      Write-Host '  $env:GITEE_TOKEN = "你的 Gitee 私人令牌"' -ForegroundColor Yellow
      Write-Host '  获取令牌：https://gitee.com/personal_access_tokens' -ForegroundColor Yellow
      exit 1
    }

    # 1) 创建 Release
    $createUri = "https://gitee.com/api/v5/repos/$giteeOwner/$giteeRepo/releases"
    $createBody = @{
      access_token = $giteeToken
      tag_name     = $tag
      name         = $title
      body         = $notes
      target_commitish = 'main'
    }
    Write-Host "  正在创建 Gitee Release..." -ForegroundColor Cyan
    try {
      $release = Invoke-RestMethod -Method Post -Uri $createUri -Body $createBody -ErrorAction Stop
    } catch {
      Write-Fail "Gitee Release 创建失败：$($_.Exception.Message)"
      exit 1
    }
    $releaseId = $release.id
    Write-Ok "Gitee Release 已创建（ID: $releaseId）"

    # 2) 上传 APK 和 AAB
    #    Gitee API 上传附件用 curl 最可靠（PowerShell 手动拼 multipart 容易格式错误）
    #    Windows 上 PowerShell 的 curl 是 Invoke-WebRequest 别名，需明确调用 curl.exe
    $curlExe = Get-CommandPath 'curl.exe'
    if (-not $curlExe) { $curlExe = Get-CommandPath 'curl' }
    if (-not $curlExe) {
      Write-Fail '未找到 curl 命令，无法上传文件'
      exit 1
    }
    foreach ($filePath in @($apkPath, $aabPath)) {
      $fileName = [IO.Path]::GetFileName($filePath)
      Write-Host "  正在上传 $fileName ..." -ForegroundColor Cyan
      $uploadUri = "https://gitee.com/api/v5/repos/$giteeOwner/$giteeRepo/releases/$releaseId/attach_files"
      $curlArgs = @(
        '-s', '-S',
        '-X', 'POST',
        '-F', "file=@$filePath",
        '-F', "access_token=$giteeToken",
        $uploadUri
      )
      Invoke-NativeStream -Block { & $curlExe @curlArgs }
      if ($LASTEXITCODE -ne 0) {
        Write-Fail "$fileName 上传失败（curl 退出码: $LASTEXITCODE）"
        exit 1
      }
      Write-Ok "$fileName 上传成功"
    }
    Write-Ok "已发布到 Gitee Release：https://gitee.com/$giteeOwner/$giteeRepo/releases/tag/$tag"

  } else {
    # ─── GitHub Release（通过 gh CLI）────────────────────────────────────────
    if (-not (Get-CommandPath 'gh')) {
      Write-Fail '未找到 gh CLI，无法发布。请先安装：https://cli.github.com/ 并运行 gh auth login'
      exit 1
    }
    Invoke-NativeStream -Block { & gh auth status }
    if ($LASTEXITCODE -ne 0) {
      Write-Fail 'gh 未登录，请先运行：gh auth login'
      exit 1
    }
    $repo = 'tea4go/Macro-Deck-Client-App'
    Invoke-NativeStream -Block {
      & gh release create $tag $apkPath $aabPath --title $title --notes-file $notesFile --repo $repo
    }
    if ($LASTEXITCODE -ne 0) {
      Write-Fail "GitHub Release 发布失败（tag 可能已存在，请提升 versionCode 后重试）"
      exit 1
    }
    Write-Ok "已发布到 GitHub Release：https://github.com/$repo/releases/tag/$tag"
  }

  exit 0
}

# ─── 构建流程 ──────────────────────────────────────────────────────────────────
Write-Banner '构建 Android release'

Load-AndroidSigningPs1 -FilePath $signingFile

# 当前 Java 版本不是 21 时，尝试用 jvms 自动切换；构建结束/异常再切回。
$originalJvmsVersion = $null
$currentJavaMajor = Get-JavaMajorVersion
if ($currentJavaMajor -ne 21) {
  if (Test-JvmsAvailable) {
    $target = Find-JvmsVersionMatching -MajorVersion 21
    if ($target) {
      $info = Get-JvmsListInfo
      $originalJvmsVersion = $info.Current
      Write-Warn "当前 Java $currentJavaMajor 不匹配，用 jvms 切换到 $target（原：$originalJvmsVersion）"
      if (-not (Set-JvmsVersion -Version $target)) {
        $originalJvmsVersion = $null
      }
    } else {
      Write-Warn "jvms 已安装但未找到 JDK 21，建议：jvms install 21"
    }
  } else {
    Write-Warn "未检测到 jvms 命令，无法自动切换 JDK 21"
  }
}

try {
  $ready = $true
  if (-not (Assert-JavaForAndroid)) { $ready = $false }
  if (-not (Require-AndroidReleaseEnv)) { $ready = $false }
  if (-not (Require-Command 'npx')) { $ready = $false }
  if (-not (Require-WebBuildDeps)) { $ready = $false }
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
  $apkPath = Join-Path $script:RootDir "android\app\build\outputs\apk\release\$outName.apk"
  $aabPath = Join-Path $script:RootDir "android\app\build\outputs\bundle\release\$outName.aab"
  Write-Ok "Android release APK 产物: $apkPath"
  Write-Ok "Android release AAB 产物: $aabPath"

  exit 0
}
finally {
  if ($originalJvmsVersion) {
    Write-Host "  恢复 jvms 版本：$originalJvmsVersion" -ForegroundColor Cyan
    $null = Set-JvmsVersion -Version $originalJvmsVersion
  }
}
