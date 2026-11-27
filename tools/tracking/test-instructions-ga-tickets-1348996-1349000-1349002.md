# GA tracking validation: tickets 1348996, 1349000, 1349002 (release 5.5.0)

One capture run covers all three tickets. Follow the steps in order, once, without restarting the capture.

| Ticket | Title | What to validate |
|---|---|---|
| [1348996](https://sdworx.visualstudio.com/Digital%20Channels/_workitems/edit/1348996) | Track Inbox/Newsfeed filter and attachment download | `newsfeed_filter_applied`, `attachment_downloaded` |
| [1349000](https://sdworx.visualstudio.com/Digital%20Channels/_workitems/edit/1349000) | Track login error and lockout states | `qr_scan_invalid_code`, `qr_scan_unsupported_url`, `login_account_locked` |
| [1349002](https://sdworx.visualstudio.com/Digital%20Channels/_workitems/edit/1349002) | Fix screen-level (`screen_view`) tracking | Every screen reports its own `screen_name` instead of `MainActivity` / `FlutterViewController` |

Source of truth for names: PRs 209983, 210123, 210506 in `mysdworx-app`, the generated `wiki/Tracking.md` and the `screen_names.txt` snapshot on `main`. The ticket text was thinner than the code, so the expected values below come from the code.

## 1. Prerequisites

- Android device with USB debugging, in-house build `be.sdworx.sdwa.inhouse` containing the 5.5.0 changes. iOS is not covered by these scripts.
- A **dedicated test account on acceptance** that you can afford to lock out (step 7 locks it). Know how to unlock or re-activate it.
- Account data needed:
  - Inbox with at least 3 messages, and at least one message with:
    - an attachment type the app can preview (e.g. PDF or image);
    - an attachment type it cannot preview (this triggers the "preview not supported" dialog).
  - Expenses, Absences and Salary modules available. Overtime and Approvals (manager) are optional but add coverage.
- The device is **logged in** and the app is fully closed before you start.
- Know your PIN. Know a wrong PIN.
- Two QR codes to scan (any generator):
  - **QR-A (invalid code):** `https://app.acc.sdworx.com/authenticate/not-valid-base64!!` (SD Worx host, `authenticate` segment, payload that cannot be decoded).
  - **QR-B (unsupported URL):** `https://example.com/test` (a URL on a host the app does not accept).
- Do not use a PIN you care about. No PIN values should ever appear in the log (checked in step 8).

## 2. Run procedure

```powershell
cd "c:\Code files\QA Work\tools\tracking"
.\start-analytics-capture.ps1
# close the app from the recents screen and reopen it (debug mode is only read at app start)
# perform steps 0 to 7 below, in order
# wait about 10 seconds after the last action
.\stop-analytics-capture.ps1
```

Tips for a readable report:
- Pause about 2 to 3 seconds after each navigation or action, so each upload batch stays in order.
- Do the steps in the order written. The report lists screens and events in order, so the order is how you map evidence to steps.
- Do not force-stop the app during the run, apart from the start in step 0.
- Step 7 locks the account, so it is deliberately last.

## 3. Steps and expected evidence

Notation: `screen:` is a `screen_view` with that `screen_name` (and `screen_class` the same value). `event:` is an app event. IDs (S = screen, E = event) are used in the results table in section 4.

### Step 0. Cold start (ticket 1349002)

| # | Action | Expected |
|---|---|---|
| 0.1 | Close the app from recents, reopen it, unlock with PIN or biometrics until Home is shown. | S1: `screen: loading`. S2: the PIN or biometric screen (e.g. `enter_pin` or `authentication_result`). S3: `screen: home`. Each is one `screen_view`, with no `MainActivity` and no `FlutterViewController` anywhere. |
| 0.2 | Check the report's User properties section. | `module_overtime` is set to `none`, `grouped` or `ungrouped`, matching the account. |

### Step 1. Inbox / Newsfeed (ticket 1348996)

| # | Action | Expected |
|---|---|---|
| 1.1 | Home: open **Inbox**. | S4: `screen: notifications_center_overview`. |
| 1.2 | Tap the **filter** control, then **dismiss the picker without confirming** (back / close). | S5: `screen: picker` (or `picker_modal`) with param `picker_type=notification_center_overview`. **No** `newsfeed_filter_applied`. Then `notifications_center_overview` is reported again when the picker closes. |
| 1.3 | Tap the filter again, select one or more filters, **confirm**. | E1: `event: newsfeed_filter_applied`, exactly 1, fired after confirming. |
| 1.4 | Open the filter again, clear all selections and confirm. | Edge case: record whether `newsfeed_filter_applied` fires again (the code fires on any confirmed selection, including an empty one). |
| 1.5 | Open a message that has attachments. | S6: `screen: newsfeed_detail`. |
| 1.6 | Tap the **previewable** attachment to open it, then go back. | S7: `screen: attachment_details`. Existing event `attachment_details_tapped` fires and is distinct. **No** `attachment_downloaded`. |
| 1.7 | Tap the attachment's **download** control. In the system save dialog, **cancel**. | **No** `attachment_downloaded`. |
| 1.8 | Tap download again and **save** the file. | E2: `event: attachment_downloaded`, 1. |
| 1.9 | Tap the **unsupported-preview** attachment, tap the positive action in the dialog to download, then **save**. | The dialog is reported as `screen: dialog` (it is unnamed). E3: `attachment_downloaded`, 1. |
| 1.10 | Back to the Home screen. | `screen: home`. |

After step 1 the totals must be: `newsfeed_filter_applied` once per confirmed selection, and `attachment_downloaded` exactly 2 (steps 1.8 and 1.9). Cancelled saves, and a failed download if you can force one, must add none.

### Step 2. Screen walk (ticket 1349002)

Go through the screens your account has. For each one the expectation is its own `screen_name`, in snake_case, with no IDs or personal data.

| # | Action | Expected screen_view(s) |
|---|---|---|
| 2.1 | Home: open **Salary**, then open a payslip, then back. | `salary_overview`, `salary_detail` (or `salary_pdf_detail`), then `salary_overview` again on return. |
| 2.2 | Home: open **Expenses**. Switch between the **Open** and **Completed** tabs (and Group / Ungroup / Claims variants if your account has them). | A tab name for each tab shown and on each switch, e.g. `expenses_ungroup_overview_open_tab`, `expenses_ungroup_overview_completed_tab` (or the `expenses_group_*` / `expenses_claims_*` variants). The parent `expenses_overview` is a container and is **not** reported itself. |
| 2.3 | Open an expense. | `expense_detail`, and its `screen_view` carries a `context` param (a fixed value, never an ID). |
| 2.4 | Back, tap **Add expense**, then open the category picker, pick a category. | `add_edit_expense` (or `init_add_edit_expense`), `choose_category_expense` or `picker` with `picker_type=choose_category_expense`, then `add_edit_expense` again on return. |
| 2.5 | Enter a value, then tap back. In the discard dialog, tap **stay / continue**. | `add_edit_expense_close_dialog`, then `add_edit_expense` reported again after the dialog closes. Then discard and leave. |
| 2.6 | Home: open **Absences**. Switch between **My calendar** and **Team calendar** tabs. | `absences_overview_my_calendar_tab`, `absences_overview_team_calendar_tab` (reported when shown and on each switch). `absences_overview` itself is not reported. |
| 2.7 | Tap **Request absence**. | `request_absence`, and its `screen_view` carries `initiated_from`. |
| 2.8 | Back out with changes entered, and confirm the close dialog with "stay", then leave. | `request_absence_close_dialog`, then `request_absence` again. |
| 2.9 | If the account has **Overtime**: open it and switch tabs. | `overtime_ungroup_overview_open_tab` / `..._completed_tab` (or `overtime_group_*`). |
| 2.10 | If the account is a **manager**: open **Approvals** and switch to the approval detail tabs. | `approvals`, plus tabs such as `absence_approval_details_details_tab` and `absence_approval_details_team_calendar_tab`. If Approvals embeds a single generic category, `pending_approvals_generic_content` fires with a `category` param. |
| 2.11 | Home: open **Settings**, then open **Language**, **Theme**, **My profile**, **Account**, back out each time. | `settings`, `settings_language`, `settings_theme`, `settings_my_profile`, `settings_account`, returning to `settings` between them. |
| 2.12 | In Settings, tap **Log out**, then **cancel** the dialog. | `logout_dialog`, then `settings` again after cancelling. |
| 2.13 | Optional: **Feedback**. | `feedback`, plus `picker` with `picker_type=feedback_subject` for the subject picker. |

### Step 3. QR scan errors (ticket 1349000)

The in-app QR scanner is reached from **Settings, passwordless login** (that is the in-app way to confirm a web login). If your build exposes the scanner elsewhere, such as the login or landing screen, use that instead. Confirm which entry point you used.

| # | Action | Expected |
|---|---|---|
| 3.1 | Settings: open the QR scanner. Allow camera access if asked. | `screen: qr_scanner`. |
| 3.2 | Scan **QR-A** (invalid code). | E4: `event: qr_scan_invalid_code`, 1. The invalid-QR dialog is shown (reported as `dialog`). Dismiss it. |
| 3.3 | Scan **QR-B** (unsupported URL). | E5: `event: qr_scan_unsupported_url`, 1. The invalid-QR dialog is shown again. Dismiss it. |
| 3.4 | Optional: scan a QR on an SD Worx host without an `authenticate`, activation or verify segment. | Not covered by either new event (the app shows its update screen). Record behaviour only. |
| 3.5 | Leave the scanner, return to Home. | `screen: home`. |

The two QR events must be distinct from each other. Each scan should send exactly one event, and the event must carry no scanned content.

### Step 4. Lockout (ticket 1349000), always last

**This locks the test account.**

| # | Action | Expected |
|---|---|---|
| 4.1 | Close the app from recents and reopen it. At the PIN screen enter a **wrong PIN** repeatedly until the app locks the account (the limit depends on the environment, typically a few attempts). | Each attempt stays on the PIN screen. E6: `event: login_account_locked`, **exactly once**, sent **before** `screen: pin_blocked` is reported. |
| 4.2 | Stay on the locked screen for a few seconds. | `screen: pin_blocked`, and nothing else for this step. No second `login_account_locked`. |

If the account never reaches the lock-out within your attempt budget, record the count and stop. Do not guess a larger number on an account you cannot unlock.

### Step 5. Stop

Wait about 10 seconds, then run `.\stop-analytics-capture.ps1`. The saved report is in `output\tracking\reports\log_<timestamp>\`.

## 4. Results checklist

Tick each line against `report.txt` (and `events.csv` for parameters). Copy this table into the result log.

### Events

| ID | Ticket | Event | When | Expected count | Params that must / must not be there | Result |
|---|---|---|---|---|---|---|
| E1 | 1348996 | `newsfeed_filter_applied` | Filter selection confirmed (1.3, and 1.4 if it fires) | 1 (2 if 1.4 fires) | None needed | |
| E2 | 1348996 | `attachment_downloaded` | Previewable attachment saved (1.8) | 1 | None needed | |
| E3 | 1348996 | `attachment_downloaded` | Unsupported-preview attachment saved via the dialog (1.9) | 1 | None needed | |
| N1 | 1348996 | `newsfeed_filter_applied` | Picker dismissed without confirming (1.2) | 0 | | |
| N2 | 1348996 | `attachment_downloaded` | Save cancelled (1.7) / attachment only opened (1.6) | 0 | | |
| N3 | 1348996 | `attachment_details_tapped` | Open attachment (1.6) | Fires, separate from E2/E3 | | |
| E4 | 1349000 | `qr_scan_invalid_code` | QR-A (3.2) | 1 | No scanned content | |
| E5 | 1349000 | `qr_scan_unsupported_url` | QR-B (3.3) | 1 | No scanned content | |
| E6 | 1349000 | `login_account_locked` | Account locked (4.1) | 1, before `pin_blocked` | **No PIN, no token** | |
| E7 | 1349002 | `pending_approvals_generic_content` | Manager, single generic category (2.10, optional) | 1 | `category` | |

### Screens (1349002)

| ID | Screen | Step | Extra expectation | Result |
|---|---|---|---|---|
| S1 | `loading` | 0.1 | | |
| S2 | PIN or biometric screen | 0.1 | | |
| S3 | `home` | 0.1, 1.10, 3.5 | Reported again each time you return | |
| S4 | `notifications_center_overview` | 1.1 | | |
| S5 | `picker` / `picker_modal` | 1.2 | `picker_type=notification_center_overview` | |
| S6 | `newsfeed_detail` | 1.5 | | |
| S7 | `attachment_details` | 1.6 | | |
| S8 | `dialog` | 1.9, 3.2, 3.3 | Unnamed dialogs report `dialog` | |
| S9 | `salary_overview`, `salary_detail` | 2.1 | | |
| S10 | Expense tabs (`expenses_*_tab`) | 2.2 | On shown and on every switch; `expenses_overview` absent | |
| S11 | `expense_detail` | 2.3 | `context` param | |
| S12 | `add_edit_expense`, `choose_category_expense` / `picker` | 2.4 | `picker_type=choose_category_expense` if via `picker` | |
| S13 | `add_edit_expense_close_dialog` | 2.5 | `add_edit_expense` reported again afterwards | |
| S14 | Absence tabs (`absences_overview_*_tab`) | 2.6 | `absences_overview` absent | |
| S15 | `request_absence` | 2.7 | `initiated_from` param | |
| S16 | `request_absence_close_dialog` | 2.8 | `request_absence` reported again afterwards | |
| S17 | Overtime tabs | 2.9 (optional) | | |
| S18 | `approvals`, approval detail tabs | 2.10 (optional) | | |
| S19 | `settings` and sub-screens | 2.11 | `settings` reported again on each return | |
| S20 | `logout_dialog` | 2.12 | `settings` reported again afterwards | |
| S21 | `qr_scanner` | 3.1 | | |
| S22 | `pin_blocked` | 4.2 | Reported after `login_account_locked` | |

### Global checks for ticket 1349002

| ID | Check | Expected | Result |
|---|---|---|---|
| G1 | No `screen_name` or `screen_class` is `MainActivity` or `FlutterViewController` | None found | |
| G2 | `screen_class` equals `screen_name` on every `screen_view` | True | |
| G3 | No legacy `screenview` event and no `s_*` events (`s_Home`, `s_Login`, ...) | None found | |
| G4 | No IDs or personal data in any `screen_name` (no record IDs, names, dates) | None found | |
| G5 | Each screen is reported once per visit (no double count from flow wrappers or containers) | One `screen_view` per visit | |
| G6 | Returning from a dialog, picker or sub-screen reports the screen underneath again | Seen at 1.2, 2.5, 2.8, 2.12 | |
| G7 | Container screens (`expenses_overview`, `absences_overview`, `overtime_overview`, `absence_approval_details`) are never reported themselves | None found | |
| G8 | Removed events `spotlight_flyout_tapped`, `newsfeed_flyout_tapped` do not appear | None found | |
| G9 | Names match the snapshot: every `screen_name` seen exists in `Tracking.md` (Screens, Tabs, Dialogs) | True | |
| G10 | No `error(_err)` rejection and every batch `OK (204)` | True | |
| G11 | No PIN or token in any event or param (checked in `filtered.log` around E4, E5, E6) | None found | |

## 5. Reading the results

```powershell
$log = Get-ChildItem "c:\Code files\QA Work\output\tracking\logs_raw\log_*.log" | Sort-Object LastWriteTime | Select-Object -Last 1
# new events
Select-String -Path $log -Pattern 'newsfeed_filter_applied|attachment_downloaded|qr_scan_invalid_code|qr_scan_unsupported_url|login_account_locked|attachment_details_tapped'
# bad screen names
Select-String -Path $log -Pattern 'MainActivity|FlutterViewController|name=screenview|s_Home|s_Login'
# SDK rejections
Select-String -Path $log -Pattern 'name=error\(_err\)'
# screen_view parameters
Select-String -Path $log -Pattern 'screen_view' | Select-Object -First 60
```

- `report.txt` Screens section gives the ordered screen list. `events.csv` and `filtered.log` hold the params for `screen_view`, so use them for `picker_type`, `context` and `initiated_from`.
- The report shows what the SDK uploaded, not what GA4 processed. Confirm a sample in DebugView or BigQuery before closing the tickets.
- If an event is missing, check the build version first. A build older than 5.5.0 will not send the new events and will still send `MainActivity`.

## 6. Open points to confirm while testing

- **QR entry point:** Settings, passwordless login is assumed. Note the entry point you actually used.
- **QR-A and QR-B:** the SD Worx host in QR-A is an assumption for acceptance. If it is rejected as an unsupported URL instead, record the host that gives `qr_scan_invalid_code`.
- **Lockout threshold:** the attempt count is set by the backend, not the app. Record it.
- **Empty filter confirm (1.4):** the ticket does not say whether it counts as "applied". Record and raise it if it fires.
- **Attachment download without a save dialog:** record how the save step behaves on this device, since a cancel must not fire `attachment_downloaded`.
- **Ticket 1349000 asks to verify the three event names do not already exist under another pattern.** If the raw stream contains a similar older event for the same action, record it.
