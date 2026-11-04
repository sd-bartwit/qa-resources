# Parse-document Mock Responses

30 mock response bodies for `POST .../expenses/parsedocument`, one per variant in
[../response-variants.md](../response-variants.md). Modeled on the real captured happy-path
structure ([../context.md](../context.md)).

## How to use
1. In HTTP Toolkit, add/edit a **Modify** rule matching `POST` … `/expenses/parsedocument`.
2. Set the response handler to return the chosen file's JSON body (status `200`,
   `content-type: application/json`).
3. Trigger the scan in the app, then say **"capture"** to log the result.

## Naming
`<variantId>_<slug>.json` — matches the results file stem
(`<variantId>_<slug>.response.json` / `.png`) for readable pairing.

## Variants needing more than a body swap
These two are **error-status** cases — set the HTTP status code in the Modify rule, not
just the body:
- `F2_http-4xx.json` → return with status **400**
- `F3_http-5xx.json` → return with status **500**

All other files are `200 OK` JSON bodies.

## Expense-type context (from captured `/config`)
- **VAT** cases (group B) run on **Restaurant with VAT** (`unit-eur` only; supported tax
  rates 0/6/12/21%). `B2_vat-unsupported.json` uses **0.17** (genuinely not in config).
- **Currency** cases (group C) run on **Hotel booking (foreign currency)** (unitIds
  EUR/USD/GBP/CHF; `preferredCurrencyIsoCode: EUR`). `C5_only-iso-unsupported.json` uses
  **JPY** (not in the type's unitIds).
