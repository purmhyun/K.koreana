<#
.SYNOPSIS
    Claude가 내 컴퓨터에서 하는 작업이 끊기지 않도록 한 번에 설정합니다.

.DESCRIPTION
    1. 작업 폴더 준비: CLAUDE.md(작업 규칙), 작업일지.md, 결과물 폴더
    2. 유지용 스크립트를 작업 폴더\_maintain 에 복사
    3. 전원 연결 시 절전/최대 절전 끄기 (이전 값은 저장해 두고 uninstall 로 복원)
    4. Windows 로그인 시 Claude 데스크톱 앱 자동 실행
    5. 매일 작업 폴더를 zip 으로 백업 (작업 스케줄러)
    6. Remote Control 실행 파일 만들기

    이미 있는 CLAUDE.md, 작업일지.md 는 덮어쓰지 않으므로 여러 번 실행해도 됩니다.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 -BackupDir "D:\OneDrive\Claude-backup" -BackupTime 21:00
#>
[CmdletBinding()]
param(
    [string]$WorkDir    = 'C:\utility\Cowork task Claude setup 2026-10-05',
    [string]$BackupDir  = 'C:\utility\Claude-backup',
    [string]$BackupTime = '23:00',
    [switch]$SkipPower,
    [switch]$SkipStartup,
    [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw '이 스크립트는 Windows 에서만 실행할 수 있습니다.' }

. (Join-Path $PSScriptRoot 'common.ps1')

$KitRoot     = Split-Path -Parent $PSScriptRoot
$WorkDir     = [IO.Path]::GetFullPath($WorkDir).TrimEnd('\')
$BackupDir   = [IO.Path]::GetFullPath($BackupDir).TrimEnd('\')
$MaintainDir = Join-Path $WorkDir '_maintain'
$Utf8NoBom   = New-Object Text.UTF8Encoding $false

function Write-Step ([int]$N, [string]$Title) {
    Write-Host "`n[$N/6] $Title" -ForegroundColor Cyan
}

Write-Host "`nClaude 작업 유지 설정" -ForegroundColor Cyan
Write-Host "작업 폴더: $WorkDir"
Write-Host "백업 폴더: $BackupDir"

# ---------------------------------------------------------------------------
Write-Step 1 '작업 폴더 준비'
New-Item -ItemType Directory -Force -Path $WorkDir, (Join-Path $WorkDir '결과물') | Out-Null

$templates = [ordered]@{ 'CLAUDE.md' = 'CLAUDE.md'; 'worklog.md' = '작업일지.md' }
foreach ($src in $templates.Keys) {
    $name = $templates[$src]
    $dest = Join-Path $WorkDir $name
    if (Test-Path -LiteralPath $dest) {
        Write-Info "$name 이미 있음 (그대로 둠)"
        continue
    }
    $text = [IO.File]::ReadAllText((Join-Path $KitRoot "templates\$src"))
    $text = $text.Replace('{{DATE}}', (Get-Date -Format 'yyyy-MM-dd'))
    [IO.File]::WriteAllText($dest, $text, $Utf8NoBom)
    Write-Ok "$name 만듦"
}

# ---------------------------------------------------------------------------
Write-Step 2 '유지용 스크립트 복사 (_maintain)'
New-Item -ItemType Directory -Force -Path $MaintainDir | Out-Null
foreach ($f in 'common.ps1', 'backup.ps1', 'keep-awake.ps1', 'check.ps1', 'uninstall.ps1') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $f) -Destination $MaintainDir -Force
}

$launchers = [ordered]@{
    'check.cmd'      = 'check.ps1'
    'backup-now.cmd' = 'backup.ps1'
    'keep-awake.cmd' = 'keep-awake.ps1'
    'uninstall.cmd'  = 'uninstall.ps1'
}
foreach ($cmd in $launchers.Keys) {
    Set-Content -LiteralPath (Join-Path $MaintainDir $cmd) -Encoding ASCII -Value @(
        '@echo off',
        "powershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0$($launchers[$cmd])`" %*",
        'pause'
    )
}
Get-ChildItem -LiteralPath $MaintainDir -File | Unblock-File

[ordered]@{ WorkDir = $WorkDir; BackupDir = $BackupDir } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $MaintainDir 'config.json') -Encoding UTF8
Write-Ok "$MaintainDir 에 check / backup-now / keep-awake / uninstall 준비"

# ---------------------------------------------------------------------------
Write-Step 3 '전원 연결 시 절전 끄기'
if ($SkipPower) {
    Write-Info '건너뜀 (-SkipPower). 필요할 때 _maintain\keep-awake.cmd 를 쓰세요.'
} else {
    $powerFile = Join-Path $MaintainDir 'power-backup.json'
    # 다시 실행해도 처음 값(0 이 아닌 원래 값)을 잃지 않도록 한 번만 저장한다.
    if (-not (Test-Path -LiteralPath $powerFile)) {
        $saved = [ordered]@{}
        foreach ($s in 'STANDBYIDLE', 'HIBERNATEIDLE') {
            $v = Get-SleepSetting $s
            $saved[$s] = if ($v) { $v.AC } else { $null }
        }
        $saved | ConvertTo-Json | Set-Content -LiteralPath $powerFile -Encoding UTF8
        Write-Info "원래 값 저장: $powerFile"
    }
    $labels = @{ STANDBYIDLE = '절전'; HIBERNATEIDLE = '최대 절전' }
    foreach ($s in 'STANDBYIDLE', 'HIBERNATEIDLE') {
        if (Set-AcSleepSetting $s 0) { Write-Ok "전원 연결 시 $($labels[$s]): 사용 안 함" }
        else { Write-Warn "$($labels[$s]) 설정을 바꾸지 못했습니다" }
    }
    powercfg /setactive SCHEME_CURRENT | Out-Null
    Write-Info '배터리 사용 시 설정과 화면 끄기 시간은 그대로 둡니다.'
}

# ---------------------------------------------------------------------------
Write-Step 4 '로그인 시 Claude 데스크톱 앱 자동 실행'
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) $ShortcutName
if ($SkipStartup) {
    Write-Info '건너뜀 (-SkipStartup)'
} elseif (Test-Path -LiteralPath $startupLnk) {
    Write-Info '시작프로그램 바로가기가 이미 있음'
} elseif (Test-ClaudeRunKey) {
    Write-Ok 'Claude 앱이 이미 자동 실행되도록 설정되어 있음'
} else {
    $app = Find-ClaudeDesktop
    if ($app) {
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut($startupLnk)
        $lnk.TargetPath = $app.Target
        $lnk.Arguments  = $app.Arguments
        $lnk.Save()
        Write-Ok "시작프로그램에 등록: $startupLnk"
    } else {
        Write-Warn 'Claude 데스크톱 앱을 찾지 못했습니다.'
        Write-Warn '앱을 설치한 뒤 setup 을 다시 실행하거나, Win+R > shell:startup 폴더에 Claude 바로가기를 넣으세요.'
    }
}

# ---------------------------------------------------------------------------
Write-Step 5 "매일 $BackupTime 작업 폴더 백업"
if ($SkipBackup) {
    Write-Info '건너뜀 (-SkipBackup)'
} else {
    $backupScript = Join-Path $MaintainDir 'backup.ps1'
    try {
        $action   = New-ScheduledTaskAction -Execute 'powershell.exe' `
            -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$backupScript`""
        $trigger  = New-ScheduledTaskTrigger -Daily -At ([datetime]$BackupTime)
        # PC가 꺼져 있어 놓친 백업은 다음에 켜졌을 때 바로 실행한다.
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
            -Description "Claude 작업 폴더($WorkDir)를 $BackupDir 에 zip 으로 백업" -Force | Out-Null
        Write-Ok "작업 스케줄러 등록: '$TaskName'"
    } catch {
        Write-Warn "작업 스케줄러 등록 실패: $($_.Exception.Message)"
        Write-Warn 'PowerShell 을 관리자 권한으로 열고 setup 을 다시 실행해 보세요.'
    }
    Write-Info '첫 백업을 지금 실행합니다...'
    & $backupScript
}

# ---------------------------------------------------------------------------
Write-Step 6 'Remote Control (밖에서 휴대폰/웹으로 이어가기)'
$rcFile = Join-Path $WorkDir 'Claude-remote-control.cmd'
Set-Content -LiteralPath $rcFile -Encoding ASCII -Value @(
    '@echo off',
    'cd /d "%~dp0"',
    'claude remote-control',
    'pause'
)
Write-Ok "실행 파일 만듦: $rcFile"
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Warn 'Claude Code CLI(claude 명령)가 없습니다. Remote Control 을 쓰려면 PowerShell 에서 설치하세요:'
    Write-Warn '    irm https://claude.ai/install.ps1 | iex'
}

# ---------------------------------------------------------------------------
Write-Host "`n설정 완료." -ForegroundColor Green
Write-Host @"

이제 이렇게 쓰세요:
  - Claude(Cowork 또는 Claude Code)에서 이 폴더를 열고 첫 메시지로:
        "CLAUDE.md 와 작업일지.md 를 먼저 읽고 이어서 진행해줘"
  - 작업을 끝낼 때:
        "작업일지.md 에 오늘 한 일과 다음 할 일을 적어줘"
  - 상태 점검:      $MaintainDir\check.cmd
  - 설정 되돌리기:  $MaintainDir\uninstall.cmd
"@
