# Simple Expressions – Regression Test Permutations

Feature: Interfield dependencies in Forms. The properties **`required`**, **`readOnly`** and
**`visible`** of each field accept either a **boolean constant** or a **simple expression**.
Expressions make a field's state dynamic based on the values of other fields (referenced with `#fieldId`).

Engine reference: `simple-expressions` (StevenThuriot / LieselThuriot).

> This document is aligned to **Form_Wizard_SimpleExpression_Advanced.json**, which is the source of truth.
> Each SE-id below maps to a field in that form.

## Engine cheat-sheet (operators used in the form)

| Category | Tokens | Notes |
|--|--|--|
| Function operators | `not`, `eq`, `and`, `or`, `contains`, `gt`, `lt`, `empty` | function form only |
| Constants | `true`, `false`, numbers, quoted strings | case-insensitive (`TRUE` = `true`) |
| Field reference | `#fieldId` | driver must be in the **same step** as the target |
| Missing field | treated as **empty** | `empty( #doesNotExist )` = `true` |

## Known engine limitations (confirmed during testing)

- **Symbol operators not supported** (`!`, `&`, `|`, `>`, `>=`, `<`, `<=`) — use the function forms.
- **No truthiness coercion** — a bare `0` / `"string"` inside `and`/`or` throws (`Invalid Expression`); only booleans / field refs / operator calls are valid operands.
- **No circular-reference guard** — two fields referencing each other's state cause an infinite load.
- **Global id uniqueness** — field ids, group names, and dropdown option ids must all be unique across the whole form.
- **Cross-step references break** — a driver referenced by a target must live in the **same step**.
- One invalid expression fails the **entire** form load (no per-field fallback).

---

## 1. Constants (non-expression values)

| ID | Field | Property | Value | Expected |
|--|--|--|--|--|
| SE-001 | const-visible-true | visible | `true` | shown |
| SE-002 | const-visible-false | visible | `false` | hidden |
| SE-003 | const-required-true | required | `true` | empty triggers validation |
| SE-004 | const-required-false | required | `false` | optional |
| SE-005 | const-readonly-true | readOnly | `true` | not editable |
| SE-006 | const-readonly-false | readOnly | `false` | editable |
| SE-007 | const-required-readonly | required + readOnly | `true` + `true` | edge case – confirm behaviour |

## 2. Single reference & boolean logic

Local drivers: `toggle-a` (true), `toggle-b` (false).

| ID | Field | Property | Expression | Expected (by driver) |
|--|--|--|--|--|
| SE-101 | ref-visible | visible | `#toggle-a` | shown when toggle-a=true |
| SE-102 | ref-required | required | `#toggle-a` | required when toggle-a=true |
| SE-103 | ref-readonly | readOnly | `#toggle-a` | locked when toggle-a=true |
| SE-104 | ref-not | visible | `not( #toggle-a )` | shown when toggle-a=false |
| SE-201 | logic-and | visible | `and( #toggle-a, #toggle-b )` | shown only if both true |
| SE-202 | logic-or | visible | `or( #toggle-a, #toggle-b )` | shown if either true |
| SE-205 | logic-not-and | visible | `not( and( #toggle-a, #toggle-b ) )` | hidden only if both true |
| SE-206 | logic-and-notb | visible | `and( #toggle-a, not( #toggle-b ) )` | shown if a=true & b=false |

## 3. Numeric comparison

Local driver: `age` (Numeric, 30).

| ID | Field | Property | Expression | Expected (by driver) |
|--|--|--|--|--|
| SE-301 | num-gt | visible | `gt( #age, 18 )` | shown when age>18 |
| SE-302 | num-lt | visible | `lt( #age, 65 )` | shown when age<65 |
| SE-303 | num-eq | visible | `eq( #age, 30 )` | shown when age=30 |

## 4. String / empty / contains

Local drivers: `name` (Text), `email` (Text), `color` (Select 1/2/3).

| ID | Field | Property | Expression | Expected (by driver) |
|--|--|--|--|--|
| SE-401 | str-empty | visible | `empty( #name )` | shown when name empty |
| SE-402 | str-not-empty-req | required | `not( empty( #name ) )` | required when name filled |
| SE-403 | str-eq-select | visible | `eq( #color, "2" )` | shown when color=2 |
| SE-404 | str-contains | visible | `contains( #name, "nn" )` | shown when name has "nn" |
| SE-406 | str-not-eq | visible | `not( eq( #color, "3" ) )` | shown when color≠3 |
| SE-407 | str-email-empty | visible | `empty( #email )` | shown when email empty |

## 5. Field type coverage

Local drivers: Boolean, Numeric, DateTime, Select, TextArea. Targets cover **every field type** and all three properties (`visible`, `required`, `readOnly`).

| ID | Field | Target type | Property | Expression | Expected (by driver) |
|--|--|--|--|--|--|
| SE-501 | type-text-target | Text | visible | `#type-bool-driver` (Boolean → Text) | shown when bool=true |
| SE-502 | type-multiline-target | TextArea | readOnly | `#type-bool-driver` (Boolean → TextArea) | locked when bool=true |
| SE-503 | type-numeric-target | Numeric | visible | `gt( #type-num-driver, 3 )` (Numeric → Numeric) | shown when num>3 |
| SE-504 | type-bool-target | Boolean | visible | `#type-bool-driver` (Boolean → Boolean) | shown when bool=true |
| SE-505 | type-select-target | Select | readOnly | `eq( #type-select-driver, "opt-1" )` (Select → Select) | locked when select=opt-1 |
| SE-506 | type-date-target | DateTime | required | `not( empty( #type-date-driver ) )` (DateTime → DateTime) | required when date set |
| SE-507 | type-comment | Comment | visible | `contains( #type-textarea-driver, "nn" )` (TextArea → Comment) | shown when TextArea has "nn" |

## 6. Nested expression

Local drivers: `person-name` (Text), `person-age` (Numeric), `person-sex` (Select).

| ID | Field | Property | Expression | Expected (by driver) |
|--|--|--|--|--|
| SE-601 | nested-required | required | `and( not( empty( #person-name ) ), and( gt( #person-age, 18 ), eq( #person-sex, "sex-2" ) ) )` | required when name filled, age>18 & sex=sex-2 |
| SE-602 | nested-visible | visible | `and( not( empty( #person-name ) ), and( gt( #person-age, 18 ), eq( #person-sex, "sex-2" ) ) )` | shown when name filled, age>18 & sex=sex-2 |
| SE-603 | nested-readonly | readOnly | `and( not( empty( #person-name ) ), and( gt( #person-age, 18 ), eq( #person-sex, "sex-2" ) ) )` | locked when name filled, age>18 & sex=sex-2 |
| SE-604 | nested-or | visible | `or( eq( #person-sex, "sex-1" ), gt( #person-age, 18 ) )` | shown when sex=sex-1 OR age>18 |

## 7. Cascading dependencies

Local chain in one step: `chain-a` (Boolean) → `chain-b` → `chain-c`.

| ID | Field | Property | Expression | Expected (by driver) |
|--|--|--|--|--|
| SE-701 | chain-b | required + visible | `#chain-a` | B shown+required when A=true |
| SE-702 | chain-c | required + visible | `not( empty( #chain-b ) )` | C shown+required when B has value |

## 8. Negative / error handling

| ID | Field | Property | Expression | Expected |
|--|--|--|--|--|
| SE-0901 | ghost-ref | visible | `not( empty( #ghost ) )` | unknown field = empty → hidden, no crash |

---

### How to use with the JSON
Open **Form_Wizard_SimpleExpression_Advanced.json**. Within each step, change the fields marked
**Driver**, then verify each dependent field's `required` / `readOnly` / `visible` state matches the
expression column above.
