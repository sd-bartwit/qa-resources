# Document Parser — Response Variants (Test Matrix)

Mock variants for `POST .../expenses/parsedocument`, fed through HTTP Toolkit Modify rules.
JSON bodies live in [mocks/](mocks). **Numbering is per-group** (A1, A2… B1, B2…).

**Baseline (happy path):** amount `10.05`, currency `EUR` / `unit-eur`, date `2026-03-28`
(both `expenseDateTimeUtc` + `expenseDateTimeOffset`), VAT `21%`, net `8.31`, tax `1.74`,
`state: "Success"`.

## Expense types & units (from captured `/config`)
| Type id | Name | unitIds | VAT |
|---|---|---|---|
| `type-vat` | **Restaurant with VAT** | `unit-eur` only | ✅ tax rates [0, 0.06, 0.12, 0.21], max 5 lines |
| `type-route` | Business trip with route | `unit-km` | — (out of scope) |
| `type-currency-conversion` | **Hotel booking (foreign currency)** | `unit-eur, unit-usd, unit-gbp, unit-chf` | ❌ preferred `EUR` |

Units: `unit-eur`→EUR €, `unit-usd`→USD $, `unit-gbp`→GBP £, `unit-chf`→CHF.

**App logic under test:**
- **VAT:** run on *Restaurant with VAT*. If detected VAT % is **not** in [0, 6, 12, 21] →
  VAT line not parsed + message. VAT value is **app-calculated** (net × rate), not autofilled.
- **Currency:** run on *Hotel booking*.
  - ✅ `unitId` present → used directly for display (**no conversion**).
  - 🔄 only `currencyIsoCode` → **conversion attempted**; unitId derived via preferred unit / iso.
  - ❌ neither → proceed with amount + date only (🟡 Partial Success / 🔴 Failure banner).

---

## A. Duplicate-property isolation (which property does the app honor?)
| ID | Variant | What it does | Status |
|----|---------|--------------|--------|
| A1 | Amount split | `amount.value` = 10.05 but `customFieldMap[Total]` = 99.99 | ✅ done → uses `amount.value` |
| A2 | Amount split reverse | `amount.value` = 99.99 but `customFieldMap[Total]` = 10.05 | ✅ done → confirms `amount.value` |
| A3 | Date split | `expenseDateTimeUtc` = 2026-03-28 vs `expenseDateTimeOffset` = 2026-01-01 | ✅ done → uses `expenseDateTimeOffset` |
| A4 | Date split reverse | swap the two date values | ✅ done → confirms `expenseDateTimeOffset` |

> _VAT-value split dropped:_ the app computes VAT itself from **net × rate** and ignores the
> API's `totalTax` / `taxDetails[].tax` / `customFieldMap[TotalTax]` fields, so splitting them
> tests nothing. The net×rate recalculation is covered by **G4 (net-tax-mismatch)**.

## B. VAT % vs app config (run on *Restaurant with VAT*; supported rates 0/6/12/21%)
| ID | Variant | What it does |
|----|---------|--------------|
| B1 | VAT % match | clean 21% (supported) → baseline confirm |
| B2 | VAT % unsupported | rate = 0.17 (not in config) → expect "VAT not parsed" message |
| B3 | VAT % zero | rate = 0.0 (**supported** per config) → 0% handling |
| B4 | Multiple VAT lines | two `taxDetails` entries (21% + 9%) → parse both / reject / pick |
| B4b | Multiple VAT lines (both supported) | two `taxDetails` (21% + 6%, both in config) → isolates whether B4's rejection was the unsupported rate or multi-line itself |
| B4c | Multiple VAT lines (same rate) | two `taxDetails` both 21% (net 8.31 + 2.00) → does the app keep two separate lines, merge them, or reject a duplicate rate? |
| B5 | VAT % only | rate present but `netAmount`/`tax` missing |
| B6 | VAT line, no total amount | valid VAT line (21%, net 8.31) but **no `amount`/`customFieldMap[Total]`** → does the VAT item still autofill when the total is missing? (run on *Restaurant with VAT*) |
| B7 | VAT line, no tax value | `taxDetails` has `netAmount` + `rate` but **no `tax`** → does the VAT item still autofill (app computes tax = net × rate) or does the missing `tax` break it? (run on *Restaurant with VAT*) |

## C. Currency parsing & conversion (run on *Hotel booking*; unitIds EUR/USD/GBP/CHF, preferred EUR)
| ID | Variant | unitId | currencyIsoCode | Expected |
|----|---------|--------|-----------------|----------|
| C1 | both-supported-match | `unit-usd` | USD | No conversion; display USD ($) via unitId |
| C2 | both-conflict | `unit-eur` | USD | No conversion; unitId wins → EUR |
| C3 | only-iso-supported | — | USD | Conversion runs; unitId derived → USD |
| C4 | only-iso-preferred | — | EUR | Conversion path with preferred EUR (EUR→EUR edge) |
| C5 | only-iso-unsupported | — | JPY | iso not in unitIds → conversion of unsupported → error/partial |
| C6 | only-unitid | `unit-gbp` | — | Use unitId directly, no conversion → GBP |
| C7 | neither | — | — | Amount + date only, 🟡 Partial / 🔴 Failure banner |

## D. Missing / partial fields
| ID | Variant | What it does |
|----|---------|--------------|
| D1 | No date | both date properties absent |
| D2 | No amount | `amount` and `customFieldMap[Total]` absent |
| D3 | Amount only | currency, date, VAT all missing |
| D4 | Empty result | `result` present but all fields empty / `customFieldMap: []` |

## F. State / error responses
| ID | Variant | What it does |
|----|---------|--------------|
| F1 | Non-Success state | `state` = `"Failed"` with null result |
| F2 | HTTP 4xx | e.g. 400 bad request (set status in Modify rule) |
| F3 | HTTP 5xx | e.g. 500 server error (set status in Modify rule) |
| F4 | Null result | `result: null`, `state: "Success"` |

## G. Data-format edge values
| ID | Variant | What it does |
|----|---------|--------------|
| G1 | Amount precision / formatting | test a range of amount values in turn (all logged under G1): **1234.5** (thousands separator + decimals), **0.00** (zero), **-10.05** (negative). Run on *Restaurant with VAT*. |
| G2 | Non-ISO / lowercase currency | lowercase `usd` in `currencyIsoCode`, **no `unitId`**, no VAT, on *Hotel booking* → does the app normalize the case and convert (like C3 `USD`), or fail to recognize it? |
| G3a | Date format/edge | future date, far-past date, different offset (+12:00) |
| G3b | Impossible date | out-of-range components `2091-13-32` (month 13, day 32) → does the app reject or normalize/roll over? (run on *Hotel booking*) |


---

### Confirmed findings (see [results/results-log.md](results/results-log.md))
- **Total ← `result.amount.value`** (A1+A2). `customFieldMap[Total]` ignored.
- **Date ← `result.expenseDateTimeOffset`** (A3+A4). `expenseDateTimeUtc` ignored.
- **VAT value is app-calculated** (net × rate → 1.75), not API `tax`/`totalTax` (1.74).
