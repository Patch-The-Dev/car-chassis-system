param(
    [string]$StudioPath,
    [ValidateSet('All', 'Structural', 'Integration')][string]$Suite = 'All'
)

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$place = Join-Path $env:TEMP 'CarChassisTestPlace.rbxlx'
$rojo = (Get-Command rojo -ErrorAction SilentlyContinue).Source
if (-not $rojo) {
    $rojo = Join-Path $env:USERPROFILE '.rokit\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe'
}
if (-not (Test-Path -LiteralPath $rojo)) {
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
    $output = Join-Path $env:TEMP $ReportName
    $consoleOutput = Join-Path $env:TEMP ($ReportName + '.console.log')
    Remove-Item -LiteralPath $output -ErrorAction SilentlyContinue
    $runner = Join-Path $PSScriptRoot $RunnerName
    $arguments = '--task RunScript --localPlaceFile "{0}" --runScriptFile "{1}" --outputFile "{2}" --quitAfterExecution' -f $place, $runner, $output
    $process = Start-Process -FilePath $StudioPath -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $consoleOutput -PassThru
    $deadline = (Get-Date).AddSeconds(120)
    $report = ''
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
            $report -split '\r?\n' | Where-Object { $_ -match '^CAR_CHASSIS_INTEGRATION_FAILURE:|^RunScript:\d+:|^Stack (Begin|End)|^Script .*Line' }
        }
        throw "Studio did not report a passing result for $RunnerName."
    }
    $report -split '\r?\n' | Where-Object { $_ -match '^\d+ (passed, 0 failed|integration checks passed)$' -or $_ -eq $Marker } | Select-Object -Last 2
}

if ($Suite -in @('All', 'Structural')) {
    Invoke-StudioCheck 'RunInStudio.luau' 'CarChassisTestReport.log' 'CAR_CHASSIS_TESTS_PASS'
}
if ($Suite -in @('All', 'Integration')) {
    Invoke-StudioCheck 'RunPlayTest.luau' 'CarChassisIntegrationReport.log' 'CAR_CHASSIS_INTEGRATION_PASS'
}
