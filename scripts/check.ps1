<#
.SYNOPSIS
    Claude 작업 유지 설정이 제대로 살아 있는지 점검합니다. 아무것도 바꾸지 않습니다.
#>
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'common.ps1')

$cfg = Read-KitConfig $PSScriptRoot
if (-not $cfg) {
    Write-Warn 'config.json 이 없습니다. setup 을 먼저 실행하세요.'
    exit 1
}

Write-Host "`nClaude 작업 유지 상태 점검 ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))" -ForegroundColor Cyan
Write-Host "작업 폴더: $($cfg.WorkDir)"

Write-Host "`n작업 맥락"
foreach ($name in 'CLAUDE.md', '작업일지.md') {
    $p = Join-Path $cfg.WorkDir $name
    if (Test-Path -LiteralPath $p) {
        Write-Ok "$name (마지막 수정 $((Get-Item -LiteralPath $p).LastWriteTime.ToString('yyyy-MM-dd HH:mm')))"
    } else {
        Write-Warn "$name 없음 - setup 을 다시 실행하면 새로 만듭니다"
    }
}

Write-Host "`nPC 깨어 있기"
$labels = @{ STANDBYIDLE = '절전'; HIBERNATEIDLE = '최대 절전' }
foreach ($s in 'STANDBYIDLE', 'HIBERNATEIDLE') {
    $v = Get-SleepSetting $s
    if ($null -eq $v) {
        Write-Info "$($labels[$s]): 확인할 수 없음"
    } elseif ($v.AC -eq 0) {
        Write-Ok "전원 연결 시 $($labels[$s]): 사용 안 함"
    } else {
        Write-Warn ("전원 연결 시 {0}: {1}분 후 - 긴 작업 때는 keep-awake.cmd 를 켜 두세요" -f $labels[$s], [math]::Round($v.AC / 60))
    }
}

Write-Host "`nClaude 앱"
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) $ShortcutName
if (Test-Path -LiteralPath $startupLnk) { Write-Ok '로그인 시 자동 실행 (시작프로그램 바로가기)' }
elseif (Test-ClaudeRunKey)             { Write-Ok '로그인 시 자동 실행 (앱 자체 설정)' }
else                                   { Write-Warn '자동 실행 설정 없음' }

# Claude Code CLI 도 claude.exe 이므로 CLI 설치 위치(.local\bin)는 빼고 찾는다.
$desktop = Get-Process -Name 'claude' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path -notlike '*\.local\bin\*' }
if ($desktop) { Write-Ok '지금 실행 중' }
else          { Write-Warn '지금 실행 중이 아님 - 앱이 꺼져 있으면 Cowork 예약 작업이 돌지 않습니다' }

Write-Host "`n백업"
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    $info = $task | Get-ScheduledTaskInfo
    if ($info.LastRunTime.Year -lt 2000) { $last = '아직 실행 안 됨' }
    elseif ($info.LastTaskResult -eq 0)  { $last = '{0:yyyy-MM-dd HH:mm} 성공' -f $info.LastRunTime }
    else                                 { $last = '{0:yyyy-MM-dd HH:mm} 실패(코드 {1})' -f $info.LastRunTime, $info.LastTaskResult }
    if ($task.State -eq 'Disabled') { Write-Warn "백업 예약이 꺼져 있음 - 마지막 $last" }
    else { Write-Ok ('매일 백업 예약됨 - 다음 {0:yyyy-MM-dd HH:mm}, 마지막 {1}' -f $info.NextRunTime, $last) }
} else {
    Write-Warn "백업 예약('$TaskName') 없음"
}

$latest = Get-ChildItem -LiteralPath $cfg.BackupDir -Filter 'claude-work-*.zip' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if ($latest) {
    $msg = '최근 백업: {0} ({1:N1} MB)' -f $latest.Name, ($latest.Length / 1MB)
    if (((Get-Date) - $latest.LastWriteTime).TotalHours -gt 48) { Write-Warn "$msg - 이틀 넘게 새 백업이 없습니다" }
    else                                                         { Write-Ok $msg }
} else {
    Write-Warn "백업 파일 없음 ($($cfg.BackupDir))"
}

Write-Host "`nRemote Control"
if (Get-Command claude -ErrorAction SilentlyContinue) { Write-Ok 'Claude Code CLI 설치됨 - Claude-remote-control.cmd 사용 가능' }
else { Write-Info 'Claude Code CLI 없음 - 쓰려면: irm https://claude.ai/install.ps1 | iex' }
Write-Host ''
