# QA Work — Global Context

> Kick-start context for AI assistants doing QA work in this workspace. Read this first: it describes the tools available, the app under test, key conventions, and where the source-of-truth documentation lives.

---

## 1. What this workspace is for
Manual + automated **QA of the mysdworx mobile app** (SD Worx). Work here includes: exploring/verifying functional behaviour, designing test cases, response mocking/interception, on-device screenshot evidence, and building Appium/WebdriverIO automation. Deliverables are usually functional context docs, test permutations, mock catalogs, and automation specs.

---

## 2. Tools available

### 2.1 MCP servers
| Server | Purpose | Notes / limits |
|--|--|--|
| **HTTP Toolkit** | Intercept & inspect live app traffic; read request/response bodies; drive response **mocking** for test scenarios. | Configured in `.vscode/mcp.json` (stdio). **Read-only tools** — the AI can list events and read bodies but **cannot create Modify/mock rules**; those are set up manually in the HTTP Toolkit UI. Proxy port **8000**. The traffic/event list **resets per session/day** — always fetch the newest event (don't rely on stored offsets). |
| **Azure DevOps** | Read functional docs from the **wiki**, manage **work items / bugs**, **test plans & test cases**, **pipelines**, and **repos**. | Org `sdworx` (`sdworx.visualstudio.com`), project **Digital Channels**. |
| **Playwright** | Browser automation for any web surfaces / web validation. | |
| **Azure (azmcp)** | Azure resource operations if ever needed. | Rarely used for app QA. |
| **Context7** | Up-to-date library/framework docs on demand. | |

### 2.2 Android device (ADB)
- Physical device id: from `adb devices` (per machine, not committed), connected and intercepted via ADB through the HTTP Toolkit proxy.
- **Screenshot pipeline (binary-safe — do NOT use PowerShell `>` redirection, it corrupts PNGs):**
  ```
  adb shell screencap -p /sdcard/_sc.png
  adb pull /sdcard/_sc.png ".\<name>.png"
  adb shell rm /sdcard/_sc.png
  ```
- **Long screens:** scroll-capture loop — screencap+pull, then `adb shell input swipe <x> <y1> <y2> 1000` (slow swipe, no `Start-Sleep`), repeat until the page repeats. Save as `_p1.png`, `_p2.png`, …
- Use `view_image` to read a captured screenshot.

### 2.3 Automation stack
- This repo is self-contained: root `package.json` holds all dependencies and the root `wdio.conf.js` holds the full WebdriverIO/Appium config; run `npm install` in this folder (`node_modules` is local).
- Existing Appium project: `C:\Code files\Automation on device` (WebdriverIO + Appium, uiautomator2 driver).
- Known transitive npm audit findings come from `appium-uiautomator2-driver` — pre-existing, not introduced here.
- Start the Appium server: `npm run appium:start` (port 4723) from this folder. UiAutomator2 driver `5.0.3` is installed; caps target Android 15.
- **Flutter automation note (verified 2026-07-13):** the app is Flutter and exposes NO usable `text` or `resource-id` in the native tree, but **does expose accessibility labels via `content-desc`** (e.g. Claims overview shows `Claims overview`, `Open`, `Sent`, `Draft claims\n2`, `Add expense`). So automation is feasible with **accessibility-id / content-desc selectors using partial (`contains`) matching** (counts are embedded in labels). No Flutter driver is installed/needed for helper-level use.
- **Claims Appium helper:** `QA Work/tools/device/claims-helper.js` — `dump [name]` (page source + label list → `output/device/`), `tap "<label part>"`, `shot <name>`. Manual-assisted aid for navigation/inspection/evidence; primary Claims testing stays manual-assisted.
- **Screenshot scroll-capture script:** `tools/device/capture-screens.ps1`.
- **Firebase Analytics tracking validation:** `tools/tracking/` (start/stop capture scripts + README); raw logs and reports land in `output/tracking/`.

---

## 3. App under test — specifications
| Attribute | Value |
|--|--|
| App | **mysdworx** (SD Worx employee/manager mobile app) |
| Framework | **Flutter** (source: Dart/3.10) |
| Android package | `be.sdworx.sdwa.inhouse` (in-house build) |
| Backend gateway | `https://api.acc.sdworx.com/mysdworxappgateway` (**acceptance** environment) |
| Auth | Bearer token, ~**30 min** expiry — long idle sessions drop back to the **login screen**; re-login before capturing. |
| Config model | **Provider / Form driven** — many screens (expense creation, claim creation) render a provider-defined Form; the app does not own field structure or validation. Behaviour is gated by backend flags (`canEdit`, `canDelete`, `canUnlinkExpenses`, `canLinkExpenses`, `supportsExpenseLinking`, `processingType`, etc.). |

### Functional domains present in the app
Absences, Overtime, **Expenses**, **Expense Claims**, Pending Approvals (Absences / Claims / Generic), Forms (WIP). Current QA focus: **Expenses** and **Expense Claims** (requester + approver).

---

## 4. Documentation — sources of truth
| Source | Location |
|--|--|
| **Functional docs (canonical)** | Azure DevOps wiki — project **Digital Channels**, wiki **`Digital-Channels.wiki`** (id `c18f6113-3cba-4571-998b-640f412cb281`), under path `/Channels App/mysdworx app/Functional documentation/...`. Requester = `Expense Claims/...`; Approver = `Pending Approvals/Claims/...`; core expense behaviour = `Expenses/...`. |
| **QA Hub (our published QA space)** | Azure DevOps wiki **`Digital-Channels.wiki`**, page path `/Channels App/Test Documentation/QA Hub` (subpages: Testware, How To's, Points of Contact, Copy-Pastes). This is where **our** QA deliverables get published (test results, how-tos, templates). Publish clone-free by pasting a self-contained `.md` into a new subpage. |
| **Claims API** | `resources/claims/Claim_APIdoc` (written API doc) + `resources/claims/Claim_APIrequests.json` (OpenAPI 3.0.4, filtered to Expenses tag; full original in `resources/claims/Claim_APIrequests.backup.json`). |
| **Claims functional context** | `resources/claims/Claim_FunctionalDoc_Requester` and `resources/claims/Claim_FunctionalDoc_Approver` (distilled from the wiki; QA-oriented). |
| **Document-parser (receipt AI autofill) findings** | `resources/document-parser/context.md`, `open-questions.md`, `results/results-log.md`, and `mocks/`. |
| **Forms** | `resources/forms/` (sample form JSON responses + simple-expression test permutations). |
| **Payslips** | `resources/payslips/` (wrapping variants, examples, results). |
| **Tracking (Firebase Analytics)** | `tools/tracking/README.md`. |

### Azure DevOps identifiers (for MCP tools / scripts)
| Key | Value |
|--|--|
| Organization | `sdworx` — `https://dev.azure.com/sdworx` (legacy `sdworx.visualstudio.com`) |
| Project | `Digital Channels` |
| Area Path | `Digital Channels` |
| Wiki | `Digital-Channels.wiki`, id `c18f6113-3cba-4571-998b-640f412cb281` |
| Iterations root (APP dev) | `Digital Channels\Channels App\Development\APP Development\<year>\Q<q>\Sprint <n>` |
| Iteration node for sprint dates | `Channels Front` (classification node queried for start/finish dates) |
| Board swimlanes | `System.BoardLane` on the team Kanban board = release version, e.g. `4.27.0` (used to scope release tickets) |
| Master test plan | **Release testing: mysdworx app master** (ID `1132029`) |

---

## 5. Conventions & caveats (read before testing)
- **Start each scan/flow from a fresh screen** (e.g. a clean "Add expense" form). Re-using a form with existing values leaves **stale field values** that look like app behaviour but are test artifacts.
- **HTTP Toolkit mock/Modify rules** are created **manually in the UI** (AI can only read traffic). To force a status code (e.g. 400/500) the Modify rule must set the HTTP status, not just the body.
- **HTTP Toolkit event list resets** per session/day — fetch the newest matching event each time.
- **Screenshots:** always use the `adb pull` method above; never PowerShell `>`.
- **PowerShell 5.1** shell: chain with `;` (not `&&`); native-command quoting mangles `$` and inner quotes — for non-trivial Node/JS one-liners, **write a temp `.js` file and run it**, then delete it.
- **Do not create markdown files to document changes** unless explicitly asked; edit the relevant file directly.
- The user sometimes **undoes or hand-edits** files — always re-check current file state before editing.
- Filenames in this workspace often have **no extension** (e.g. `Claim_APIdoc`, `Claim_FunctionalDoc_Approver`); match that convention when adding sibling docs unless asked otherwise.

---

## 5b. Workspace layout
```
.github/            copilot-instructions.md (this file), prompts/
resources/          per-feature reference material (docs, mocks, results)
  claims/  document-parser/  forms/  payslips/     (lowercase kebab-case)
    <docs at folder root>, mocks/ (response variants), results/ (run logs + evidence)
tools/              scripts that do something
  tracking/         Firebase Analytics capture + report (PowerShell)
  device/           adb / Appium helpers (screenshots, claims-helper)
output/             generated artefacts only (tracking/logs_raw, tracking/reports, device/)
tests/              WebdriverIO specs
package.json, wdio.conf.js   dependencies + WebdriverIO config
package.json, wdio.conf.js   npm workspace root + WebdriverIO config
```
Rules: scripts go in `tools/`, generated output in `output/`, reference docs and manual-test evidence in `resources/<feature>/`.

---

## 6. Quick-start checklist for a new QA task
1. Confirm the **domain** (Expenses / Claims / Approvals …) and the **perspective** (requester vs approver).
2. Pull behaviour from the **wiki** (functional docs) and cross-check the **API spec** in `resources/claims/`.
3. If live verification is needed: ensure the device is **logged in**, capture traffic via **HTTP Toolkit**, and take evidence with the **adb screenshot pipeline**.
4. For mocked scenarios: define the response variant, set the **Modify rule manually** in HTTP Toolkit, then re-scan from a **fresh form**.
5. Record findings in the relevant existing doc; raise **bugs / test cases** in Azure DevOps (Digital Channels) when asked.
