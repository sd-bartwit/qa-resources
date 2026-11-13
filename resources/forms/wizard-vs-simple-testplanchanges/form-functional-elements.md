# Forms: Functional Elements Overview (UAT)

What a tester can see or do in Forms, and whether it is **Shared**, **Simple-specific** or **Wizard-specific**.

- **Shared** = same behaviour and same result on both layouts.
- If a behaviour differs per layout (for example Submit enablement), it is listed once per layout and is not Shared.
- Technical-only differences (service lifetime, ViewModels, converters, TODOs) are left out.

## 1. Entry and header

| Element | Description | Scope |
|---|---|---|
| Open from in-app screens (claims, approvals, time & attendance, home widget) | Opens the Forms overview; backend `type` picks Simple or Wizard | Shared |
| Open from home tile | Same | Shared |
| Open from deep link | Same | Shared |
| Form title | Shown in the app bar | Shared |
| Form description | Shown on the form | Shared |
| Form comment banner | Information message above the content | Shared |
| Form badge | Information / Warning / Success / Error badge with title | Shared |

## 2. Structure

| Element | Description | Scope |
|---|---|---|
| Group header | Name, optional description, badge, error icon, expand arrow | Shared |
| Group initial state | `isExpanded` true = open; false or missing = closed | Shared |
| Group expand / collapse | Tap the header | Shared |
| Hidden group | Not shown | Shared |
| Group with no visible fields | Header only, no content | Shared |
| Single scrollable page | All fields and groups on one page | Simple-specific |
| Fields outside groups | Shown next to groups | Simple-specific |
| Nested groups | Rendered inside each other | Simple-specific |
| Overview with step cards | One card per visible step, no progress bar | Wizard-specific |
| Step card | Name, optional description and badge, warning icon on error | Wizard-specific |
| Hidden step | Card not shown | Wizard-specific |
| Step page | Opens when a card is tapped | Wizard-specific |
| Empty step | Opens the standard empty state | Wizard-specific |
| Fields outside groups | Ignored: not shown, not submitted (`clocking-v2/wizardNoGroup.json` uses step-level items; confirm if intended) | Wizard-specific |
| Nested groups | Not shown (known gap) | Wizard-specific |

## 3. Field types and states

| Element | Description | Scope |
|---|---|---|
| Text | Single-line input | Shared |
| TextArea | Multi-line input | Shared |
| Numeric | Number input | Shared |
| Numeric with currency mask | Prefix and thousands separator shown | Shared |
| Boolean | Toggle | Shared |
| DateTime | Date picker | Shared |
| Select | Single choice from a list | Shared |
| Radio | Single choice, vertical or horizontal | Shared |
| MultiSelect | Several choices | Shared |
| Large option list | 200+ entries stay usable | Shared |
| Shared value set | Two fields use the same options | Shared |
| Inline comment | Information / Success / Warning / Error banner, not editable, not submitted | Shared |
| Image | Shown at the given size | Shared |
| Attachment | Limits on amount, size and file type; error dialog when exceeded | Shared |
| File item | Rendered and usable | Shared |
| Visible true / false | Field shown / hidden | Shared |
| Required true / false | Required field is validated; optional is not | Shared |
| ReadOnly true / false | Not editable / editable | Shared |
| Required and ReadOnly together | Edge case, behaviour to confirm | Shared |

## 4. Validation and errors

| Element | Description | Scope |
|---|---|---|
| Inline validation | Error text on an empty required field | Shared |
| Provider / app error after submit | Error shown, form stays open, values kept | Shared |
| Submit blocked by required fields | Submit disabled until visible required fields are filled and no errors exist | Simple-specific |
| Hidden required field | Ignored by validation | Simple-specific |
| Error roll-up | Error shows on the field, the group icon and the step card warning icon | Wizard-specific |
| Confirm blocked by errors | Confirm disabled while the step has errors | Wizard-specific |

## 5. Buttons and actions

| Element | Description | Scope |
|---|---|---|
| Submit label | `submitText`, or "Submit changes" | Shared |
| Submit with `submitUri` (editable form) | Opens the next form, replacing the current one | Shared |
| Custom buttons | Close the form and return the button id, no save, Submit hidden (also Approve / Reject in claims and approvals) | Shared |
| Submit position and visibility | At the bottom; hidden when view-only or custom buttons exist | Simple-specific |
| Submit enabled | Required fields filled and no errors | Simple-specific |
| Submit with `changesOnly` | Also needs at least one change | Simple-specific |
| Submit without `submitUri` | Saves, shows success message, closes | Simple-specific |
| Submit visibility | Shown only after a step was confirmed (or view-only with `submitUri`); hidden with custom buttons | Wizard-specific |
| Submit enabled | Always enabled when shown | Wizard-specific |
| Submit without `submitUri` | Saves, shows success message, refreshes other forms, reloads in place (closes if opened by Replace) | Wizard-specific |
| Submit with `submitUri` (view-only) | Opens the next form on top; Back returns | Wizard-specific |
| Confirm button | On step page, hidden when view-only; enabled when the step changed and has no errors | Wizard-specific |
| Confirm action | Back to overview, keeps changes in memory, no save, no success message | Wizard-specific |

### Submit permutations (with and without `submitUri`)

Custom buttons present: Submit is hidden in every case below. Label is `submitText`, or "Submit changes" if missing.

| Layout | Form state | `submitUri` | Submit button | Result |
|---|---|---|---|---|
| Simple | Editable | No | Shown at the bottom; enabled when visible required fields are filled and no errors (with `changesOnly`: also needs a change) | Saves, success message, closes; if opened On top, form underneath is not reloaded |
| Simple | Editable | Yes | Same as above | No save; next form opens by Replace and current form closes; external forms get values in the `x-form-functionality` header (changed values only with `changesOnly`), internal forms get none; Back from the next form goes before the first form |
| Simple | View-only | No | Hidden | Nothing to submit |
| Simple | View-only | Yes | Hidden | Nothing to submit (not reachable) |
| Simple | Empty | No | Not shown | Empty state only |
| Simple | Empty (also view-only) | Yes, with `submitText` | Shown, always enabled | Next form opens by Replace |
| Wizard | Editable | No | Hidden until a step is confirmed, then always enabled | Saves, success message, refreshes other open forms; reloads in place, or closes if opened by Replace; if opened On top, stays open and reloads and the form underneath refreshes too |
| Wizard | Editable | Yes | Same as above | No save; next form opens by Replace and current form closes; values passed as in Simple |
| Wizard | View-only | No | Hidden (Confirm hidden too) | Nothing to submit |
| Wizard | View-only | Yes | Shown | Next form opens On top, no values passed; Back returns to the current form |
| Wizard | Empty | No | Not shown | Empty state only |
| Wizard | Empty | Yes, with `submitText` | Shown, always enabled | Editable: Replace; view-only: On top |

Wizard Confirm never saves and never follows `submitUri`; it only returns to the overview. The next form can be Simple or Wizard.

## 6. Navigation items

| Element | Description | Scope |
|---|---|---|
| Web item, Default | Opens the in-app web-view; form stays open, values kept | Shared |
| Web item, Inline | Opens an in-app browser; external-link icon | Shared |
| Web item, External | Opens the phone browser; external-link icon | Shared |
| Unknown display mode / type / missing deep link | Unknown mode acts as Default; unknown type or missing link hides the item | Shared |
| Functionality item to a Simple form | Opens on top; Back returns | Simple-specific |
| Functionality item with unsaved changes | Warning; Continue discards | Simple-specific |
| Functionality item to a Wizard form | Generic error, new page closes, form stays | Simple-specific |
| Functionality item | Not shown | Wizard-specific |

## 7. Unsaved changes

| Element | Description | Scope |
|---|---|---|
| Value changed back to original | No change, no warning | Shared |
| Back with no changes | No warning | Shared |
| Back after a change | Warning for the whole form; Continue discards | Simple-specific |
| Back from overview | Warning for the whole form; Continue discards | Wizard-specific |
| Back from a step | Warning for that step only; Continue discards it | Wizard-specific |

## 8. View-only

| Element | Description | Scope |
|---|---|---|
| Read-only rendering of all field types | Label and value, not editable | Shared |
| Badge in view-only | Shown | Shared |
| Groups as cards | Each group is a card | Simple-specific |
| No groups | All non-navigation fields in one card; navigation items separate | Simple-specific |
| Submit | Hidden | Simple-specific |
| Navigation items | Functionality and Web stay active | Simple-specific |
| Groups as cards | Each group is a card on the step page | Wizard-specific |
| Submit / Confirm | Confirm hidden; Submit only when `submitUri` exists | Wizard-specific |
| Navigation items | Web stays active | Wizard-specific |

## 9. `changesOnly` and data sent

| Element | Description | Scope |
|---|---|---|
| `changesOnly` true | Only changed values sent | Shared |
| `changesOnly` false | All regular items sent, including hidden; inline comments excluded | Shared |
| Attachments on Submit | Sent when they contain a file | Shared |
| Values passed to next form (external) | Sent in `x-form-functionality` header; attachments and metadata not forwarded | Shared |
| Values passed to next form (internal) | None | Shared |

## 10. Opening a next form

| Element | Description | Scope |
|---|---|---|
| Layout of next form | Simple or Wizard from either layout | Shared |
| Back after Replace | Returns before the first form; warns only if the new form changed | Shared |
| Back after On top | Returns to the form underneath | Shared |
| Submit (no `submitUri`) after On top | Success message, closes, form underneath not reloaded | Simple-specific |
| Submit (no `submitUri`) after Replace | Success message, closes | Simple-specific |
| Submit (no `submitUri`) after On top | Success message, stays open and reloads; form underneath refreshed | Wizard-specific |
| Submit (no `submitUri`) after Replace | Success message, closes, other forms refreshed | Wizard-specific |
| View-only Wizard underneath another form | Risk: underlying Wizard may break after returning (to reproduce) | Wizard-specific |

## 11. Empty form

| Element | Description | Scope |
|---|---|---|
| Empty state | Title, illustration, "No data available", description | Shared |
| Submit on empty form | Shown only with `submitText` and `submitUri` and no custom buttons; always enabled | Shared |
| Empty when | No visible item at any depth | Simple-specific |
| View-only empty form with `submitUri` | Next form replaces the current one | Simple-specific |
| Empty when | No visible step holding a visible group with a visible item | Wizard-specific |
| View-only empty form with `submitUri` | Next form opens on top | Wizard-specific |

## 12. Search (planned)

Design outline only; confirm it is released before regression.

| Element | Description | Scope |
|---|---|---|
| Search field | Shown only when the form defines `search`; filters by label or value; minimum characters respected | Simple-specific |
| Search does not change data | Values and required validation unaffected | Simple-specific |
| No search field | Not available | Wizard-specific |

## 13. Analytics

| Element | Description | Scope |
|---|---|---|
| `form_view`, `form_edit`, `form_submit` | Once per session; `view_mode` set; layout not in the payload | Shared |
| Form identity | Home tile: tile name. Home widget: form id. Deep link: anonymous (known gap) | Shared |

## 14. To confirm

- Step-level items in `clocking-v2/wizardNoGroup.json`: defect or planned feature.
- View-only Wizard underneath another form (shared state risk).
- Nested groups not rendered in Wizard.
- Required and ReadOnly together.
- Whether a hidden required field is ignored on Wizard too.
- Where description and comment appear on the Wizard overview.
- Footer is shared with Approve / Reject in claims and approvals: smoke test them after footer changes.
