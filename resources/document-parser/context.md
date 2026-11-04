# Document Parser — Test Context

## Feature under test
Mobile app (SD Worx, Flutter/Dart client) **receipt scanning** feature:
1. User uploads/takes a **photo of a receipt**.
2. App sends the image to the **parse-document API**.
3. The API returns detected fields (amount, currency, tax, date/time, merchant, etc.).
4. On the **happy path**, the app **autofills an expense request form** with the detected
   **date, currency, and amount**, ready for the user to submit.

**Testing goal:** verify the app's behaviour for different parser responses — happy path
(all fields detected) and variations/edge cases (missing fields, low confidence, error
states, etc.).

## Environment
- **Environment:** ACC (acceptance) — `*.acc.sdworx.com`
- **Interception:** HTTP Toolkit, Android device via ADB interceptor
- **Proxy:** HTTP Toolkit on port 8000 (see MCP notes below)

## Parse-document endpoint
- **Method / URL:** `POST https://api.acc.sdworx.com/mysdworxappgateway/api/1.0/expenses/parsedocument`
- **Request content-type:** `multipart/form-data` (the receipt image is uploaded; sample body ~42 KB)
- **Client source:** `Dart/3.10 (dart:io)` — the mobile app
- **Key request headers (non-sensitive):**
  - `sdworx-channel: MobileApp`
  - `sdworx-simon-app-os: android`
  - `sdworx-simon-app-version: 5.2.0`
  - `sdworx-simon-api-version: 1`
  - `sdworx-time-zone-info: Europe/Warsaw`, `x-client-utc-offset: +02:00`
  - `accept-language: en`
  - `authorization: Bearer <redacted>` (OIDC token from `auth.acc.sdworx.com/idhub`)

## Happy-path response (real captured sample)
- **Status:** `200 OK`, `content-type: application/json`
- **UI result (confirmed happy path):** date autofilled correctly, total amount `10.05`,
  a VAT item with percentage `21%`, VAT value `1.74`*, and net amount `8.31`.
  \*The app UI showed `1.75`; the API returned `1.74` — see QA observation below.
- **Body (`state: "Success"`):**

```json
{
  "result": {
    "amount": { "value": 10.05, "confidence": 0.988 },
    "totalTax": { "value": 1.74, "confidence": 0.962 },
    "taxDetails": [
      {
        "netAmount": { "value": 8.31, "confidence": 0.963 },
        "rate":      { "value": 0.21, "confidence": 0.966 },
        "tax":       { "value": 1.74, "confidence": 0.962 }
      }
    ],
    "currencyIsoCode": { "value": "EUR", "confidence": 0.988 },
    "unitId": { "value": "unit-eur", "confidence": 0.988 },
    "expenseDateTimeUtc":    { "value": "2026-03-28T00:00:00+00:00", "confidence": 0.995 },
    "expenseDateTimeOffset": { "value": "2026-03-28T00:00:00+00:00", "confidence": 0.995 },
    "customFields": [],
    "customFieldMap": [
      { "knownType": "Total",    "value": "10.05", "confidence": 0.988, "isCurrency": true },
      { "knownType": "TotalTax", "value": "1.74",  "confidence": 0.962, "isCurrency": true }
    ]
  },
  "state": "Success"
}
```

### Exhaustive field mapping (UI value → every parser property that carries it)
Where more than one property points to the same UI value, **all** are listed so we can
manipulate each one individually in future testing to learn which one the app actually
reacts to.

| UI field (expense form) | UI value | Parser property/properties | Property value | Confidence |
|-------------------------|----------|----------------------------|----------------|------------|
| **Date** | `2026-03-28` | `result.expenseDateTimeUtc.value` | `2026-03-28T00:00:00+00:00` | 0.995 |
|          |            | `result.expenseDateTimeOffset.value` | `2026-03-28T00:00:00+00:00` | 0.995 |
| **Total amount** | `10.05` | `result.amount.value` | `10.05` | 0.988 |
|                  |         | `result.customFieldMap[knownType=Total].value` | `"10.05"` | 0.988 |
| **Currency** | `EUR` | `result.currencyIsoCode.value` | `EUR` | 0.988 |
|              |       | `result.unitId.value` | `unit-eur` | 0.988 |
| **VAT percentage** | `21%` | `result.taxDetails[0].rate.value` | `0.21` | 0.966 |
| **VAT value (tax)** | `1.74`* | `result.totalTax.value` | `1.74` | 0.962 |
|                     |         | `result.taxDetails[0].tax.value` | `1.74` | 0.962 |
|                     |         | `result.customFieldMap[knownType=TotalTax].value` | `"1.74"` | 0.962 |
| **Net amount** | `8.31` | `result.taxDetails[0].netAmount.value` | `8.31` | 0.963 |

## Parser response structure — currency field relationship

**Important:** The parser returns **two currency-related fields** in the result:
- `currencyIsoCode` — the detected ISO 4217 currency code (string, e.g. `"USD"`, `"EUR"`)
- `unitId` — the resolved unit identifier from the app's `Units` catalog (string, e.g. `"unit-usd"`, `"unit-eur"`)

**Critical invariant:**
- If **both fields are present**, they **must refer to the same currency**. The `unitId` is derived after `currencyIsoCode` is matched to a supported Unit, so they cannot conflict.
- If **only `currencyIsoCode` is present**, the currency was detected but is not in the supported Units list (unsupported foreign currency or system-wide currency mismatch).
- If **neither field is present**, currency detection failed entirely.

**It is impossible to have:**
- ❌ `unitId` without `currencyIsoCode` (the unitId is only created after iso-code matching)
- ❌ Conflicting `unitId` and `currencyIsoCode` referring to different currencies

See [PARSER_CURRENCY_MATRIX.md](PARSER_CURRENCY_MATRIX.md) for the complete matrix of naturally possible parser responses and their test coverage.

> **QA observations:**
> - **VAT value mismatch:** the app UI displayed `1.75` for the VAT item, but every VAT
>   property in the API response is `1.74` (`totalTax`, `taxDetails[0].tax`, and
>   `customFieldMap[TotalTax]`). Worth confirming whether the app rounds/derives the VAT
>   value independently (e.g. from net × rate = `8.31 × 0.21 = 1.7451`) rather than using
>   the API's `tax` value directly.
> - **Duplicate date fields:** the date is carried by **two** properties
>   (`expenseDateTimeUtc` and `expenseDateTimeOffset`), both identical here. Manipulate
>   each independently to learn which one drives the autofilled date.
> - **Amount appears twice** (`amount.value` and `customFieldMap[Total]`) and **currency
>   twice** (`currencyIsoCode` and `unitId`). Same approach: vary one at a time.
> - Unlike the earlier sample (17.9 / no date), this response includes `netAmount` in
>   `taxDetails` and both date properties, i.e. a fuller happy-path payload.

## Confirmed findings (from capture testing)
- **Total amount ← `result.amount.value` only.** Tests A1 (`amount.value`=10.05 vs
  `customFieldMap[Total]`=99.99 → app showed **10.05**) and A2 (reverse: 99.99 vs 10.05
  → app showed **99.99**) conclusively prove the expense form's Total field is driven
  **solely by `result.amount.value`**. `customFieldMap[Total]` is **ignored** for the total.
  See [results/results-log.md](results/results-log.md).
- **Date ← `result.expenseDateTimeOffset` only.** Tests A3 (`expenseDateTimeUtc`=2026-03-28
  vs `expenseDateTimeOffset`=2026-01-01 → app showed **1/1/2026**) and A4 (reverse:
  2026-01-01 vs 2026-03-28 → app showed **28/3/2026**) conclusively prove the Date field is
  driven **solely by `expenseDateTimeOffset`**. `expenseDateTimeUtc` is **ignored** for the
  displayed date.
- **VAT value is app-calculated**, not taken from the API. The app computes it from
  net × rate (8.31 × 0.21 = 1.7451 → shown **1.75**) rather than using the API `tax` /
  `totalTax` value (1.74).

## App config — supported VAT rates (from `GET .../expenses/{id}/config`)
Each expense type in the `/config` response lists the tax rates the app supports. The
**Restaurant with VAT** type (`type-vat`) has `customTypes[].taxRates = [0, 0.06, 0.12, 0.21]`
(i.e. **0%, 6%, 12%, 21%**, max 5 VAT lines, `unit-eur` only).

- **Expected VAT-parse rule:** if the parser's detected VAT `rate` **is** in that list → the
  VAT item is autofilled; if it is **not** (e.g. **17%**) → the VAT item is **not autofilled**
  and a message should be shown. This is what **B2 (vat-unsupported, 0.17)** tests.

### Confirmed currency behaviour (Hotel booking type)
- **Both `unitId` + `currencyIsoCode` present, supported (C1, unit-usd + USD)** → Total shown
  as **10.05 with `$` (USD)** via the **`unitId`**; **no conversion** (amount unchanged). The
  type's pink "Amount will be converted to EUR" note is static `warningText`, not proof of a
  conversion. Confirms: unitId present → used directly, no conversion.
- **Conflict, both present (C2, unit-eur + USD)** → Total shown as **10.05 with `€` (EUR)** →
  **`unitId` wins** and `currencyIsoCode` is ignored; still no conversion. So when `unitId`
  is present it **solely** drives the displayed currency (C1 + C2).
- **Only `currencyIsoCode` (C3, USD, no unitId)** → **conversion runs**. App calls
  `POST .../functionalities/api/1.0/currencyconversion/{profileId}/convert` with
  `{amount, currencyIsoCode, destinationCurrencyIsoCode: EUR, conversionDateTimeOffset}`
  (the expense date, so a **date-specific** rate). Response `{conversionRate, amount}`. The
  Total is replaced with the **converted EUR amount** (10.05 USD × 0.92 = **9.25 €**) and a
  banner shows the rate. Confirms: no unitId → convert to the type's preferred currency (EUR).
  - **Source of the target currency:** `destinationCurrencyIsoCode` (EUR) is taken from the
    expense type's **config** — `customTypes[].preferredCurrencyIsoCode` on the Hotel booking
    type (`type-currency-conversion`) in the `/config` response. (See open-questions Q2: can a
    type define more than one preferred currency?)
- **Only `currencyIsoCode` = preferred EUR, no unitId (C4)** → ⚠️ **suspected bug.** The app
  shows amber *"This currency is not supported by your company, please convert amount to EUR"*,
  leaves **Total = 0.00** (amount not autofilled), and fires **no** `convert` call. Yet EUR is
  the supported/preferred currency. Appears the "only iso" path only fills the amount when a
  conversion actually runs (foreign → EUR); when the iso already equals EUR, convert is skipped
  and the amount is left empty with a misleading "unsupported" message. Date still autofills.
  **Candidate defect — see open-questions.**
- **Only `currencyIsoCode` = unconvertible foreign (C5, JPY), no unitId** → app **attempts
  conversion** (`convert` call) but the provider returns `{state:"ProviderError", error:"No
  rates for JPY->EUR"}`. UI shows generic amber **"An error occurred. Please try again."** and
  **Total 0.00** (amount not filled); date still autofills. ⚠️ UX: "try again" is misleading —
  a missing rate is permanent, not transient (see open-questions).
- **Only `unitId` (C6, unit-gbp), no currencyIsoCode** → Total shown as **10.05 with `£`
  (GBP)** via the **`unitId`**, **no conversion** (no `convert` call). Confirms a present
  `unitId` alone is sufficient to display the currency and fill the amount — and is the field
  that makes the amount reliably fill (contrast the C4 bug where `unitId` was absent).
- **Neither `unitId` nor `currencyIsoCode` (C7, clean re-verify)** → amber **"We were unable
  to detect the currency. Please update the currency manually"**; **Total 0.00 (amount NOT
  filled)**, currency selector defaults to **€ (EUR)**; date still fills. This matches the D3
  rule (amount fills only when a `unitId` resolves). ⚠️ The **first** C7 capture showed "Total
  10.05" + "£" — those were **stale carryover from C6** (form not cleared), not real behaviour.
  The clean default currency is **€ (EUR)** (resolves open-question Q4).

### Missing / partial fields (D group)
- **No date (D1, clean re-scan)** → new amber banner **"Only part of the details were
  autofilled. Please enter the rest manually."** Amount + currency fill (10.05 €); the **Date
  field is left empty** (placeholder "Day, dd/mm/yyyy") for manual entry. Correct behaviour.
  - *Test-method note:* an earlier D1 attempt showed a stale date (28/3/2026) because the
    form wasn't cleared between scans — a **test artifact**, not app behaviour. Always start
    each capture from a fresh "Add expense" form. (The C7 `£` currency default may similarly
    be stale from C6 — worth re-verifying on a clean form.)
- **No amount (D2)** → same amber partial-autofill banner; **Total shows `0.00`** (undetected
  amount → numeric default for manual entry), while date and currency (present in the response)
  fill normally. Note the two empty representations differ: **missing amount → `0.00`**,
  **missing date → empty placeholder**.
  - ⚠️ *Type caveat:* D2 was captured on the **Hotel booking** type, which has **no VAT**
    support, so the mock's VAT line did not render — this is unrelated to the missing amount.
    Whether a missing total blocks **VAT** autofill is still **open**; re-run D2 on the
    *Restaurant with VAT* type to answer it.
- **Amount only, no currency (D3, clean, Hotel booking)** → amber **"We were unable to detect
  the currency. Please update the currency manually"**; **Total 0.00 — the amount is NOT filled**
  even though it's present (10.05). → **The amount only autofills when a currency unit
  (`unitId`) can be resolved**; with no `currencyIsoCode`/`unitId`, the amount stays 0.00.
  This unifies the currency cases (C1/C2/C6 unitId→fill; C3 iso→convert→fill; C4 EUR-no-unitId
  → 0.00; D3 no-currency → 0.00) and shows **C7's earlier "Total 10.05" was stale from C6** —
  re-verify C7 on a clean form.
- **Empty result (D4, `state: Success`, all fields `[]`)** → **nothing autofilled** + amber
  **"We could not autofill your details, please enter them manually."** Handled gracefully
  (Date empty, Total 0.00, currency `€`).

### Autofill banner states (3)
The banner adapts to how much was autofilled:
1. **Green** (all fields detected): *"We've auto-filled your expense details from your attachment."*
2. **Amber — partial** (some fields): *"Only part of the details were autofilled. Please enter the rest manually."* (D1, D2)
3. **Amber — none** (empty result): *"We could not autofill your details, please enter them manually."* (D4)

### State / error responses (F group)
- **Non-success state, null result (F1, `state: "Error"`, `result: null`)** → **identical to
  D4**: nothing autofilled + amber *"We could not autofill your details, please enter them
  manually."* The app treats a null / non-success result the same as an empty one — no crash,
  no distinct error UI. (Behaviour is the same whether `state` is `Error`, `Failed`, or an
  empty-but-Success result.)
- **HTTP 4xx (F2, status 400 + error body)** → **same** "could not autofill" amber banner;
  nothing filled, no crash, no distinct HTTP-error message. So an HTTP failure is handled
  identically to an empty/failed result — the user just fills the form manually.
- **HTTP 5xx (F3, status 500 + error body)** → **same** "could not autofill" behaviour as F2.
  → **Summary:** every failure mode (empty result, null/non-success state, HTTP 4xx, HTTP 5xx)
  converges to the same graceful "could not autofill" amber banner + manual entry. Robust and
  consistent; no crashes and no failure-specific messaging.
- **Null result with `state: "Success"` (F4, HTTP 200)** → **same** "could not autofill" banner.
  So the trigger is the **result being null/empty**, not the `state` value — a `Success` state
  does not force a green banner over empty data.

### Data-format edges (G group)
- **Amount precision / formatting (G1a, amount 1234.5)** → displayed as **1,234.50** with a
  **thousands separator** and **2 decimals**; net 1020.41 → **1,020.41 EUR**. Proper localized
  currency formatting. VAT recomputed (1020.41 × 0.21 = **214.29**), ignoring the API's 214.09.
- **Zero total + negative net (G1b, amount 0.00, net -10.05)** → **all autofilled with the green
  banner**: Total **0.00 €**; VAT item Net **-10.05 EUR**, VAT 21% = **-2.11** (negative VAT
  computed). ⚠️ The app performs **no min/negative validation at autofill time** — it accepts
  `0.00` and negative values as-is, despite the `unit-eur` config `minimum: 0.01`. Whether the
  **submit** ("Add expense") step rejects them is untested (see open-questions Q6).
- **Negative total (G1c, amount -22.00)** → autofilled (green banner) **plus a dedicated amber
  warning**: *"A negative (−) sign was detected in the amount. If this is not a refund or
  credit, please remove the sign before submitting."* Total shows **-22.00 €**. The negative
  detection keys off the **total (`amount.value`) only** — case G1b (total 0.00, negative *net*)
  showed **no** such warning. So the app flags a negative **total**, not a negative VAT net.
- **Lowercase currency code (G2, `usd`, no unitId, Hotel booking)** → **conversion succeeds**.
  The app forwards the code **as-is** (`convert` request `currencyIsoCode:"usd"`) and the backend
  is **case-insensitive** → rate 0.92, Total **9.25 €** (identical to C3's uppercase `USD`).
  ⚠️ Cosmetic: the exchange-rate banner echoes the lowercase code (*"1 usd = 0.920000 EUR"*)
  rather than normalizing to uppercase ISO for display.
- **Far-future date + offset (G3a, 2099-12-31T00:00:00+12:00)** → accepted and displayed as
  **Thu, 31/12/2099** (green banner). (1) **No future-date validation** at autofill. (2) The
  **`+12:00` offset is ignored** for the date — a timezone conversion would shift to 30/12, but
  the app shows 31/12, so it uses the **literal date part** of `expenseDateTimeOffset` (not a
  tz-adjusted date). Consistent with the date ← `expenseDateTimeOffset` finding.
- **Impossible date (G3b, `2091-13-32T00:00:00+12:00`, Hotel booking)** → **normalized, not
  rejected**. Out-of-range components roll over: month **13 → +1 year** (Jan 2092), day **32 →
  past Jan's 31 → Feb 1**, giving **Fri, 1/2/2092**. Green banner (fully autofilled), Total
  **10.05 €**. So the app (Dart `DateTime`) **overflow-normalizes** invalid date parts rather
  than validating/rejecting them — extends G3a's "no date validation" to out-of-range values.

### Confirmed VAT-gating behaviour (Restaurant with VAT type)
- **Supported rate (B1, 21%)** → VAT item autofilled (Net + app-calculated VAT), green
  auto-fill banner.
- **Unsupported rate (B2, 17%)** → **VAT item NOT autofilled**; amber banner *"We were
  unable to detect the VAT of the expenses. Please update them manually."* is shown, with
  only an empty **Add VAT item** control. **Amount and date still autofill** — only the VAT
  line is dropped. Confirms VAT autofill is gated by the expense type's config `taxRates`.
- **Supported 0% (B3)** → VAT item autofilled (Net = Total, VAT 0.00). 0% counts as supported.
- **Multiple VAT lines are supported** (B4b, 21% + 6% both supported → **two VAT items
  autofilled**: 8.31 EUR @ 21% = 1.75 and 2.00 EUR @ 6% = 0.12).
- **All-or-nothing gating (B4, 21% + 9%)** → when **any** line has an unsupported rate, the
  **entire** VAT parse is rejected (even valid lines) + the amber "unable to detect the VAT"
  banner. So VAT autofill requires **every** detected line's rate to be in the config
  `taxRates`; a single unsupported line drops them all. Amount and date still autofill.
- **Same rate on multiple lines (B4c, 21% + 21%)** → kept as **two separate VAT items**
  (Net 8.31 @ 21% = 1.75 and Net 2.00 @ 21% = 0.42). The app does **not merge** same-rate
  lines and does **not** reject the duplicate rate. ❓ Merging same-rate lines into a single
  item (combined net 10.31 @ 21%) was the plausible alternative behaviour — the app does not
  do it. **Open question for the team:** is keeping separate same-rate lines the intended design?
- **Rate only, no net (B5)** → a `taxDetails` line with just `rate` (no `netAmount`/`tax`) is
  **not autofilled** — same amber "unable to detect the VAT" banner. Because VAT is computed
  as net × rate, **`netAmount` is required**; a rate alone is insufficient. Amount + date
  still autofill.
- **VAT line but no total amount (B6)** → **VAT item NOT autofilled** + the same amber "unable
  to detect the VAT" banner, even though the VAT line is complete and valid (net 8.31, 21%).
  → **VAT autofill also requires the total `amount` to be present.** Date still fills; Total 0.00.
  ❓ Possible unwanted coupling — the VAT line is self-contained (own net/rate/tax), so it could
  arguably autofill without the total. See open-questions Q5.
- **VAT line, no `tax` value (B7)** → `taxDetails` with `netAmount` + `rate` but **no `tax`** →
  **VAT item NOT autofilled** + the same amber banner. So the `tax` field's **presence is
  required** to parse the VAT line, even though its **value is ignored** (VAT is recomputed as
  net × rate). `totalTax` / `customFieldMap[TotalTax]` (present, 1.74) did **not** compensate.
  → **A VAT line needs `netAmount` + `rate` + `tax` all present to autofill.**

## Test ideas — app behaviour by parser response
- **Happy path:** amount + currency + date all present → form autofills correctly.
- **Partial data:** one of amount / currency / date missing → what does the app do?
- **Low confidence:** low `confidence` values → does the app flag/skip the field?
- **Different currency:** non-EUR `currencyIsoCode` → correct currency + unit handling.
- **Amount formatting:** decimals, thousands separators, zero, negative.
- **Non-success state:** `state != "Success"` → error/empty handling.
- **Error statuses:** 4xx/5xx from the API → user messaging, retry behaviour.
- **Empty result:** `result` with empty/`customFieldMap: []` → graceful fallback.

## HTTP Toolkit MCP — capabilities & limits (for this workflow)
The HTTP Toolkit MCP server connected to VS Code is **read-only for traffic**:
- Can: list/filter captured exchanges, read request & response headers and bodies,
  list/activate simple interceptors, read proxy config.
- **Cannot:** create/modify **Modify (mock/rewrite) rules** programmatically — those must
  be built in the HTTP Toolkit UI's Modify tab (or exported/imported as a rules file to
  reuse without rebuilding each time).

To test different parser responses without a real receipt, set up a **Modify rule** in
HTTP Toolkit that matches `POST .../expenses/parsedocument` and returns a mocked JSON
body (based on the happy-path sample above), then vary it per test case.
