# Firebase Analytics capture (Android)

Captures every Firebase Analytics event, user property and upload the app produces on a connected Android device, so tracking can be verified without the DebugView UI.

## Quick start

```powershell
cd "c:\Code files\QA Work\tools\tracking"
.\start-analytics-capture.ps1          # enable + start capturing
# fully close and reopen the app, then perform the test actions
.\stop-analytics-capture.ps1           # save log + disable everything
```

The full raw log is saved to `output/tracking/logs_raw/analytics_<yyyyMMdd_HHmmss>.log` and a readable report to `output/tracking/reports/analytics_<yyyyMMdd_HHmmss>/` (see below). Paths in this document are relative to the `QA Work` folder unless they start with `.\`.

Requirements: `adb` on PATH (or in `%LOCALAPPDATA%\Android\Sdk\platform-tools`), USB debugging on, one device connected (otherwise pass `-Serial <id>`).

## What the scripts do

**`start-analytics-capture.ps1`**
Switches Firebase debug mode and verbose SDK logging on for the app, clears the device log so only new activity is recorded, and starts a background capture. Options: `-Package` (default `be.sdworx.sdwa.inhouse`), `-Serial`. The script never restarts or force-stops the app (force-stop clears the device's notifications); close and reopen the app yourself.

**`stop-analytics-capture.ps1`**
Stops the background capture, saves it to `output/tracking/logs_raw/` with a timestamp, switches all logging and debug mode off again, then analyses the log and prints a report. Option: `-LogFile <path>` analyses an existing raw log only (no device needed, nothing is stopped or disabled).

Internal state is kept in a temporary `output/tracking/.capture/` folder that is removed on stop.

## The report

The report is built from the payloads the SDK actually uploads, so it shows what reached Firebase, not just what the app attempted. It answers: which events and screens were sent, and was each upload accepted.

| Section | Content |
|---|---|
| Result | Batches uploaded / accepted / failed, event totals, rejected events, debug-mode check. |
| Event summary | Per event name: count, uploaded, failed, pending. |
| Screens | Screen views in order, with the previous screen and upload status. |
| App events | App-emitted events in order with their screen, custom params and upload status. |
| Rejected by the SDK | Events refused by the SDK (for example invalid names) and the reason. |
| Other SDK errors / warnings | Any other `E/FA` or `W/FA` message. |
| User properties | Properties the app set during the capture. |

Files written to `output/tracking/reports/<log name>/`:

- `report.txt`: the report above.
- `events.csv`: every uploaded event (including auto events) for filtering in Excel.
- `filtered.log`: only the raw log lines about events, user properties and uploads.

Upload status is `OK (204)` when Firebase accepted the batch, `FAILED (code)` when it did not, and `no result` when the capture ended before a result was logged. Wait a few seconds after the last action before stopping.

## What gets enabled

| Setting | Purpose |
|---|---|
| `debug.firebase.analytics.app = <package>` | Firebase debug mode: events upload immediately and appear in DebugView. Read only when the app starts. |
| `log.tag.FA = VERBOSE` | SDK logging of events, user properties and upload activity. |
| `log.tag.FA-SVC = VERBOSE` | SDK service logging (event bundles, upload scheduling and result). |

These settings reset on a device reboot.

## Manual steps

Enable:

```powershell
adb shell setprop log.tag.FA VERBOSE
adb shell setprop log.tag.FA-SVC VERBOSE
adb shell setprop debug.firebase.analytics.app be.sdworx.sdwa.inhouse
adb logcat -c
adb logcat -v time -s FA FA-SVC | Tee-Object analytics.log
```

Then fully close and reopen the app.

Turn everything off:

```powershell
adb shell setprop debug.firebase.analytics.app .none.
adb shell "setprop log.tag.FA ''"
adb shell "setprop log.tag.FA-SVC ''"
```

Then restart the app. Check with `adb shell getprop debug.firebase.analytics.app` (should print `.none.`) and `adb shell getprop log.tag.FA` (should print nothing).

## Reading the log

| Search for | Meaning |
|---|---|
| `Logging event` | An event with its params, as the SDK recorded it. |
| `name=error(_err)` | The SDK rejected an event; `ga_error_value` holds the name the app tried to send. Event names may only contain letters, digits and `_`. |
| `Setting user property` | A user property being set. |
| `Network upload successful ... 204` | A batch was accepted by Firebase. |

```powershell
Select-String -Path ..\..\output\tracking\logs_raw\<file>.log -Pattern 'Logging event|Setting user property|Network upload'
```

## Notes

- The log shows what the SDK sent; it does not prove Firebase processed it. Use DebugView or the BigQuery export for server-side confirmation.
- iOS is not covered: use the `-FIRAnalyticsDebugEnabled` launch argument in Xcode instead.
