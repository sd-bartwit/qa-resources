# Employee Benefit Card — API contracts & endpoints (US 1381780)

Source: Azure DevOps work item [1381780](https://sdworx.visualstudio.com/Digital%20Channels/_workitems/edit/1381780) — *API | Employee Benefit Card | Create contracts & endpoints*.
Analysed from the work item and the final code on the linked PR branches (code may have changed after these PRs).

## 1. Summary

- **State:** Resolved. Assigned to Lukasz Tomczok, API Development, Sprint 23 (2026 Q4). Tags: `DEV; HR Pay`.
- **Acceptance criteria:** "add new contracts & endpoint to support employee benefit card".
- **Testing instructions in the story:** "in swagger & nuget packages" (API/contract testing, no UI).
- **Out of scope:** Paymentology SDK and in-app payments.
- **Related items:**
  - 1348742 — closed investigation (provider API contract proposal attached).
  - 1402177 — active story "MOCK | Employee Benefit Card | Support new endpoints and contracts" (card provider / mock).
  - 1376843 — parent Feature "Vouchers | Employee Benefit Card | Technical exploration".
- **Design:** [Hr Pay – Figma](https://www.figma.com/design/9jdMxQ7hCRJN9iG2DfI6Lx/Hr-Pay?node-id=520-2845).

### Delivered PRs (branch `improvements/1381780-Employee-Benefit-Card`)

| Repo | PRs | Content |
|---|---|---|
| `SDWA.Providers.Contracts` | 210480, 210903, 211279 | Provider-side Pay contracts, functionality URIs, error codes |
| `SDWA.AssistantApi.Contracts` | 210514, 210909, 211281 | App-facing Pay contracts (NuGet) |
| `Functionalities` (project SPARC Internal) | 211378 | `PayController`, `PayProvider`, mappings, mock/documentation controller, integration tests |

The 2nd and 3rd PR in each contracts repo add the digital card request and an enums cleanup.

## 2. Endpoints introduced

All routes: `api/1.0/pay/{accessRightId}/…`, `[Authorize]`, `accessRightId` is a long. FAPI forwards to provider paths under `pay/…` (e.g. `pay/balances`). Swagger group: `sdfunctionalities`.

| # | Method and path | Functionality gate | Notes |
|---|---|---|---|
| 1 | `GET balances` | `pay/overview 1.0` | Returns `Balances` |
| 2 | `GET transactions?accountCategories=…&page=0&count=10` | `pay/overview` | `accountCategories` repeatable; `page` zero-based. Returns `PagedResponse<Transaction>` |
| 3 | `GET transactions/{transactionId}` | `pay/overview` | Returns `TransactionDetail` |
| 4 | `GET cards` | `pay/cards` | Physical cards only |
| 5 | `GET cards/{cardToken}/credentials` | `pay/cards` | Short-lived secret; must not be stored, logged or reused |
| 6 | `POST cards/{cardToken}/activate` | `pay/cards` | No request body |
| 7 | `POST cards/digital` | `pay/digitalcards` | Body `{ "category": "MealVouchers" }`. Each call creates a new card; do not auto-retry after a timeout |

Gates `Overview`, `Cards` and `DigitalCards` are separate provider functionalities, each can be on/off independently.

## 3. Response schema

**Serialization:** camelCase property names, enums as strings, null values omitted.

**Envelope**
```json
{
  "state": "Success | ProviderWarning | ProviderError | ProviderCritical | ProviderForbidden | Error",
  "error": { "message": "...", "optionalDetails": [ { "id": "...", "message": "..." } ] },
  "result": { }
}
```
- Provider business error → HTTP 200, `state: ProviderError`.
- Provider forbidden → HTTP 200, `state: ProviderForbidden`.
- Error `message` and `optionalDetails[].id`/`message` are passed through unchanged (asserted by tests).

### Types

| Type | Fields |
|---|---|
| `Amount` | `value` (decimal; signed: loads positive, spends/expiries negative), `symbol` (string) |
| `Balances` | `accounts[]` of `AccountBalance` |
| `AccountBalance` | `category`, `amount`, `expiries[]?` — `expiries` present for Meal/Eco, omitted for Mobility; ordered ascending by expiry; accounts returned only for categories in use |
| `Expiry` | `amount`, `expiresAtDateTimeOffset` |
| `Cards` | `physicalCards[]` of `Card` (digital cards are never listed) |
| `Card` | `token`, `status`, `expirationMonth` (1–12), `expirationYear` (4 digits), `issuedAtDateTimeOffset`, `accountCategories[]` (digital: exactly one; physical: possibly several) |
| `CardCredentials` | `cardToken`, `secret` |
| `CardActivationResult` | `cardStatus` (`Active` on success) |
| `CreateDigitalCardRequest` | `category` |
| `CreateDigitalCardResult` | `card` (created, active, one category) |
| `Transaction` | `id`, `accountCategory`, `kind`, `category?`, `amount`, `dateTimeOffset`, `title` (required, non-empty), `description?` |
| `TransactionDetail` | all `Transaction` fields + `voucherLoad?`, `cardPayment?` (omitted when not applicable) |
| `VoucherLoadDetails` | `count`, `amount` (per voucher), `expiresAtDateTimeOffset` — Meal/Eco Load only |
| `CardPaymentDetails` | `status` — card Spend only |
| `PagedResponse<T>` | `hasMore`, `items[]` |

### Enums

| Enum | Values |
|---|---|
| `AccountCategory` | `MealVouchers`, `EcoVouchers`, `Mobility` |
| `CardStatus` | `NotActivated`, `Active`, `Blocked`, `Lost`, `Stolen`, `Fraud` |
| `TransactionKind` | `Load`, `Spend`, `Expiry` |
| `TransactionCategory` | `EmployerFunding`, `Grocery`, `Fuel`, `Restaurant`, `Parking`, `PublicTransport`, `BikeRental`, `BikeLease`, `Shopping`, `Entertainment`, `Expiry`, `Other` |
| `CardPaymentStatus` | `Pending`, `Settled`, `Voided` |

### Known business error codes (`optionalDetails[].id`)

| Code | Seen on |
|---|---|
| `processorUnavailable` | credentials, activate, digital |
| `cardNotEligible` | activate |
| `noAccountForCategory` | digital |
| `digitalCardIssuingDisabled` | digital |
| `unknownCategory` | digital |

### Example (mock provider data)

`GET balances`
```json
{
  "state": "Success",
  "result": {
    "accounts": [
      {
        "category": "MealVouchers",
        "amount": { "value": 100, "symbol": "EUR" },
        "expiries": [
          { "amount": { "value": 100, "symbol": "EUR" }, "expiresAtDateTimeOffset": "2026-12-17T00:00:00+00:00" }
        ]
      }
    ]
  }
}
```

`POST cards/digital` → `{ "state": "Success", "result": { "card": { "token": "example-sdk-token", "status": "Active", "expirationMonth": 12, "expirationYear": 2030, "issuedAtDateTimeOffset": "...", "accountCategories": ["MealVouchers"] } } }`

## 4. Observations and risks

- **Unknown enum values:** the provider→contract mapping throws `InvalidEnumArgumentException` on an unrecognised value; a new provider value could cause a 500 instead of a graceful response.
- **Category filter:** `PayProvider` sends `accountCategories` as enum names; verify an empty filter sends no parameter and repeated parameters are handled.
- **Paging inconsistency:** the mock controller returns `IPagedResponse` via `Result.Page(...)`, the real controller `PagedResponse<Transaction>`; verify `hasMore` on both.
- **Story feedback not clearly addressed in code:** config endpoint with ETag/version, date-range filtering, and the open security review of the card secret (pending with Teal Partners architects).
- **`POST cards/digital` is not idempotent:** a timeout may still have created the card; check how the app behaves.
- **Thin automated coverage:** integration tests cover happy paths plus error/forbidden pass-through for credentials, activate and digital only.

## 5. Proposed test tasks

**A. Contract and Swagger**
1. Swagger (`sdfunctionalities`) lists all 7 routes with correct verbs and parameter defaults (`page=0`, `count=10`).
2. NuGet `SDWA.AssistantApi.Contracts` exposes the Pay types; enum names and fields match section 3.
3. JSON is camelCase, enums are strings, nulls omitted, dates carry an offset.

**B. `GET balances`**
4. Meal, Eco and Mobility accounts: `expiries` present for Meal/Eco, omitted for Mobility.
5. Expiries sorted ascending.
6. A category not in use is not returned.
7. `amount.value` is decimal and `symbol` is correct.

**C. `GET transactions`**
8. No filter, one category, multiple categories (`accountCategories=A&accountCategories=B`).
9. Paging: default `page=0`, `count=10`; `hasMore` true before the last page, false on the last.
10. Boundaries: `count=0`, negative `page`, very large `count`, page past the end.
11. Invalid category value: record the actual response (400 vs provider error).
12. Sign convention: Load positive, Spend and Expiry negative.
13. `category` null (omitted) and each category value.
14. `title` always non-empty; `description` may be absent.

**D. `GET transactions/{id}`**
15. Meal/Eco Load: `voucherLoad` populated; other kinds: omitted.
16. Card Spend: `cardPayment.status` is Pending/Settled/Voided; non-card spend: omitted.
17. Non-existent or other user's transaction ID: not found/forbidden, no data leak.

**E. Cards**
18. `GET cards` returns physical cards only; a previously created digital card is not listed.
19. All 6 card statuses; `expirationMonth`/`expirationYear` in range.
20. Card with multiple categories.
21. `GET credentials`: `cardToken` echoes the input; a new secret on each call.
22. `POST activate` on `NotActivated` returns `Active`; on active/blocked returns `cardNotEligible`.
23. Another user's card token: error/forbidden, no data leak.

**F. `POST cards/digital`**
24. Create for each of the 3 categories: card Active, one category matching the request.
25. No account for category: `noAccountForCategory`.
26. Issuing disabled for the organisation: `digitalCardIssuingDisabled`.
27. Missing body, null category, unknown category string (e.g. `"Foo"`).
28. Two identical calls create two different cards; the new card is not in `GET cards`.

**G. Errors and security**
29. Provider error passed through for credentials/activate/digital: HTTP 200, `state: ProviderError`, message and detail `id` unchanged.
30. Provider forbidden gives `ProviderForbidden`.
31. Provider unavailable/timeout gives `processorUnavailable` or `ProviderCritical`.
32. No/expired token gives 401.
33. Functionality gating: with `Cards`, `DigitalCards` or `Overview` disabled, matching endpoints are refused.
34. The credentials secret never appears in logs or gateway traffic logs.
35. Wrong or other-user `accessRightId` is refused.
36. Provider response with an unknown enum value: no 500 (see risks).

**H. Mock provider**
37. `api/pay/...` documentation endpoints return the sample data (related to story 1402177).
