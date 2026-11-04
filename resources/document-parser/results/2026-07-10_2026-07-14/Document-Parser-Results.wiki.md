# Document Parser — Receipt Scan Autofill Test Results

Test results for the mobile app's **receipt scanning → expense autofill** feature. The app
sends a receipt photo to the parse-document API; on success it autofills the expense form
(date, currency, amount, VAT) from the detected fields. These tests map exactly **which
parser fields drive which form fields**, and how the app behaves for missing/edge/error
responses.

> This page is a self-contained summary. Screenshots and raw JSON captures are kept in the
> QA working folder and are not embedded here; the relevant response fragment is shown inline
> for each test.

## How the tests were run

- **Environment:** ACC (acceptance) — `*.acc.sdworx.com`, Android device intercepted via
  **HTTP Toolkit** (ADB interceptor, proxy on port 8000).
- **Endpoint under test:**
  `POST https://api.acc.sdworx.com/mysdworxappgateway/api/1.0/expenses/parsedocument`
- **Method:** each test uses an HTTP Toolkit **Modify rule** that matches the `parsedocument`
  call and returns a **mocked JSON response** based on the happy-path baseline, varying one or
  more fields per case. No real receipt is needed.
- **Expense types used:**
  - **Restaurant with VAT** (`type-vat`) — `unit-eur` only, supported VAT rates **0 / 6 / 12 / 21 %**, max 5 lines.
  - **Hotel booking (foreign currency)** (`type-currency-conversion`) — units EUR/USD/GBP/CHF, preferred currency **EUR** (converts foreign amounts).

### Baseline (happy-path) response

All tests start from this shape and change only the highlighted field(s):

```json
{
  "result": {
    "amount": { "value": 10.05 },
    "totalTax": { "value": 1.74 },
    "taxDetails": [
      { "netAmount": { "value": 8.31 }, "rate": { "value": 0.21 }, "tax": { "value": 1.74 } }
    ],
    "currencyIsoCode": { "value": "EUR" },
    "unitId": { "value": "unit-eur" },
    "expenseDateTimeUtc":    { "value": "2026-03-28T00:00:00+00:00" },
    "expenseDateTimeOffset": { "value": "2026-03-28T00:00:00+00:00" },
    "customFieldMap": [
      { "knownType": "Total",    "value": "10.05", "isCurrency": true },
      { "knownType": "TotalTax", "value": "1.74",  "isCurrency": true }
    ]
  },
  "state": "Success"
}
```

---

## Which parser field drives which form field

| Form field | Driven by | Ignored |
|---|---|---|
| **Total amount** | `result.amount.value` | `customFieldMap[Total]` |
| **Date** | `result.expenseDateTimeOffset` (literal date part; timezone offset **not** applied) | `expenseDateTimeUtc` |
| **Currency** | `unitId` (used directly, no conversion) | `currencyIsoCode` when a `unitId` is present |
| **VAT value** | **app-computed** `netAmount × rate` | `totalTax`, `taxDetails[].tax`, `customFieldMap[TotalTax]` (values ignored) |

> **VAT value is calculated on the client**, not taken from the API: net × rate =
> `8.31 × 0.21 = 1.7451` → shown **1.75**, while the API returns **1.74**.

---

## A — Duplicate-property isolation

Two parser properties can carry the same UI value; these tests set them to **different**
values to see which one the app honors.

| ID | What is modified | Result |
|----|------------------|--------|
| A1 | `amount.value` = 10.05 **vs** `customFieldMap[Total]` = 99.99 | App shows **10.05** → honors `amount.value` |
| A2 | Reverse: `amount.value` = 99.99 **vs** `customFieldMap[Total]` = 10.05 | App shows **99.99** → confirms `amount.value` drives Total |
| A3 | `expenseDateTimeUtc` = 2026-03-28 **vs** `expenseDateTimeOffset` = 2026-01-01 | App shows **1/1/2026** → uses `expenseDateTimeOffset` |
| A4 | Reverse the two date values | App shows **28/3/2026** → confirms `expenseDateTimeOffset` drives Date |

Example of the A1 modification:

```json
"amount": { "value": 10.05 },
"customFieldMap": [ { "knownType": "Total", "value": "99.99", "isCurrency": true } ]
```

---

## B — VAT gating (Restaurant with VAT)

Supported rates per config: **0, 6, 12, 21 %**. VAT value is always recomputed as net × rate.

| ID | What is modified | Result |
|----|------------------|--------|
| B1 | Baseline supported **21%** | ✅ VAT item autofilled (net 8.31, VAT 1.75), green banner |
| B2 | Unsupported rate **17%** (`rate` = 0.17) | ❌ VAT not autofilled + amber *"unable to detect the VAT… update manually"*; amount & date still fill |
| B3 | Supported **0%** (`rate` = 0.0) | ✅ VAT item autofilled (net = total, VAT 0.00). 0% counts as supported |
| B4 | Two lines **21% + 9%** (9% unsupported) | ❌ **All** VAT rejected (even the valid 21% line) → **all-or-nothing** gating |
| B4b | Two lines **21% + 6%** (both supported) | ✅ Both VAT items autofilled → multiple lines supported; B4 rejection was the 9% |
| B4c | Two lines **21% + 21%** (net 8.31 + 2.00) | Kept as **two separate items** (not merged, not rejected) — see open question |
| B5 | `rate` only, **no** `netAmount`/`tax` | ❌ Not autofilled — `netAmount` is required (VAT = net × rate) |
| B6 | Valid VAT line but **no total `amount`** | ❌ Not autofilled — a missing total **blocks** VAT autofill; Total 0.00 |
| B7 | `netAmount` + `rate` but **no `tax`** | ❌ Not autofilled — `tax` **presence** required (value still ignored) |

Example of the B2 modification (unsupported rate):

```json
"taxDetails": [
  { "netAmount": { "value": 8.31 }, "rate": { "value": 0.17 }, "tax": { "value": 1.41 } }
]
```

**B group conclusion:** a VAT line autofills **only if all** hold — every line's `rate` is in
config `[0, 6, 12, 21]%`, each line has `netAmount` + `rate` + `tax` all **present** (tax value
ignored), **and** the total `amount` is present. Any violation drops **all** VAT lines.

---

## C — Currency & conversion (Hotel booking)

| ID | unitId | currencyIsoCode | Result |
|----|--------|-----------------|--------|
| C1 | `unit-usd` | USD | Total **10.05 $** via `unitId`, **no conversion** |
| C2 | `unit-eur` | USD (conflict) | Total **10.05 €** → **`unitId` wins**, USD ignored |
| C3 | — | USD | **Conversion runs** (USD→EUR at expense-date rate 0.92) → Total **9.25 €** + rate banner |
| C4 | — | EUR (preferred) | ⚠️ **Potential bug** — amber *"currency not supported"*, **Total 0.00**, no convert call (see below) |
| C5 | — | JPY (no rate) | Convert call → `ProviderError`; generic amber *"An error occurred. Please try again."*, Total 0.00 |
| C6 | `unit-gbp` | — | Total **10.05 £** via `unitId`, **no conversion** |
| C7 | — | — | Amber *"unable to detect the currency"*, **Total 0.00**, currency defaults to **€** |

The C3 conversion call the app makes:

```
POST .../functionalities/api/1.0/currencyconversion/{profileId}/convert
{ "amount": 10.05, "currencyIsoCode": "USD",
  "destinationCurrencyIsoCode": "EUR", "conversionDateTimeOffset": "<expense date>" }
```

**C group conclusion:** `unitId` present → used directly, no conversion (and wins over
`currencyIsoCode`). Only `currencyIsoCode` (foreign) → converts to the type's preferred EUR at
a date-specific rate. **The amount only autofills when a currency unit can be resolved** — no
resolvable currency → Total 0.00.

---

## D — Missing / partial fields

| ID | What is modified | Result |
|----|------------------|--------|
| D1 | Both date properties absent | Amber *"Only part of the details were autofilled…"*; amount & currency fill, **Date left empty** |
| D2 | `amount` + `customFieldMap[Total]` absent | Amber partial banner; **Total 0.00**, date & currency fill |
| D3 | Amount only (no currency, date, VAT) | Amber *"unable to detect the currency"*; **Total 0.00** (amount not filled without a currency unit) |
| D4 | `result` present but all fields empty (`state: Success`) | Nothing autofilled + amber *"We could not autofill your details…"* |

> Note the two "empty" representations differ: **missing amount → `0.00`**, **missing date →
> empty placeholder**.

---

## F — State / error responses

All four converge to the **same** graceful handling — nothing autofilled, amber *"We could not
autofill your details, please enter them manually."*, no crash, no error-specific message.

| ID | What is modified | Result |
|----|------------------|--------|
| F1 | `state` non-success, `result: null` | Same as D4 (empty) |
| F2 | **HTTP 400** + error body | Same "could not autofill" banner |
| F3 | **HTTP 500** + error body | Same "could not autofill" banner |
| F4 | **HTTP 200**, `result: null`, `state: "Success"` | Same — trigger is the **null/empty result**, not `state` |

---

## G — Data-format edge values

| ID | What is modified | Result |
|----|------------------|--------|
| G1a | `amount.value` = **1234.5** | Displayed **1,234.50** (thousands sep + 2 decimals); net **1,020.41 EUR**, VAT recalc **214.29** |
| G1b | `amount.value` = **0.00**, net **-10.05** | All autofilled (green), Total **0.00 €**, negative VAT **-2.11**, **no** negative warning |
| G1c | `amount.value` = **-22.00** | Autofilled (green) **plus** amber *"A negative (−) sign was detected…"* — flags negative **total** only |
| G2 | lowercase `usd`, no `unitId` | Conversion succeeds (backend case-insensitive) → **9.25 €**; banner echoes lowercase *"1 usd…"* (cosmetic) |
| G3a | Far-future date **2099-12-31T00:00:00+12:00** | Displayed **31/12/2099** — no future-date validation; **+12:00 offset ignored** (literal date used) |
| G3b | Impossible date **2091-13-32T00:00:00+12:00** (month 13, day 32) | **Normalized, not rejected** → **Fri, 1/2/2092** (month 13 → +1 yr; day 32 → +1 mo, +1 day). Green banner, Total 10.05 € — app overflow-normalizes invalid date parts |
| G4 | net + tax that don't reconcile | Resolved by G1a/B7 — app recomputes VAT from net × rate and **ignores** the API `tax` |

> **No validation at autofill:** zero, negative, and far-future values are accepted as-is; an
> **impossible date** (`2091-13-32`) is **overflow-normalized** (→ Fri, 1/2/2092), not rejected.
> A negative **total** raises a warning; a negative VAT **net** does not.

---

## Suspected defects

### Bug — EUR (preferred currency) with no `unitId` treated as "not supported" (C4)
`currencyIsoCode: "EUR"` with **no `unitId`** on Hotel booking → amber *"This currency is not
supported by your company, please convert amount to EUR."*, **Total 0.00**, no convert call.
EUR **is** the preferred/supported currency, so the amount should fill directly as **10.05 €**
(as C2/C6 do with a `unitId`). The "only iso" path appears to fill the amount only when a
conversion actually runs (foreign → EUR); for EUR→EUR the convert is skipped and the amount is
left empty with a misleading message.

### UX — Misleading "try again" for an unconvertible currency (C5)
`currencyIsoCode: "JPY"` (no provider rate) → convert returns `ProviderError` and the app shows
generic *"An error occurred. Please try again."* A missing exchange rate is **permanent**, not
transient, so "try again" sets wrong expectations.

### Minor — Lowercase currency echoed in banner (G2)
Conversion works with lowercase `usd`, but the exchange-rate banner shows *"1 usd = 0.920000
EUR"* instead of normalizing to uppercase ISO.

---

## Autofill banner states (3)

1. **Green** — all fields detected: *"We've auto-filled your expense details from your attachment."*
2. **Amber (partial)** — some fields: *"Only part of the details were autofilled. Please enter the rest manually."*
3. **Amber (none)** — empty/failed result: *"We could not autofill your details, please enter them manually."*

---

## Open questions for dev / product

| # | Question |
|---|----------|
| Q1 | Are the API VAT-value fields used at all? Value is ignored, but `taxDetails[].tax` **presence** is required — is requiring presence-but-ignoring-value intended? |
| Q2 | Can an expense type define **more than one** preferred currency, and how is the conversion target chosen? |
| Q3 | Should same-rate VAT lines (B4c) be **merged**, or is keeping them separate intended? |
| Q5 | Should VAT autofill require the total `amount` to be present (B6), given the VAT line is self-contained? |
| Q6 | Are zero/negative amounts validated at **submit**, or not at all? Autofill currently accepts them. |

---

## Test method notes

- **Always start each scan from a fresh "Add expense" form.** Re-scanning a populated form
  leaves **stale field values** that mimic app behaviour (caused false readings in the first
  D1 and C7 attempts).
- Tests were mocked entirely via HTTP Toolkit **Modify rules** on the `parsedocument`
  response — no real receipts required.
