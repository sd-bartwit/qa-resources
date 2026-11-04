<#
.SYNOPSIS
  Reusable adb screenshot capture: grabs the current screen, then auto-scrolls and
  keeps capturing until a page repeats (bottom reached), so the whole UI is collected
  in one run instead of deciding page-by-page.

.USAGE
  ./tools/capture-screens.ps1 -OutPrefix "resources/Document Parser/results/2026-09-28/CC-203_unitid-only-foreign"

  Produces <OutPrefix>.png if everything fits on one screen, otherwise
  <OutPrefix>_p1.png, _p2.png, ... (last page is the one before the repeat/bottom).

.PARAMETER OutPrefix
  Path + filename stem (no extension) for the screenshot(s).

.PARAMETER MaxPages
  Safety cap on how many pages to capture (default 6).

.PARAMETER SwipeCoords
  "x1 y1 x2 y2 durationMs" passed to `adb shell input swipe` between captures (default
  matches a 1080x2340 device: swipe up from near-bottom to near-top).
#>
param(
  [Parameter(Mandatory = $true)][string]$OutPrefix,
  [int]$MaxPages = 6,
  [string]$SwipeCoords = "540 1800 540 600 300"
)

function Get-Screenshot([string]$destPath) {
  adb shell screencap -p /sdcard/_sc.png | Out-Null
  adb pull /sdcard/_sc.png $destPath | Out-Null
  adb shell rm /sdcard/_sc.png | Out-Null
}

$pages = @()
$tempFirst = "$OutPrefix.png"
Get-Screenshot $tempFirst
$pages += $tempFirst

for ($i = 2; $i -le $MaxPages; $i++) {
  $prevPath = $pages[-1]
  & adb shell input swipe $SwipeCoords.Split(" ") | Out-Null
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
