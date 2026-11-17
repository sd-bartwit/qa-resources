<#
.SYNOPSIS
  Reusable adb screenshot capture: grabs the current screen, then auto-scrolls and
  keeps capturing until a page repeats (bottom reached), so the whole UI is collected
  in one run instead of deciding page-by-page.

.USAGE
  ./tools/device/capture-screens.ps1 -OutPrefix "resources/document-parser/results/2026-09-28/CC-203_unitid-only-foreign"

  Produces <OutPrefix>.png if everything fits on one screen, otherwise
  <OutPrefix>_p1.png, _p2.png, ... (last page is the one before the repeat/bottom).

.PARAMETER OutPrefix
  Path + filename stem (no extension) for the screenshot(s).

.PARAMETER MaxPages
  Safety cap on how many pages to capture (default 6).

.PARAMETER SwipeCoords
  "x1 y1 x2 y2 durationMs" passed to `adb shell input swipe` between captures. Default: derived
  from the device screen size (swipe up from ~77% to ~26% of the height, centred horizontally).

.PARAMETER Serial
  Device serial (adb devices). Defaults to $env:ANDROID_SERIAL, or the only connected device.
#>
param(
  [Parameter(Mandatory = $true)][string]$OutPrefix,
  [int]$MaxPages = 6,
  [string]$SwipeCoords,
  [string]$Serial
)

if (-not $Serial) { $Serial = $env:ANDROID_SERIAL }
if (-not $Serial) {
  $serials = @(adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' } | ForEach-Object { ($_ -split '\s+')[0] })
  if ($serials.Count -eq 0) { throw 'No authorised device connected.' }
  if ($serials.Count -gt 1) { throw "Several devices connected ($($serials -join ', ')). Pass -Serial <id>." }
  $Serial = $serials[0]
}
$a = @('-s', $Serial)

if (-not $SwipeCoords) {
  $size = @(adb @a shell wm size) | Where-Object { $_ -match '(\d+)x(\d+)' } | Select-Object -Last 1
  if (-not $size) { throw 'Could not read the screen size; pass -SwipeCoords.' }
  $null = $size -match '(\d+)x(\d+)'
  $w = [int]$Matches[1]; $h = [int]$Matches[2]
  $SwipeCoords = "{0} {1} {0} {2} 300" -f [int]($w / 2), [int]($h * 0.77), [int]($h * 0.26)
}

function Get-Screenshot([string]$destPath) {
  adb @a shell screencap -p /sdcard/_sc.png | Out-Null
  adb @a pull /sdcard/_sc.png $destPath | Out-Null
  adb @a shell rm /sdcard/_sc.png | Out-Null
}

$pages = @()
$tempFirst = "$OutPrefix.png"
Get-Screenshot $tempFirst
$pages += $tempFirst

for ($i = 2; $i -le $MaxPages; $i++) {
  $prevPath = $pages[-1]
  & adb @a shell input swipe $SwipeCoords.Split(" ") | Out-Null
  $nextPath = "${OutPrefix}_p$i.png"
  Get-Screenshot $nextPath

  $prevHash = (Get-FileHash $prevPath -Algorithm SHA256).Hash
  $nextHash = (Get-FileHash $nextPath -Algorithm SHA256).Hash
  if ($prevHash -eq $nextHash) {
    Remove-Item $nextPath  # duplicate of previous page = bottom reached, discard
    break
  }
  $pages += $nextPath
}

# If we captured more than one page, rename the first to the _p1 suffix for consistency
if ($pages.Count -gt 1) {
  $renamedFirst = "${OutPrefix}_p1.png"
  Move-Item $pages[0] $renamedFirst
  $pages[0] = $renamedFirst
}

Write-Output "Captured $($pages.Count) page(s):"
$pages | ForEach-Object { Write-Output "  $_" }
