# Forms: Test Plan Changes (Simple vs Wizard)

Sources: [dev-output.md](dev-output.md), ADO test plan 1132029 (Release testing: mysdworx app master), suite 1132312 "12 - Forms".

## 1. Existing [Native] coverage in suite 12 - Forms

| ID | Title | Covers | Overlap with new cases |
|---|---|---|---|
| 1132201 | 12M - [Native] Open native Forms | Home tile, root screen, steps, Confirm/Submit visibility, step progression | Wizard happy path. Only the Wizard-specific rules below are new. |
| 1132202 | 12N - item types | Field types | None |
| 1132203 | 12O - item-level rules WIP | readOnly, required | Field-level readOnly/required are not repeated in the Simple readonly case |
| 1132217 | 12R - provider validation (eBloxHR) | Provider errors on submit | Not repeated |
| 1132277 | 12S - customized Submit button | Empty steps | Custom buttons are in TC-1 here. Revisit 12S once it has steps. |
| 1196421 | Edit and submit simple form | Simple submit, app and provider errors, groups | Simple submit happy path is not repeated in TC-3 |
| 1342152 | Simple expressions | Expression behaviour | Not repeated |
| 1132155 to 1132166 | Deeplink cases 12A to 12L | Deeplink entry and field types | Native cases here do not repeat deeplink entry |

## 2. New test cases

### TC-1 General Forms behaviour (both layouts)

Preconditions: user logged in with a form that has no visible items, and a second form to open with `submitUri`.

| Step | Action | Expected |
|---|---|---|
| 1 | Open a form with no visible items, `submitText` set and no `submitUri` [empty state] | Title in app bar; empty-state text "No data available" with description shown; no Submit button |
| 2 | Open a form with no visible items, `submitText` and `submitUri` set [empty state with submitUri] | Submit button shown; tapping it opens the next form replacing the current one |
| 3 | Open a form with no visible items and `submitUri` but no `submitText` [submitText missing] | No Submit button |
| 4 | Open a form with `submitUri` and an editable field; change value; tap Submit [submitUri payload] | Next form opens by Replace; `x-form-functionality` header lists `<item id>=<value>` for submitted items; attachments not forwarded |
| 5 | Open a Wizard form with `viewOnly` true and `submitUri`; tap Submit [viewOnly with submitUri] | Next form opens On top; Back returns to the current form |
| 6 | Open a form with custom buttons; tap one [custom button action] | Form closes; caller receives the button id; no save |
| 7 | Open a form with custom buttons [custom button hides Submit] | Submit button not shown |
| 8 | Open a form with `changesOnly` true; change one field; tap Submit or open the next form with `submitUri` [changesOnly payload] | Only the changed field is sent or appears in the header |
| 9 | Change a field, then set it back to its original value; press back [unsaved-changes revert] | No unsaved-changes warning |
| 10 | Open a form with a `Web` navigation item in Default, Inline, and External modes; tap each [Web display modes] | Default opens the in-app web view; Inline opens an in-app browser; External opens the phone browser; form stays open with values kept; no warning |
| 11 | Submit a form; inspect analytics events [analytics] | `form_view` (with `view_mode`) and `form_submit` are sent; layout is not in the payload; CAPI-opened forms emit anonymous events (known gap) |

Run on Simple and Wizard. Step 5 applies to Wizard only; a view-only Simple form has no Submit button.

### TC-2 Wizard layout specifics

Preconditions: Wizard form with at least 2 steps; each step has a group with editable fields; one required field.

| Step | Action | Expected |
|---|---|---|
| 1 | Open the form [overview layout] | Overview shows one card per visible step with name; no progress bar |
| 2 | Leave a required field empty in step 1 [required validation] | Confirm disabled; warning icon on step 1 card because the step has a validation error |
| 3 | Change a value in step 2 without errors [Confirm enablement] | Confirm enabled |
| 4 | Press Confirm on step 2 [Confirm keeps changes in memory] | Back to overview; no save; no success message |
| 5 | Tap Submit on overview [overview Submit] | Data saved; success message; screen closes or reloads |
| 6 | Open overview with no confirmed step [Submit gating] | Submit not shown |
| 7 | Open step, make no change [Confirm gating without change] | Confirm not enabled |
| 8 | Open a step with a group containing a nested group and a field at step level [nested group rendering] | Nested group and step-level field not shown (known limitation, verify on build) |
| 9 | Change a value in a step; press back [unsaved-changes per step] | Unsaved-changes warning; Continue discards that step's changes only |
| 10 | Form with a Functionality nav item [Functionality nav in Wizard] | Item not shown |
| 11 | viewOnly with no `submitUri` [viewOnly without submitUri] | Confirm hidden; Submit hidden |

### TC-3 Simple layout specifics

Preconditions: Simple form with required fields, a group, and a Functionality nav item linking to a Simple form and a Wizard form.

| Step | Action | Expected |
|---|---|---|
| 1 | Open the form with a required field empty [required gating] | Submit button disabled |
| 2 | Fill required fields [required gating] | Submit button enabled |
| 3 | Open a form with `changesOnly` true, no change made [changesOnly gating] | Submit disabled |
| 4 | Change one field, tap Submit; inspect request [changesOnly payload] | Only the changed field is sent |
| 5 | Open a form with `changesOnly` false, tap Submit; inspect request [full payload] | All visible and hidden regular items sent; inline comments excluded |
| 6 | Open a `viewOnly` form, with or without `changesOnly` [viewOnly] | All fields read-only; no Submit button; no changes possible |
| 7 | Change a value; press back [unsaved-changes] | Unsaved-changes warning; Continue discards |
| 8 | Tap a Functionality nav item to a Simple form [Functionality to Simple] | Form opens On top; Back returns |
| 9 | Tap a Functionality nav item to a Wizard form [Functionality to Wizard] | Generic error; new page closed; current Simple form stays with values |
| 10 | Group inside group [nested group rendering] | Nested group and its fields rendered |

## 3. Items to verify before execution

| ID | Item | Action |
|---|---|---|
| VER-01 | Wizard screens share one in-memory service; opening another form may clear data for a view-only Wizard underneath | Reproduce: open view-only Wizard, open a Replace/On top form, return, open a step and press Submit |
| VER-02 | Wizard overview Back warning and Simple Back warning differ in scope | Confirm with TC-2 step 9 and TC-3 step 7 |
| VER-03 | Wizard nested group rendering | Confirm TC-2 step 8 on the build under test |

