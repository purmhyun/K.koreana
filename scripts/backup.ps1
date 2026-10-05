<#
.SYNOPSIS
    작업 폴더를 zip 으로 백업하고 오래된 백업은 정리합니다.

.DESCRIPTION
    작업 스케줄러가 매일 실행합니다. 지금 바로 백업하려면 backup-now.cmd 를 실행하세요.
    .git 폴더와 백업 폴더 자체는 제외합니다. 사용 중이라 읽을 수 없는 파일은 건너뛰고 기록합니다.
    기록은 백업 폴더의 backup.log 에 남습니다.

.PARAMETER Keep
    보관할 백업 개수. 이보다 오래된 zip 은 지웁니다.
#>
[CmdletBinding()]
param(
    [string]$WorkDir,
    [string]$BackupDir,
    [int]$Keep = 14
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$cfg = Read-KitConfig $PSScriptRoot
if (-not $WorkDir)   { $WorkDir   = $cfg.WorkDir }
if (-not $BackupDir) { $BackupDir = $cfg.BackupDir }
if (-not $WorkDir -or -not $BackupDir) {
    throw 'config.json 이 없습니다. setup 을 먼저 실행하거나 -WorkDir, -BackupDir 를 지정하세요.'
}

$WorkDir = (Resolve-Path -LiteralPath $WorkDir).Path.TrimEnd('\')
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$BackupDir = (Resolve-Path -LiteralPath $BackupDir).Path.TrimEnd('\')
$logFile = Join-Path $BackupDir 'backup.log'

function Write-Log ([string]$Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

try {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

    $zipPath = Join-Path $BackupDir ('claude-work-{0:yyyyMMdd-HHmmss}.zip' -f (Get-Date))
    $sep     = [IO.Path]::DirectorySeparatorChar
    $prefix  = $WorkDir + $sep
    $files = Get-ChildItem -LiteralPath $WorkDir -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            -not $_.FullName.StartsWith($BackupDir + $sep, [StringComparison]::OrdinalIgnoreCase) -and
            $_.FullName -notmatch '[\\/]\.git[\\/]'
        }

    $added = 0
    $skipped = 0
    $zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($f in $files) {
            $entry = $f.FullName.Substring($prefix.Length).Replace('\', '/')
            try {
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $zip, $f.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
                $added++
            } catch {
                $skipped++
                Write-Log "건너뜀 (사용 중이거나 읽을 수 없음): $entry"
            }
        }
    } finally {
        $zip.Dispose()
    }

    $sizeMb = (Get-Item -LiteralPath $zipPath).Length / 1MB
    Write-Log ('백업 완료: {0} (파일 {1}개, {2:N1} MB, 건너뜀 {3}개)' -f (Split-Path -Leaf $zipPath), $added, $sizeMb, $skipped)

    Get-ChildItem -LiteralPath $BackupDir -Filter 'claude-work-*.zip' |
        Sort-Object Name -Descending |
        Select-Object -Skip $Keep |
        ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
            Write-Log "오래된 백업 삭제: $($_.Name)"
        }
} catch {
    Write-Log "백업 실패: $($_.Exception.Message)"
    exit 1
}
