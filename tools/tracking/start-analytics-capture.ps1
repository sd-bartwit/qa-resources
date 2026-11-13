<#
.SYNOPSIS
    Enables Firebase Analytics debug logging on an Android device and starts capturing it.
.PARAMETER Package
    App id to put into Firebase debug mode.
.PARAMETER Serial
    Device serial (adb devices). Required only when several devices are connected.
#>
[CmdletBinding()]
param(
    [string]$Package = 'be.sdworx.sdwa.inhouse',
    [string]$Serial
)

$ErrorActionPreference = 'Stop'
$outRoot   = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\output\tracking'))
$stateDir  = Join-Path $outRoot '.capture'
$statePath = Join-Path $stateDir 'state.json'
$tempLog   = Join-Path $stateDir 'current.log'
$errLog    = Join-Path $stateDir 'logcat.err'

$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if ($adbCmd) { $adb = $adbCmd.Source }
else {
    $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (-not (Test-Path $adb)) { throw 'adb not found. Install Android platform-tools or add adb to PATH.' }
}

$devices = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' })
if ($devices.Count -eq 0) { throw 'No authorised device connected.' }
if (-not $Serial -and $devices.Count -gt 1) { throw 'Several devices connected. Pass -Serial <id>.' }
$a = @(); if ($Serial) { $a = @('-s', $Serial) }

New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

# Stop a capture left over from a previous run
if (Test-Path $statePath) {
    $old = Get-Content $statePath -Raw | ConvertFrom-Json
    Stop-Process -Id $old.pid -ErrorAction SilentlyContinue
    Write-Warning 'A previous capture was still active; it was stopped and its log discarded.'
}

& $adb @a shell setprop log.tag.FA VERBOSE
& $adb @a shell setprop log.tag.FA-SVC VERBOSE
& $adb @a shell setprop debug.firebase.analytics.app $Package
& $adb @a logcat -c

$proc = Start-Process -FilePath $adb `
    -ArgumentList ($a + @('logcat', '-v', 'time', '-s', 'FA', 'FA-SVC')) `
    -RedirectStandardOutput $tempLog -RedirectStandardError $errLog `
    -WindowStyle Hidden -PassThru

[pscustomobject]@{
    pid       = $proc.Id
    package   = $Package
    serial    = $Serial
    startedAt = (Get-Date).ToString('s')
} | ConvertTo-Json | Set-Content $statePath

Write-Host "Capture started for $Package (logcat pid $($proc.Id))."
Write-Host 'Close the app from the recents screen and reopen it now - debug mode is only read at app start.'
Write-Host 'When finished run: .\stop-analytics-capture.ps1'
