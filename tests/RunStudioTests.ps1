param(
    [string]$StudioPath,
    [ValidateSet('All', 'Structural', 'Integration')][string]$Suite = 'All',
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$invocation = [guid]::NewGuid().ToString('N')
$place = Join-Path $env:TEMP "CarChassis-$invocation.rbxlx"
$rojo = Join-Path $env:USERPROFILE '.rokit\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe'
if (-not (Test-Path -LiteralPath $rojo)) { $rojo = (Get-Command rojo -ErrorAction SilentlyContinue).Source }
if (-not $rojo -or -not (Test-Path -LiteralPath $rojo)) {
    throw 'Rojo was not found. Install the pinned tools with rokit install.'
}
if (-not $StudioPath) {
    $StudioPath = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox\Versions\*\RobloxStudioBeta.exe') -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $StudioPath -or -not (Test-Path -LiteralPath $StudioPath)) {
    throw 'Roblox Studio was not found. Pass -StudioPath with the installed executable.'
}

Push-Location $repository
try {
    & $rojo build test.project.json --output $place
    if ($LASTEXITCODE -ne 0) { throw 'The Rojo test build failed.' }
} finally {
    Pop-Location
}

function Invoke-StudioCheck([string]$RunnerName, [string]$ReportName, [string]$Marker) {
    $output = Join-Path $env:TEMP ($invocation + '-' + $ReportName)
    $consoleOutput = $output + '.console.log'
    Remove-Item -LiteralPath $output -ErrorAction SilentlyContinue
    $runner = Join-Path $PSScriptRoot $RunnerName
    $arguments = '--task RunScript --localPlaceFile "{0}" --runScriptFile "{1}" --outputFile "{2}" --quitAfterExecution' -f $place, $runner, $output
    $process = Start-Process -FilePath $StudioPath -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $consoleOutput -PassThru
    $startedAt = Get-Date
    $deadline = (Get-Date).AddSeconds(180)
    $report = ''
    $runtimeMetrics = $null
    $markerPattern = '(?m)^' + [regex]::Escape($Marker) + '\s*$'
    while ((Get-Date) -lt $deadline) {
        $report = ''
        if (Test-Path -LiteralPath $output) {
            $report = Get-Content -LiteralPath $output -Raw
        }
        if (Test-Path -LiteralPath $consoleOutput) {
            $console = (Get-Content -LiteralPath $consoleOutput -Raw) -replace '(?m)^.*\[FLog::Output\] ', ''
            $report += "`n" + $console
        }
        # Multiplayer server output lives in a child Studio process. Only accept
        # a result carrying this invocation's unique ID, never an older test log.
        if ($report -match '(?m)^CAR_CHASSIS_RUN_ID:([a-fA-F0-9-]+)\s*$') {
            $runId = $Matches[1]
            $resultPattern = 'CAR_CHASSIS_RESULT:' + [regex]::Escape($runId) + ':(PASS|FAIL):(.+)$'
            $logDirectory = Join-Path $env:LOCALAPPDATA 'Roblox\logs'
            $newLogs = Get-ChildItem -LiteralPath $logDirectory -Filter '*_Studio_*.log' -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -ge $startedAt }
            foreach ($log in $newLogs) {
                $resultLine = Select-String -LiteralPath $log.FullName -Pattern $resultPattern -ErrorAction SilentlyContinue | Select-Object -Last 1
                if ($resultLine -and $resultLine.Line -match $resultPattern) {
                    if ($Matches[1] -eq 'PASS') {
                        $report += "`n$($Matches[2]) integration checks passed`n$Marker`n"
                        $metricsPattern = 'CAR_CHASSIS_METRICS:' + [regex]::Escape($runId) + ':(.+)$'
                        $metricsLine = Select-String -LiteralPath $log.FullName -Pattern $metricsPattern -ErrorAction SilentlyContinue | Select-Object -Last 1
                        if ($metricsLine -and $metricsLine.Line -match $metricsPattern) { $runtimeMetrics = $Matches[1] | ConvertFrom-Json }
                    } else {
                        $report += "`nCAR_CHASSIS_INTEGRATION_FAILURE: $($Matches[2])`n"
                    }
                    break
                }
            }
        }
        if ($report -match $markerPattern) { break }
        if ($report -match '(?m)^CAR_CHASSIS_INTEGRATION_FAILURE:|^RunScript:\d+:') { break }
        $process.Refresh()
        if ($process.HasExited) { break }
        Start-Sleep -Milliseconds 500
    }
    if ($report -notmatch $markerPattern) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
        if ($report) {
            $report -split '\r?\n' | Where-Object { $_ -match '^CAR_CHASSIS_INTEGRATION_FAILURE:|^RunScript:\d+:|^Stack (Begin|End)|^Script .*Line' } | ForEach-Object { Write-Host $_ }
        }
        throw "Studio did not report a passing result for $RunnerName."
    }
    $lines = $report -split '\r?\n' | Where-Object { $_ -match '^\d+ (passed, 0 failed|integration checks passed)$' -or $_ -eq $Marker } | Select-Object -Last 2
    $lines | ForEach-Object { Write-Host $_ }
    $countLine = $lines | Where-Object { $_ -match '^\d+ ' } | Select-Object -Last 1
    if (-not $countLine -or $countLine -notmatch '^(\d+) ') { throw 'Studio returned a marker without a check count.' }
    $checks = [int]$Matches[1]
    if ($RunnerName -eq 'RunPlayTest.luau' -and $runtimeMetrics -eq $null) {
        $metricsPattern = '(?m)^CAR_CHASSIS_METRICS:' + [regex]::Escape($runId) + ':(.+)$'
        if ($report -match $metricsPattern) { $runtimeMetrics = $Matches[1] | ConvertFrom-Json }
        if ($runtimeMetrics -eq $null) { throw 'Multiplayer suite returned no fleet measurement.' }
    }
    return [pscustomobject]@{ suite = $RunnerName; status = 'passed'; checks = $checks; metrics = $runtimeMetrics }
}

$results = [System.Collections.Generic.List[object]]::new()
$completed = $false
$failureReason = $null
try {
    if ($Suite -in @('All', 'Structural')) {
        $results.Add((Invoke-StudioCheck 'RunInStudio.luau' 'CarChassisTestReport.log' 'CAR_CHASSIS_TESTS_PASS'))
    }
    if ($Suite -in @('All', 'Integration')) {
        $results.Add((Invoke-StudioCheck 'RunPlayTest.luau' 'CarChassisIntegrationReport.log' 'CAR_CHASSIS_INTEGRATION_PASS'))
    }
    $completed = $true
} catch {
    $failureReason = $_.Exception.Message
    throw
} finally {
    if ($ReportPath) {
        $absoluteReport = [System.IO.Path]::GetFullPath($ReportPath)
        New-Item -ItemType Directory -Path (Split-Path -Parent $absoluteReport) -Force | Out-Null
        [ordered]@{
            commit = (git -C $repository rev-parse HEAD)
            workingTreeDirty = [bool](git -C $repository status --porcelain)
            finishedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            status = $(if ($completed) { 'passed' } else { 'failed' })
            suites = @($results.ToArray())
            error = $failureReason
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $absoluteReport -Encoding utf8
    }
}
