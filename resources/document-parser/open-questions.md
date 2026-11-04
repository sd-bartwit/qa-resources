# Document Parser — Open Questions

Questions raised during parse-document testing that need confirmation from the
dev team / product. See [context.md](context.md) and [results/results-log.md](results/results-log.md)
for the supporting evidence.

## Q1 — Are the API's VAT-value fields used at all?
The app calculates the VAT value on the front end from **net × rate** (confirmed: it shows
1.75 from 8.31 × 0.21, not the API's 1.74). Given that, are any of these parser fields
**used by the app in any way**, or are they fully ignored?
- `result.totalTax`
- `result.taxDetails[].tax`
- `result.customFieldMap[TotalTax]`

_Impact:_ if never used, they can be dropped from parser expectations / test assertions.

**Update (B7):** `taxDetails[].tax` **value** is ignored, but its **presence is required** —
removing it (net + rate only) stops the VAT item autofilling (amber "unable to detect VAT").
`totalTax` / `customFieldMap[TotalTax]` were present and did **not** compensate, so they don't
appear to drive VAT-line parsing either. So the refined question: is requiring `tax` to be
*present* (while ignoring its value) intended, or should net + rate suffice?

## Q2 — Can an expense type have more than one preferred currency?
The Hotel booking type's config has a single `customTypes[].preferredCurrencyIsoCode: "EUR"`,
and conversion targets that one currency (`destinationCurrencyIsoCode: EUR`). Is it possible
(now or by design) for a type to define **more than one preferred currency**, and if so how
would the conversion target be chosen?

## Q3 — Are separate same-rate VAT lines intended (no merge)?
When two VAT lines share the same rate (B4c: 21% + 21%), the app keeps them as **two
separate VAT items** rather than merging into one (combined net 10.31 @ 21%). Is keeping
them separate the intended behaviour, or should same-rate lines be merged?

## Q5 — Should VAT autofill require the total amount to be present?
On *Restaurant with VAT* (B6), a **complete, valid VAT line** (net 8.31, 21%, supported rate)
is **not** autofilled when the response has **no total `amount`** — the app shows "unable to
detect the VAT" and leaves an empty Add VAT item. Since the VAT line is self-contained (its
own net/rate/tax), should it autofill independently of the total, or is requiring the total
intended? _Evidence: [results/results-log.md](results/results-log.md) row 19,
[results/B/B6_vat-no-total_p2.png](results/B/B6_vat-no-total_p2.png)._

## Q6 — Are zero / negative amounts validated (and when)?
The `unit-eur` config defines `minimum: 0.01`, but at **autofill time** the app accepts a
**Total of 0.00** and a **negative net (-10.05)** as-is, computing a negative VAT (-2.11), with
the green "auto-filled" banner (G1). Is the `minimum`/non-negative rule enforced only on
**submit** ("Add expense"), or not at all? If autofill can populate invalid values, should it
flag them? _Evidence: [results/results-log.md](results/results-log.md) row 27,
[results/G/G1_amount-precision_p2.png](results/G/G1_amount-precision_p2.png)._

---

## Suspected defects

### D1 — EUR (preferred currency) with no `unitId` is treated as "not supported" (C4)
When the parser returns `currencyIsoCode: "EUR"` and **no `unitId`** on the Hotel booking
type, the app shows the amber banner *"This currency is not supported by your company,
please convert amount to EUR."* and leaves **Total = 0.00** (amount not autofilled). No
`convert` call is made.

- **Expected:** EUR *is* the company's preferred/supported currency, so the amount (10.05)
  should autofill directly as **10.05 €** (no conversion needed).
- **Contrast (C3):** the same shape with `USD` → app converts (USD→EUR) and fills 9.25 €.
- **Likely cause:** the "only `currencyIsoCode`" path only fills the amount when a conversion
  actually runs (foreign → EUR). When the iso already equals EUR, `convert` is skipped, no
  `unitId` is resolved, and the amount is left empty with a misleading "unsupported" message.
- **Evidence:** [results/results-log.md](results/results-log.md) row 13,
  [results/C/C4_only-iso-preferred_p2.png](results/C/C4_only-iso-preferred_p2.png).

### D2 (UX) — Misleading "try again" message for an unconvertible currency (C5)
When the parser returns a currency the conversion provider has no rate for (C5: `JPY`, no
`unitId`), the `convert` call returns `{state:"ProviderError", error:"No rates for JPY->EUR"}`
and the app shows the generic amber banner **"An error occurred. Please try again."** with
**Total 0.00**.

- **Issue:** "Please try again" implies a transient failure, but a missing exchange rate is a
  **permanent** condition — retrying will never succeed. A clearer message (e.g. "This currency
  can't be converted / isn't supported") would set correct expectations.
- **Evidence:** [results/results-log.md](results/results-log.md) row 14,
  [results/C/C5_only-iso-unsupported_p2.png](results/C/C5_only-iso-unsupported_p2.png).

## Q4 — Stale field values between scans (RESOLVED for currency/date defaults)
Early captures showed fields retaining a **previous value** when the parser omitted that field:
the C7 currency selector showed **£ (GBP)** and a D1 attempt showed a stale date — both were
**test artifacts** from re-scanning without clearing the form.

- **Resolved:** a **clean C7 re-verify** (fresh form) showed the currency defaults to **€ (EUR)**
  (the type's preferred), and undetected date shows an **empty** field (clean D1). So the app
  does reset/default correctly on a fresh "Add expense" form.
- **Testing note:** always start each scan from a fresh form; re-scanning a populated form
  leaves stale values that look like app behaviour but aren't.
- _Evidence: [results/results-log.md](results/results-log.md) rows 16 (C7 clean) & 17 (D1 clean)._

