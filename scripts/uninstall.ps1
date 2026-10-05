<#
.SYNOPSIS
    setup 이 바꾼 설정을 되돌립니다. 작업 파일과 백업 zip 은 지우지 않습니다.
#>
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host "`nClaude 작업 유지 설정 되돌리기" -ForegroundColor Cyan

$powerFile = Join-Path $PSScriptRoot 'power-backup.json'
if (Test-Path -LiteralPath $powerFile) {
    $saved  = Get-Content -LiteralPath $powerFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $labels = @{ STANDBYIDLE = '절전'; HIBERNATEIDLE = '최대 절전' }
    $allOk  = $true
    foreach ($s in 'STANDBYIDLE', 'HIBERNATEIDLE') {
        if ($null -eq $saved.$s) { continue }
        if (Set-AcSleepSetting $s ($saved.$s)) {
            Write-Ok ("전원 연결 시 {0}: 원래 값으로 복원 ({1})" -f $labels[$s], $(if ($saved.$s -eq 0) { '사용 안 함' } else { "$([math]::Round($saved.$s / 60))분" }))
        } else {
            Write-Warn "$($labels[$s]) 복원 실패"
            $allOk = $false
        }
    }
    powercfg /setactive SCHEME_CURRENT | Out-Null
    if ($allOk) { Remove-Item -LiteralPath $powerFile }
} else {
    Write-Info '저장된 전원 설정 없음 (setup 이 전원 설정을 바꾸지 않았음)'
}

$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) $ShortcutName
if (Test-Path -LiteralPath $startupLnk) {
    Remove-Item -LiteralPath $startupLnk
    Write-Ok 'Claude 앱 자동 실행 바로가기 삭제'
} else {
    Write-Info '자동 실행 바로가기 없음'
}

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Ok "백업 예약('$TaskName') 삭제"
} else {
    Write-Info '백업 예약 없음'
}

Write-Host "`nCLAUDE.md, 작업일지.md, 결과물 폴더와 백업 zip 은 그대로 두었습니다."
Write-Host '_maintain 폴더와 Claude-remote-control.cmd 는 필요 없으면 직접 지우세요.'
