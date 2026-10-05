<#
.SYNOPSIS
    이 창이 열려 있는 동안 PC가 절전 모드로 들어가지 않게 합니다.

.DESCRIPTION
    전원 설정을 바꾸지 않고, 실행 중일 때만 절전을 막습니다.
    화면은 꺼질 수 있지만 PC와 Claude 작업은 계속 돌아갑니다.
    창을 닫거나 Ctrl+C 를 누르면 원래대로 돌아갑니다.
    setup 에서 -SkipPower 로 전원 설정을 그대로 둔 경우, 긴 작업을 맡길 때 쓰세요.

.PARAMETER Hours
    이 시간이 지나면 자동으로 끝납니다. 0 이면 창을 닫을 때까지 유지합니다.

.EXAMPLE
    .\keep-awake.ps1 -Hours 8
#>
[CmdletBinding()]
param([double]$Hours = 0)

Add-Type -Namespace ClaudeKit -Name Power -MemberDefinition @'
[DllImport("kernel32.dll")]
public static extern uint SetThreadExecutionState(uint esFlags);
'@

$ES_CONTINUOUS      = [uint32]2147483648   # 0x80000000
$ES_SYSTEM_REQUIRED = [uint32]1
$keepAwake          = [uint32]2147483649   # ES_CONTINUOUS | ES_SYSTEM_REQUIRED

if ([ClaudeKit.Power]::SetThreadExecutionState($keepAwake) -eq 0) {
    throw '절전 방지를 설정하지 못했습니다.'
}

$until = if ($Hours -gt 0) { (Get-Date).AddHours($Hours) } else { [datetime]::MaxValue }
if ($Hours -gt 0) {
    Write-Host ("절전 방지 중: {0:yyyy-MM-dd HH:mm} 까지. 끝내려면 이 창을 닫거나 Ctrl+C." -f $until) -ForegroundColor Green
} else {
    Write-Host '절전 방지 중: 이 창을 닫거나 Ctrl+C 를 누를 때까지.' -ForegroundColor Green
}

try {
    while ((Get-Date) -lt $until) {
        [void][ClaudeKit.Power]::SetThreadExecutionState($keepAwake)
        $Host.UI.RawUI.WindowTitle = "Claude 작업 유지 - 절전 방지 중 ($(Get-Date -Format 'HH:mm') 확인)"
        Start-Sleep -Seconds 60
    }
} finally {
    [void][ClaudeKit.Power]::SetThreadExecutionState($ES_CONTINUOUS)
    Write-Host '절전 방지를 해제했습니다.'
}
