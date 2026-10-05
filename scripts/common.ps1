# 여러 스크립트가 함께 쓰는 값과 함수 모음입니다. 직접 실행하지 않습니다.

$TaskName     = 'Claude Work Backup'
$ShortcutName = 'Claude Desktop (keep).lnk'

function Write-Ok   ([string]$Message) { Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Info ([string]$Message) { Write-Host "  [--] $Message" -ForegroundColor Gray }
function Write-Warn ([string]$Message) { Write-Host "  [!!] $Message" -ForegroundColor Yellow }

function Read-KitConfig ([string]$Dir) {
    $file = Join-Path $Dir 'config.json'
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
}

# 현재 전원 관리 옵션의 절전 관련 값(초)을 읽는다.
# powercfg 출력 문구는 Windows 언어마다 다르므로 16진수 값만 뽑는다.
# 마지막 두 값이 각각 AC(전원 연결)와 DC(배터리)의 현재 값이다.
function Get-SleepSetting ([string]$Setting) {
    $out = (powercfg /query SCHEME_CURRENT SUB_SLEEP $Setting) | Out-String
    if ($LASTEXITCODE -ne 0) { return $null }
    $hex = @([regex]::Matches($out, '0x[0-9a-fA-F]{8}') | ForEach-Object { $_.Value })
    if ($hex.Count -lt 2) { return $null }
    [pscustomobject]@{
        AC = [Convert]::ToUInt32($hex[-2], 16)
        DC = [Convert]::ToUInt32($hex[-1], 16)
    }
}

# 전원 연결(AC) 상태의 값만 바꾼다. 배터리 설정은 건드리지 않는다.
# 바꾼 뒤에는 powercfg /setactive SCHEME_CURRENT 로 적용해야 한다.
function Set-AcSleepSetting ([string]$Setting, [uint32]$Seconds) {
    powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP $Setting $Seconds | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Test-ClaudeRunKey {
    $run = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
    if (-not $run) { return $false }
    foreach ($p in $run.PSObject.Properties) {
        if ($p.Name -notlike 'PS*' -and "$($p.Name) $($p.Value)" -match 'claude') { return $true }
    }
    return $false
}

# Claude 데스크톱 앱 실행 파일을 찾는다. 설치 방식에 따라 위치가 다르다.
function Find-ClaudeDesktop {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Claude\Claude.exe'),
        (Join-Path $env:ProgramFiles 'Claude\Claude.exe')
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return @{ Target = $p; Arguments = '' } }
    }
    try {
        $pkg = Get-AppxPackage -ErrorAction Stop |
            Where-Object { $_.Name -like '*Claude*' -and $_.Publisher -like '*Anthropic*' } |
            Select-Object -First 1
        if ($pkg) {
            $appId = (Get-AppxPackageManifest -Package $pkg.PackageFullName).Package.Applications.Application |
                Select-Object -First 1 -ExpandProperty Id
            return @{
                Target    = Join-Path $env:WINDIR 'explorer.exe'
                Arguments = "shell:AppsFolder\$($pkg.PackageFamilyName)!$appId"
            }
        }
    } catch { }
    return $null
}
