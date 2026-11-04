

##:bulb: This document is essentially a set of test cases which can be manually executed with Form JSON responses created specifically for simple expression regressions


## Engine cheat-sheet (operators used in the form)

| Category | Values| Notes |
|--|--|--|
|Propreties| `required`, `readOnly` and `visible` |
| Function operators | **`not`, `eq`, `and`, `or`, `contains`, `gt`, `lt`, `empty` | function form only |
| Constants | `true`, `false`, numbers, quoted strings | case-insensitive (`TRUE` = `true`) |
| Field reference | `#fieldId` | driver must be in the **same step** as the target |


## Known engine limitations (confirmed during testing)

- **Symbol operators not supported** (`!`, `&`, `|`, `>`, `>=`, `<`, `<=`) - use the function forms.
- **special not supported** (`match` regex, `len`, `concat`).

- **No truthiness coercion** - a bare `0` / `"string"` inside `and`/`or` throws (`Invalid Expression`); only booleans / field refs / operator calls are valid operands.

- **No circular-reference guard** - two fields referencing each other's state cause an infinite load.

- **`or()` arguments are restricted** — `or()` only accepts comparison operators (`eq`, `gt`, `lt`, `contains`, `empty`) and simple values (field refs, constants) as arguments. Logical operators (`or`, `and`, `not`) as arguments to `or()` throw `Invalid Expression`. Use `and`/`not` to combine the results of `or()` calls instead.

- **`or()` cannot be used for multi-value membership checks** — any form expression like `or( or(...), ... )` will crash the form. Backend generators must not produce nested `or()` constructs.


  

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
| SE-201 | ref-visible | visible | `#toggle-a` | shown when toggle-a=true |
| SE-202 | ref-required | required | `#toggle-a` | required when toggle-a=true |
| SE-203 | ref-readonly | readOnly | `#toggle-a` | locked when toggle-a=true |
| SE-204 | ref-not | visible | `not( #toggle-a )` | shown when toggle-a=false |
| SE-205 | logic-and | visible | `and( #toggle-a, #toggle-b )` | shown only if both true |
| SE-206 | logic-or | visible | `or( #toggle-a, #toggle-b )` | shown if either true |
| SE-207 | logic-not-and | visible | `not( and( #toggle-a, #toggle-b ) )` | hidden only if both true |
| SE-208 | logic-and-notb | visible | `and( #toggle-a, not( #toggle-b ) )` | shown if a=true & b=false |

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
| SE-604b | nested-or-invalid | visible | `or( or( eq( #person-sex, "sex-1" ), eq( #person-sex, "sex-2" ) ), gt( #person-age, 18 ) )` | should show when (sex=sex-1 OR sex=sex-2) OR age>18 — **crashes form**: `or` as arg to `or` not supported |
| SE-604c | nested-or-and-invalid | visible | `or( and( gt( #person-age, 18 ), not( empty( #person-name ) ) ), eq( #person-sex, "sex-1" ) )` | should show when (age>18 AND name filled) OR sex=sex-1 — **predicted crash (untested)**: `and` as arg to `or` inferred to be rejected by same grammar restriction as SE-604b |
| SE-604d | nested-or-not-invalid | visible | `or( not( eq( #person-sex, "sex-1" ) ), gt( #person-age, 18 ) )` | should show when sex≠sex-1 OR age>18 — **predicted crash (untested)**: `not` as arg to `or` inferred to be rejected by same grammar restriction as SE-604b |
| SE-605 | nested-and-and | visible | `and( and( gt( #person-age, 18 ), not( empty( #person-name ) ) ), eq( #person-sex, "sex-2" ) )` | shown when all conditions met — `and` as arg to `and` is valid |
| SE-606 | nested-not-not | visible | `not( not( eq( #person-sex, "sex-1" ) ) )` | shown when sex=sex-1 — double negation is valid |

## 7. Cascading dependencies

Local chain in one step: `chain-a` (Boolean) → `chain-b` → `chain-c`.

| ID | Field | Property | Expression | Expected (by driver) |
|--|--|--|--|--|
| SE-701 | chain-b | required + visible | `#chain-a` | B shown+required when A=true |
| SE-702 | chain-c | required + visible | `not( empty( #chain-b ) )` | C shown+required when B has value |

 

## 8. Negative / error handling

| ID | Field | Property | Expression | Expected |
|--|--|--|--|--|
| SE-801 | ghost-ref | visible | `not( empty( #ghost ) )` | unknown field = empty → hidden, no crash |

  