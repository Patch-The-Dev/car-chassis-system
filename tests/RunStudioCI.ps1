param(
    [Parameter(Mandatory = $true)][string]$ReportPath
)

$ErrorActionPreference = 'Stop'
# All three repositories share this lock when their runners use the same desktop.
$studioLock = [System.Threading.Mutex]::new($false, 'Local\PatchTheDev.RobloxStudioCI')
$ownsLock = $false
try {
    try {
        $ownsLock = $studioLock.WaitOne([TimeSpan]::FromMinutes(10))
    } catch [System.Threading.AbandonedMutexException] {
        # Windows transferred ownership after the previous test process exited.
        $ownsLock = $true
    }
    if (-not $ownsLock) {
        throw 'Another Studio suite did not release the shared runner within ten minutes.'
    }
    & (Join-Path $PSScriptRoot 'RunStudioTests.ps1') -ReportPath $ReportPath
} finally {
    if ($ownsLock) { $studioLock.ReleaseMutex() }
    $studioLock.Dispose()
}
