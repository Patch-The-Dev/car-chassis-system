param([string]$StudioPath)

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$place = Join-Path $env:TEMP 'CarChassisTestPlace.rbxlx'
$output = Join-Path $env:TEMP 'CarChassisTestReport.log'
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

Remove-Item -LiteralPath $output -ErrorAction SilentlyContinue
$runner = Join-Path $PSScriptRoot 'RunInStudio.luau'
$arguments = '--task RunScript --localPlaceFile "{0}" --runScriptFile "{1}" --outputFile "{2}" --quitAfterExecution' -f $place, $runner, $output
$process = Start-Process -FilePath $StudioPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
$deadline = (Get-Date).AddSeconds(120)
$report = ''
while ((Get-Date) -lt $deadline) {
    if (Test-Path -LiteralPath $output) {
        $report = Get-Content -LiteralPath $output -Raw
        if ($report -match '(?m)^CAR_CHASSIS_TESTS_PASS\s*$') { break }
    }
    $process.Refresh()
    if ($process.HasExited) { break }
    Start-Sleep -Milliseconds 500
}
if ($report -notmatch '(?m)^\d+ passed, 0 failed\s*$' -or $report -notmatch '(?m)^CAR_CHASSIS_TESTS_PASS\s*$') {
    $process.Refresh()
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
    if ($report) { Write-Output $report }
    throw 'Studio did not report a passing chassis check.'
}
$report -split '\r?\n' | Where-Object { $_ -match '^\d+ passed, 0 failed$|^CAR_CHASSIS_TESTS_PASS$' } | Select-Object -Last 2
