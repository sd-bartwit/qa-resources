[[_TOC_]]


## Summary

- All callers use `FormRouter.openFormOverview` and `FormOverviewRoute`. The backend selects Simple or Wizard through the form's `type` field.
- Both layouts use the same field types and widgets. Simple shows all fields on one page; Wizard shows step cards and opens each step on a separate page.
- Submit sends the form to the backend unless `submitUri` opens a next form instead. Wizard's Confirm button only keeps one step's changes in memory; it does not call the backend.
- `viewOnly` and `changesOnly` are independent. `viewOnly` controls interaction and buttons; `changesOnly` controls the payload and, for Simple, whether Submit can be pressed.
- Deep-link form tracking is anonymous today, and the Forms code contains 43 `US-1213846` TODO comments about duplication and Simple/Wizard drift.

---
## 1. Behaviour

### 1.1 Layout and controls

| Topic | Simple | Wizard |
|---|---|---|
| Structure | One scrollable page with all fields | Overview with one card per visible step; tapping a card opens the step page |
| Step cards | Not used | Step name; optional description and badge; warning icon when the step has an error; no progress bar |
| Groups | Expandable sections; a view-only form without groups shows all fields in one card | Expandable sections inside each step |
| Main control | Submit at the bottom | Submit on the overview; Confirm on each step page |
| Navigation items | `Functionality` and `Web` | `Web` only; `Functionality` items are removed while the form is converted |

#### Group rules

| Rule | Simple | Wizard |
|---|---|---|
| Where fields may appear | Fields and groups can be mixed on the form page | Fields must be inside a group, and groups must be inside a step |
| No groups | Valid: fields are shown directly on the page | `groups: []` is valid but makes the step empty; if no step has visible content, the whole form uses the empty state |
| Items outside groups | Supported | Not supported: the Wizard API model has no `items` field at form or step level |
| Nested groups | Supported and rendered recursively | Converted into the domain model, but not rendered by the current step UI |
| Visibility | A hidden group or field is not shown | A hidden step, group, or field is not shown |
| Initial expansion | `isExpanded: true` starts open; `false` or missing starts closed | Same |
| Header | Group name; optional description, badge, error icon, and expand/collapse arrow | Same |
| View-only | Each group is wrapped in a card. With no groups, all non-navigation fields share one card and navigation items remain separate | Each group is wrapped in a card |

Wizard JSON must follow `steps → groups → items`. An `items` property placed directly on the Wizard form or a step is ignored because neither API model reads it; those items are not displayed or submitted.
The required `steps` and `groups` properties must still be present as lists; omitting either can fail deserialization.

Groups can be empty. If another visible field keeps the form or step non-empty, a visible empty group may still appear as an expandable header with no content. A visible Wizard step may also have no visible fields; opening that card shows the standard empty state.

The Wizard nested-group limitation is in rendering, not parsing: `form_groups_extension.dart` builds `GroupItemWithValue` recursively, but `FormStepLoadedBody` sends nested group items to `FormItemBuilder`, which has no group case. Simple uses its own recursive `_buildItem` and displays them.

### 1.2 What each action does

| Action | Available in | Result | Backend save? |
|---|---|---|---|
| Submit without `submitUri` | Simple; Wizard overview | Saves the form | Yes |
| Submit with `submitUri` | Simple; Wizard overview; empty form | Opens the next form | No |
| Confirm | Wizard step | Keeps the step's changes and returns to the overview | No |
| `Functionality` navigation item | Simple only | Opens another form On top | No |
| `Web` navigation item | Simple and Wizard | Opens a web page | No |
| Custom button | Simple; Wizard overview | Closes the form and returns the selected button id to the caller | No; the caller decides what to do |

### 1.3 Submit and Confirm rules

| Rule | Simple Submit | Wizard overview Submit | Wizard step Confirm |
|---|---|---|---|
| Label | `submitText`, or "Submit changes" | `submitText`, or "Submit changes" | Always "Confirm" |
| Shown when | Not view-only and no custom buttons | No custom buttons, and either a step was confirmed or the view-only form has a `submitUri` | Not view-only |
| Enabled when | All visible required fields are filled; no errors; a `changesOnly` form also needs at least one change | Always enabled when shown; step errors are handled before Confirm | The step changed and has no errors |
| Without `submitUri` | Save, show a success message, close, return `FormMetadataResult` | Save, show a success message, broadcast a refresh, and normally reload in place | Not applicable |
| With `submitUri` | Open the next form by Replace | Open by Replace; a view-only Wizard opens it On top | Not applicable |

Confirm does not submit anything. It calls `confirmChangesInForm`, keeps the step's changes in memory, and returns to the Wizard overview. The user must then press Submit.

If the user leaves a changed step without Confirm, the app shows the unsaved-changes warning. Continuing clears that step's temporary changes and returns to the overview.

### 1.4 Navigation items

The form JSON gives each navigation item a type and, for `Web`, a display mode.

| Type | Display mode | Result | Simple | Wizard |
|---|---|---|---|---|
| `Functionality` | n/a | Open another form On top | Yes | No; removed when the form loads |
| `Web` | `Default` | Open the app's web-view screen | Yes | Yes |
| `Web` | `Inline` | Open an in-app browser | Yes | Yes |
| `Web` | `External` | Open the phone's browser | Yes | Yes |

Details and edge cases:

- A Simple `Functionality` link shows the unsaved-changes warning when needed. Continuing discards the current changes.
- For a Simple `Functionality` link to open successfully, its `functionality` URI must point to the Forms overview and the backend response must have `type: Simple`. If the URI points to another app functionality, or the backend returns `type: Wizard`, the app shows a generic error, closes the new page, and returns to the original Simple form. This restriction applies only to `Functionality` navigation items; Simple → Wizard through `submitUri` is allowed.
- `Web` links keep the form open, so values and temporary changes remain. No warning is shown.
- `Inline` and `External` show the external-link icon; `Default` and `Functionality` show an arrow.
- An unknown display mode becomes `Default`. An unknown type or missing deep link hides the item.

### 1.5 Opening a next form (`submitUri`)

| Mode | What the user experiences | Values passed? |
|---|---|---|
| Replace | The current form closes; the next form takes its place; Back cannot return to the closed form | External forms: entries from `FormUpdate.items` are sent to the backend while the next form loads. Internal forms: no values. Attachment files and metadata are not sent |
| On top | The current form remains underneath; Back returns to it | No |

#### What "values are passed" means

1. Submit builds a `FormUpdate` from the current form.
2. `replaceWithNewFormOverview` stores it on the new route as `paramsToSend`.
3. The new `FormViewModel` passes it to `FormsDataManager.getForms` while loading the next form.
4. For an external form, `_prepareHeader` URL-encodes each `FormUpdate.items` entry as `<item id>=<item value>` and appends it to the `x-form-functionality` header.
5. The backend reads those parameters and decides what values appear in the returned form JSON. The app does not copy values directly into the next form.

`FormUpdate.items` contains changed item values when `changesOnly` is true; otherwise it contains the regular item values regardless of whether they changed (including hidden items). Inline comments are excluded. Groups are traversed to reach their fields.

Attachment files are held in `FormUpdate.attachments`, and metadata is held in `FormUpdate.metadata`.
`_prepareHeader` reads only `FormUpdate.items`, so neither is forwarded to the next form. One Simple-form edge case remains: without `changesOnly`, an empty attachment field can enter `items` as its id with a null value; the file itself is still never forwarded. Wizard excludes attachment fields from `items`.

Internal forms call `getInternalForms(formId)` without `paramsToSend`, so they forward no values at all.

Replace is used by Simple and editable Wizard forms. A view-only Wizard form opens its next form On top.
An empty form follows the same rule. A `Functionality` navigation item is different: it opens On top and is available only in Simple.

The next form may be Simple or Wizard, regardless of the current layout. A Simple `Functionality` item is the exception: it cannot target Wizard.

#### Which layouts can open which?

With `submitUri`, **all four combinations are allowed**:

| Current form | Next Simple | Next Wizard | Opening mode |
|---|---|---|---|
| Simple | Allowed | Allowed | Replace. A regular view-only Simple has no Submit; an empty view-only Simple can still Replace |
| Editable Wizard | Allowed | Allowed | Replace |
| View-only Wizard | Allowed | Allowed | On top |

With a `Functionality` navigation item, the rules are narrower:

| Current form | Next Simple | Next Wizard |
|---|---|---|
| Simple | Allowed; opens On top | Blocked after loading; the app shows a generic error and closes the new page |
| Wizard | Not available; `Functionality` items are removed | Not available; `Functionality` items are removed |

Direct, home-tile, and deep-link entry can return either layout; the backend `type` decides it.

#### After the next form opens

| User action | After Replace | After On top |
|---|---|---|
| Back | Return to the screen before the first form in the chain; warn only if the new form itself changed | Return to the form underneath |
| Submit a Simple form without `submitUri` | Success message; close | Success message; close; do not reload the form underneath |
| Submit a Wizard form without `submitUri` | Success message; close; refresh other open forms | Success message; remain open and reload; refresh the form underneath too |
| Submit another form with `submitUri` | Continue the chain with the same rules | Continue the chain with the same rules |


> **QA risk (finding from AI - need to recheck):** all Wizard screens share one in-memory service. Opening another form can clear or overwrite the data used by a view-only Wizard underneath. The page may still look normal, but opening a step or pressing Submit may fail or use the wrong form. This is based on code inspection and still needs reproduction in the app.

### 1.6 `viewOnly` and `changesOnly`

Both flags come from the form JSON, default to `false`, and are independent. The code does not derive one from the other.

#### `viewOnly`

| Area | Simple | Wizard |
|---|---|---|
| Fields | Read-only label/value rendering; groups become cards | Same, on each step page |
| Submit | Hidden | Shown only when the form has `submitUri` |
| Confirm | n/a | Hidden |
| `submitUri` | Regular form cannot reach it because Submit is hidden; an empty form still opens it by Replace | Opens On top; passes no values |
| Navigation items | Still active | Still active (`Web` only) |
| Tracking | `form_view` uses `view_mode = view_only`; no `form_edit` | Same |

`viewOnly` is interpreted by the presentation layer. The data layer stores the flag but does not use it to filter the payload.

#### `changesOnly`

| Area | Simple | Wizard |
|---|---|---|
| Direct-submit payload | Only changed values | Same |
| Values passed by Replace | Only changed values | Same |
| Attachments on direct Submit | Included when they contain a file; not filtered by `changesOnly` | Same |
| Submit gate | At least one changed value is required | No extra gate; Submit appears after a step was confirmed |

Without `changesOnly`, all regular items with an id are sent, including hidden items; inline comments are skipped. Simple may then submit without any change once all visible required fields are filled.

"Changed" means different from the original loaded value. Changing a value back to its original value removes the change. If `viewOnly` and `changesOnly` are both true, the user cannot create a change, so `changesOnly` has nothing to filter. The Back warning depends on actual changes, not on either flag.

### 1.7 Empty forms

A form is empty when it has no visible content:

- Simple: no visible item, including inside nested groups.
- Wizard: no visible step containing a visible group with a visible item.

The shared empty state shows the form title in the app bar, a standard illustration, "No data available", and the standard description. A Submit button appears only when both `submitText` and `submitUri` exist and no custom buttons were supplied. It is always enabled.

---

## 2. Technical design

### 2.1 Shared foundation

| Area | Shared implementation |
|---|---|
| Base model | `BaseForm`: `type`, `title`, `description`, `comment`, `valueSets`, `metadata`, `submitUri`, `submitText`, `changesOnly`, `badge`, `viewOnly` |
| Field models/widgets | Text, multiline, date/time, numeric, toggle, select, multi-select, inline comment, attachment, group, image, navigation, and file |
| Rendering | `FormItemBuilder`, field widgets, expandable group, view-only card/field, badge, inline-comment banner, `SubmitFormButtonWidget` |
| Expressions | `SimpleExpressionBuilder` evaluates visibility, required, and read-only expressions |
| Service contract | Temporary/confirmed form storage, clear/store/update, comments, change/error checks, confirmation, payload construction, expression evaluation, id uniqueness |
| Use cases | `ResolveNavigationItemUseCase` for Simple and Wizard steps; `SubscribeToRefreshStreamUseCase` in `FormViewModel` |
| Empty state | `EmptyFormState`, `FormEmptyContent`, `FormViewModel.onEmptyFormSubmit` |
| Tracking | One `FormTrackingContext` implementation for both layouts |

There are 17 converter files under `data/extensions/`: 15 are shared. The layout-specific converters are `simple_form_extension.dart` (Simple items and `areRequiredFieldsFilled`) and `form_steps_extension.dart` (Wizard steps).

### 2.2 Implementation differences

| Area | Simple | Wizard |
|---|---|---|
| Domain structure | Fields and groups can be mixed; groups may nest recursively | Steps → groups → items; nested groups are mapped but not rendered by the step UI |
| Service lifetime | `@Injectable`: new instance per screen | `@LazySingleton`: one shared instance |
| Payload traversal | Items, recursively through groups | Steps → groups → items |
| Required validation | Recursive `areRequiredFieldsFilled`; ignores invisible items | Required-item errors roll up to group and step |
| Screen ViewModel | `SimpleFormViewModel` extends `BaseFormViewModel` | Overview VM does not extend the base; step VM does |
| Item updates | Form-wide; nested lookup; direct Simple service call | Step/group scoped through `UpdateItemUseCase` |
| Provider-error updates | Implemented inside `SimpleFormViewModel` | `UpdateItemWithProviderErrorUseCase` |
| Submit state | `canSubmit` | `isSubmitAvailable`, `hasChanges`; Confirm uses step-local change comparison |
| Back warning | Whole-form changes | Overview: whole form; step: only that step |
| Form navigation items | Supported, with warning | Removed during conversion |
| After direct submit | Pop with `FormMetadataResult` | `notifyToRefresh`: reload or close when opened by Replace |

`FormGroupExpansionTile` applies the same header, initial-expansion, view-only card, and child-visibility behaviour in both layouts. The caller differs: Simple handles a nested `GroupItemWithValue` recursively; the Wizard step delegates it to `FormItemBuilder`, which falls through to an empty widget.

Two base-service members are Wizard-specific despite being declared on `BaseFormService`:

- `clearStepTemporaryChanges` is an empty base stub implemented only by Wizard.
- `hasSomethingToSubmit` is read only by Wizard. Simple sets and exposes it but never reads it.

---

## 3. Dependencies and entry points

### 3.1 Dependencies

| Category | Packages/services |
|---|---|
| Features | `sd_feature_base`, `sd_feature_sd_api`, `sd_feature_user`, `sd_feature_generic_picker`, `sd_feature_attachment`, `sd_feature_webview`, `sd_feature_information_screen` |
| Logging | `sd_logging_tracking`, logger, crash, performance |
| Platform | Media, file storage, launcher, share, connectivity, lifecycle |
| UI | Components, assets, dialogs, top-toast |
| Core/setup | Localization, config, extensions, `sd_setup_navigation`, `sd_setup_appconfig` |

### 3.2 Consumers

All consumers call `FormRouter.openFormOverview` with `functionality_uri`; the backend may return either layout.

| Consumer | Code location | Purpose |
|---|---|---|
| Generic approvals | `open_generic_approval_details_use_case.dart` | Approval form with custom Approve/Reject `FormButton`s |
| Expenses — claims | `expenses_claims_detail_view_model.dart` | Edit or view full claim details |
| Expenses — approvals | `expenses_claims_approvals_detail_view_model.dart` | Approver views full claim details |
| Home | `home_widget_viewmodel.dart`, early-access modal | Home actions using the `forms` scheme |
| Time & attendance | `time_attendance_viewmodel.dart` | Request forms |
| Deep links / home tile | `new_app_link_handler.dart`, `app_link_service.dart` | External deep links and tile entry |

Approve/Reject custom buttons and empty-form Submit use shared Forms footer behaviour. A footer change can therefore affect claims and approvals, not only standard forms.

### 3.3 Entry paths

- In-app: feature ViewModels call `FormRouter.openFormOverview`.
- Home tile: `app_link_service.dart` also passes `form_tile_name: <tile title>`.
- Deep link: `FormsQuickActionParser` parses `sdwa://forms?functionality_uri=…&access_right_id=…` into `FormsAppLinkRoute`, handled by `new_app_link_handler.dart`.

---

## 4. Tracking and the CAPI production check

### 4.1 Events

`FormTrackingContext` emits the same events for both layouts. View and edit are guarded so they fire once per form session.

| Constant | Event | Parameters |
|---|---|---|
| `eventFormView` | `form_view` | `form_name`, `form_id`, `view_mode` (`editable` / `view_only`) |
| `eventFormEdit` | `form_edit` | `form_name`, `form_id` |
| `eventFormSubmit` | `form_submit` | `form_name`, `form_id` |

The layout is not included in the payload. Constants and methods live in `tracking_constants.dart` and `tracking_service.dart` in `sd_logging_tracking`.

### 4.2 How form identity is selected

`FormOverviewScreen` creates the context from:

- `formName = parameters['form_tile_name']`
- `isInternal = accessRightIds.isEmpty`
- `trackedName = isInternal ? null : formName`
- `trackedId = isInternal ? formId : null`

| Open path | `form_tile_name` | `accessRightIds` | Tracked `form_name` | Tracked `form_id` |
|---|---|---|---|---|
| Home tile | Tile title | Non-empty | Tile title | null |
| Home widget / pilot (internal) | None | Empty | null | Form id |
| Deep link / CAPI | None | Non-empty (`access_right_id`) | null | null |

### 4.3 Current gap

CAPI/deep-link opens still emit `form_view`, `form_edit`, and `form_submit`, but all three are anonymous.
Analytics cannot identify the form or distinguish CAPI from another external open. Forms also has no dedicated deep-link-opened event, unlike invitations (`trackAcceptInviteDeeplinkOpened`).

---

## Appendix A — `US-1213846` TODO inventory (asked AI to generate it, maybe it's better to move to this US-1213846)

There are 43 comments carrying `todo: US-1213846`: 24 in the data layer and 19 in ViewModels. They mark duplication, misplaced members, and behavioural drift.

Some comments use the old name `FormGroupViewModel`; this means `FormStepViewModel`, whose log tag still uses the old name.

### A.1 Wizard-only members on the base (4 TODOs)

| Location | TODO meaning |
|---|---|
| `BaseFormService.clearStepTemporaryChanges` | Move to Wizard; Simple has no steps |
| `BaseFormService.hasSomethingToSubmit` | Read only by Wizard; move it so other service tests do not own it |
| `SimpleFormServiceImpl._hasSomethingToSubmit` | Never read by Simple; remove it |
| `SimpleFormServiceImpl.hasSomethingToSubmit` | Same as the field |

### A.2 Duplicated service logic (20 TODOs)

Nine members have one TODO in each service (18 total):

| Member | Extra note |
|---|---|
| `getTemporaryForm` | Wizard TODO says it can move to `BaseFormService` |
| `clearTemporaryChanges` | Wizard TODO names `WizardFormServiceImpl` as the duplicate; this is a typo and means Simple |
| `clearForm` | None |
| `storeForm` | None |
| `updateLiveForm` | None |
| `setFormComment` | None |
| `confirmChangesInForm` | None |
| `getFormUpdateToSend` | Both TODOs say it can move to `BaseFormService` |
| `_getItemToSend` | Both TODOs say it can move to `BaseFormService` |

Two additional data-layer TODOs complete the count of 20:

- `WizardFormsServiceImpl.getFormUpdateToSend`: nested loops could become `flatMap`, but that may reduce readability.
- `FormHasErrorsException`: declared in `wizard_forms_service.dart` but used by Simple too; move it to the base-service area.

### A.3 ViewModel logic (19 TODOs)

| Logic | Locations | TODO meaning |
|---|---|---|
| State building (`_updateState`) | Simple VM, Wizard VM | Mostly overlaps with another VM; consider `BaseFormViewModel`. Wizard would first need to extend it |
| Step `_updateState` | Step VM | Refers to removed Simple flag `hasSomethingUpdate` (`hasChanges` OR `accessRightId == null`); outdated |
| Back (`onPopInvoked`) | Simple, Step, Wizard VMs | Similar signature but different scope: whole form vs one step. Wizard TODO calls all three the same, which is not fully accurate |
| Single-select picker | Simple and Step VMs | Same picker flow; Simple searches form-wide, Step needs `groupName` |
| Multi-select picker | Simple and Step VMs | Same distinction as single-select |
| File errors | Simple and Step VMs | Same exception-to-dialog mapping |
| Navigation item | Simple and Step VMs | Simple guards form links with an unsaved-changes dialog; Step delegates directly |
| Update item | Simple and Step VMs | Simple calls its service directly and ignores `groupName`; Step uses `UpdateItemUseCase` with step/group |
| Submit / Confirm | Simple and Step VMs | Simple performs save or chaining; Step only confirms and returns |
| Empty-form submit | `FormViewModel` | Duplicates Simple/Wizard `submitUri` routing because Empty uses a separate state |

The TODOs collectively propose:

1. Move Wizard-only members out of `BaseFormService`.
2. Move common service code into `BaseFormService`.
3. Share genuinely common ViewModel logic; make Wizard overview compatible with that abstraction first.
4. Correct the typo, removed `hasSomethingUpdate` reference, and old `FormGroupViewModel` name.