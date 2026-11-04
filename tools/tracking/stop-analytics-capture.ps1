<#
.SYNOPSIS
    Stops the capture, saves the raw log, switches all Firebase Analytics logging off
    and writes a report of what the app sent to Firebase and whether the uploads succeeded.
.PARAMETER Serial
    Device serial. Defaults to the one used by start-analytics-capture.ps1.
.PARAMETER LogFile
    Only analyse an existing raw log (no device access, nothing is stopped or disabled).
#>
[CmdletBinding()]
param(
    [string]$Serial,
    [string]$LogFile
)

$ErrorActionPreference = 'Stop'
$outRoot   = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\output\tracking'))
$stateDir  = Join-Path $outRoot '.capture'
$statePath = Join-Path $stateDir 'state.json'
$tempLog   = Join-Path $stateDir 'current.log'
$outDir    = Join-Path $outRoot 'logs_raw'
$reportDir = Join-Path $outRoot 'reports'

function Get-AnalyticsReport {
    param([string]$Path, [string]$OutDir)

    # Raw logs can be UTF-16 (Tee-Object) or UTF-8 (capture script)
    $fs = [IO.File]::OpenRead($Path); $h = New-Object byte[] 2; [void]$fs.Read($h, 0, 2); $fs.Close()
    $enc = if ($h[0] -eq 0xFF -and $h[1] -eq 0xFE) { 'Unicode' } else { 'UTF8' }
    $lines = @(Get-Content -Path $Path -Encoding $enc)

    $rx    = '^(\d\d-\d\d) (\d\d:\d\d:\d\d\.\d{3}) ([VDIWEF])/(FA-SVC|FA)\s*\(\s*\d+\): ?(.*)$'
    $short = '\(_[^)]*\)$'

    $batches  = New-Object System.Collections.Generic.List[object]
    $filtered = New-Object System.Collections.Generic.List[string]
    $loggedBy = @{}; $props = @{}; $issues = @{}; $rejected = @{}; $reasons = @{}; $meta = @{}
    $first = $null; $last = $null
    $cur = $null; $inBatch = $false; $ctx = ''; $ev = $null; $pn = ''; $pv = ''

    foreach ($line in $lines) {
        if ($line -notmatch $rx) { continue }
        $stamp = "$($Matches[1]) $($Matches[2])"; $level = $Matches[3]; $tag = $Matches[4]; $msg = $Matches[5]
        if (-not $first) { $first = $stamp }
        $last = $stamp
        $keep = $false

        if (($level -in 'E', 'W') -and $tag -eq 'FA') {
            $keep = $true
            if ($msg -match '^(.*?)\. Type, name: \w+, (\S+)$') { $reasons[$Matches[2]] = $Matches[1] }
            elseif ($msg -match 'Event will not be logged.*: (\S+)$') { $rejected[$Matches[1]] = 1 + [int]$rejected[$Matches[1]] }
            else { $issues[$msg] = 1 + [int]$issues[$msg] }
        }

        if ($msg -match '^Logging event: origin=\w+,name=(.+?),params=') {
            $n = $Matches[1] -replace $short, ''
            $loggedBy[$n] = 1 + [int]$loggedBy[$n]; $keep = $true
        }
        elseif ($msg -match '^Setting user property: (.+?), (.*)$') {
            $keep = $true
            if ($Matches[1] -notmatch $short) { $k = "$($Matches[1])`t$($Matches[2])"; $props[$k] = 1 + [int]$props[$k] }
        }
        elseif ($tag -eq 'FA-SVC') {
            $t = $msg.Trim()
            if ($inBatch) {
                if ($t -like '} // End-of-batch*') { $inBatch = $false }
                elseif ($t -eq 'event {') { $ev = @{ name = ''; ms = [int64]0; params = [ordered]@{} }; $ctx = 'event' }
                elseif ($t -eq 'user_property {') { $ctx = 'up' }
                elseif ($t -eq 'param {') { $pn = ''; $pv = ''; $ctx = 'param' }
                elseif ($t -eq '}') {
                    if ($ctx -eq 'param') { $ev.params[$pn] = $pv; $ctx = 'event' }
                    elseif ($ctx -eq 'event') { $cur.Events.Add($ev); $ctx = 'bundle' }
                    elseif ($ctx -eq 'up') { $ctx = 'bundle' }
                }
                elseif ($t -match '^(\w+): ?(.*)$') {
                    $k = $Matches[1]; $v = $Matches[2]
                    if ($ctx -eq 'bundle') {
                        if ($k -eq 'time_zone_offset_minutes') { $cur.Tz = [int]$v }
                        elseif ($k -in 'app_id', 'app_version', 'device_model', 'os_version') { $meta[$k] = $v }
                    }
                    elseif ($ctx -eq 'event') {
                        if ($k -eq 'name') { $ev.name = $v } elseif ($k -eq 'timestamp_millis') { $ev.ms = [int64]$v }
                    }
                    elseif ($ctx -eq 'param') {
                        if ($k -eq 'name') { $pn = $v -replace $short, '' }
                        elseif (($k -in 'string_value', 'int_value', 'double_value') -and $v -ne '') { $pv = $v }
                    }
                }
            }
            elseif ($msg -match '^Uploading data\. app, uncompressed size, data: \S+, (\d+)') {
                $keep = $true
                $cur = [pscustomobject]@{ Size = [int]$Matches[1]; Events = (New-Object System.Collections.Generic.List[object]); Status = 'none'; Code = ''; Tz = 0 }
                $batches.Add($cur)
            }
            elseif ($msg -match '^batch \{') { $inBatch = $true; $ctx = 'bundle' }
            elseif ($cur -and $msg -match '^Network upload \w+ with code, uploadAttempted: (\d+)') {
                $keep = $true
                $cur.Code = $Matches[1]
                $cur.Status = if ($Matches[1] -match '^2\d\d$') { 'ok' } else { 'failed' }
            }
            elseif ($msg -match '^Successful upload') { $keep = $true }
            elseif ($cur -and $cur.Status -ne 'ok' -and $msg -match '(?i)(upload|network).*(fail|error|exception|unsuccessful)') {
                $keep = $true; $cur.Status = 'failed'
            }
        }
        if ($keep) { $filtered.Add($line) }
    }

    # One row per event actually present in an uploaded batch (retries are de-duplicated, OK wins)
    $byKey = @{}
    foreach ($b in $batches) {
        $state = switch ($b.Status) { 'ok' { "OK ($($b.Code))" } 'failed' { "FAILED ($($b.Code))" } default { 'no result' } }
        $rank = switch ($b.Status) { 'ok' { 2 } 'failed' { 1 } default { 0 } }
        foreach ($e in $b.Events) {
            $key = "$($e.ms)|$($e.name)"
            if ($byKey.ContainsKey($key) -and $byKey[$key].Rank -ge $rank) { continue }
            $p = $e.params
            $name = $e.name -replace $short, ''
            $origin = [string]$p['ga_event_origin']
            $detail = @($p.Keys | Where-Object { $_ -notmatch '^(ga_|_)' -and $_ -ne 'engagement_time_msec' } | ForEach-Object { "$_=$($p[$_])" })
            if ($name -eq 'screen_view' -and $p['ga_previous_screen']) { $detail = @("from=$($p['ga_previous_screen'])") + $detail }
            if ($name -eq 'error' -and $p['ga_error_value']) { $detail = @("rejected=$($p['ga_error_value'])") + $detail }
            $kind = if ($name -eq 'screen_view') { 'Screen' }
                    elseif ($name -eq 'error' -and $origin -eq 'auto') { 'SDK error' }
                    elseif ($origin -eq 'auto') { 'Auto' }
                    else { 'App' }
            $time = [DateTimeOffset]::FromUnixTimeMilliseconds($e.ms).ToOffset([TimeSpan]::FromMinutes($b.Tz)).ToString('HH:mm:ss.fff')
            $byKey[$key] = [pscustomobject]@{
                Ms = $e.ms; Time = $time; Kind = $kind; Event = $name; Screen = [string]$p['ga_screen']
                Details = ($detail -join '; '); Upload = $state; Origin = $origin; Debug = $p.Contains('_dbg'); Rank = $rank
            }
        }
    }
    $rows = @($byKey.Values | Sort-Object Ms)

    $nameSet = @{}
    foreach ($r in $rows) { $nameSet[$r.Event] = 1 }
    foreach ($k in $loggedBy.Keys) { $nameSet[$k] = 1 }
    $summary = @(foreach ($n in $nameSet.Keys) {
        $mine = @($rows | Where-Object { $_.Event -eq $n })
        $ok  = @($mine | Where-Object { $_.Upload -like 'OK*' }).Count
        $bad = @($mine | Where-Object { $_.Upload -like 'FAILED*' }).Count
        $total = [Math]::Max([int]$loggedBy[$n], $mine.Count)
        [pscustomobject]@{
            Event = $n; Kind = $(if ($mine) { $mine[0].Kind } else { '?' }); Count = $total
            Uploaded = $ok; Failed = $bad; Pending = $total - $ok - $bad
        }
    }) | Sort-Object Kind, Event

    $nOk = @($batches | Where-Object { $_.Status -eq 'ok' }).Count
    $nBad = @($batches | Where-Object { $_.Status -eq 'failed' }).Count
    $nNone = $batches.Count - $nOk - $nBad
    $nRejected = ($rejected.Values | Measure-Object -Sum).Sum
    $pending = ($summary | Measure-Object -Property Pending -Sum).Sum
    $dbgOn = @($rows | Where-Object { $_.Debug }).Count

    $sb = New-Object System.Text.StringBuilder
    function Add-Text([string]$s = '') { [void]$sb.AppendLine($s) }
    function Add-Table($data, [string[]]$cols) {
        if (@($data).Count -eq 0) { Add-Text '  (none)'; return }
        Add-Text (($data | Format-Table -Property $cols -AutoSize -Wrap | Out-String -Width 200).Trim())
    }

    Add-Text 'FIREBASE ANALYTICS CAPTURE REPORT'
    Add-Text ('=' * 60)
    Add-Text "Log file : $(Split-Path $Path -Leaf)"
    Add-Text "Window   : $first -> $last (device time)"
    Add-Text "App      : $($meta['app_id']) $($meta['app_version']) | $($meta['device_model']) | Android $($meta['os_version'])"
    $dbgText = if ($rows.Count -eq 0) { 'n/a' } elseif ($dbgOn -eq $rows.Count) { 'on (all events carry _dbg)' } elseif ($dbgOn -eq 0) { 'OFF - restart the app after enabling it' } else { "partial ($dbgOn of $($rows.Count) events) - app was not restarted at the start" }
    Add-Text "Debug    : $dbgText"
    Add-Text
    Add-Text 'RESULT'
    Add-Text ('-' * 60)
    Add-Text "Uploads  : $($batches.Count) batch(es): $nOk accepted, $nBad FAILED, $nNone without result"
    Add-Text "Events   : $($rows.Count) uploaded ($(@($rows | Where-Object Kind -eq 'App').Count) app, $(@($rows | Where-Object Kind -eq 'Screen').Count) screen, $(@($rows | Where-Object Kind -eq 'Auto').Count) auto, $(@($rows | Where-Object Kind -eq 'SDK error').Count) sdk-error)"
    if ($nRejected) { Add-Text "Rejected : $nRejected event(s) refused by the SDK - NOT tracked under their own name (see below)" }
    if ($pending -gt 0) { Add-Text "Pending  : $pending event(s) logged but not confirmed uploaded - wait a few seconds before stopping" }
    if ($nBad -eq 0 -and $nNone -eq 0 -and -not $nRejected -and $pending -le 0 -and $batches.Count -gt 0) { Add-Text 'All good: every event was accepted by Firebase.' }
    Add-Text
    Add-Text 'EVENT SUMMARY'
    Add-Text ('-' * 60)
    Add-Table $summary @('Event', 'Kind', 'Count', 'Uploaded', 'Failed', 'Pending')
    Add-Text
    Add-Text 'SCREENS (in order)'
    Add-Text ('-' * 60)
    Add-Table @($rows | Where-Object Kind -eq 'Screen' | ForEach-Object {
        [pscustomobject]@{ Time = $_.Time; Screen = $_.Screen; Details = $_.Details; Upload = $_.Upload } }) @('Time', 'Screen', 'Details', 'Upload')
    Add-Text
    Add-Text 'APP EVENTS (in order; auto events omitted, see events.csv)'
    Add-Text ('-' * 60)
    Add-Table @($rows | Where-Object { $_.Kind -in 'App', 'SDK error' }) @('Time', 'Event', 'Screen', 'Details', 'Upload')
    Add-Text
    Add-Text 'REJECTED BY THE SDK'
    Add-Text ('-' * 60)
    Add-Table @($rejected.Keys | Sort-Object | ForEach-Object {
        [pscustomobject]@{ Event = $_; Times = $rejected[$_]; Reason = $reasons[$_] } }) @('Event', 'Times', 'Reason')
    Add-Text
    Add-Text 'OTHER SDK ERRORS / WARNINGS'
    Add-Text ('-' * 60)
    Add-Table @($issues.Keys | Sort-Object | ForEach-Object {
        [pscustomobject]@{ Times = $issues[$_]; Message = $_ } }) @('Times', 'Message')
    Add-Text
    Add-Text 'USER PROPERTIES SET BY THE APP'
    Add-Text ('-' * 60)
    Add-Table @($props.Keys | Sort-Object | ForEach-Object {
        $parts = $_ -split "`t", 2
        [pscustomobject]@{ Name = $parts[0]; Value = $parts[1]; Times = $props[$_] } }) @('Name', 'Value', 'Times')

    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $text = $sb.ToString()
    $text | Set-Content -Path (Join-Path $OutDir 'report.txt') -Encoding UTF8
    $rows | Select-Object Time, Kind, Event, Screen, Details, Upload, Origin |
        Export-Csv -Path (Join-Path $OutDir 'events.csv') -NoTypeInformation -Encoding UTF8
    $filtered | Set-Content -Path (Join-Path $OutDir 'filtered.log') -Encoding UTF8
    return $text
}

if ($LogFile) {
    $src = (Resolve-Path $LogFile).Path
    $target = Join-Path $reportDir ([IO.Path]::GetFileNameWithoutExtension($src))
    Write-Host (Get-AnalyticsReport -Path $src -OutDir $target)
    Write-Host "Report folder: $target"
    return
}

$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if ($adbCmd) { $adb = $adbCmd.Source }
else {
    $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (-not (Test-Path $adb)) { throw 'adb not found. Install Android platform-tools or add adb to PATH.' }
}

$state = $null
if (Test-Path $statePath) { $state = Get-Content $statePath -Raw | ConvertFrom-Json }
if (-not $Serial -and $state -and $state.serial) { $Serial = $state.serial }
$a = @(); if ($Serial) { $a = @('-s', $Serial) }

# Stop the background logcat and save its output
if ($state) {
    Stop-Process -Id $state.pid -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    if (Test-Path $tempLog) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
        $dest = Join-Path $outDir ("analytics_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        Copy-Item $tempLog $dest
        Write-Host "Saved $dest"
    }
    Remove-Item $stateDir -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Warning 'No active capture found; only switching logging off.'
}

# Switch every logging channel off
& $adb @a shell setprop debug.firebase.analytics.app .none.
& $adb @a shell "setprop log.tag.FA ''"
& $adb @a shell "setprop log.tag.FA-SVC ''"

Write-Host 'Logging disabled. Restart the app to leave Firebase debug mode.'

if ($dest -and (Get-Item $dest).Length -gt 0) {
    Write-Host ''
    $target = Join-Path $reportDir ([IO.Path]::GetFileNameWithoutExtension($dest))
    Write-Host (Get-AnalyticsReport -Path $dest -OutDir $target)
    Write-Host "Report folder: $target"
}
