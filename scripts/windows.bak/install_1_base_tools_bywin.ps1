<#
.SYNOPSIS
  在 Windows 上按需安装/卸载基础工具：winget、Windows Terminal、Microsoft Store、Node.js LTS。
.DESCRIPTION
  主要流程：
  - 支持 -AddTools / -RemoveTools 指定工具列表；支持 all 代表全部
  - 对部分工具提供多种安装来源（GitHub/MS Store/winget），并尽量给出可复现的提示
  - Node.js（提供 npm/npx）是后续 Ionic + Angular Web 构建的前置依赖
.PARAMETER Yes
  自动确认（静默模式）。
.PARAMETER AddTools
  要安装的工具 Id 列表（winget/terminal/store/node 或 all）。
.PARAMETER RemoveTools
  要卸载的工具 Id 列表（terminal 或 all）。
#>
param(
  [Alias('y')]
  [switch]$Yes,

  [string[]]$AddTools,

  [string[]]$RemoveTools
)

$ErrorActionPreference = 'Stop'
$Failed = $false

. (Join-Path $PSScriptRoot '_common.ps1')

if ($Yes) { Enable-AutoConfirm }

# ─── 工具注册表 ───────────────────────────────────────────────────────────────
# 每个工具：Id（参数名）、Name（显示名）、Description
$ToolDefs = @(
  @{ Id = 'winget'; Name = 'winget'; Description = 'Windows 包管理器' },
  @{ Id = 'terminal'; Name = 'Windows 终端'; Description = 'Windows Terminal（多标签终端）' },
  @{ Id = 'store'; Name = 'Microsoft Store'; Description = 'Microsoft Store（应用商店）' },
  @{ Id = 'node'; Name = 'Node.js LTS'; Description = 'Node.js LTS（npm / npx / Ionic 构建前置）' }
)

# ─── winget ───────────────────────────────────────────────────────────────────


<#
.SYNOPSIS
  检测 winget 是否可用，并输出路径/版本/大小等信息。
.OUTPUTS
  [bool] 可用返回 $true，否则返回 $false。
#>
function Test-Winget {
  $winget = Get-ExePath 'winget.exe'
  if (-not $winget) { return $false }
  try {
    $ver = (Invoke-NativeText -FilePath $winget -Arguments @('--version') | Select-Object -First 1)
  }
  catch {
    return $false
  }
  Write-Ok "winget 已安装"
  Write-Host "    路径：$winget"
  try {
    if ($winget -match 'WindowsApps') {
      # WindowsApps 下的是零字节别名，通过 AppxPackage 获取实际大小
      $pkg = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction Stop | Select-Object -First 1
      if ($pkg -and $pkg.InstallLocation) {
        $total = 0L
        foreach ($f in [System.IO.Directory]::EnumerateFiles($pkg.InstallLocation, '*', [System.IO.SearchOption]::AllDirectories)) {
          $total += (New-Object System.IO.FileInfo($f)).Length
        }
        $sizeMB = '{0:N2}' -f ($total / 1MB)
        Write-Host "    大小：${sizeMB} MB（App Installer 包）"
      }
    }
    else {
      $fi = Get-Item -LiteralPath $winget -ErrorAction Stop
      $sizeMB = '{0:N2}' -f ($fi.Length / 1MB)
      Write-Host "    大小：${sizeMB} MB"
    }
  }
  catch {}
  if (-not [string]::IsNullOrWhiteSpace($ver)) { Write-Host "    版本：$ver" }
  return $true
}


<#
.SYNOPSIS
  配置 winget 国内镜像源，并移除易出错的 msstore 源（可选）。
.DESCRIPTION
  - 优先配置 USTC 镜像源：https://mirrors.ustc.edu.cn/winget-source
  - 对 winget 1.8+ 使用 --trust-level trusted 以减少交互与校验问题
.NOTES
  本函数不保证一定成功；失败时只输出警告，不中断主流程。
#>
function Add-WingetMirrorSource {
  $winget = Get-ExePath 'winget.exe'
  if (-not $winget) { return }

  # 获取 winget 版本号
  $ver = $null
  try {
    $verStr = (Invoke-NativeText -FilePath $winget -Arguments @('--version') | Select-Object -First 1).Trim()
    $ver = [version]::new($verStr.Substring(0, [Math]::Min($verStr.Length, 10 - 1))) # 取前缀避免多余字符
  }
  catch {
    $ver = $null
  }

  # 检查是否已存在同名源
  $sourceList = $null
  try {
    $sourceList = Invoke-NativeText -FilePath $winget -Arguments @('source', 'list')
  }
  catch {
    $sourceList = ''
  }

      # 移除 msstore 源（证书验证问题，且开发者通常不需要）
  if ($sourceList -and ($sourceList | Where-Object { $_ -match 'msstore' })) {
    try {
      Invoke-NativeStream -Block { & $winget source remove msstore }
      Write-Ok "已移除 msstore 源（避免证书验证报错）"
    }
    catch {
      Write-Warn "移除 msstore 源失败：$($_.Exception.Message)"
    }
  }

  $mirrorUrl = 'https://mirrors.ustc.edu.cn/winget-source'
  $alreadyHas = $false
  if ($sourceList) {
    $alreadyHas = ($sourceList | Where-Object { $_ -match 'winget' -and $_ -match [regex]::Escape($mirrorUrl) }) -ne $null
  }

  if ($alreadyHas) {
    Write-Ok "winget 国内镜像源已配置（ustc）"
    return
  }

  # 如果已有默认 winget 源，先移除再添加镜像源
  if ($sourceList -and ($sourceList | Where-Object { $_ -match 'winget\s' })) {
    try {
      Invoke-NativeStream -Block { & $winget source remove winget }
    }
    catch {
      Write-Warn "移除默认 winget 源失败：$($_.Exception.Message)"
    }
  }

  # WinGet 1.8+ 支持 --trust-level 参数
  if ($ver -and $ver -ge [version]'1.8') {
    try {
      Invoke-NativeStream -Block { & $winget source add winget $mirrorUrl --trust-level trusted }
      Write-Ok "winget 国内镜像源配置成功（ustc，trust-level trusted）"
    }
    catch {
      Write-Warn "配置镜像源失败：$($_.Exception.Message)"
    }
  }
  else {
    try {
      Invoke-NativeStream -Block { & $winget source add winget $mirrorUrl }
      Write-Ok "winget 国内镜像源配置成功（ustc）"
    }
    catch {
      Write-Warn "配置镜像源失败：$($_.Exception.Message)"
    }
  }
}

<#
.SYNOPSIS
  安装 winget（Windows 包管理器），并在安装后配置国内镜像源。
.OUTPUTS
  [bool] 安装成功返回 $true，否则返回 $false。
.NOTES
  优先尝试下载 App Installer 的 msixbundle；失败会给出手动安装提示。
#>
function Install-WingetTool {
  Write-Host ""
  Write-Host "═══ 安装 winget ═══" -ForegroundColor Cyan
  Write-Host ""

  if (Test-Winget) {
    Write-Host ""
    Add-WingetMirrorSource
    return $true
  }

  Write-Host "  ✗ 未检测到 winget" -ForegroundColor Red
  Write-Host ""

  if (-not (Confirm-Install "安装 winget（Windows 包管理器）")) { return $false }

  $installed = $false

  # 方式一：从 GitHub 下载最新版 App Installer msixbundle 安装
  Write-Host "  下载 winget 安装包 ..." -ForegroundColor Cyan
  $wingetInstaller = Join-Path $env:TEMP ("Microsoft.DesktopAppInstaller_{0}.msixbundle" -f ([guid]::NewGuid().ToString('N')))
  try {
    # 尝试从 GitHub API 获取最新版下载地址
    $downloadUrl = $null
    try {
      $prev = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -TimeoutSec 15
      $asset = $release.assets | Where-Object { $_.name -like 'Microsoft.DesktopAppInstaller_*.msixbundle' } | Select-Object -First 1
      if ($asset) { $downloadUrl = $asset.browser_download_url }
      $ErrorActionPreference = $prev
    }
    catch {
      Write-Warn "无法获取 winget 最新版下载地址，使用固定版本 ..."
    }

    # 构建下载 URL 列表：优先 gh-proxy.org 加速镜像，再尝试直连
    $urls = @()
    if ($downloadUrl) {
      $urls += "https://gh-proxy.org/$downloadUrl"
      $urls += "https://cdn.gh-proxy.org/$downloadUrl"
      $urls += "https://hk.gh-proxy.org/$downloadUrl"
      $urls += "https://gh.llkk.cc/$downloadUrl"
      $urls += $downloadUrl
    }
    # 固定版本兜底
    $fixedUrl = 'http://nj.yj2025.icu:23432/update/winapp/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
    $urls += $fixedUrl

    if (Save-WebFile -Urls $urls -OutFile $wingetInstaller -TimeoutSec 120 -MinSizeKB 10240) {
      try {
        Add-AppxPackage -Path $wingetInstaller -ErrorAction Stop
        Write-Ok "winget 安装成功"
        $installed = $true
      }
      catch {
        Write-Fail "winget 安装失败：$($_.Exception.Message)"
      }
    }
    else {
      Write-Fail "下载 winget 安装包失败"
    }
  }
  catch {
    Write-Warn "winget 下载/安装过程出错：$($_.Exception.Message)"
  }
  # 保留安装包文件，方便手动重装

  if (Test-Winget) {
    Add-WingetMirrorSource
    Write-Banner -Title 'winget 安装成功' -Color Green
    return $true
  }
  if ($installed) {
    Write-Warn "winget 安装流程已执行，但当前 shell 未检测到 winget"
    Write-Warn "请重新打开终端后再次运行此脚本验证"
    return $false
  }
  Write-Fail "winget 自动安装失败"
  Write-Fail "请手动安装 winget："
  Write-Fail "  • 访问 https://github.com/microsoft/winget-cli/releases 下载 .msixbundle 安装"
  Write-Fail "  • 或打开 Microsoft Store 搜索「应用安装程序」并安装/更新"
  return $false
}

# ─── Windows 终端 ─────────────────────────────────────────────────────────────

<#
.SYNOPSIS
  检测 Windows Terminal（wt.exe）是否可用，并输出路径/版本/大小等信息。
.OUTPUTS
  [bool]
#>
function Test-WindowsTerminal {
  $wt = Get-ExePath 'wt.exe'
  if (-not $wt) {
    $localWt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
    if (Test-Path -LiteralPath $localWt) { $wt = $localWt }
  }
  if (-not $wt) { return $false }
  $ver = $null
  try {
    $wtPkg = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction Stop | Select-Object -First 1
    if ($wtPkg -and $wtPkg.Version) { $ver = $wtPkg.Version.ToString() }
  }
  catch {}
  if ([string]::IsNullOrWhiteSpace($ver)) {
    try {
      $fi = Get-Item -LiteralPath $wt -ErrorAction Stop
      $ver = $fi.VersionInfo.ProductVersion
    }
    catch {}
  }
  Write-Ok "Windows 终端 已安装"
  Write-Host "    路径：$wt"
  try {
    if ($wt -match 'WindowsApps') {
      # WindowsApps 下的是零字节别名，通过 AppxPackage 获取实际大小
      $pkg = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction Stop | Select-Object -First 1
      if ($pkg -and $pkg.InstallLocation) {
        $total = 0L
        foreach ($f in [System.IO.Directory]::EnumerateFiles($pkg.InstallLocation, '*', [System.IO.SearchOption]::AllDirectories)) {
          $total += (New-Object System.IO.FileInfo($f)).Length
        }
        $sizeMB = '{0:N2}' -f ($total / 1MB)
        Write-Host "    大小：${sizeMB} MB（Windows Terminal 包）"
      }
    }
    else {
      $fi = Get-Item -LiteralPath $wt -ErrorAction Stop
      $sizeMB = '{0:N2}' -f ($fi.Length / 1MB)
      Write-Host "    大小：${sizeMB} MB"
    }
  }
  catch {}
  if (-not [string]::IsNullOrWhiteSpace($ver)) { Write-Host "    版本：$ver" }
  return $true
}

<#
.SYNOPSIS
  安装 Windows Terminal（优先下载 msixbundle，其次 winget，最后引导到 Microsoft Store）。
.OUTPUTS
  [bool]
#>
function Install-WindowsTerminalTool {
  Write-Host ""
  Write-Host "═══ 安装 Windows 终端 ═══" -ForegroundColor Cyan
  Write-Host ""

  if (Test-WindowsTerminal) {
    Write-Host ""
    return $true
  }

  Write-Host "  ✗ 未检测到 Windows 终端" -ForegroundColor Red
  Write-Host ""

  if (-not (Confirm-Install "安装 Windows 终端（Windows Terminal）")) { return $false }

  $installed = $false

  # 方式一：从 GitHub releases 下载 .msixbundle 安装
  if (-not $installed) {
    Write-Host "  下载 Windows 终端安装包 ..." -ForegroundColor Cyan
    $wtInstaller = Join-Path $env:TEMP ("Microsoft.WindowsTerminal_{0}.msixbundle" -f ([guid]::NewGuid().ToString('N')))
    try {
      $downloadUrl = $null
      try {
        $prev = $ErrorActionPreference
        try {
          $ErrorActionPreference = 'Continue'
          $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/terminal/releases/latest' -TimeoutSec 15
          $assets = @($release.assets | Where-Object { $_.name -like '*.msixbundle' -and $_.name -notlike '*PreinstallKit*' })
          $asset = $assets | Where-Object { $_.name -like 'Microsoft.WindowsTerminal_*_8wekyb3d8bbwe.msixbundle' } | Select-Object -First 1
          if (-not $asset) { $asset = $assets | Where-Object { $_.name -like 'Microsoft.WindowsTerminal_*_x64.msixbundle' } | Select-Object -First 1 }
          if (-not $asset) { $asset = $assets | Where-Object { $_.name -like 'Microsoft.WindowsTerminal_*.msixbundle' } | Select-Object -First 1 }
          if ($asset) { $downloadUrl = $asset.browser_download_url }
        }
        finally {
          $ErrorActionPreference = $prev
        }
      }
      catch {
        Write-Warn "无法获取 Windows 终端最新版下载地址，使用固定版本 ..."
      }

      $urls = @()
      if ($downloadUrl) {
        $urls += "https://gh-proxy.org/$downloadUrl"
        $urls += "https://cdn.gh-proxy.org/$downloadUrl"
        $urls += "https://hk.gh-proxy.org/$downloadUrl"
        $urls += "https://gh.llkk.cc/$downloadUrl"
        $urls += $downloadUrl
      }
    # 固定版本兜底
    $fixedUrl = 'http://nj.yj2025.icu:23432/update/winapp/Microsoft.WindowsTerminal_1.24.10921.0_8wekyb3d8bbwe.msixbundle'
    $urls += $fixedUrl

      if (Save-WebFile -Urls $urls -OutFile $wtInstaller -TimeoutSec 120 -MinSizeKB 10240) {
        try {
          Add-AppxPackage -Path $wtInstaller -ErrorAction Stop
          Write-Ok "Windows 终端安装成功"
          $installed = $true
        }
        catch {
          Write-Fail "Windows 终端安装失败：$($_.Exception.Message)"
        }
      }
      else {
        Write-Fail "下载 Windows 终端安装包失败"
      }
    }
    catch {
      Write-Warn "Windows 终端 下载/安装过程出错：$($_.Exception.Message)"
    }
  }

  # 方式二：通过 winget 安装
  if (-not $installed -and (Get-ExePath 'winget.exe')) {
    Write-Host "  通过 winget 安装 Windows 终端 ..." -ForegroundColor Cyan
    try {
      Invoke-NativeStream -Block { & winget install --id Microsoft.WindowsTerminal --source winget --accept-package-agreements --accept-source-agreements }
      $installed = $true
    }
    catch {
      Write-Fail "winget 安装失败：$($_.Exception.Message)"
    }
    if ($installed -and -not (Test-WindowsTerminal)) {
      Write-Warn "winget 报告成功但未检测到 wt.exe"
      $installed = $false
    }
  }

  # 方式三：打开 Microsoft Store
  if (-not $installed) {
    Write-Host "  尝试从 Microsoft Store 安装 ..." -ForegroundColor Cyan
    try {
      Start-Process 'ms-windows-store://pdp/?ProductId=9n0dx20hk701'
      Write-Warn "已打开 Microsoft Store 页面，请在 Store 中点击「安装」"
      Write-Warn "安装完成后按 Enter 继续 ..."
      Read-Host
      $installed = Test-WindowsTerminal
    }
    catch {
      Write-Warn "无法打开 Microsoft Store：$($_.Exception.Message)"
    }
  }

  Write-Host ""
  if (Test-WindowsTerminal) {
    Write-Banner -Title 'Windows 终端 安装成功' -Color Green
    return $true
  }
  if ($installed) {
    Write-Warn "Windows 终端安装流程已执行，但当前 shell 未检测到 wt.exe"
    Write-Warn "请重新打开终端后再次运行此脚本验证"
    return $false
  }
  Write-Fail "Windows 终端自动安装失败"
  Write-Fail "请手动安装 Windows 终端："
  Write-Fail "  • 打开 Microsoft Store 搜索「Windows 终端」并安装"
  Write-Fail "  • 或访问 https://github.com/microsoft/terminal/releases 下载安装"
  return $false
}

<#
.SYNOPSIS
  卸载 Windows Terminal（优先 Remove-AppxPackage，其次 winget，最后引导到 Microsoft Store）。
.OUTPUTS
  [bool]
.NOTES
  该函数仅对 Windows Terminal 提供卸载流程；其他工具可能需要系统组件方式处理。
#>
function Uninstall-WindowsTerminalTool {
  if (-not (Test-WindowsTerminal)) {
    Write-Warn 'Windows 终端 未安装，无需卸载'
    return $true
  }

  Write-Host ""
  if (-not (Confirm-Continue "确认卸载 Windows 终端")) { return $false }

  $uninstalled = $false

  # 方式一：通过 Remove-AppxPackage 卸载
  $wtPackage = Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue
  if ($wtPackage) {
    Write-Host "  通过 Remove-AppxPackage 卸载 Windows 终端 ..." -ForegroundColor Cyan
    try {
      Remove-AppxPackage -Package $wtPackage.PackageFullName -ErrorAction Stop
      Write-Ok "Windows 终端已卸载"
      $uninstalled = $true
    }
    catch {
      Write-Warn "Remove-AppxPackage 卸载失败：$($_.Exception.Message)"
    }
  }

  # 方式二：通过 winget 卸载
  if (-not $uninstalled -and (Get-ExePath 'winget.exe')) {
    Write-Host "  通过 winget 卸载 Windows 终端 ..." -ForegroundColor Cyan
    try {
      Invoke-NativeStream -Block { & winget uninstall --id Microsoft.WindowsTerminal --source winget --accept-source-agreements }
      $uninstalled = $true
    }
    catch {
      Write-Fail "winget 卸载失败：$($_.Exception.Message)"
    }
  }

  # 方式三：打开 Microsoft Store 卸载
  if (-not $uninstalled) {
    Write-Host "  尝试通过 Microsoft Store 卸载 ..." -ForegroundColor Cyan
    try {
      Start-Process 'ms-windows-store://pdp/?ProductId=9n0dx20hk701'
      Write-Warn "已打开 Microsoft Store 页面，请在 Store 中点击「卸载」"
      Write-Warn "卸载完成后按 Enter 继续 ..."
      Read-Host
      $uninstalled = -not (Test-WindowsTerminal)
    }
    catch {
      Write-Warn "无法打开 Microsoft Store：$($_.Exception.Message)"
    }
  }

  Write-Host ""
  if (-not (Test-WindowsTerminal)) {
    Write-Banner -Title 'Windows 终端 卸载成功' -Color Green
    return $true
  }
  if ($uninstalled) {
    Write-Warn "Windows 终端卸载流程已执行，但当前 shell 仍检测到 wt.exe"
    Write-Warn "请重新打开终端后再次运行此脚本验证"
    return $false
  }
  Write-Fail "Windows 终端自动卸载失败"
  Write-Fail "请手动卸载 Windows 终端："
  Write-Fail "  • 打开 Microsoft Store 搜索「Windows 终端」并卸载"
  Write-Fail "  • 或在「设置 → 应用」中找到「Windows 终端」并卸载"
  Write-Fail "  • 或运行：Get-AppxPackage Microsoft.WindowsTerminal | Remove-AppxPackage"
  return $false
}

<#
.SYNOPSIS
  检测 Microsoft Store 是否已安装（Microsoft.WindowsStore 包）。
.OUTPUTS
  [bool]
#>
function Test-MicrosoftStore {
  $pkg = $null
  try {
    $pkg = Get-AppxPackage -Name Microsoft.WindowsStore -ErrorAction Stop | Select-Object -First 1
  }
  catch {
    return $false
  }

  if (-not $pkg) { return $false }

  Write-Ok "Microsoft Store 已安装"
  if ($pkg.InstallLocation) { Write-Host "    路径：$($pkg.InstallLocation)" }
  if ($pkg.Version) { Write-Host "    版本：$($pkg.Version.ToString())" }

  try {
    if ($pkg.InstallLocation -and (Test-Path -LiteralPath $pkg.InstallLocation)) {
      $total = 0L
      foreach ($f in [System.IO.Directory]::EnumerateFiles($pkg.InstallLocation, '*', [System.IO.SearchOption]::AllDirectories)) {
        $total += (New-Object System.IO.FileInfo($f)).Length
      }
      $sizeMB = '{0:N2}' -f ($total / 1MB)
      Write-Host "    大小：${sizeMB} MB（Microsoft Store 包）"
    }
  }
  catch {}

  return $true
}

<#
.SYNOPSIS
  检测 Windows Sandbox 功能是否启用，并输出相关信息。
.OUTPUTS
  [bool] 已启用返回 $true，否则返回 $false。
.NOTES
  主要用于“装完基础工具后做附加检测”的提示，不作为强依赖。
#>
function Test-MicrosoftSandbox {
  $featureState = $null
  try {
    $cmd = Get-Command 'Get-WindowsOptionalFeature' -ErrorAction SilentlyContinue
    if ($cmd) {
      $f = Get-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -ErrorAction Stop
      $featureState = $f.State
    }
  }
  catch {
    $featureState = $null
  }

  if (-not $featureState) {
    try {
      $out = Invoke-NativeText -FilePath 'dism.exe' -Arguments @('/Online', '/Get-FeatureInfo', '/FeatureName:Containers-DisposableClientVM')
      if ($out -match 'State\s*:\s*Enabled') { $featureState = 'Enabled' }
      elseif ($out -match 'State\s*:\s*Disabled') { $featureState = 'Disabled' }
    }
    catch {
      $featureState = $null
    }
  }

  if ($featureState -ne 'Enabled') { return $false }

  $candidates = @(
    (Join-Path $env:WINDIR 'System32\WindowsSandbox.exe'),
    (Join-Path $env:WINDIR 'System32\WindowsSandboxClient.exe'),
    (Join-Path $env:WINDIR 'System32\WindowsSandboxRemoteSession.exe')
  )
  $exe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

  Write-Ok "Microsoft Sandbox 已启用"
  Write-Host "    功能：Containers-DisposableClientVM（Enabled）"

  $ver = $null
  if ($exe) {
    Write-Host "    程序：$exe"
    try {
      $fi = Get-Item -LiteralPath $exe -ErrorAction Stop
      $sizeMB = '{0:N2}' -f ($fi.Length / 1MB)
      Write-Host "    大小：${sizeMB} MB"
      $ver = $fi.VersionInfo.ProductVersion
    }
    catch {}
  }
  if (-not [string]::IsNullOrWhiteSpace($ver)) { Write-Host "    版本：$ver" }

  return $true
}

<#
.SYNOPSIS
  安装 Microsoft Store（仅在系统缺失时尝试修复/引导安装）。
.OUTPUTS
  [bool]
.NOTES
  Microsoft Store 属于系统组件，不同 Windows 版本/精简系统可能无法自动补齐。
#>
function Install-MicrosoftStoreTool {
  Write-Host ""
  Write-Host "═══ 安装 Microsoft Store ═══" -ForegroundColor Cyan
  Write-Host ""

  if (Test-MicrosoftStore) {
    Write-Host ""
    return $true
  }

  Write-Host "  ✗ 未检测到 Microsoft Store" -ForegroundColor Red
  Write-Host ""

  if (-not (Confirm-Install "安装 Microsoft Store（应用商店）")) { return $false }

  $installed = $false

  Write-Host "  下载 Microsoft Store 安装程序 ..." -ForegroundColor Cyan
  $installer = Join-Path $env:TEMP ("MicrosoftStoreInstaller_{0}.exe" -f ([guid]::NewGuid().ToString('N')))
  try {
    $urls = @()
    $fixedUrl = 'http://nj.yj2025.icu:23432/update/winapp/MicrosoftStoreInstaller.exe'
    $urls += $fixedUrl

    if (Save-WebFile -Urls $urls -OutFile $installer -TimeoutSec 120 -MinSizeKB 512) {
      try {
        Write-Host "  运行安装程序 ..." -ForegroundColor Cyan
        Start-Process -FilePath $installer -Wait
        $installed = $true
      }
      catch {
        Write-Fail "安装程序启动失败：$($_.Exception.Message)"
      }
    }
    else {
      Write-Fail "下载 Microsoft Store 安装程序失败"
    }
  }
  catch {
    Write-Warn "Microsoft Store 下载/安装过程出错：$($_.Exception.Message)"
  }

  Write-Host ""
  if (Test-MicrosoftStore) {
    Write-Banner -Title 'Microsoft Store 安装成功' -Color Green
    return $true
  }
  if ($installed) {
    Write-Warn "Microsoft Store 安装流程已执行，但当前未检测到 Microsoft.WindowsStore 包"
    Write-Warn "请重新登录/重启后再次运行此脚本验证"
    return $false
  }
  Write-Fail "Microsoft Store 自动安装失败"
  Write-Fail "请手动安装 Microsoft Store（若系统支持）："
  Write-Fail "  • 运行 wsreset -i（Windows 11 及以上可能支持）"
  Write-Fail "  • 或使用离线安装包重新安装"
  return $false
}

# ─── Node.js ─────────────────────────────────────────────────────────────────

function Test-NodeTool {
  $node = Get-ExePath 'node.exe'
  $npm = Get-ExePath 'npm.cmd'
  if (-not $npm) { $npm = Get-ExePath 'npm.exe' }
  $npx = Get-ExePath 'npx.cmd'
  if (-not $npx) { $npx = Get-ExePath 'npx.exe' }

  if (-not $node -or -not $npm -or -not $npx) { return $false }

  $nodeVersion = Invoke-NativeText -FilePath $node -Arguments @('--version') | Select-Object -First 1
  $npmVersion = Invoke-NativeText -FilePath $npm -Arguments @('--version') | Select-Object -First 1
  Write-Ok "Node.js 已安装"
  Write-Host "    node：$node ($nodeVersion)"
  Write-Host "    npm ：$npm ($npmVersion)"
  Write-Host "    npx ：$npx"
  return $true
}

function Install-NodeTool {
  Write-Host ""
  Write-Host "═══ 安装 Node.js LTS ═══" -ForegroundColor Cyan
  Write-Host ""

  if (Test-NodeTool) { return $true }
  if (-not (Confirm-Install "安装 Node.js LTS")) { return $false }

  if (-not (Get-ExePath 'winget.exe')) {
    Write-Fail "缺少 winget，无法自动安装 Node.js LTS"
    Write-Fail "请手动安装：https://nodejs.org/"
    return $false
  }

  try {
    Invoke-NativeStream -Block { & winget install --id OpenJS.NodeJS.LTS --source winget --accept-package-agreements --accept-source-agreements }
  }
  catch {
    Write-Fail "Node.js LTS 安装失败：$($_.Exception.Message)"
    return $false
  }

  if (Test-NodeTool) { return $true }
  Write-Warn "Node.js 安装流程已执行，但当前 shell 未检测到 node/npm/npx"
  Write-Warn "请重新打开终端后再次运行此脚本验证"
  return $false
}

# ─── 工具调度 ─────────────────────────────────────────────────────────────────

# Id → Install 函数 的映射
$ToolInstallers = @{
  'winget'   = ${function:Install-WingetTool}
  'terminal' = ${function:Install-WindowsTerminalTool}
  'store'    = ${function:Install-MicrosoftStoreTool}
  'node'     = ${function:Install-NodeTool}
}

# Id → Uninstall 函数 的映射
$ToolUninstallers = @{
  'terminal' = ${function:Uninstall-WindowsTerminalTool}
}

<#
.SYNOPSIS
  打印脚本用法与可用工具列表。
#>
function Write-Usage {
  Write-Host ""
  Write-Banner -Title '基础工具管理（Windows）    ' -Color Cyan
  Write-Host ""
  Write-Host "用法：" -ForegroundColor Cyan
  Write-Host "  .\install_base_tools_bywin.ps1 -AddTools <工具1,工具2,...>     安装指定工具"
  Write-Host "  .\install_base_tools_bywin.ps1 -RemoveTools <工具1,工具2,...>  卸载指定工具"
  Write-Host "  .\install_base_tools_bywin.ps1 -y -AddTools all               静默安装所有工具"
  Write-Host ""
  Write-Host "可用工具：winget, terminal, store, node" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "可用工具：" -ForegroundColor Cyan
  foreach ($t in $ToolDefs) {
    Write-Host ("  {0,-10} {1}" -f $t.Id, $t.Description)
  }
  Write-Host ""
  Write-Host "示例：" -ForegroundColor Cyan
  Write-Host "  .\install_base_tools_bywin.ps1 -AddTools winget"
  Write-Host "  .\install_base_tools_bywin.ps1 -AddTools winget,terminal"
  Write-Host "  .\install_base_tools_bywin.ps1 -AddTools all"
  Write-Host "  .\install_base_tools_bywin.ps1 -RemoveTools terminal"
  Write-Host "  .\install_base_tools_bywin.ps1 -RemoveTools all"
  Write-Host ""
}

# ─── 主流程 ───────────────────────────────────────────────────────────────────

if ((-not $AddTools -or $AddTools.Count -eq 0) -and (-not $RemoveTools -or $RemoveTools.Count -eq 0)) {
  Write-Usage
  exit 0
}

# 展开别名：all → 所有工具 Id
$validIds = $ToolDefs | ForEach-Object { $_.Id }
$addAllRequested = $false
$removeAllRequested = $false

# 校验 -AddTools 参数
if ($AddTools -and $AddTools.Count -gt 0) {
  if ($AddTools -contains 'all') {
    $addAllRequested = $true
    $AddTools = @($validIds)
  }
  $unknown = $AddTools | Where-Object { $_ -notin $validIds }
  if ($unknown) {
    Write-Fail "未知工具（-AddTools）：$($unknown -join ', ')"
    Write-Host ""
    Write-Host "可用工具：$($validIds -join ', ')" -ForegroundColor Yellow
    exit 1
  }
}

# 校验 -RemoveTools 参数
if ($RemoveTools -and $RemoveTools.Count -gt 0) {
  if ($RemoveTools -contains 'all') {
    $removeAllRequested = $true
    $RemoveTools = @($validIds)
  }
  $unknown = $RemoveTools | Where-Object { $_ -notin $validIds }
  if ($unknown) {
    Write-Fail "未知工具（-RemoveTools）：$($unknown -join ', ')"
    Write-Host ""
    Write-Host "可用工具：$($validIds -join ', ')" -ForegroundColor Yellow
    exit 1
  }
}

# 不允许同时安装和卸载同一工具
if ($AddTools -and $RemoveTools) {
  $conflict = $AddTools | Where-Object { $_ -in $RemoveTools }
  if ($conflict) {
    Write-Fail "不能同时安装和卸载同一工具：$($conflict -join ', ')"
    exit 1
  }
}

Write-Host ""
Write-Banner -Title '基础工具管理（Windows）    ' -Color Cyan
Write-Host ""

# ── 卸载流程 ──
if ($RemoveTools -and $RemoveTools.Count -gt 0) {
  $step = 0
  $total = $RemoveTools.Count
  $removeResults = @{}
  $removeDetails = @{}

  foreach ($id in $RemoveTools) {
    $step++
    $def = $ToolDefs | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    Write-Host "[$step/$total] 卸载 $($def.Name)" -ForegroundColor Cyan
    $uninstaller = $null
    if ($ToolUninstallers.ContainsKey($id)) { $uninstaller = $ToolUninstallers[$id] }
    if (-not $uninstaller) {
      Write-Warn "$($def.Name) 跳过"
      $removeResults[$id] = $true
      $removeDetails[$id] = '跳过'
    }
    else {
      try {
        $removeResults[$id] = [bool](& $uninstaller)
      }
      catch {
        Write-Fail "$($def.Name) 卸载过程出错：$($_.Exception.Message)"
        $removeResults[$id] = $false
        $removeDetails[$id] = $_.Exception.Message
      }
    }
    Write-Host ""
  }

  # 卸载摘要
  Write-Host "═══ 卸载摘要 ═══" -ForegroundColor Cyan
  foreach ($id in $RemoveTools) {
    $def = $ToolDefs | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    Write-StatusLine -Label $def.Name -Ok:$removeResults[$id] -OkText '已处理' -NotOkText '未处理' -Detail $removeDetails[$id]
  }
  Write-Host ""

  if ($removeResults.Values -notcontains $false) {
    Write-Host "  所有工具卸载完成！" -ForegroundColor Green
  }
  else {
    Write-Host "  部分工具卸载未成功，请查看上方日志。" -ForegroundColor Yellow
  }
  Write-Host ""
}

# ── 安装流程 ──
if ($AddTools -and $AddTools.Count -gt 0) {
  # winget 是其他工具的前置依赖，如果选了非 winget 工具但缺少 winget，自动前置安装
  $needsWinget = $AddTools | Where-Object { $_ -ne 'winget' -and $_ -ne 'store' }
  if ($needsWinget -and -not (Get-ExePath 'winget.exe') -and 'winget' -notin $AddTools) {
    Write-Warn "安装其他工具需要 winget，将先安装 winget"
    $AddTools = @('winget') + @($AddTools)
  }

  $step = 0
  $total = $AddTools.Count
  $addResults = @{}

  foreach ($id in $AddTools) {
    $step++
    $def = $ToolDefs | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    Write-Host "[$step/$total] 安装 $($def.Name)" -ForegroundColor Cyan
    $addResults[$id] = & $ToolInstallers[$id]
    Write-Host ""
  }

  # 安装摘要
  Write-Host "═══ 安装摘要 ═══" -ForegroundColor Cyan
  foreach ($id in $AddTools) {
    $def = $ToolDefs | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    Write-StatusLine -Label $def.Name -Ok:$addResults[$id]
  }
  Write-Host ""

  if ($addResults.Values -notcontains $false) {
    Write-Host "  所有工具安装完成！" -ForegroundColor Green
  }
  else {
    Write-Host "  部分工具安装未成功，请查看上方日志。" -ForegroundColor Yellow
  }

  if ($addAllRequested) {
    Write-Host ""
    Write-Host "═══ 附加检测 ═══" -ForegroundColor Cyan
    try {
      $sandboxOk = [bool](Test-MicrosoftSandbox)
      if (-not $sandboxOk) { Write-Warn "Microsoft Sandbox 未启用/不可用" }
    }
    catch {
      Write-Warn "Microsoft Sandbox 检测失败：$($_.Exception.Message)"
    }
    Write-Host ""
  }
}
