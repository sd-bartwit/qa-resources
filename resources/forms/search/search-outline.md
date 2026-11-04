# Simple Forms — Local "Search" Filter: Implementation Outline (top-level property)

A grounded outline for adding a local **Search** filter to Simple Forms. Search is modeled as a
**top-level property** of `SimpleForm` — a sibling of `items`, following the established
`comment` / `badge` / `valueSets` pattern — rather than as an entry inside the `items` list. This
matches how the API exposes the customization block.

### API contract (source of truth)

From `src/SDWA.AssistantApi.Contracts/Forms/SimpleForm.cs` and `FormSearchOptions.cs`:

```csharp
public sealed class SimpleForm : FormLayoutBase, ISearchableForm
{
    ...
    /// Search configuration. Null means search is not supported.
    public FormSearchOptions? Search { get; set; }

    /// Whether this form currently supports search.
    public bool IsSearchSupported => Search is not null;
}

/// Configures search supported by a form.
public sealed class FormSearchOptions
{
    /// Minimum query length before searching. Zero allows an empty query.
    /// Defaults to one character. Must be non-negative.
    [Range(0, int.MaxValue)]
    public int MinimumCharacters { get; set; } = 1;
}
```

Key takeaways that drive the client design:

- **Presence = support.** `Search == null` ⇒ search is not supported ⇒ render nothing, never
  filter. There is no separate `enabled` flag; `IsSearchSupported` is derived from `Search != null`.
- **Single option today: `MinimumCharacters`** (int, default `1`, non-negative). Below this length
  the query is a no-op passthrough; `0` allows an empty query to drive filtering.
- **No `placeholder` field** in the contract — the client supplies its own localized placeholder.

### Data flow

```
backend DTO (SimpleForm.search: FormSearchOptions) → FormSearchOptions DTO → FormSearchConfig (domain)
    → SimpleForm.search → Loaded.search → SimpleFormLoadedBody (sticky header)
                                        ↘ SimpleFormViewModel._applySearchFilter (presentation-only)
```

The search field retains only those items/groups whose displayed text properties match the filter
text. Filtering is **presentation-only** — it never mutates the service's temporary form, so values,
validation, and submit remain unaffected.

> **Why top-level instead of an item?** Search is *customization/config*, not a submittable field,
> and the API already exposes it as a top-level `Search` property. Modeling it the same way on the
> client keeps it structurally out of the item set by construction, so we avoid "inert item"
> gymnastics (faked `isValueChanged => false`, null id, `getFormUpdateToSend` exclusion, "always
> retain the search item in its own filter", view-only-card special-casing). It also degrades
> gracefully on older clients (an unknown top-level field is ignored, instead of a new item-type
> enum value throwing `FormInvalidItemTypeException`).

---

## 1. Model / data layer — introduce the top-level property

Mirror the existing `comment` pipeline end-to-end (`FormComment` DTO → `FormComment` domain →
`form_comment_extension.dart` → wired in `form_extension.dart`).

### 1a. API DTO

- **New DTO** `data/api/models/form_search_options.dart` (`@JsonSerializable`), matching
  `FormSearchOptions.cs`:

  ```dart
  @JsonSerializable()
  class FormSearchOptions {
    final int? minimumCharacters; // C# default 1; null-safe on read
    FormSearchOptions(this.minimumCharacters);
    factory FormSearchOptions.fromJson(Map<String, dynamic> json) => _$FormSearchOptionsFromJson(json);
    Map<String, dynamic> toJson() => _$FormSearchOptionsToJson(this);
  }
  ```

- Add `final FormSearchOptions? search;` to `data/api/models/form_simple_form.dart` — field +
  constructor param (keep positional ordering consistent with the existing constructor). `null`
  encodes "search not supported", exactly like the contract.
- **Regenerate** `form_simple_form.g.dart` and the new `form_search_options.g.dart`
  (`dart run build_runner build`).
- If search should also apply to wizard forms, add `search` to `BaseForm`
  (`data/api/models/form_base_form.dart`) where `comment` / `badge` / `valueSets` already live;
  otherwise keep it on `SimpleForm` only. (The contract only adds it to `SimpleForm`, so prefer
  `SimpleForm`-only unless wizard support is requested.)

### 1b. Domain model

- **New domain model** `data/models/form_search.dart` (plain `Equatable`, like `form_comment.dart`):

  ```dart
  class FormSearchConfig extends Equatable {
    /// Minimum query length before filtering. 0 allows an empty query. Defaults to 1.
    final int minimumCharacters;
    const FormSearchConfig({this.minimumCharacters = 1});
    @override
    List<Object?> get props => [minimumCharacters];
  }
  ```

- Add `final FormSearchConfig? search;` to `data/models/simple_form.dart`:
  - add to the constructor,
  - add to `props`,
  - propagate through `copyWithComment` (and any future copy helpers).
  - optional convenience getter mirroring the contract: `bool get isSearchSupported => search != null;`

### 1c. Mapper

- **New** `data/extensions/form_search_extension.dart` (clone `form_comment_extension.dart`),
  clamping to the contract's non-negative rule and default:

  ```dart
  extension FormSearchExtension on api.FormSearchOptions {
    FormSearchConfig toDomain() => FormSearchConfig(
      minimumCharacters: (minimumCharacters ?? 1).clamp(0, 1 << 31),
    );
  }
  ```

- Wire it in `data/extensions/form_extension.dart` → `SimpleFormExtension.toDomain`, next to the
  existing `comment:` / `badge:` lines:

  ```dart
  return SimpleForm(
    ...
    comment: comment?.type != ... ? comment?.toDomain() : null,
    badge: badge?.toDomain(simpleExpressionBuilder),
    search: search?.toDomain(),   // null stays null → "search not supported"
    ...
  );
  ```

> **Not needed with this approach:** no `FormItemType` enum changes (API or domain), no
> `form_items_extension._mapFormItemType` case, no `SearchItemWithValue` in `item_with_value.dart`,
> and no `FormItemType.search` case in `simple_form_extension.dart`. The item pipeline is untouched.

---

## 2. Presentation — the widget

- New `FormSearchField` widget (clone the `text_item/text_item.dart` pattern:
  `TextEditingController`, `onChanged`). Add **debounce** (~250–300ms) and a clear (✕) affix. Use a
  localized placeholder (the API does not send one).
- **Placement is trivial** — render it as a sticky header in `simple_form_loaded_body.dart`, in the
  same slot where `comment` is rendered today (above `Expanded(child: _buildItemsList(context))`):

  ```dart
  if (search != null) ...[
    const SizedBox(height: 12),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: FormSearchField(
        config: search!,
        onChanged: getViewModel(context).onSearchChanged,
      ),
    ),
    const SizedBox(height: 12),
  ],
  Expanded(child: _buildItemsList(context)),
  ```

  `search != null` is the client-side equivalent of `IsSearchSupported`.

- Thread a new `final FormSearchConfig? search;` field into `SimpleFormLoadedBody`'s fields +
  constructor (sibling of the existing `comment` / `badge` fields).

> Because the field lives in the header (outside `items`), **both** render paths
> (`_buildItemsList` → `ListView.separated`, and `_buildViewOnlyItems` → `_buildFieldsCard`) stay
> clean automatically. No need to exclude a "search item" from the fields card in view-only mode.

---

## 3. Callback chain — filtering in the ViewModel

Crucial design point: **filter at presentation only, never mutate the service's temporary form.**
`SimpleFormServiceImpl.getTemporaryForm()` stays the full source of truth (values, validation,
submit unaffected).

### Why `getTemporaryForm()` stays the source of truth

The service holds **two private fields** and never exposes them directly:

- `_formToSend` — the confirmed, submittable form.
- `_temporaryForm` — the live editing copy.

Every read returns a **defensive deep copy**, and every value write goes back through the service.
That's why a presentation-only filter is safe — nothing you render is ever written back:

- **Values persist regardless of what's displayed.** `updateItem` looks up by `itemId` against the
  *full* temporary form (recursing into groups), not against the VM's filtered `Loaded.items`. So
  typing in a field that is currently filtered out keeps its value intact.
- **Validation is computed over all items, not the visible subset.** `areRequiredFieldsFilled` /
  `hasError` are recomputed over the full item tree on every copy; `_updateState` reads these from
  the service / full form. A required-but-empty item that your filter hides still contributes to
  `canSubmit`, so narrowing the search can't accidentally "unlock" submit — the correct, safe
  behavior.
- **Submit ignores the filtered list entirely.** `getFormUpdateToSend()` iterates
  `_formToSend!.items`, never the VM state.

**Net effect:** the search filter lives *downstream* of `getTemporaryForm()` — it transforms only
the list handed to the `Loaded` state. Since the filtered list is never passed back to the service,
`_temporaryForm` / `_formToSend` always retain the complete item set.

### The callback wiring

- Add `onSearchChanged(String query)` (abstract in `base_form_viewmodel.dart` if shared, implemented
  in `SimpleFormViewModel`):

  ```dart
  String _searchQuery = '';

  Future<void> onSearchChanged(String query) async {
    _searchQuery = query.trim().toLowerCase();
    await _updateState(isLoading: false); // no trackEdit, no service write
  }
  ```

- In `SimpleFormViewModel._updateState`, wrap the existing visibility filter with the search filter
  and pass the search config into `Loaded`:

  ```dart
  updateState(
    Loaded(
      ...
      items: _applySearchFilter(_getItemsFilteredByVisibility(simpleForm?.items), simpleForm?.search),
      badge: simpleForm?.badge,
      comment: errorComment ?? simpleForm?.comment,
      search: simpleForm?.search,   // mirrors badge/comment
      ...
    ),
  );
  ```

  Since `_updateState` already rebuilds the `Loaded` state and `ViewModelBuilder` re-renders, this
  is the entire reactive chain. (Also add `FormSearchConfig? search` to the `Loaded` state in
  `simple_form_state.dart`: field, constructor param, and `props`.)

---

## 4. The matching helper

Define a "searchable text" per item and recurse into groups:

- **Leaf match** = query ⊆ lowercased(`label` + rendered value):
  - text / multiline → `value`
  - numeric → formatted number
  - date → formatted date
  - select / multiselect → selected `allowedValue.value`(s)
  - toggle → label
  - comment → `message`
  - navigation → `label`
- **`GroupItemWithValue`**: keep the group if its `group.group` title matches **or** any child
  matches; when kept, replace its children with the filtered subset via
  `group.copyWith(items: ...)` / `copyWithGroupItems(...)`. Drop empty, non-title-matching groups.
- **Honor `minimumCharacters`:** if `_searchQuery.length < search.minimumCharacters`, return the
  list unchanged (no filtering). With the default `1`, an empty query is a passthrough; with `0`,
  even an empty query drives filtering (and matches everything).

```dart
List<FormItemWithValue> _applySearchFilter(List<FormItemWithValue> items, FormSearchConfig? search) {
  if (search == null || _searchQuery.length < search.minimumCharacters) return items;
  return items.where(...).map(...).toList();
}
```

> There is **no "always retain the search item"** branch, because the search field isn't in the
> list.

---

## 5. Loose ends to cover

- The filtered list flows into **both** render paths via the single `Loaded.items` field
  (`_buildItemsList` and `_buildViewOnlyItems`) — apply the filter **once in the VM**
  (`_updateState`), never inline inside `_buildItemsList`, so both paths stay covered automatically.
- Keep `_searchQuery` in the VM (not the service/widget) so controller rebuilds and form refreshes
  preserve the query; use a stable `ValueKey` on the `FormSearchField` so the controller survives
  rebuilds.
- `canSubmit` / required-fields stay computed from the **unfiltered** service form (already the
  case, since those read `getTemporaryForm()`), so hiding items never changes submit eligibility.
- Treat `search == null` as "not supported": render nothing and skip filtering entirely (the
  client mirror of `IsSearchSupported`).
- **Codegen:** remember to run `build_runner` after adding/altering the `@JsonSerializable` DTOs.
- Add unit tests for `_applySearchFilter`:
  - leaf match
  - group title match
  - group child match
  - below-`minimumCharacters` passthrough (default `1` ⇒ empty query passthrough)
  - `minimumCharacters: 0` filters on empty query
  - `search == null` ⇒ list returned unchanged

  Plus a mapper test: `FormSearchOptions.toJson/fromJson` round-trip, non-negative/default handling
  of `minimumCharacters`, and `SimpleFormExtension.toDomain` populating (and preserving `null` for)
  `search`. This is the critical logic worth covering.

---

## Appendix: delta from the item-based approach

| Area | Search as an item (in `items`) | Search as a top-level property |
|---|---|---|
| API enum `FormItemType` | add `search` value (DTO + domain) | **not needed** — no enum change |
| `form_items_extension` mapper | add `search` case | **not needed** |
| `item_with_value.dart` | new `SearchItemWithValue` (inert) | **not needed** |
| `simple_form_extension` builder | add `FormItemType.search` case | **not needed** |
| `form_item_builder.dart` | add `SearchItemWithValue` case | **not needed** |
| DTO/domain model | — | **new** `FormSearchOptions` DTO + `FormSearchConfig` domain + `.g.dart` regen |
| `form_extension.toDomain` | — | **new** `search: search?.toDomain()` |
| `simple_form.dart` (domain) | — | **new** `search` field (props/copy) |
| `Loaded` state + body | pass item through list | **new** `search` field (sibling of `comment`) |
| "Supported?" signal | implicit in item presence | `search != null` (mirrors `IsSearchSupported`) |
| Submit safety | manual exclusion / null id | safe by construction |
| Filter "retain search item" | required | **not needed** |
| View-only card exclusion | required | **not needed** |
| VM filtering (`_applySearchFilter`) | same | same |