# scripts/windows.bak/_common.ps1
# 本目录各 .ps1 脚本（install_* / build_* / run_*）共享的辅助函数与状态变量。
# 面向 Ionic + Angular + Capacitor + fastlane 工具链。
# 通过 dot-sourcing 引入：. (Join-Path $PSScriptRoot '_common.ps1')
#
# 调用脚本约定：
#   - -y 静默模式：调用脚本声明 [switch]$Yes 并在 dot-source 后执行
#       if ($Yes) { Enable-AutoConfirm }
#   - 如需追踪整体失败状态，调用脚本应在顶部声明 $Failed = $false

$script:RootDir = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# ─── Logging ─────────────────────────────────────────────────────────────────
<#
.SYNOPSIS
  输出成功日志（绿色 ✓）。
.PARAMETER Message
  要输出的提示文本。
#>
function Write-Ok([string]$Message) {
  Write-Host "  ✓  $Message" -ForegroundColor Green
}

<#
.SYNOPSIS
  输出警告日志（黄色 ⚠）。
.PARAMETER Message
  要输出的提示文本。
#>
function Write-Warn([string]$Message) {
  Write-Host "  ⚠  $Message" -ForegroundColor Yellow
}

<#
.SYNOPSIS
  输出失败日志（红色 ✗），并把全局失败标记置为 $true。
.PARAMETER Message
  要输出的提示文本。
.NOTES
  会写入 $script:Failed = $true，便于调用脚本在结尾统一判断是否失败。
#>
function Write-Fail([string]$Message) {
  Write-Host "  ✗  $Message" -ForegroundColor Red
  $script:Failed = $true
}

<#
.SYNOPSIS
  输出“状态行”格式：Label：已安装/未安装（可自定义文本与附加说明）。
.PARAMETER Label
  左侧标签文本。
.PARAMETER Ok
  是否为“成功/已安装”状态。
.PARAMETER OkText
  Ok 为 $true 时显示的文本。
.PARAMETER NotOkText
  Ok 为 $false 时显示的文本。
.PARAMETER Detail
  额外说明（可为空）。
#>
function Write-StatusLine {
  param(
    [string]$Label,
    [bool]$Ok,
    [string]$OkText = '已安装',
    [string]$NotOkText = '未安装',
    [string]$Detail = ''
  )
  $value = if ($Ok) { $OkText } else { $NotOkText }
  $color = if ($Ok) { 'Green' } else { 'Yellow' }
  $line = "  $Label：$value"
  if ($Detail) { $line += " ($Detail)" }
  Write-Host $line -ForegroundColor $color
}

<#
.SYNOPSIS
  remove_*.ps1 的卸载摘要专用状态行：固定 OkText='已移除'。
.PARAMETER Label
  左侧标签文本。
.PARAMETER NotPresent
  目标是否“不存在”（不存在即视为已移除）。
.PARAMETER Detail
  额外说明（可为空）。
.PARAMETER NotOkText
  NotPresent 为 $false 时显示文本，默认“仍存在”。
#>
function Write-RemovedStatus {
  # remove_*.ps1 卸载摘要专用包装：固定 OkText='已移除' / NotOkText 默认 '仍存在'。
  param([string]$Label, [bool]$NotPresent, [string]$Detail = '', [string]$NotOkText = '仍存在')
  Write-StatusLine -Label $Label -Ok:$NotPresent -OkText '已移除' -NotOkText $NotOkText -Detail $Detail
}

<#
.SYNOPSIS
  输出 3 行横幅：上分隔线 + 标题 + 下分隔线。
.PARAMETER Title
  标题文本。
.PARAMETER Color
  分隔线颜色。
.PARAMETER TitleColor
  标题颜色（默认与 Color 相同）。
.PARAMETER Width
  分隔线宽度（字符数）。
#>
function Write-Banner {
  # 输出 3 行横幅：上 ═ 条 + 标题 + 下 ═ 条。前后空行由调用方控制。
  # TitleColor 缺省与 Color 一致；少数场合（如安装完成提示）用 Green 标题 + Cyan 边。
  param(
    [string]$Title,
    [string]$Color = 'Cyan',
    [string]$TitleColor,
    [int]$Width = 42
  )
  if ([string]::IsNullOrWhiteSpace($TitleColor)) { $TitleColor = $Color }
  $bar = '═' * $Width
  Write-Host $bar -ForegroundColor $Color
  Write-Host "  $Title" -ForegroundColor $TitleColor
  Write-Host $bar -ForegroundColor $Color
}

# ─── Confirmations ───────────────────────────────────────────────────────────
# 全局自动确认开关：一旦置位，本脚本进程内所有 Confirm-* 都直接返回 true。
# 用于 -y 静默模式，以及"主菜单选择后子操作不再重复确认"场景。
$script:__AutoConfirm = $false

<#
.SYNOPSIS
  启用“自动确认”模式：所有 Confirm-* 直接返回 $true。
.NOTES
  常用于 -y 静默模式，或主菜单确认后子操作不再重复询问。
#>
function Enable-AutoConfirm { $script:__AutoConfirm = $true }

<#
.SYNOPSIS
  关闭“自动确认”模式：Confirm-* 恢复交互询问。
#>
function Disable-AutoConfirm { $script:__AutoConfirm = $false }

<#
.SYNOPSIS
  交互式确认步骤（支持默认值与自动确认）。
.PARAMETER Desc
  交互提示文本。
.PARAMETER Default
  默认选项（Yes/No）。
.PARAMETER AutoLabel
  自动确认场景下的说明标签（目前仅用于语义表达）。
.OUTPUTS
  [bool] 用户是否确认继续。
#>
function Confirm-Step {
  param(
    [string]$Desc,
    [ValidateSet('Yes', 'No')] [string]$Default = 'Yes',
    [string]$AutoLabel = '自动确认'
  )
  if ($script:__AutoConfirm) {
    return $true
  }
  $hint = if ($Default -eq 'Yes') { '[Y/n]' } else { '[y/N]' }
  $ans = Read-Host "  ? $Desc $hint"
  if ($Default -eq 'Yes') {
    return -not ($ans -match '^(n|no)$')
  } else {
    return ($ans -match '^(y|yes)$')
  }
}

<#
.SYNOPSIS
  询问“是否安装/自动安装”。
.PARAMETER Desc
  描述文本。
.OUTPUTS
  [bool]
#>
function Confirm-Install([string]$Desc) { Confirm-Step -Desc "$Desc 是否自动安装？" -Default 'Yes' }

<#
.SYNOPSIS
  询问“是否继续”。
.PARAMETER Desc
  描述文本。
.OUTPUTS
  [bool]
#>
function Confirm-Continue([string]$Desc) { Confirm-Step -Desc "$Desc 是否继续？" -Default 'Yes' }

<#
.SYNOPSIS
  询问“是否卸载”（默认 No，更安全）。
.PARAMETER Desc
  描述文本。
.OUTPUTS
  [bool]
#>
function Confirm-Remove([string]$Desc) { Confirm-Step -Desc "$Desc —— 是否卸载？" -Default 'No' -AutoLabel '自动确认卸载' }

<#
.SYNOPSIS
  输出提示并退出脚本（用于“用户选择不操作”场景）。
.PARAMETER Message
  退出前输出的提示文本。
.PARAMETER Code
  退出码（默认 0）。
#>
function Exit-NoOp {
  # 用户在菜单或确认提示中选择放弃时的统一退出：黄字提示 + exit。
  # remove_*.ps1 的"菜单选 0 / Confirm-Remove 拒绝"以及 install_c_compile 的"菜单选 0"共用。
  param([string]$Message, [int]$Code = 0)
  Write-Host ""
  Write-Host "  $Message" -ForegroundColor Yellow
  exit $Code
}

<#
.SYNOPSIS
  输出简单编号菜单并读取用户选择。
.PARAMETER Prompt
  菜单提示标题。
.PARAMETER Options
  选项列表（从 1 开始编号，0 代表退出）。
.OUTPUTS
  [int] 选择的编号（0 表示退出/无效输入）。
#>
function Select-MenuOption {
  param(
    [string]$Prompt,
    [string[]]$Options
  )
  Write-Host $Prompt -ForegroundColor Cyan
  for ($i = 0; $i -lt $Options.Count; $i++) {
    Write-Host ("  {0}) {1}" -f ($i + 1), $Options[$i]) -ForegroundColor Cyan
  }
  Write-Host "  0) 退出（不操作）" -ForegroundColor Cyan
  Write-Host ""
  $choice = Read-Host ("  请选择 [0-{0}]" -f $Options.Count)
  $n = 0
  if ([int]::TryParse($choice, [ref]$n) -and $n -ge 1 -and $n -le $Options.Count) { return $n }
  return 0
}

# ─── Native command helpers ──────────────────────────────────────────────────
# 在 Windows PowerShell 5.1 下，native 命令通过 2>&1 把 stderr 合并到成功流时，
# 每行 stderr 会被包装成 NativeCommandError；当 $ErrorActionPreference='Stop'
# 时会被当作终止异常抛出（如 java/cl/gcc 把版本写到 stderr 就会炸）。
# 下面两个助手在调用期间局部把 EAP 降到 Continue，避免误抛。

<#
.SYNOPSIS
  以“文本行数组”的方式执行 native 命令（合并 stdout+stderr），且避免 PowerShell 5.1 的 NativeCommandError 终止异常。
.PARAMETER FilePath
  可执行文件路径或命令名。
.PARAMETER Arguments
  参数数组。
.OUTPUTS
  [string[]] 每行一条文本。
.NOTES
  函数内部临时把 $ErrorActionPreference 设为 Continue，执行结束后恢复。
#>
function Invoke-NativeText {
  # 捕获 native 命令的 stdout+stderr 为字符串数组（每行一项）。
  param([string]$FilePath, [string[]]$Arguments = @())
  $prev = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    & $FilePath @Arguments 2>&1 | ForEach-Object { "$_" }
  } finally {
    $ErrorActionPreference = $prev
  }
}

<#
.SYNOPSIS
  执行 native 命令并把输出“流式”打印到 Host（处理 PowerShell 5.1 的 stderr/进度条兼容问题）。
.PARAMETER Block
  要执行的脚本块（内部应仅包含 native 命令调用）。
.NOTES
  - 会把 stderr 合并并强制转成字符串，避免红色 ErrorRecord 块污染日志。
  - 对常见进度条/旋转帧做单行覆盖，减少刷屏。
#>
function Invoke-NativeStream {
  # 透传 native 命令的输出到 Host：把 stderr 合并进 stdout，并把 ErrorRecord
  # 强制转为字符串，避免 PowerShell 5.1 用错误格式化器显示
  # （部分 CLI 把 "info: ..." 写到 stderr 时会被显示成大红块）。
  # 调用方不要在块里再写 `2>&1 | Out-Host`，本函数已统一处理。
  # winget 等工具的进度条帧（如 "▉  3%" 或 "- \ | /" 旋转动画）每帧输出一行，
  # 用 [Console]::SetCursorPosition 覆盖同一行，避免刷屏。
  # 非进度条的正常文本始终正常输出。
  param([scriptblock]$Block)
  $prev = $ErrorActionPreference
  $isSpinnerLine = $false
  try {
    $ErrorActionPreference = 'Continue'
    & $Block 2>&1 | ForEach-Object {
      $text = "$_"
      $trimmed = $text.Trim()
      # 检测进度条帧：行内仅包含进度条字符（▉▓░█─━■□●○◆◇★☆spinner等）+ 空格 + 百分比
      # 不含字母/中文等正常文本内容的短行视为进度条帧
      $isSpinner = ($trimmed.Length -gt 0) -and ($trimmed.Length -le 40) -and
                   ($trimmed -notmatch '[a-zA-Z一-鿿]') -and
                   ($trimmed -match '[▉▓░█─━■□●○◆◇★☆\-\\/|%0-9]')
      if ($isSpinner) {
        if ($isSpinnerLine) {
          [Console]::SetCursorPosition(0, [Console]::CursorTop)
          # 用空格覆盖旧内容（新内容可能比旧内容短）
          [Console]::Write((' ' * [Math]::Max(0, [Console]::WindowWidth - 1)))
          [Console]::SetCursorPosition(0, [Console]::CursorTop)
        }
        [Console]::Write($text)
        $isSpinnerLine = $true
      } else {
        if ($isSpinnerLine) {
          [Console]::WriteLine()
          $isSpinnerLine = $false
        }
        Write-Host $text
      }
    }
    # 如果最后一行是进度条，补一个换行
    if ($isSpinnerLine) {
      [Console]::WriteLine()
    }
  } finally {
    $ErrorActionPreference = $prev
  }
}

<#
.SYNOPSIS
  切换到指定目录后执行 native 命令（执行完必定恢复当前目录）。
.PARAMETER Path
  工作目录。
.PARAMETER Block
  要执行的脚本块（内部应包含 native 命令调用）。
#>
function Invoke-NativeStreamIn {
  # 在 $Path 目录下运行 $Block；总是恢复 cwd，即便 native 命令出错也不残留。
  param([string]$Path, [scriptblock]$Block)
  Push-Location $Path
  try { Invoke-NativeStream -Block $Block } finally { Pop-Location }
}

# ─── Path / process discovery ────────────────────────────────────────────────
<#
.SYNOPSIS
  解析可执行文件路径（相当于 Windows 的 where/PowerShell 的 Get-Command Source）。
.PARAMETER Name
  命令名（如 node.exe）。
.OUTPUTS
  [string] 可执行文件路径；不存在返回 $null。
#>
function Get-ExePath([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($null -eq $cmd) { return $null }
  return $cmd.Source
}

<#
.SYNOPSIS
  确保目录存在，不存在则创建。
.PARAMETER Path
  目录路径。
#>
function New-DirectoryIfMissing([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

<#
.SYNOPSIS
  把指定目录前置到当前进程 PATH（避免重复添加）。
.PARAMETER Prefix
  需要前置的目录路径。
#>
function Add-PathPrefix([string]$Prefix) {
  if ([string]::IsNullOrWhiteSpace($Prefix)) { return }
  $parts = $env:Path -split ';'
  if ($parts -contains $Prefix) { return }
  $env:Path = "$Prefix;$env:Path"
}

<#
.SYNOPSIS
  获取 pnpm 可执行文件路径（优先 pnpm.cmd）。
.OUTPUTS
  [string] pnpm 路径；未安装返回 $null。
#>
function Get-PnpmExe {
  # Windows 上 pnpm 同时存在 pnpm.cmd（npm 全局装）与 pnpm.exe（独立安装器），优先 .cmd。
  return (Get-ExePath 'pnpm.cmd'), (Get-ExePath 'pnpm.exe') | Where-Object { $_ } | Select-Object -First 1
}

# ─── User environment writers ────────────────────────────────────────────────
<#
.SYNOPSIS
  写入用户级环境变量（User scope）。
.PARAMETER Name
  变量名。
.PARAMETER ValueOrNull
  变量值；传 $null 表示删除该变量。
.OUTPUTS
  [bool] 是否写入成功。
#>
function Set-UserEnv([string]$Name, [string]$ValueOrNull) {
  try {
    [Environment]::SetEnvironmentVariable($Name, $ValueOrNull, 'User')
    return $true
  } catch {
    return $false
  }
}

<#
.SYNOPSIS
  把一个目录段追加到用户 PATH（User scope），避免重复添加。
.PARAMETER Segment
  要追加的目录路径。
.OUTPUTS
  [bool] 是否处理成功（含“已存在”场景）。
#>
function Add-UserPathSegment([string]$Segment) {
  $seg = $Segment.Trim()
  if ([string]::IsNullOrWhiteSpace($seg)) { return $true }
  $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
  $parts = if ([string]::IsNullOrWhiteSpace($userPath)) { @() } else { $userPath -split ';' }
  foreach ($p in $parts) {
    if ($p.Trim().ToLowerInvariant() -eq $seg.ToLowerInvariant()) { return $true }
  }
  $new = if ([string]::IsNullOrWhiteSpace($userPath)) { $seg } else { "$userPath;$seg" }
  return (Set-UserEnv -Name 'PATH' -ValueOrNull $new)
}

<#
.SYNOPSIS
  仅在值变化时写入用户环境变量，并输出中文提示。
.PARAMETER Name
  变量名。
.PARAMETER Value
  要写入的新值。
.NOTES
  用于减少重复写入与重复日志。
#>
function Set-UserEnvIfChanged {
  # 写入用户环境变量；若与现值相同则只打印"已正确设置"日志。
  # 替代 install_android_sdk 中重复的 ANDROID_HOME 设置块。
  param([string]$Name, [string]$Value)
  $current = [Environment]::GetEnvironmentVariable($Name, 'User')
  if ($current -eq $Value) {
    return
  }
  if (Set-UserEnv -Name $Name -ValueOrNull $Value) {
    Write-Ok "set $Name = $Value"
  } else {
    Write-Warn "set $Name = $Value (失败)"
  }
}

# ─── Web download ────────────────────────────────────────────────────────────
<#
.SYNOPSIS
  从单个 URL 下载文件（带简单进度显示）。
.PARAMETER Url
  下载地址。
.PARAMETER OutFile
  输出文件路径。
.PARAMETER TimeoutSec
  超时秒数（连接与读写）。
.OUTPUTS
  [bool] 是否下载成功。
#>
function Save-WebFileSingle {
  # 单地址直接下载，带进度显示
  param([string]$Url, [string]$OutFile, [int]$TimeoutSec = 30)

  Write-Host "  下载：$Url" -ForegroundColor Cyan
  $resp = $null; $stream = $null; $out = $null
  try {
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Timeout = $TimeoutSec * 1000
    $req.ReadWriteTimeout = $TimeoutSec * 1000
    $req.UserAgent = 'PowerShell/Save-WebFile'
    $req.AllowAutoRedirect = $true
    $resp = $req.GetResponse()
    $total = $resp.ContentLength
    $stream = $resp.GetResponseStream()
    $out = [System.IO.File]::Create($OutFile)

    $buf = New-Object byte[] 81920
    [long]$read = 0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $lastReport = 0L
    $lastLineLen = 0
    while (($n = $stream.Read($buf, 0, $buf.Length)) -gt 0) {
      $out.Write($buf, 0, $n)
      $read += $n
      $now = $sw.ElapsedMilliseconds
      if ($now - $lastReport -lt 200) { continue }
      $lastReport = $now
      $sec = [Math]::Max($sw.Elapsed.TotalSeconds, 0.001)
      $speedKB = ($read / $sec) / 1KB
      if ($total -gt 0) {
        $pct = [int](($read / $total) * 100)
        $etaSec = if ($speedKB -gt 0) { [int](($total - $read) / 1KB / $speedKB) } else { 0 }
        $status = '{0,3}%  {1,8:N0} / {2,8:N0} KB  {3,6:N0} KB/s  ETA {4}s' -f $pct, ($read/1KB), ($total/1KB), $speedKB, $etaSec
      } else {
        $status = '{0,8:N0} KB  {1,6:N0} KB/s' -f ($read/1KB), $speedKB
      }
      $line = "    $status"
      $pad = [Math]::Max(0, $lastLineLen - $line.Length)
      [Console]::Write("`r" + $line + (' ' * $pad))
      $lastLineLen = $line.Length
    }
    [Console]::Write("`r" + (' ' * $lastLineLen) + "`r")

    $sw.Stop()
    $sec = [Math]::Max($sw.Elapsed.TotalSeconds, 0.001)
    $avgKB = ($read / $sec) / 1KB
    Write-Ok ("下载完成（{0:N0} KB，{1:N0} KB/s）" -f ($read/1KB), $avgKB)
    Write-Host "  下载完成：$OutFile" -ForegroundColor Cyan
    return $true
  } catch {
    Write-Warn "下载失败：$($_.Exception.Message)"
    Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
  } finally {
    if ($out) { $out.Close() }
    if ($stream) { $stream.Close() }
    if ($resp) { $resp.Close() }
  }
  return $false
}

<#
.SYNOPSIS
  多地址下载：先并行测速选择最快源，再用单线程稳定下载。
.PARAMETER Urls
  候选 URL 列表（会自动去空/去空白）。
.PARAMETER OutFile
  输出文件路径。
.PARAMETER TimeoutSec
  单次下载超时秒数。
.PARAMETER MinSizeKB
  下载完成后的最小文件大小校验（防止下载到错误页面）。
.PARAMETER RaceSec
  并行测速时间（秒）。
.OUTPUTS
  [bool] 是否下载成功。
#>
function Save-WebFile {
  # 并行竞速 + 单线程下载：先用 Start-Job 对所有 URL 并行采样测速，选出最快的源，
  # 再用 Save-WebFileSingle（同步 I/O）从该源完成完整下载。
  # MinSizeKB 参数：下载完成后校验文件大小，小于此值视为无效（如代理返回错误页面）。
  param([string[]]$Urls, [string]$OutFile, [int]$TimeoutSec = 30, [int]$MinSizeKB = 0, [int]$RaceSec = 10)

  $urlList = @(
    $Urls |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { $_.Trim() } |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  )
  if ($urlList.Count -le 0) {
    Write-Warn "未提供下载地址"
    return $false
  }

  # 单地址直接下载，无需竞速
  if ($urlList.Count -eq 1) {
    $result = Save-WebFileSingle -Url $urlList[0] -OutFile $OutFile -TimeoutSec $TimeoutSec
    if ($result -and $MinSizeKB -gt 0) {
      $info = Get-Item -LiteralPath $OutFile -ErrorAction SilentlyContinue
      if ($info -and ($info.Length / 1KB) -lt $MinSizeKB) {
        Write-Warn "下载文件过小（{0:N0} KB < {1:N0} KB），可能为错误页面" -f ($info.Length / 1KB), $MinSizeKB
        Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
        return $false
      }
    }
    return $result
  }

  Write-Host "  可下载的地址库：" -ForegroundColor Cyan
  for ($i = 0; $i -lt $urlList.Count; $i++) {
    Write-Host ("    {0}) {1}" -f ($i + 1), $urlList[$i]) -ForegroundColor Cyan
  }

  # ── 阶段一：并行测速 ──
  # 用 Start-Job 对每个 URL 起独立进程，下载约 256KB 采样测速
  Write-Host "  并行测速 ${RaceSec}s，选择最快源 ..." -ForegroundColor Cyan

  $timeoutMs = [Math]::Max($TimeoutSec, $RaceSec + 10) * 1000
  $jobs = @()
  foreach ($u in $urlList) {
    $job = Start-Job -ArgumentList $u, $RaceSec, $timeoutMs -ScriptBlock {
      param($url, $raceSec, $timeoutMs)
      try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.Timeout = $timeoutMs
        $req.ReadWriteTimeout = $timeoutMs
        $req.UserAgent = 'PowerShell/Save-WebFile'
        $req.AllowAutoRedirect = $true
        $resp = $req.GetResponse()
        $stream = $resp.GetResponseStream()
        $buf = New-Object byte[] 8192
        $total = 0L
        $maxBytes = 256KB
        while ($total -lt $maxBytes -and $sw.Elapsed.TotalSeconds -lt $raceSec) {
          $n = $stream.Read($buf, 0, [Math]::Min($buf.Length, $maxBytes - $total))
          if ($n -le 0) { break }
          $total += $n
        }
        $stream.Close()
        $resp.Close()
        $sw.Stop()
        $elapsed = [Math]::Max($sw.Elapsed.TotalSeconds, 0.001)
        [PSCustomObject]@{ Url = $url; SpeedKBps = [int](($total / $elapsed) / 1KB); Error = '' }
      } catch {
        [PSCustomObject]@{ Url = $url; SpeedKBps = 0; Error = $_.Exception.Message }
      }
    }
    $jobs += $job
  }

  # 等待所有测速任务完成
  Wait-Job -Job $jobs -Timeout ($RaceSec + 15) | Out-Null

  # 显示测速结果
  Write-Host ""
  Write-Host "  测速结果：" -ForegroundColor Cyan
  $raceResults = @()
  foreach ($job in $jobs) {
    $result = Receive-Job -Job $job
    Remove-Job -Job $job -Force
    if (-not $result) { continue }
    try { $uri = [System.Uri]::new($result.Url); $shortName = $uri.Host } catch { $shortName = $result.Url }
    if ($result.Error) {
      Write-Host ("    {0} ✗" -f $shortName, $result.Error) -ForegroundColor Red
    } else {
      Write-Host ("    {0}  {1:N0} KB/s" -f $shortName, $result.SpeedKBps) -ForegroundColor Cyan
      $raceResults += $result
    }
  }

  if ($raceResults.Count -eq 0) {
    Write-Warn "所有下载源均失败"
    return $false
  }

  # 选出最快源
  $best = $raceResults | Sort-Object -Property SpeedKBps -Descending | Select-Object -First 1
  try { $uri = [System.Uri]::new($best.Url); $bestShortName = $uri.Host } catch { $bestShortName = $best.Url }
  Write-Host ""
  Write-Ok "选择最快源：$bestShortName（$($best.SpeedKBps) KB/s）"

  # ── 阶段二：用 Save-WebFileSingle 从最快源同步下载 ──
  $result = Save-WebFileSingle -Url $best.Url -OutFile $OutFile -TimeoutSec $TimeoutSec
  if (-not $result) { return $false }

  # 校验文件大小
  if ($MinSizeKB -gt 0) {
    $info = Get-Item -LiteralPath $OutFile -ErrorAction SilentlyContinue
    if (-not $info -or ($info.Length / 1KB) -lt $MinSizeKB) {
      $actualKB = if ($info) { [int]($info.Length / 1KB) } else { 0 }
      Write-Warn "下载文件过小（${actualKB} KB < ${MinSizeKB} KB），可能为错误页面"
      Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
      return $false
    }
  }

  return $true
}

# ─── Android SDK discovery ──────────────────────────────────────────────────
<#
.SYNOPSIS
  获取 Android SDK 根目录候选列表（按优先级）。
.PARAMETER PreferredRoot
  显式指定的优先路径（通常来自脚本参数）。
.OUTPUTS
  [string[]] 候选路径列表（不保证存在）。
#>
function Get-AndroidSdkRootCandidate {
  # 候选 SDK 根（按探测优先级返回 string[]）：显式 -PreferredRoot → ANDROID_HOME →
  # ANDROID_SDK_ROOT → 项目约定 C:\DevDisk\DevTools\AndroidSDK → Android Studio 默认。
  param([string]$PreferredRoot)

  $roots = New-Object System.Collections.Generic.List[string]
  if (-not [string]::IsNullOrWhiteSpace($PreferredRoot)) {
    $roots.Add($PreferredRoot.Trim('"')) | Out-Null
  }
  if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_HOME)) { $roots.Add($env:ANDROID_HOME.Trim('"')) | Out-Null }
  if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT)) { $roots.Add($env:ANDROID_SDK_ROOT.Trim('"')) | Out-Null }
  $roots.Add('C:\DevDisk\DevTools\AndroidSDK') | Out-Null
  if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $roots.Add((Join-Path $env:LOCALAPPDATA 'Android\Sdk')) | Out-Null
  }
  $roots.Add((Join-Path $HOME 'AppData\Local\Android\Sdk')) | Out-Null
  return $roots
}

<#
.SYNOPSIS
  解析可用的 ANDROID_HOME（存在且可 Resolve-Path）。
.PARAMETER PreferredRoot
  优先使用的 SDK 根目录（可为空）。
.OUTPUTS
  [string] SDK 根目录；不存在返回 $null。
#>
function Resolve-AndroidHome {
  param([string]$PreferredRoot)
  foreach ($p in (Get-AndroidSdkRootCandidate -PreferredRoot $PreferredRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path -LiteralPath $p)) {
      return (Resolve-Path -LiteralPath $p).Path
    }
  }
  return $null
}

<#
.SYNOPSIS
  在候选 SDK 根目录中查找 sdkmanager.bat。
.PARAMETER PreferredRoot
  优先使用的 SDK 根目录（可为空）。
.OUTPUTS
  [string] sdkmanager.bat 的绝对路径；未找到返回 $null。
#>
function Find-SdkManager {
  param([string]$PreferredRoot)
  foreach ($r in (Get-AndroidSdkRootCandidate -PreferredRoot $PreferredRoot)) {
    if ([string]::IsNullOrWhiteSpace($r)) { continue }
    $p = Join-Path $r 'cmdline-tools\latest\bin\sdkmanager.bat'
    if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
  }
  return $null
}

<#
.SYNOPSIS
  根据 sdkmanager.bat 的路径反推出 SDK 根目录（ANDROID_HOME）。
.PARAMETER SdkManagerPath
  sdkmanager.bat 的绝对路径。
.OUTPUTS
  [string] SDK 根目录。
#>
function Get-AndroidHomeFromSdkManager([string]$SdkManagerPath) {
  $binDir = Split-Path -Parent $SdkManagerPath
  $latestDir = Split-Path -Parent $binDir
  $cmdlineDir = Split-Path -Parent $latestDir
  $sdkRoot = Split-Path -Parent $cmdlineDir
  return (Resolve-Path -LiteralPath $sdkRoot).Path
}

<#
.SYNOPSIS
  将 gradle-wrapper.properties 的 distributionUrl 替换为国内镜像源。
.PARAMETER GenAndroidDir
  gen\android 目录路径。
.NOTES
  每次 pnpm tauri android init 会重置为官方 URL，需在 init 之后调用。
#>
function Set-GradleWrapperMirror {
  param([Parameter(Mandatory)][string]$GenAndroidDir)

  $wrapperProps = Join-Path $GenAndroidDir 'gradle\wrapper\gradle-wrapper.properties'
  if (-not (Test-Path -LiteralPath $wrapperProps)) { return }

  $content = Get-Content -LiteralPath $wrapperProps -Raw
  if ($content -match 'mirrors\.cloud\.tencent\.com') { return }

  $content = $content -replace 'https\\://services\.gradle\.org/distributions/', 'https\://mirrors.cloud.tencent.com/gradle/'
  [System.IO.File]::WriteAllText($wrapperProps, $content, [System.Text.UTF8Encoding]::new($false))
  Write-Ok "gradle-wrapper.properties 已切换为腾讯云镜像 ($wrapperProps)"
}

<#
.SYNOPSIS
  获取当前 java 的主版本号（如 17）。
.OUTPUTS
  [int] 主版本号；未找到 java 时返回 $null。
#>
function Get-JavaMajorVersion {
  if ($null -eq (Get-ExePath 'java.exe')) { return $null }
  $line = (Invoke-NativeText -FilePath 'java' -Arguments @('-version') | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($line)) { return $null }
  $m = [regex]::Match($line, '([0-9]+)')
  if (-not $m.Success) { return $null }
  return [int]$m.Groups[1].Value
}

<#
.SYNOPSIS
  断言 Java 版本 >= 17（Android/Tauri 构建所需）。
.OUTPUTS
  [bool] 满足返回 $true；不满足会输出失败提示并返回 $false。
.NOTES
  本函数只负责校验与输出；是否 exit 由调用脚本决定。
#>
function Assert-Java17 {
  # 检查 Java >= 17。OK 时 Write-Ok 并返回 $true；不满足时 Write-Fail 两条提示并返回 $false。
  # 由调用方决定是 exit 1 还是仅累积 $Failed。
  $ver = Get-JavaMajorVersion
  $hint = '请从 https://adoptium.net/ 下载 JDK 17+，或运行：winget install EclipseAdoptium.Temurin.17.JDK'
  if ($null -eq $ver) {
    Write-Fail "未找到 Java，需要 JDK 17+"
    Write-Fail $hint
    return $false
  }
  if ($ver -lt 17) {
    Write-Fail "检测到 Java $ver，但需要 JDK 17+"
    Write-Fail $hint
    return $false
  }
  Write-Ok "Java $ver 已安装：$(Get-ExePath 'java.exe')"
  return $true
}

# ─── Misc helpers ────────────────────────────────────────────────────────────
<#
.SYNOPSIS
  从类似 properties 的文本行数组里读取 key=value 的 value（自动去引号）。
.PARAMETER Lines
  文本行数组。
.PARAMETER Key
  键名。
.OUTPUTS
  [string] value；不存在返回空字符串。
#>
function Get-PropValue {
  param([string[]]$Lines, [string]$Key)
  $line = $Lines | Where-Object { $_ -match ('^' + [regex]::Escape($Key) + '\s*=') } | Select-Object -First 1
  if (-not $line) { return '' }
  return ($line -replace ('^' + [regex]::Escape($Key) + '\s*=\s*'), '').Trim().Trim('"').Trim("'")
}

# ─── Macro Deck / Capacitor helpers ──────────────────────────────────────────
<#
.SYNOPSIS
  兼容包装：按命令名解析可执行文件路径。
.PARAMETER Name
  命令名，例如 ruby、bundle、npx。
.OUTPUTS
  [string] 命令路径；不存在返回 null。
.NOTES
  保留这个包装是为了让 windows.bak 的 Ruby/Fastlane 脚本和早期实现命名兼容；
  实际解析逻辑复用模板里的 Get-ExePath。
#>
function Get-CommandPath([string]$Name) {
  Get-ExePath $Name
}

<#
.SYNOPSIS
  检查必要命令是否存在。
.PARAMETER Name
  要检查的命令名。
.PARAMETER InstallHint
  命令缺失时追加输出的安装提示。
.OUTPUTS
  [bool] 命令存在返回 true，否则返回 false。
#>
function Require-Command([string]$Name, [string]$InstallHint = '') {
  if (Get-ExePath $Name) { return $true }
  Write-Fail "缺少必要命令：$Name"
  if (-not [string]::IsNullOrWhiteSpace($InstallHint)) {
    Write-Host ""
    Write-Host $InstallHint
  }
  return $false
}

<#
.SYNOPSIS
  检查必要环境变量是否已在当前进程中设置。
.PARAMETER Name
  环境变量名。
.OUTPUTS
  [bool] 变量存在且非空返回 true。
#>
function Require-Env([string]$Name) {
  $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if (-not [string]::IsNullOrWhiteSpace($value)) { return $true }
  Write-Fail "缺少必要环境变量：$Name"
  return $false
}

<#
.SYNOPSIS
  在仓库根目录执行 native 命令。
.PARAMETER Block
  要执行的命令脚本块。
.OUTPUTS
  [int] native 命令退出码。
.NOTES
  用于 Ionic/Capacitor 命令，避免调用脚本当前目录影响结果。
#>
function Invoke-InRoot {
  param([Parameter(Mandatory)] [scriptblock]$Block)
  Invoke-NativeStreamIn -Path $script:RootDir -Block $Block
  return $LASTEXITCODE
}

<#
.SYNOPSIS
  在指定目录执行 native 命令。
.PARAMETER Path
  命令工作目录。
.PARAMETER Block
  要执行的命令脚本块。
.OUTPUTS
  [int] native 命令退出码。
#>
function Invoke-NativeIn {
  param(
    [Parameter(Mandatory)] [string]$Path,
    [Parameter(Mandatory)] [scriptblock]$Block
  )
  Invoke-NativeStreamIn -Path $Path -Block $Block
  return $LASTEXITCODE
}

<#
.SYNOPSIS
  执行 native 命令并在失败时抛出异常。
.PARAMETER Display
  用于日志展示的命令文本。
.PARAMETER Block
  要执行的命令脚本块。
.NOTES
  安装类脚本用它统一处理命令日志与退出码检查。
#>
function Invoke-Checked {
  param(
    [Parameter(Mandatory)] [string]$Display,
    [Parameter(Mandatory)] [scriptblock]$Block
  )
  Write-Host "  运行命令：$Display" -ForegroundColor Cyan
  Invoke-NativeStream -Block $Block
  if ($LASTEXITCODE -ne 0) {
    throw "$Display failed with exit code $LASTEXITCODE"
  }
}

<#
.SYNOPSIS
  通过 winget 安装指定软件包。
.PARAMETER Id
  winget 包 Id。
.PARAMETER Name
  日志中展示的软件名称。
.OUTPUTS
  [bool] 安装命令成功返回 true。
#>
function Install-WingetPackage {
  param(
    [Parameter(Mandatory)] [string]$Id,
    [Parameter(Mandatory)] [string]$Name
  )
  if (-not (Get-ExePath 'winget.exe')) {
    Write-Fail "缺少 winget，无法自动安装 $Name"
    return $false
  }
  $cmd = "winget install --id $Id --source winget --accept-package-agreements --accept-source-agreements"
  Write-Host "[CMD] $cmd" -ForegroundColor Cyan
  Invoke-NativeStream -Block { & winget install --id $Id --source winget --accept-package-agreements --accept-source-agreements }
  if ($LASTEXITCODE -ne 0) {
    Write-Fail "$Name 安装失败"
    return $false
  }
  return $true
}

<#
.SYNOPSIS
  确保前端依赖已安装。
.NOTES
  本仓库存在 npm peer dependency 冲突，因此沿用原脚本的
  npm install --legacy-peer-deps，而不是普通 npm install。
#>
function Ensure-NodeModules {
  if (Test-Path -LiteralPath (Join-Path $script:RootDir 'node_modules')) {
    Write-Ok "node_modules 已存在"
    return
  }
  Write-Warn "node_modules 不存在，准备执行 npm install --legacy-peer-deps"
  Invoke-NativeStreamIn -Path $script:RootDir -Block { & npm install --legacy-peer-deps }
  if ($LASTEXITCODE -ne 0) {
    throw "npm install --legacy-peer-deps failed with exit code $LASTEXITCODE"
  }
}

<#
.SYNOPSIS
  执行 Ionic Web 构建。
.PARAMETER Configuration
  Ionic 构建配置名，例如 development、production、web_production。
.NOTES
  会先调用 Ensure-NodeModules，确保依赖存在。
#>
function Invoke-IonicBuild([string]$Configuration) {
  Ensure-NodeModules
  Invoke-NativeStreamIn -Path $script:RootDir -Block { & npx ionic build -c $Configuration }
  if ($LASTEXITCODE -ne 0) {
    throw "ionic build failed with exit code $LASTEXITCODE"
  }
}

<#
.SYNOPSIS
  执行 Capacitor 平台同步。
.PARAMETER Platform
  Capacitor 平台名，例如 android。
#>
function Invoke-CapSync([string]$Platform) {
  Invoke-NativeStreamIn -Path $script:RootDir -Block { & npx cap sync $Platform }
  if ($LASTEXITCODE -ne 0) {
    throw "cap sync $Platform failed with exit code $LASTEXITCODE"
  }
}

<#
.SYNOPSIS
  查找包含 fastlane 声明的 Gemfile 所在目录。
.OUTPUTS
  [string] Gemfile 所在目录；找不到返回 null。
.NOTES
  优先检查 android\Gemfile，再检查仓库根 Gemfile；只有包含 gem 'fastlane'
  的 Gemfile 才会被用于 bundle exec fastlane。
#>
function Get-FastlaneBundleRoot {
  $candidates = @(
    (Join-Path $script:RootDir 'android'),
    $script:RootDir
  )
  foreach ($dir in $candidates) {
    $gemfile = Join-Path $dir 'Gemfile'
    if (-not (Test-Path -LiteralPath $gemfile)) { continue }
    $content = Get-Content -LiteralPath $gemfile -Raw
    if ($content -match "gem\s+['""]fastlane['""]") {
      return $dir
    }
  }
  return $null
}

<#
.SYNOPSIS
  解析 fastlane 调用方式。
.OUTPUTS
  [pscustomobject] 包含 Command、Arguments、Display；不可用返回 null。
.NOTES
  优先返回 bundle exec fastlane，符合 fastlane 官方推荐；只有没有可用
  Bundler/Gemfile 时才回退全局 fastlane。
#>
function Get-FastlaneCommand {
  $bundleRoot = Get-FastlaneBundleRoot
  if ($bundleRoot -and (Get-ExePath 'bundle')) {
    $env:BUNDLE_GEMFILE = Join-Path $bundleRoot 'Gemfile'
    return [pscustomobject]@{
      Command = 'bundle'
      Arguments = @('exec', 'fastlane')
      Display = 'bundle exec fastlane'
    }
  }
  if (Get-ExePath 'fastlane') {
    return [pscustomobject]@{
      Command = 'fastlane'
      Arguments = @()
      Display = 'fastlane'
    }
  }
  return $null
}

<#
.SYNOPSIS
  从 android\variables.gradle 读取 compileSdkVersion。
.OUTPUTS
  [string] Android API 版本号；读取失败默认返回 35。
#>
function Get-AndroidSdkApi {
  $variables = Join-Path $script:RootDir 'android\variables.gradle'
  if (-not (Test-Path -LiteralPath $variables)) { return '35' }
  foreach ($line in Get-Content -LiteralPath $variables) {
    if ($line -match 'compileSdkVersion\s*=\s*(\d+)') {
      return $Matches[1]
    }
  }
  return '35'
}

<#
.SYNOPSIS
  从 android\app\build.gradle 读取 Android Gradle 字段值。
.PARAMETER Key
  字段名，例如 versionCode、versionName。
.OUTPUTS
  [string] 字段值；不存在返回空字符串。
#>
function Read-AndroidGradleValue([string]$Key) {
  $gradleFile = Join-Path $script:RootDir 'android\app\build.gradle'
  if (-not (Test-Path -LiteralPath $gradleFile)) { return '' }
  foreach ($line in Get-Content -LiteralPath $gradleFile) {
    if ($line -match "^\s*$([regex]::Escape($Key))\s+(.+?)\s*$") {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

<#
.SYNOPSIS
  加载本地 Android 签名 PowerShell 配置。
.PARAMETER FilePath
  本地签名配置文件路径。
.NOTES
  期望文件设置 $env:KEYSTORE_FILE_PASSWORD 等进程环境变量；
  该文件应放在 scripts\local\android-signing.ps1，且不应提交密钥密码。
#>
function Load-AndroidSigningPs1 {
  param([string]$FilePath)
  if (-not (Test-Path -LiteralPath $FilePath)) { return }
  Write-Ok "加载 Android 签名配置：$FilePath"
  . $FilePath
}

<#
.SYNOPSIS
  输出 Android release 签名配置缺失时的修复提示。
.PARAMETER SigningFile
  推荐创建的本地签名配置文件路径。
.PARAMETER DefaultKeystore
  默认 keystore 文件路径。
.PARAMETER DefaultAlias
  默认 key alias。
#>
function Print-AndroidSigningHelp {
  param(
    [string]$SigningFile,
    [string]$DefaultKeystore,
    [string]$DefaultAlias
  )
  Write-Host ""
  Write-Host "Android release builds require a signing keystore." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Create or update:" -ForegroundColor Yellow
  Write-Host "  $SigningFile"
  Write-Host ""
  Write-Host "Minimum content:"
  Write-Host '  $env:KEYSTORE_FILE_PASSWORD = "your_keystore_password"'
  Write-Host ""
  Write-Host "Optional overrides:"
  Write-Host "  `$env:BUILD_NUMBER = `"$(Read-AndroidGradleValue 'versionCode')`""
  Write-Host "  `$env:VERSION_NUMBER = `"$(Read-AndroidGradleValue 'versionName')`""
  Write-Host "  `$env:KEYSTORE_FILE_PATH = `"$DefaultKeystore`""
  Write-Host "  `$env:KEYSTORE_FILE_ALIAS = `"$DefaultAlias`""
  Write-Host ""
  Write-Host "Create a default keystore:"
  Write-Host "  keytool -genkey -v -keystore `"$DefaultKeystore`" -keyalg RSA -keysize 2048 -validity 10000 -alias $DefaultAlias"
}
