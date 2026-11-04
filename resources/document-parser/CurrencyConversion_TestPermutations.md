# Currency Conversion — Always-Trigger Regression Test Permutations

**Source ticket:** [User Story 1362684 — APP | Currency | Always trigger currency conversion
when detected currency is different than home currency of the
user](https://sdworx.visualstudio.com/Digital%20Channels/_workitems/edit/1362684)
(Parent: #1311249, related: #1342965, child: #1379941). State: Resolved / In Validation, tag `5.4.0`.

## Feature under test (per ticket)
Applies to any **ExpenseType** whose `CustomTypes` includes a `CurrencyConversionTypeDefinition`
(carries `PreferredCurrencyIsoCode`). Core rule:

> Whenever the **receipt/selected currency differs** from `PreferredCurrencyIsoCode`, conversion
> is **not optional** and **always runs** — regardless of whether the amount/currency/date came
> from **AI/OCR receipt parsing** or **manual user entry/edit**.

Key invariants to verify:
- The ExpenseType's `Units` list must contain **every** pickable receipt currency, **including**
  `PreferredCurrencyIsoCode` itself. The dropdown is built from this list.
- The **selected** currency is just the receipt's printed currency — **not necessarily** the
  booking currency.
- The **saved** `UnitId` always resolves to the Unit where `AmountISOCode == PreferredCurrencyIsoCode`
  — the expense is **always booked in the preferred currency**.
- `CreateExpense.Amount` / `UnitId` always come from the **conversion result**, never directly
  from a user-entered foreign amount.
- AI-prefilled date/amount/currency must remain **user-editable**, and **any correction
  re-triggers conversion**.
- The conversion API must be called whenever **date, amount, or receipt currency** changes on
  the form (any of the three, not just currency).
- `CurrencyConversionTypeInstance` (persisted in `CreateExpense.CustomTypes`) stores:
  `OriginAmount`, `OriginCurrencyIsoCode`, `ConversionDateTimeOffset`, `ConversionRate`,
  `DestinationAmount`, `DestinationCurrencyIsoCode`.

## ⚠️ Behaviour change vs. previously confirmed app behaviour
This ticket **changes** currency handling documented in [context.md](context.md) from earlier
parse-document exploration (Hotel booking type, `PreferredCurrencyIsoCode = EUR`).

⚠️ **Clarification on parser response structure:** The parser returns **two currency fields** (`currencyIsoCode` and `unitId`). These fields have a strict relationship (see [PARSER_CURRENCY_MATRIX.md](PARSER_CURRENCY_MATRIX.md)):
- If `unitId` is present, `currencyIsoCode` **must also be present** (both refer to the same matched currency).
- Cases claiming "unitId-only" or "currencyIsoCode + mismatched unitId" are **impossible** and have been removed from the test matrix.

| Old confirmed case | Old behaviour | Expected **new** behaviour under this ticket | Status |
|--|--|--|--|
| C1 — `unitId` + `currencyIsoCode`, both supported, same currency (USD) | `unitId` wins, **no conversion** | Still no conversion (receipt currency = booking currency here — re-verify which field the app now treats as "receipt currency" for a non-preferred `unitId`) | Covered by CC-206 (both fields, foreign) |
| C2 — `unitId` (EUR) + `currencyIsoCode` (USD) conflict | `unitId` wins (EUR shown), **no conversion**, `currencyIsoCode` ignored | If receipt currency is resolved as USD (≠ preferred EUR) → conversion **must now run**; `unitId` should no longer silently bypass it | Not tested (impossible: if both fields present, they match) |
| C4 — only `currencyIsoCode = EUR` (= preferred), no `unitId` | **Bug:** amber "not supported", Total 0.00, no `convert` call | **Fixed:** EUR = preferred → **no conversion needed**, amount autofills directly (10.05 €), no error banner | Covered by CC-202 (iso-only EUR, **bug reproduced**) |
| C6 — only `unitId` (GBP), no `currencyIsoCode` | `unitId` alone fills amount, **no conversion** | ~~GBP ≠ preferred EUR → conversion must now run~~ | **Impossible** — unitId cannot exist without matching currencyIsoCode (removed from test matrix) |
| C7 — neither field | Amber "unable to detect currency", Total 0.00, defaults to €/EUR selector | Unaffected by this ticket (still nothing to convert) | Not actively tested (edge case, old C7) |

Re-running these cases is required to catch any silent "no conversion because `unitId` was
present" regressions — see §5 below.

---

## 1. Manual input + currency conversion

User types/selects values directly on the form — no receipt scan involved.

| ID | Scenario | Setup | Expected |
|--|--|--|--|
| CC-101 | Foreign currency, manual entry | User selects a non-preferred currency (e.g. USD) and types an amount | Conversion API called; Total shown **converted** to the preferred currency; saved `UnitId` resolves to the preferred-currency unit |
| CC-102 | Preferred currency, manual entry | User selects the preferred currency (e.g. EUR) and types an amount | No conversion call; amount saved as typed |

## 2. Document parser (OCR) autofill + currency conversion

Receipt is scanned; no manual entry involved. **Valid parser responses only** (see [PARSER_CURRENCY_MATRIX.md](PARSER_CURRENCY_MATRIX.md) for field relationships).

| ID | Scenario | Parser response | Expected |
|--|--|--|--|
| CC-201 | Foreign currency, OCR-detected | `currencyIsoCode`-only USD | Conversion API called **automatically** (no user action); Total shown converted; saved `UnitId` = preferred-currency unit |
| CC-202 | Preferred currency, OCR-detected | `currencyIsoCode`-only EUR | No conversion call; amount autofills directly — **fix for old bug C4** (see §5). **Status: Bug reproduced** |
| CC-205 | Foreign currency with unitId | `currencyIsoCode` + `unitId` both GBP | Conversion **must run** (confirms unitId presence does NOT bypass conversion when ≠ preferred, fixes old C6 intent) |
| CC-206 | Preferred currency with unitId | `currencyIsoCode` + `unitId` both EUR | No conversion call; confirms both fields together avoid the CC-202 bug |

## 3. OCR autofill, then manual correction

User edits a field the parser already filled in.

| ID | Scenario | Setup | Expected |
|--|--|--|--|
| CC-301 | Edit OCR-prefilled amount | Foreign-currency amount autofilled and converted; user changes the amount | Conversion **re-runs** with the new amount; Total/`DestinationAmount` updates accordingly |
| CC-302 | Edit OCR-prefilled currency to another foreign currency | OCR detected USD (converted); user changes the currency dropdown to GBP | Conversion **re-runs** for GBP→preferred, replacing the previous result |
| CC-303 | Edit OCR-prefilled currency to the preferred currency | OCR detected a foreign currency (converted); user changes dropdown to the preferred currency | Conversion is **cancelled**; amount reverts to a direct (non-converted) value |

## 4. Manual input, then OCR autofill overwrites it

User has already typed something, then scans/re-scans a receipt that overwrites the form.

| ID | Scenario | Setup | Expected |
|--|--|--|--|
| CC-401 | Manual preferred-currency entry, then OCR detects a foreign currency | User types an amount in the preferred currency; a receipt scan afterwards autofills a non-preferred currency | Autofilled (foreign) values win; conversion **runs** based on the new OCR data, not the earlier manual entry |
| CC-402 | Manual foreign-currency entry (converted), then OCR detects the preferred currency | User enters a foreign currency manually (conversion already ran); a receipt scan afterwards autofills the preferred currency | Autofilled (preferred) values win; conversion is **cancelled**, Total reflects the new direct amount, not the stale converted one |

## 5. Regression — prior confirmed currency cases

Quick re-checks against previously confirmed behaviour in [context.md](context.md) that this ticket changes.

**Note:** Old cases C2 and C6 claimed impossible parser responses (mismatched fields / unitId-only) and are **not regressed** in this round. See [PARSER_CURRENCY_MATRIX.md](PARSER_CURRENCY_MATRIX.md) for the corrected field relationship rules.

| ID | Maps to old case | Setup | Expected under new rule | Status |
|--|--|--|--|--|
| CC-202 | C4 (`currencyIsoCode` = EUR/preferred, no `unitId`) — bug case | Only `currencyIsoCode` = preferred, no `unitId` | **Bug fixed:** amount autofills directly, no "not supported" banner | **Bug reproduced** — still shows "not supported" error, not fixed yet |
| CC-503 | C7 (neither field detected) | No currency info at all | **Unchanged:** amber "unable to detect currency", manual entry required, selector defaults to preferred currency | Not actively tested (old edge case) |

---

## Deferred (ticket open items, not covered in this pass)
Rounding/precision of `DestinationAmount`, which date prices the conversion (receipt vs.
submission date), UX when the conversion API is unavailable, and whether a manual override of
the calculated rate/amount is ever allowed — all flagged as **open** in the ticket itself and
left for a follow-up pass once product/dev align on the expected behaviour.

## Notes for execution
- Reuse the HTTP Toolkit Modify-rule mocking approach from [context.md](context.md) to simulate
  parser (`parsedocument`) and `convert` API responses without needing real receipts for every
  currency combination.
- Always start each capture from a **fresh** "Add expense" form (per the stale-field lesson in
  [open-questions.md](open-questions.md) Q4) to avoid false positives from carried-over field values.
- Where expected behaviour **contradicts** a previously confirmed finding in context.md, flag
  any mismatch as a **regression**, not a new defect, and cross-reference the original case ID.
