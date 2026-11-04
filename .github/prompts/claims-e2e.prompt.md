---
mode: agent
description: 'Execute an Expense Claims acceptance test case on the connected Android device using the mock → capture → verify → log loop.'
---

# Run Claims test case: ${input:testCaseId:Test case ID (e.g. E2E-03, REQ-02, APP-04)}

You are executing a single Expense Claims acceptance test case on the physically connected device, manual-assisted. Work through it step by step, capturing evidence and verifying each expected result.

## Context to load first
- `../copilot-instructions.md` — tools, device, app specs, conventions, caveats. **Follow all caveats.**
- `../../resources/claims/Claim_TestCases` — find the case with ID **${input:testCaseId}** and use its Preconditions / Steps / Expected / Variants.
- `../../resources/claims/Claim_FunctionalDoc_Requester` and `../../resources/claims/Claim_FunctionalDoc_Approver` — behavioural reference for expected results.

## Non-negotiable rules
- **Screenshots (binary-safe):** `adb shell screencap -p /sdcard/_sc.png` → `adb pull /sdcard/_sc.png ".\<name>.png"` → `adb shell rm /sdcard/_sc.png`. Never use PowerShell `>`. For long screens, scroll-capture with `adb shell input swipe <x> <y1> <y2> 1000` (no `Start-Sleep`), save `_p1,_p2,…`.
- Read every screenshot with the image viewer before asserting a result.
- **Start each flow from a fresh screen** (e.g. clean "Add expense"/claim detail) to avoid stale-state artifacts.
- PowerShell 5.1: chain with `;`. For non-trivial JS, write a temp `.js` file and run it, then delete it.
- **[MOCK] steps:** you cannot create HTTP Toolkit rules. Instead, output the exact Modify rule the user must set in the HTTP Toolkit UI: matcher (method + URL/path), what to change (response body JSON and/or **HTTP status code** for 4xx/5xx), then wait for confirmation before continuing. Remember the HTTP Toolkit event list resets per session/day — fetch the newest matching event.
- **[2-ROLE] steps:** perform the requester portion, capture, then prompt the user to switch to the **approver** account (both accounts are available), continue, and finally return to the requester to verify downstream state. Never assume the switch happened — ask and wait.

## Execution loop (repeat per step)
1. State the step and its expected result.
2. If it needs a mock, give the exact rule and wait for confirmation.
3. Drive/observe the action on device; capture screenshot(s) into `../../resources/claims/results/${input:testCaseId}/` with descriptive names (e.g. `01_draft-detail.png`).
4. View the screenshot; compare actual vs expected; mark **Pass / Fail / Blocked** with a one-line reason.
5. For any doc "(gap)", record the actual observed behaviour explicitly.

## Output
- Append a run record to `../../resources/claims/results/results-log` with: date, test case ID, environment, per-step Pass/Fail, screenshots (relative links), overall verdict, and any defects/observations (especially for gap items).
- If a genuine defect is found, summarise it (steps to reproduce, expected vs actual, evidence) so it can later be raised — but do **not** create anything in Azure DevOps unless explicitly asked.
- Do not create extra markdown docs beyond the run log unless asked.
