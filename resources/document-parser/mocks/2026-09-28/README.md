# Mock responses — 2026-09-28 (Currency Conversion test permutations)

Mock bodies for the CC-IDs in
[../../CurrencyConversion_TestPermutations.md](../../CurrencyConversion_TestPermutations.md).
Run on **Hotel booking (foreign currency)** (unitIds EUR/USD/GBP/CHF, `preferredCurrencyIsoCode: EUR`).

**Parser response validation:** Only **naturally possible** parser responses are tested. See [../PARSER_CURRENCY_MATRIX.md](../PARSER_CURRENCY_MATRIX.md) for the complete field-relationship rules. Impossible cases (e.g. unitId-only, mismatched fields) have been removed.

Only the genuinely new OCR variants got a file here — everything else reuses an existing
mock (either from this folder or the legacy top-level [../](../) set) to avoid duplicates.

| CC-ID | Mock to use | Parser response | Notes |
|--|--|--|--|
| CC-101, CC-102 | _none — manual entry only_ | N/A | No receipt scan involved |
| CC-201 | [CC-201_foreign-currency-autofill.json](CC-201_foreign-currency-autofill.json) | iso-only USD | Foreign (non-preferred) → conversion runs |
| CC-202 | [CC-202_preferred-currency-autofill.json](CC-202_preferred-currency-autofill.json) | iso-only EUR | Preferred → no conversion, bug-fix check (**bug reproduced**) |
| CC-205 | [CC-205_unitid-and-iso-preferred.json](CC-205_unitid-and-iso-preferred.json) | both fields EUR | Both fields, preferred → no conversion |
| CC-206 | [CC-206_unitid-and-iso-foreign.json](CC-206_unitid-and-iso-foreign.json) | both fields GBP | Both fields, foreign → conversion runs |
| CC-301 | CC-201 | iso-only USD | Autofill first, then edit the amount in-app |
| CC-302 | CC-201 | iso-only USD | Autofill first, then edit the currency dropdown to another foreign currency |
| CC-303 | CC-201 | iso-only USD | Autofill first, then edit the currency dropdown to the preferred currency |
| CC-401 | CC-201 | iso-only USD | Type a preferred-currency amount manually first, **then** scan/apply this mock |
| CC-402 | CC-202 | iso-only EUR | Enter a foreign currency manually first, **then** scan/apply this mock |
| CC-403 | [CC-403_manual-gbp-then-parse-eur.json](CC-403_manual-gbp-then-parse-eur.json) | iso-only EUR | Manual GBP input, then parser detects EUR (preferred) |
| CC-503 | [../C7_neither.json](../C7_neither.json) | neither field | No currency info at all — unchanged behaviour |

### Removed test cases (impossible parser responses)

| CC-ID | Reason | Notes |
|--|--|--|
| CC-203 | **Impossible** — unitId cannot exist without currencyIsoCode | Regression check for old C6 is replaced by CC-205/CC-206 (both fields, for foreign/preferred) |
| CC-204 | **Impossible** — unitId cannot exist without currencyIsoCode | N/A |
| CC-501 | **N/A** — maps to old C4 regression, covered by CC-202 instead | Use CC-202 for the same C4 bug-fix check (iso-only EUR) |
| CC-502 | **Impossible** — was regression check for impossible C6 case | Replaced by CC-205/CC-206 (valid unitId+iso combinations) |
