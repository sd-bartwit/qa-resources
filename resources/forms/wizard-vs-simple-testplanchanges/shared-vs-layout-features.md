# Forms: Shared vs Layout-Specific Features

Source: [dev-output.md](dev-output.md). Summarised from the dev output; behaviour still needs confirming on the build under test.

## 1. Shared features (Simple and Wizard)

| Area | Shared behaviour |
|---|---|
| Entry | Both opened via `FormRouter.openFormOverview`; the backend `type` decides Simple or Wizard |
| Field types | Text, multiline, date/time, numeric, toggle, select, multi-select, inline comment, attachment, group, image, navigation, file |
| Visibility and required/read-only | Evaluated by `SimpleExpressionBuilder` in both layouts |
| Group header and expansion | Same header, `isExpanded` start state, and view-only card (`FormGroupExpansionTile`) |
| Visibility of hidden items | Hidden groups and fields are not shown |
| Submit with `submitUri` | Opens the next form (Replace, or On top for view-only Wizard) |
| Submit without `submitUri` | Saves the form to the backend |
| Custom buttons | Close the form and return the selected button id; no save |
| Navigation `Web` item | Default, Inline, and External display modes behave the same |
| Unknown nav display mode | Becomes `Default`; unknown type or missing deep link hides the item |
| Unsaved-changes warning | Shown when changes exist; Continue discards them |
| Changing a value back to original | Removes the change; no warning |
| `viewOnly` flag | Read-only rendering; Submit/Confirm hidden as per the rules below |
| `changesOnly` flag | Payload contains only changed values when set |
| Empty state | Title in app bar, "No data available", standard description |
| Empty form Submit | Shown only with both `submitText` and `submitUri`; always enabled |
| Replace payload | `FormUpdate.items` sent as `x-form-functionality` header for external forms; attachments and metadata not forwarded; internal forms send no values |
| Tracking | One `FormTrackingContext`; emits `form_view`, `form_edit`, `form_submit` (layout not in payload) |
| Tracking gap | CAPI/deep-link opens are anonymous (null name and id) |
| Data model base | `BaseForm` fields (`type`, `title`, `submitUri`, `submitText`, `changesOnly`, `viewOnly`, etc.) |
| Converters | 15 of 17 converter files in `data/extensions/` are shared |

## 2. Layout-specific features

### 2.1 Structure and controls

| Topic | Simple | Wizard |
|---|---|---|
| Page structure | One scrollable page | Overview with one card per visible step; each step opens its own page |
| Step cards | Not used | Name, optional description and badge, warning icon on error; no progress bar |
| Main submit control | Submit at bottom | Submit on overview; Confirm on each step page |
| Items outside groups | Supported | Not supported; `items` at form or step level is ignored |
| Group requirement | Optional | Fields must sit in a group; groups must sit in a step |
| Required `steps`/`groups` lists | n/a | Must be present, even if empty |
| Nested groups | Supported and rendered recursively | Mapped in the domain model but not rendered by the step UI |
| Empty step | n/a | Opening an empty step shows the standard empty state |

### 2.2 Actions and rules

| Action or rule | Simple | Wizard |
|---|---|---|
| Confirm | Not used | Keeps step changes in memory and returns to overview; no backend call |
| Submit shown when | Not view-only and no custom buttons | No custom buttons, and a step was confirmed (or view-only form has `submitUri`) |
| Submit enabled when | Visible required fields filled, no errors; with `changesOnly` also needs one change | Always enabled when shown |
| Confirm enabled when | n/a | Step changed and has no errors |
| Submit label | `submitText` or "Submit changes" | `submitText` or "Submit changes" |
| Functionality nav item | Supported; opens On top; must target Forms overview and backend `type: Simple` | Not supported; removed when the form loads |
| Functionality to Wizard | Blocked: generic error, new page closed | n/a |
| Back warning scope | Whole form | Overview: whole form; step: that step only |
| After direct Submit | Pops with `FormMetadataResult` | Success message, refresh other forms; reloads in place or closes if opened by Replace |
| Next form opened by Replace | Current form closes | Editable Wizard: current form closes; view-only Wizard opens On top instead |

### 2.3 viewOnly

| Area | Simple | Wizard |
|---|---|---|
| Submit | Hidden | Shown only when `submitUri` exists |
| Confirm | n/a | Hidden |
| Empty form with `submitUri` | Still opens next form by Replace | Opens On top |
| Navigation items | Still active | Still active (`Web` only) |
| Group view | Each group is a card; with no groups, all non-navigation fields share one card | Each group is a card |

### 2.4 changesOnly

| Area | Simple | Wizard |
|---|---|---|
| Submit gate | At least one change required | No extra gate |
| Payload and Replace values | Changed values only | Changed values only |
| Without `changesOnly` | All regular items sent, including hidden; inline comments skipped | Same |

## 3. Technical differences

| Area | Simple | Wizard |
|---|---|---|
| Service lifetime | New instance per screen | One shared instance |
| Payload traversal | Items, recursively through groups | Steps, then groups, then items |
| Required validation | Recursive; ignores invisible items | Errors roll up to group and step |
| Item updates | Form-wide, direct service call | Step/group scoped via `UpdateItemUseCase` |
| Provider-error updates | Inside `SimpleFormViewModel` | `UpdateItemWithProviderErrorUseCase` |
| Submit state | `canSubmit` | `isSubmitAvailable`, `hasChanges` |
| Base ViewModel | Extends `BaseFormViewModel` | Overview does not; step does |

Wizard-only members declared on `BaseFormService`: `clearStepTemporaryChanges` and `hasSomethingToSubmit` (the latter is read only by Wizard).

## 4. Open-chain behaviour (Replace and On top)

| Mode | Simple | Wizard |
|---|---|---|
| Replace | Current form closes; Back returns before first form in chain | Same |
| On top | Back returns to form underneath | Same |
| Submit without `submitUri` after On top | Success message and close; underlying form not reloaded | Success message, remain open, reload underneath |

Replace is used by Simple and editable Wizard. View-only Wizard opens its next form On top.

## 5. Open risks

| Risk | Notes |
|---|---|
| Shared Wizard service | Opening another form can clear data used by a view-only Wizard underneath. From code inspection only; needs reproduction |
| Nested Wizard groups | Parsed but not rendered; a nested group and its fields are not shown |
| Footer changes | Shared footer also serves Approve/Reject buttons in generic approvals and claims |
| `US-1213846` TODOs | 43 TODOs covering duplication and Simple/Wizard drift |

## 6. Feature test matrix

Test approach: **Once** = shared code path, test the logic once. **Once + smoke both** = test the logic once, then a short check on each layout because the caller differs. **Both** = layout-dependent behaviour, test on each layout with its own expected result. **Simple only** / **Wizard only** = no equivalent on the other layout (Wizard-only rows include a negative check on Simple where relevant).

| Feature | Simple | Wizard | Shared? | Test approach |
|---|---|---|---|---|
| Entry and layout selection by backend `type` | Used | Used | Shared | Once (fixtures for each type) |
| Field widget rendering (text, multiline, date/time, numeric, toggle, select, multi-select, inline comment, image, file) | Own `_buildItem`, shared widgets | `FormItemBuilder`, shared widgets | Shared widgets | Once per field type + smoke both |
| Attachment field rendering | Shared widget | Shared widget | Shared | Once |
| Group header (name, description, badge, error icon) | `FormGroupExpansionTile` | `FormGroupExpansionTile` | Shared | Once |
| Group expand/collapse on tap | `FormGroupExpansionTile` | `FormGroupExpansionTile` | Shared | Once + smoke both |
| Group initial state (`isExpanded` true, false, missing) | Recursive caller | Per-step caller | Shared widget | Once + smoke both |
| Hidden group or field not shown | `SimpleExpressionBuilder` | `SimpleExpressionBuilder` | Shared | Once (logic) + smoke both (rendering) |
| Required / read-only expressions | Shared evaluator | Shared evaluator | Shared | Once (evaluator) |
| Required-field validation roll-up | Recursive, ignores invisible items | Rolls up to group and step | Differs | Both |
| Nested groups | Rendered recursively | Mapped, not rendered | Differs | Simple: positive. Wizard: negative (documented gap) |
| Items outside groups | Supported | Ignored (not displayed or submitted) | Differs | Simple: positive. Wizard: negative |
| Required `steps` and `groups` lists | Not applicable | Must be present | Wizard only | Wizard only |
| Step cards (overview) | Not used | One card per visible step | Wizard only | Wizard only |
| Empty step | Not applicable | Empty-state page | Wizard only | Wizard only |
| Empty form (no visible content) | Empty state | Empty state | Shared | Once + empty-step check on Wizard |
| Empty form Submit (`submitText` + `submitUri`) | Shown | Shown | Shared | Once |
| Submit label | `submitText` or default | `submitText` or default | Shared | Once |
| Submit with `submitUri` (Replace) | Replace | Replace (editable) | Shared rule | Both |
| Submit with `submitUri` (On top) | Not used for regular Simple | View-only Wizard | Differs | Wizard: view-only case. Simple: Replace case |
| Submit without `submitUri` (save) | Saves, pops with `FormMetadataResult` | Saves, refresh other forms, reloads or closes | Differs | Both |
| Submit enabled rules | Required filled, no errors, changesOnly needs a change | Always enabled when shown | Differs | Both |
| Submit shown rules | Not view-only, no custom buttons | No custom buttons, step confirmed or view-only with `submitUri` | Differs | Both |
| Confirm button | Not used | Keeps step changes in memory, no backend call | Wizard only | Wizard only |
| Confirm enabled rules | Not applicable | Step changed and no errors | Wizard only | Wizard only |
| Per-step Back warning | Not applicable | Only the changed step | Wizard only | Wizard only |
| Whole-form Back warning | Whole form | Overview only | Differs | Both |
| Unsaved-changes warning (Continue discards) | Shared concept | Shared concept, step-scoped on steps | Shared | Once + Wizard step check |
| Reverting a value to original removes change | Shared | Shared | Shared | Once |
| Custom buttons (close and return id) | Shared footer | Shared footer (overview) | Shared | Once; also check in generic approvals and claims |
| `Web` navigation item (Default, Inline, External) | Supported | Supported | Shared | Once |
| Unknown nav display mode or type, missing deep link | Shared handling | Shared handling | Shared | Once |
| `Functionality` navigation item | Supported, On top | Removed on load | Differs | Simple: positive. Wizard: confirm item is absent |
| `Functionality` target validation (must be Forms overview, backend `type: Simple`) | Enforced | Not applicable | Simple only | Simple only |
| `viewOnly` (read-only rendering) | Shared | Shared | Shared | Once for rendering, Both for buttons |
| `viewOnly` button visibility | Submit hidden | Submit only with `submitUri` | Differs | Both |
| `changesOnly` payload (changed values only) | Shared | Shared | Shared | Once |
| `changesOnly` Submit gate | Needs at least one change | No gate | Simple only | Simple only |
| Replace payload (`x-form-functionality` header) | Shared | Shared | Shared | Once (payload), Both (Replace flow) |
| Attachments not forwarded on Replace | Shared (edge case without `changesOnly`) | Shared | Shared | Both |
| Internal forms send no values on Replace | Shared | Shared | Shared | Once |
| Back after Replace or On top | Shared chain rules | Shared chain rules | Shared | Both (post-submit results differ) |
| Submit without `submitUri` after On top | Closes, underlying form not reloaded | Stays open, reloads underneath | Differs | Both |
| Service lifetime and shared state | New instance per screen | One shared instance | Differs | Wizard only (risk check: open another form while a view-only Wizard is underneath) |
| Tracking events (`form_view`, `form_edit`, `form_submit`) | Shared | Shared | Shared | Once (layout not in payload) |
| Tracking identity for CAPI and deep-link opens | Anonymous | Anonymous | Shared | Once |
