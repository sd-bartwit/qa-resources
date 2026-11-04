# Document Parser — Currency Detection Matrix

## Foundation: What the parser naturally returns

The `parsedocument` API response contains **two currency-related fields** in the result:
- `currencyIsoCode` — the detected ISO 4217 currency code (string, e.g. `"USD"`, `"EUR"`, `"GBP"`)
- `unitId` — the resolved unit identifier from the app's `Units` catalog (string, e.g. `"unit-usd"`, `"unit-eur"`)

### Case 1: Currency not recognized
- **Fields returned:** neither `currencyIsoCode` nor `unitId`
- **Semantic meaning:** The parser could not confidently detect a currency from the receipt, or detected one that is not in any known currency system
- **App behaviour:** Amber "unable to detect currency" banner, Total shows 0.00, user must manually select currency from dropdown
- **Test cases:** *Not explicitly tested in this round; covered as edge case in old C7*

### Case 2: Currency recognized but unsupported (NOT in Units catalog)
- **Fields returned:** `currencyIsoCode` present, `unitId` absent
- **Semantic meaning:** The parser correctly identified the currency (e.g. CHF, JPY, or an old/regional code), but this currency is **not registered in the app's `Units` list** for this ExpenseType
- **Conversion decision:** Conversion should **NOT** happen (currency is not in the list of supported units; asking for a rate would be meaningless)
- **Known issue:** This case has a **known bug** — when the returned `currencyIsoCode` is the preferred currency (e.g. EUR), the app incorrectly shows "not supported" error instead of recognizing it as preferred. Ticket: old bug C4, reopened as CC-202 in this round.
- **Test cases:** CC-201 (USD, foreign, unsupported — no unitId), CC-202 (EUR, preferred, unsupported — no unitId, reproduces C4 bug)

### Case 3: Currency recognized and supported (matched to a Unit)
- **Fields returned:** `currencyIsoCode` AND `unitId` present **and matching**
- **Semantic meaning:** The parser identified the currency and the app found a corresponding `Unit` with the same ISO code
- **Invariant:** It is **impossible** for `currencyIsoCode` and `unitId` to refer to different currencies. If both are returned, they describe the same currency.
- **Conversion decision:** 
  - If the matched currency is **preferred** → no conversion needed, amount autofills directly
  - If the matched currency is **foreign** (≠ preferred) → conversion **always runs** (fixed in ticket 1362684)
- **Test cases:** CC-205 (EUR, preferred, both fields), CC-206 (GBP, foreign, both fields), CC-402 (EUR, preferred, both fields with tax breakdown)

---

## Test case audit

### Valid test cases (representing naturally possible parser responses)

| Test ID | Parser response | Case | Currency | Preferred? | Conversion expectation | Status |
|---------|-----------------|------|----------|-----------|----------------------|--------|
| CC-201 | iso-only USD | Case 2 | USD | No | Should run | ✅ Valid & Pass |
| CC-202 | iso-only EUR | Case 2 | EUR | Yes | Should NOT run; **BUG**: shows "not supported" | ✅ Valid, **Bug found** |
| CC-205 | iso + unitId EUR | Case 3 | EUR | Yes | Should NOT run | ✅ Valid & Pass |
| CC-206 | iso + unitId GBP | Case 3 | GBP | No | Should run | ✅ Valid & Pass |
| CC-402 | iso + unitId EUR | Case 3 | EUR | Yes | Should NOT run | ✅ Valid & Pass |

### Invalid test cases (impossible parser responses — REMOVE)

| Test ID | Claimed response | Issue | Why impossible |
|---------|-----------------|-------|-----------------|
| CC-203 | unitId-only GBP | Expects unitId without currencyIsoCode | If a `unitId` is returned, the currency was successfully resolved to a supported Unit. By definition, both fields must be present (they match). A `unitId` cannot exist without its corresponding `currencyIsoCode`. |
| CC-204 | unitId-only EUR | Expects unitId without currencyIsoCode | Same as CC-203. |

**Action:** Remove CC-203 and CC-204 from the active test matrix. The field-combination coverage is complete with:
- CC-201: iso-only, foreign
- CC-202: iso-only, preferred (with known bug)
- CC-205: both fields, preferred
- CC-206: both fields, foreign
- CC-402: both fields, preferred (with tax data)

---

## Workflow test cases (valid, not affected by this matrix)

These test cases exercise user workflows and are independent of the parser's response format:

| Test ID | Workflow | Status |
|---------|----------|--------|
| CC-101 | Manual entry, foreign currency | ✅ Valid |
| CC-102 | Manual currency switch | ✅ Valid |
| CC-301 | OCR autofill, then manual amount/date edits | ✅ Valid |
| CC-302 | OCR autofill, then manual currency switch to another foreign | ✅ Valid |
| CC-303 | OCR autofill, then manual currency switch to preferred | ✅ Valid |
| CC-401 | OCR autofill all three fields (date, amount, currency) | ✅ Valid |
| CC-403 | Manual foreign input, then OCR parser detects preferred | ✅ Valid |

---

## Summary

**Valid OCR autofill scenarios (parser response combinations):**
- iso-only foreign currency (CC-201) ✓
- iso-only preferred currency (CC-202) ✓ [BUG]
- both fields foreign currency (CC-206) ✓
- both fields preferred currency (CC-205, CC-402) ✓

**Invalid scenarios (impossible parser responses):**
- unitId-only foreign (CC-203) ✗ REMOVE
- unitId-only preferred (CC-204) ✗ REMOVE

**Never naturally occurs (edge case, no active test):**
- neither field (Case 1) — covered by old C7, not regressed in this round

