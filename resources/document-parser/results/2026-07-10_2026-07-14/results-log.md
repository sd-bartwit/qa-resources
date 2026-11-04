# Document Parser — Test Results Log

Human-in-the-loop capture log. **Workflow:** you overwrite the `parsedocument` response
in HTTP Toolkit (Modify tab) and trigger the scan; on **"capture"** the assistant reads
the latest `parsedocument` response, matches it to a variant, takes a full-screen `adb`
screenshot, and logs a row below.

- Mock responses: [mocks/](../mocks) · Variant definitions: [response-variants.md](../response-variants.md)
- File naming: `<variantId>_<slug>` — same stem for `.response.json` and `.png`, organized into per-group subfolders (`A/`, `B/`, `C/`, `D/`, …).

**Screenshot capture (binary-safe — do NOT use PowerShell `>` redirection, it corrupts PNGs):**
```powershell
adb shell screencap -p /sdcard/_sc.png
adb pull /sdcard/_sc.png ".\<variantId>_<slug>.png"
adb shell rm /sdcard/_sc.png
```

**Long screens (content below the fold):** capture multiple pages by screenshotting,
scrolling (`adb shell input swipe`), and repeating until a page repeats (bottom reached).
Save as `<variantId>_<slug>_p1.png`, `_p2.png`, … (see B4b).

**⚠️ Start each scan from a fresh "Add expense" form.** Re-scanning on a form that already
has values can leave **stale field values** from the previous parse (e.g. a leftover date or
currency), which is a *test artifact*, not app behaviour. The first D1 capture showed a stale
date (28/3/2026) for this reason; a clean re-scan correctly showed the date **empty**.

## Last processed event
- **Event ID:** 271cbd2c-edc7-4092-8af1-a10bd4c6bb3b
- **Timestamp:** 1784024899336 (2026-07-14 ~12:34)

## Results

| # | Test case | Expected behaviour | Response file | Screenshot | Actual result | Pass/Fail | Captured (UTC) |
|---|-----------|--------------------|---------------|------------|---------------|-----------|----------------|
| 1 | A1 amount-split | learn which amount property the app honors (`amount.value`=10.05 vs `customFieldMap[Total]`=99.99) | [A1_amount-split.response.json](A/A1_amount-split.response.json) | [A1_amount-split.png](A/A1_amount-split.png) | App displayed **Total 10.05** → honors **`result.amount.value`**, ignores `customFieldMap[Total]`. Date 28/3/2026, net 8.31 EUR, VAT 21% = 1.75 (app-calculated). | Captured | 2026-07-10 |
| 2 | A2 amount-split-reverse | confirm reverse (`amount.value`=99.99 vs `customFieldMap[Total]`=10.05) | [A2_amount-split-reverse.response.json](A/A2_amount-split-reverse.response.json) | [A2_amount-split-reverse.png](A/A2_amount-split-reverse.png) | App displayed **Total 99.99** → confirms Total is driven **solely by `result.amount.value`**; `customFieldMap[Total]` ignored. Date 28/3/2026, net 8.31 EUR, VAT 21% = 1.75. | Captured | 2026-07-10 |
| 3 | A3 date-split | learn which date property drives the display (`expenseDateTimeUtc`=2026-03-28 vs `expenseDateTimeOffset`=2026-01-01) | [A3_date-split.response.json](A/A3_date-split.response.json) | [A3_date-split.png](A/A3_date-split.png) | App displayed **Date Thu, 1/1/2026** → uses **`expenseDateTimeOffset`**, not `expenseDateTimeUtc`. Total 10.05, net 8.31 EUR, VAT 21% = 1.75. | Captured | 2026-07-10 |
| 4 | A4 date-split-reverse | confirm reverse (`expenseDateTimeUtc`=2026-01-01 vs `expenseDateTimeOffset`=2026-03-28) | [A4_date-split-reverse.response.json](A/A4_date-split-reverse.response.json) | [A4_date-split-reverse.png](A/A4_date-split-reverse.png) | App displayed **Date Sat, 28/3/2026** → confirms Date is driven **solely by `expenseDateTimeOffset`**; `expenseDateTimeUtc` ignored. Total 10.05, net 8.31 EUR, VAT 21% = 1.75. | Captured | 2026-07-10 |
| 5 | B1 vat-match | baseline: supported rate 21% on *Restaurant with VAT* | [B1_vat-match.response.json](B/B1_vat-match.response.json) | [B1_vat-match.png](B/B1_vat-match.png) | Supported 21% → **VAT item 1 parsed** (Net 8.31 EUR, VAT 21% = 1.75 app-calculated). Green auto-fill banner, Total 10.05 €, Date 28/3/2026. Baseline for B group. | Pass | 2026-07-10 |
| 6 | B2 vat-unsupported | unsupported rate 17% (not in config `[0,6,12,21]`) → expect VAT not parsed + message | [B2_vat-unsupported.response.json](B/B2_vat-unsupported.response.json) | [B2_vat-unsupported.png](B/B2_vat-unsupported.png) | **VAT item NOT autofilled** + amber banner *"We were unable to detect the VAT of the expenses. Please update them manually."* Only empty **Add VAT item** shown. Date 28/3/2026 & Total 10.05 € still autofilled. Matches expected. | Pass | 2026-07-10 |
| 7 | B3 vat-zero | supported rate 0% (in config) → expect VAT item autofilled | [B3_vat-zero.response.json](B/B3_vat-zero.response.json) | [B3_vat-zero.png](B/B3_vat-zero.png) | **VAT item 1 autofilled**: Net 10.05 EUR, VAT **0%** = 0.00 (net = total). Green auto-fill banner, Date 28/3/2026, Total 10.05 €. Confirms 0% is a supported rate. | Pass | 2026-07-10 |
| 8 | B4 vat-multiple | two lines: 21% (supported) + 9% (**not** in config) | [B4_vat-multiple.response.json](B/B4_vat-multiple.response.json) | [B4_vat-multiple.png](B/B4_vat-multiple.png) | **All VAT rejected** — no VAT items autofilled, amber *"unable to detect the VAT… update manually"* banner. Even the valid 21% line dropped. Date & Total still autofilled. **All-or-nothing** when any line is unsupported. ⚠️ Ambiguous: could also mean multi-line VAT unsupported — needs follow-up with two *supported* rates (21%+6%). | Observed | 2026-07-10 |
| 8b | B4b vat-multiple-supported | two lines both supported: 21% + 6% | [B4b_vat-multiple-supported.response.json](B/B4b_vat-multiple-supported.response.json) | _p1..p3 (scrolled)_ | **Both VAT items autofilled**: item 1 Net 8.31 EUR 21% = 1.75; item 2 Net 2.00 EUR 6% = 0.12. → App **does support multiple VAT lines**, so B4's rejection was caused by the unsupported 9% line = **all-or-nothing gating confirmed**. | Pass | 2026-07-10 |
| 8c | B4c vat-multiple-same-rate | two lines both 21% (net 8.31 + 2.00) → merge / separate / reject? | [B4c_vat-multiple-same-rate.response.json](B/B4c_vat-multiple-same-rate.response.json) | _p1..p2 (scrolled)_ | **Two separate VAT items kept**: item 1 Net 8.31 EUR 21% = 1.75; item 2 Net 2.00 EUR 21% = 0.42. Total 12.47 €. App does **not merge** same-rate lines nor reject the duplicate. ❓ **Merging same-rate lines into one (combined net 10.31 @ 21%) was the plausible alternative — the app does NOT do this. Confirm with the team whether keeping separate lines is intended.** | Pass | 2026-07-10 |
| 9 | B5 vat-percent-only | `taxDetails` has `rate` 0.21 only, no `netAmount`/`tax` | [B5_vat-percent-only.response.json](B/B5_vat-percent-only.response.json) | [B5_vat-percent-only_p1.png](B/B5_vat-percent-only_p1.png) | **VAT not autofilled** + amber *"unable to detect the VAT… update manually"* banner; only empty **Add VAT item**. Date 28/3/2026 & Total 10.05 € still autofilled. → App needs **`netAmount`** to autofill VAT (computes net × rate); a rate alone is insufficient. | Pass | 2026-07-10 |
| 10 | C1 both-supported-match | Hotel booking; `unitId`=unit-usd + `currencyIsoCode`=USD | [C1_both-supported-match.response.json](C/C1_both-supported-match.response.json) | _p1..p2 (scrolled)_ | Total shows **10.05 with `$` (USD)** selector → currency from **`unitId`**, **no conversion** (10.05 unchanged, not converted to EUR). Date 28/3/2026. Matches expected. (Pink "converted to EUR" note is the type's static warning text.) | Pass | 2026-07-10 |
| 11 | C2 both-conflict | Hotel booking; `unitId`=unit-eur but `currencyIsoCode`=USD (conflict) | [C2_both-conflict.response.json](C/C2_both-conflict.response.json) | _p1..p2 (scrolled)_ | Total shows **10.05 with `€` (EUR)** → **`unitId` wins** over `currencyIsoCode` (USD ignored); no conversion. Confirms unitId drives currency when both present. Date 28/3/2026. | Pass | 2026-07-10 |
| 12 | C3 only-iso-supported | Hotel booking; `currencyIsoCode`=USD, **no** `unitId` | [C3_only-iso-supported.response.json](C/C3_only-iso-supported.response.json) | _p1..p2 (scrolled)_ | **Conversion triggered.** App called `POST .../currencyconversion/3693839/convert` (req: amount 10.05, USD→EUR, conversionDateTimeOffset = expense date; resp: rate 0.92, amount 9.25). Total shows **9.25 €** + banner *"We've converted the amount… Exchange rate: 1 USD = 0.920000 EUR"*. Confirms: only iso → convert to default (EUR) at date-specific rate. | Pass | 2026-07-10 |
| 13 | C4 only-iso-preferred | Hotel booking; `currencyIsoCode`=EUR (=preferred), **no** `unitId` | [C4_only-iso-preferred.response.json](C/C4_only-iso-preferred.response.json) | _p1..p2 (scrolled)_ | ⚠️ **POTENTIAL BUG.** Amber *"This currency is not supported by your company, please convert amount to EUR."*; **Total 0.00 (amount NOT autofilled)**; **no `convert` call** fired. But EUR *is* the company's preferred/supported currency, so the app should resolve EUR → `unit-eur` and fill 10.05 € (as C2/C6 do with a unitId). Instead it mislabels EUR as unsupported. (Note: a clean C7 with *no* currency also yields Total 0.00 — but C4 is worse because it gives a **wrong "unsupported" message for a supported currency**.) | ⚠️ Potential bug | 2026-07-10 |
| 14 | C5 only-iso-unsupported | Hotel booking; `currencyIsoCode`=JPY (no provider rate), **no** `unitId` | [C5_only-iso-unsupported.response.json](C/C5_only-iso-unsupported.response.json) | _p1..p2 (scrolled)_ | **Conversion attempted → provider error.** `convert` call returned `{state:"ProviderError", error:"No rates for JPY->EUR"}`. UI shows generic amber **"An error occurred. Please try again."** + **Total 0.00**; date still autofills. ⚠️ **UX:** "try again" is misleading — no JPY rate is a permanent condition, not transient. | Pass (UX note) | 2026-07-10 |
| 15 | C6 only-unitid | Hotel booking; `unitId`=unit-gbp, **no** `currencyIsoCode` | [C6_only-unitid.response.json](C/C6_only-unitid.response.json) | _p1..p2 (scrolled)_ | Total shows **10.05 with `£` (GBP)** via **`unitId`**, **no conversion** (amount unchanged, no `convert` call). Date 28/3/2026. Matches expected. Reinforces that a present `unitId` is what makes the amount fill (contrast C4 bug). | Pass | 2026-07-10 |
| 16 | C7 neither | Hotel booking; **no** `unitId`, **no** `currencyIsoCode` | [C7_neither.response.json](C/C7_neither.response.json) | _p1..p2 (scrolled, clean re-verify)_ | **CLEAN RE-VERIFY (corrects the first attempt):** amber **"We were unable to detect the currency. Please update the currency manually"**; **Total 0.00** (amount **NOT** filled), currency selector defaults to **€ (EUR)**; Date 28/3/2026. → Matches D3: amount fills only when a `unitId` resolves. The first C7 capture's "Total 10.05" + "£" were **stale carryover from C6** (form not cleared). Also resolves Q4: the clean default currency is **€ (EUR)**, not a retained £. | Pass (corrected) | 2026-07-13 |
| 17 | D1 no-date | no `expenseDateTimeUtc`/`expenseDateTimeOffset` (amount, currency present) | [D1_no-date.response.json](D/D1_no-date.response.json) | _p1..p2 (scrolled)_ | **Clean re-scan.** New amber **"Only part of the details were autofilled. Please enter the rest manually."** **Total 10.05 €** filled; **Date field EMPTY** (placeholder "Day, dd/mm/yyyy"). Correct: undetected date → field left blank for manual entry. (Earlier attempt showed a stale 28/3/2026 from not clearing the form — a test artifact, not app behaviour.) | Pass | 2026-07-10 |
| 18 | D2 no-amount | no `amount` / `customFieldMap[Total]` (date, currency, VAT present) | [D2_no-amount.response.json](D/D2_no-amount.response.json) | _p1..p2 (scrolled)_ | Amber **"Only part of the details were autofilled. Please enter the rest manually."** **Total 0.00** (amount undetected → shown as 0.00 for manual entry). Date **28/3/2026** and currency **€** filled (both in the mock). Correct. Note: missing amount → `0.00`, whereas missing date (D1) → empty placeholder. ⚠️ Captured on **Hotel booking** type, which has **no VAT support** — so the mock's VAT line was N/A here (not related to the missing amount). **Follow-up:** re-run on *Restaurant with VAT* to test whether a missing total blocks VAT autofill. | Pass | 2026-07-10 |
| 19 | B6 vat-no-total | *Restaurant with VAT*; valid VAT line (21%, net 8.31) but **no `amount`/`Total`** | [B6_vat-no-total.response.json](B/B6_vat-no-total.response.json) | _p1..p2 (scrolled)_ | **VAT item NOT autofilled** + amber *"We were unable to detect the VAT of the expenses. Please update them manually."* Only empty **Add VAT item**; **Total 0.00**; Date 28/3/2026 filled. → **A missing total amount blocks VAT autofill**, even though the VAT line is complete/self-contained. Answers the D2 follow-up. ❓ Possible unwanted coupling (VAT line has its own net/rate) — see open-questions. | Observed | 2026-07-10 |
| 20 | D3 amount-only | Hotel booking; only `amount` (10.05), **no currency, no date, no VAT** | [D3_amount-only.response.json](D/D3_amount-only.response.json) | _p1..p2 (scrolled)_ | **Clean form.** Amber **"We were unable to detect the currency. Please update the currency manually"**; **Total 0.00** — amount **NOT** autofilled despite being present; Date empty; currency selector `€`. → **Amount fills only when a currency unit (`unitId`) can be resolved**; no currency → no amount. ⚠️ This means **C7's earlier "Total 10.05" was stale from C6** (re-verify C7 clean). | Observed | 2026-07-10 |
| 21 | B7 vat-no-tax | *Restaurant with VAT*; `taxDetails` has `netAmount`+`rate` but **no `tax`** | [B7_vat-no-tax.response.json](B/B7_vat-no-tax.response.json) | _p1..p2 (scrolled)_ | **VAT item NOT autofilled** + amber *"unable to detect the VAT… update manually"*. Total 10.05 € & Date filled. → The `tax` field's **presence is required** to parse the VAT line, even though its **value is ignored** (VAT recomputed as net × rate). `totalTax`/`customFieldMap[TotalTax]` (still 1.74) did **not** compensate. So a VAT line needs **net + rate + tax all present**. | Observed | 2026-07-10 |
| 22 | D4 empty-result | `result` present but all fields empty (`taxDetails`/`customFieldMap` = []), `state: Success` | [D4_empty-result.response.json](D/D4_empty-result.response.json) | _p1..p2 (scrolled)_ | **Nothing autofilled** + amber **"We could not autofill your details, please enter them manually."** (a **distinct** message from the partial one). Date empty, Total 0.00, currency `€`. Handled gracefully. → App has **3 banner states**: green (all), amber-partial ("only part…"), amber-none ("could not autofill…"). | Pass | 2026-07-10 |
| 23 | F1 non-success-state | `result: null`, non-success `state` (captured **"Error"**; mock says "Failed") | [F1_non-success-state.response.json](F/F1_non-success-state.response.json) | _p1..p2 (scrolled)_ | **Nothing autofilled** + amber **"We could not autofill your details, please enter them manually."** — **identical to D4** (empty result). App treats null/non-success result the same as empty; no crash. | Pass | 2026-07-13 |
| 24 | F2 http-4xx | **HTTP 400** + error body (`BadRequest`) | [F2_http-4xx.response.json](F/F2_http-4xx.response.json) | _p1..p2 (scrolled)_ | **Nothing autofilled** + amber **"We could not autofill your details, please enter them manually."** — same as F1/D4. App handles a 4xx **gracefully**: no crash, no distinct HTTP-error message; user proceeds manually. | Pass | 2026-07-13 |
| 25 | F3 http-5xx | **HTTP 500** + error body (`InternalServerError`) | [F3_http-5xx.response.json](F/F3_http-5xx.response.json) | _p1..p2 (scrolled)_ | **Nothing autofilled** + amber **"We could not autofill your details, please enter them manually."** — same as F1/F2/D4. A 5xx is handled identically; no crash, no distinct error. | Pass | 2026-07-13 |
| 26 | F4 null-result | **HTTP 200**, `result: null`, `state: "Success"` | [F4_null-result.response.json](F/F4_null-result.response.json) | _p1..p2 (scrolled)_ | **Nothing autofilled** + amber **"We could not autofill your details, please enter them manually."** — same as the rest. Even a **Success** state with a null result triggers "could not autofill": the app keys off the **result being null/empty**, not the `state` value. | Pass | 2026-07-13 |
| 27 | G1 amount-precision | *Restaurant with VAT*; amount value edge cases (all under G1): **1234.5**, **0.00**, negative net **-10.05**, negative total **-22.00** | [G1_amount-precision.response.json](G/G1_amount-precision.response.json) | _p1..p3 (scrolled, shows -22.00 case)_ | **(a) 1234.5** → **1,234.50** (thousands sep + 2 decimals); net **1,020.41 EUR**; VAT recalc **214.29**. **(b) 0.00 total + net -10.05** → all autofilled, green banner, Total **0.00 €**, VAT net **-10.05 EUR**, VAT **-2.11** — **no** negative warning (total not negative). **(c) negative total -22.00** → autofilled (green) **plus a dedicated amber warning: *"A negative (−) sign was detected in the amount. If this is not a refund or credit, please remove the sign before submitting."*** Total shows **-22.00 €**. → The app **detects a negative sign only on the TOTAL** (`amount.value`), not the VAT net; (b) vs (c) proves it. Also reconfirms `amount.value` drives the total (showed -22.00 while `customFieldMap[Total]`=0.00). ⚠️ No hard min/negative *block* at autofill — see Q6. | Observed | 2026-07-13 |
| 28 | G2 currency-non-iso | *Hotel booking*; lowercase `usd` in `currencyIsoCode`, no `unitId`, no VAT | [G2_currency-non-iso.response.json](G/G2_currency-non-iso.response.json) | _p1..p2 (scrolled)_ | **Conversion succeeded** — app forwarded `usd` **as-is** to `convert` (req `currencyIsoCode:"usd"`), backend is **case-insensitive** → rate 0.92, Total **9.25 €** (same as C3's uppercase USD). ⚠️ **Cosmetic nit:** the exchange-rate banner echoes the code lowercase (*"1 usd = 0.920000 EUR"*) instead of normalizing to uppercase ISO ("USD"). | Pass (minor display note) | 2026-07-13 |
| 29 | G3a date-edge | *Restaurant with VAT*; far-future date **2099-12-31** with **+12:00** offset | [G3a_date-edge.response.json](G/G3a_date-edge.response.json) | _p1..p2 (scrolled)_ | **Date accepted & displayed Thu, 31/12/2099** (green banner, Total 10.05 €, VAT 1.75). Two notes: (1) **no future-date validation** at autofill — a year-2099 date is accepted as-is; (2) the **`+12:00` offset is ignored** for the displayed date (a tz conversion would shift to 30/12) → app uses the **literal date part** of `expenseDateTimeOffset`, not a tz-adjusted date. | Pass | 2026-07-13 |
| 29b | G3b impossible-date | *Hotel booking*; **impossible date `2091-13-32`** (month 13, day 32) with +12:00 offset → reject or normalize? | [G3b_impossible-date.response.json](G/G3b_impossible-date.response.json) | _p1..p2 (scrolled)_ | **Impossible date NORMALIZED, not rejected.** `2091-13-32` → displayed **Fri, 1/2/2092**: month **13 → +1 year** (Jan 2092), day **32 → past Jan's 31 → Feb 1**. Green banner (fully autofilled), Total **10.05 €**. → The app (Dart `DateTime`) **overflow-normalizes** out-of-range date components instead of validating/rejecting them; no error shown. Consistent with G3a's "no date validation" — extends it from *far-future* to *out-of-range components*. | Observed | 2026-07-14 |
| 30 | G4 net-tax-mismatch | net + tax deliberately don't reconcile | _n/a (no separate capture)_ | _n/a_ | **Resolved by prior evidence — no capture needed.** The app **recomputes VAT from net × rate and ignores the API `tax`**, so a mismatched `tax` is simply overwritten: **G1a** (net 1020.41 × 0.21 → shown **214.29**, not API's 214.09) and **B7** (tax value ignored; only its presence required). → The app **autofills what it computes; there is no reconciliation/validation** of the API's tax vs net×rate. | Resolved (by G1a/B7) | 2026-07-13 |

### Findings
- **Total field ← `result.amount.value`** (A1+A2 conclusive). `customFieldMap[Total]` is not used for the total.
- **Date field ← `result.expenseDateTimeOffset`** (A3+A4 conclusive). `expenseDateTimeUtc` is not used for the displayed date.
- **VAT value is app-calculated** (net × rate = 8.31 × 0.21 = 1.7451 → shown 1.75), not taken from the API `tax`/`totalTax` (1.74).

---

## Summary

Parse-document autofill was mapped across 30 captures (groups A, B, C, D, F, G; E dropped
because the app ignores `confidence`). Tests ran on two expense types: **Restaurant with VAT**
(VAT lines, EUR only) and **Hotel booking (foreign currency)** (EUR/USD/GBP/CHF, converts).

### Which field drives what
| Form field | Driven by | Ignored |
|---|---|---|
| Total amount | `result.amount.value` | `customFieldMap[Total]` |
| Date | `result.expenseDateTimeOffset` (literal date part; timezone offset not applied) | `expenseDateTimeUtc` |
| Currency | `unitId` (used directly, no conversion) | `currencyIsoCode` when a `unitId` is present |
| VAT value | **app-computed** `netAmount × rate` | `totalTax`, `taxDetails[].tax`, `customFieldMap[TotalTax]` (values) |

### VAT autofill (Restaurant with VAT)
A VAT line autofills **only if all** hold: every line's `rate` ∈ config `taxRates` [0,6,12,21]%,
each line has **`netAmount` + `rate` + `tax` all present** (tax value ignored, presence
required), **and** the total `amount` is present. Otherwise the **entire** VAT parse is dropped
(all-or-nothing) with amber *"unable to detect the VAT… update manually"*. Multiple lines are
supported; same-rate lines are kept **separate** (not merged).

### Currency (Hotel booking)
- `unitId` present → used directly, **no conversion** (C1/C2/C6); `unitId` wins over `currencyIsoCode`.
- Only `currencyIsoCode` (foreign) → **conversion** via `POST …/currencyconversion/{id}/convert`
  to the type's `preferredCurrencyIsoCode` (EUR) at a **date-specific** rate (C3). Backend is
  **case-insensitive** (lowercase `usd` works, G2).
- No resolvable currency → **Total 0.00** + "unable to detect the currency" (default **€**), C7 clean.

### Error / edge handling
- **Any** failure (empty result, null/non-success state, HTTP 4xx, HTTP 5xx) → same graceful
  *"We could not autofill your details…"* — no crash, no failure-specific message (D4, F1–F4).
- **3 autofill banner states:** green (all) / amber-partial ("only part…") / amber-none
  ("could not autofill…").
- **No validation at autofill:** zero, negative, far-future dates are accepted as-is; an
  **impossible date** (`2091-13-32`, G3b) is **overflow-normalized** (→ Fri, 1/2/2092), not
  rejected. A negative **total** raises a dedicated warning (*"A negative (−) sign was
  detected…"*); a negative VAT **net** does not. Amounts format with thousands separators + 2 decimals.

### Suspected defects
- **D1 (bug):** C4 — `currencyIsoCode` = **EUR** with no `unitId` → *"currency not supported…"*
  + Total 0.00, though EUR is the supported/preferred currency (should resolve to `unit-eur`).
- **D2 (UX):** C5 — unconvertible currency (JPY, ProviderError) → generic *"An error occurred.
  Please try again."*, misleading for a permanent no-rate condition.
- **Minor:** G2 — exchange-rate banner echoes the currency code lowercase ("1 usd").

### Open questions (see [../open-questions.md](../open-questions.md))
Q1 are the API VAT-value fields used at all (value ignored, presence required)? · Q2 can a type
have >1 preferred currency? · Q3 should same-rate VAT lines merge? · Q4 **resolved** (clean
default currency €; stale values were test artifacts) · Q5 should VAT autofill require the total
amount? · Q6 are zero/negative amounts validated at **submit**?

### Testing notes
- Always start each scan from a **fresh "Add expense" form** — re-scanning a populated form
  leaves **stale field values** that mimic app behaviour (caused false readings in the first D1
  and C7 attempts).
- Screenshots via `adb pull` (PowerShell `>` corrupts PNGs); long screens captured across
  scrolled pages.
- Results are organized in per-group subfolders `A/ B/ C/ D/ F/ G/`.
