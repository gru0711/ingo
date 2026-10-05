# Task: support Quartz-style `W`, `LW`, `L-n` and `L-nW` day-of-month specifiers

You are working in the `cron-parser` repository (TypeScript). It parses cron expressions and computes the dates they fire on.

## Problem

Many cron dialects, including Quartz and the scheduling tools built on it, let the day-of-month field say:

- "the weekday nearest to the 15th" (`15W`)
- "the last weekday of the month" (`LW`)
- "three days before the last day of the month" (`L-3`)
- "the weekday nearest to three days before the last day" (`L-3W`)

Users of this library have asked for these forms (upstream issues #167 and #254). Today the parser rejects all of them:

```text
CronExpressionParser.parse('0 0 15W * *')  ->  Error: Invalid characters, got value: 15W
CronExpressionParser.parse('0 0 LW * *')   ->  Error: Invalid characters, got value: LW
CronExpressionParser.parse('0 0 L-3 * *')  ->  Error: Constraint error, got range NaN-3 expected range 1-31
```

Add support for all four forms, consistently across parsing, field objects, scheduling, matching and serialization.

## Required behavior

### 1. Syntax (day-of-month field only)

Four new item forms are accepted in the **day-of-month** field. `n` is always written in decimal digits, with no sign and no leading zero.

| Item | Meaning | Valid `n` |
|---|---|---|
| `nW` | The weekday (Monday–Friday) nearest to day `n` of the month | 1–31 |
| `LW` | The last weekday (Monday–Friday) of the month | none |
| `L-n` | The day `n` days before the last day of the month (`L-1` is the second-to-last day) | 1–30 |
| `L-nW` | The weekday nearest to the day `L-n` refers to | 1–30 |

Any of these may appear alone or as an item in a comma-separated list, together with any item the field already accepts: numbers, ranges, steps, `L`, `*`/`?`, and other new items. Examples: `1W,15W`, `1,15W,L`, `1-5,L-2`, `L-3W,LW`. A day matches the field when it matches **any** item in the list.

### 2. Semantics

All four forms are evaluated per month. "Last day" means the number of days in that month, so February has 28 or 29.

**Target day.** For `nW` the target is `n`. For `LW` it is the last day. For `L-n` and `L-nW` it is `lastDay - n`.

**No occurrence.** If the target does not exist in a month, the item produces no occurrence that month. That happens when `nW` asks for more days than the month has (`31W` in April), or when `lastDay - n` is less than 1 (`L-30` in February).

**`L-n`** occurs on the target day itself.

**`nW`, `LW` and `L-nW`** occur on the weekday nearest to the target:

- If the target is Monday–Friday, the occurrence is the target.
- If the target is a **Saturday**, the occurrence is the preceding Friday. Exception: if the target is the 1st, it is Monday the 3rd.
- If the target is a **Sunday**, the occurrence is the following Monday. Exception: if the target is the last day of the month, it is the preceding Friday.

The result therefore never moves into a different month.

Weekdays and month lengths are evaluated in the expression's timezone (the `tz` option, or the default timezone when none is given), the same way plain day-of-month values are today.

### 3. Interaction with the rest of the expression

- **Day-of-week.** When both day-of-month and day-of-week are restricted, the existing OR rule applies unchanged: a date matches if it matches either field. The new items take part in that rule exactly as a plain day-of-month value would.
- **Strict mode.** The existing strict-mode rules apply unchanged. For example, `0 0 0 15W * *` is valid in strict mode, while `0 0 0 15W * 1` is rejected because both day fields are set.
- **Single fixed month.** When the month field names exactly one month and the day-of-week field is a wildcard, the expression is rejected at parse time if **no** item of the day-of-month field can ever occur in that month. This is the same error a plain out-of-range day gets today; for example, `0 0 31 4 *` throws.
  - Month lengths here are the most a month can have, so February counts as 29.
  - `nW` can occur if `n` is at most the month's length.
  - `L-n` and `L-nW` can occur if `n` is less than the month's length.
  - `L` and `LW` can always occur.
  - Examples: `0 0 31W 4 *` and `0 0 L-29 2 *` throw. `0 0 L-28 2 *` is valid and fires only in leap years, on February 1st. `0 0 LW 4 *` is valid.
- **All public iteration and matching APIs** treat the new items consistently: `next()`, `prev()`, `take()`, `hasNext()`, `hasPrev()`, the iterator, `includesDate()`, `startDate`/`endDate` bounds, `reset()`, and `CronFileParser` (crontab lines). If two items resolve to the same date, that date occurs once. For example, `14W,15W` when the 15th is a Saturday, or `L,LW` when the last day is a weekday.

### 4. Invalid input (must throw an `Error` from `CronExpressionParser.parse`)

- `W` without a day number: `W`
- Day number out of range: `0W`, `32W`, `L-0`, `L-31`, `L-0W`, `L-31W`
- A new form combined with a range or step: `1-5W`, `1W-5`, `15W/2`, `*/2W`, `L-2/3`, `L-2-5`, `1-L-2`
- Malformed forms: `W15`, `WL`, `15WW`, `L15W`, `L-`, `L-W`, `LW-2`, `L2`, `L-2L`
- Duplicate items, as with duplicate plain values today: `15W,15W`, `LW,LW`, `L-2,L-2`
- Any new form in a field other than day-of-month, for example `0 0 * * 1W`, `0 15W * * *` or `0 0 * * L-2`. (These already throw today and must keep throwing.)

The error message text is not prescribed.

### 5. Field objects and types (public API)

- After parsing, `expression.fields.dayOfMonth.values` (and `fields.dayOfMonth.serialize().values`) contains each new item as a string exactly as written: `'15W'`, `'LW'`, `'L-3'`, `'L-3W'`. Numeric days stay numbers and `'L'` stays `'L'`. The relative order of string items in `values` is not prescribed.
- `CronDayOfMonth` accepts these strings directly, and the result schedules correctly:
  - Valid: `new CronDayOfMonth(['15W'])`, `new CronDayOfMonth([1, 'LW'])`, `new CronDayOfMonth(['L-3'])`, `new CronDayOfMonth(['L-3W', 10])`.
  - Must throw: `new CronDayOfMonth(['0W'])`, `['32W']`, `['W']`, `['L-0']`, `['L-31']`.
  - `CronFieldCollection.from(base, { dayOfMonth: ['LW'] })` followed by `CronExpression.fieldsToExpression(collection, options)` yields an expression that schedules the last weekday of each month. The same holds for the other forms.
- The exported TypeScript type `DayOfMonthRange` must accept `'LW'` and strings of the forms `` `${n}W` `` (n from 1 to 31), `` `L-${n}` `` and `` `L-${n}W` `` (n from 1 to 30), so the calls above compile without casts. Existing members of the type must remain valid.

### 6. Serialization

`stringify()` of an expression, and `CronFieldCollection#stringify`, render a day-of-month field that contains any of the new items in this canonical form:

1. First, the numeric days, written exactly as `stringify()` writes a day-of-month field that contains only those numbers today. For example, `1,2,3` → `1-3`, `1,11,21,31` → `*/10`, and `1,15` → `1,15`.
2. Then the string items in this order, joined with commas and with empty groups skipped:
   1. `nW` items, by ascending `n`
   2. `L`
   3. `LW`
   4. `L-n` items, by ascending `n`
   5. `L-nW` items, by ascending `n`

Examples:

| Expression | `stringify()` |
|---|---|
| `0 0 15W * *` | `'0 0 15W * *'` |
| `0 0 15W,1W * *` | `'0 0 1W,15W * *'` |
| `0 0 31W,4W * *` | `'0 0 4W,31W * *'` |
| `0 0 LW,15W,1 * *` | `'0 0 1,15W,LW * *'` |
| `0 0 L-10,L-2 * *` | `'0 0 L-2,L-10 * *'` |
| `0 0 L-2W,L-10,L,20W,3 * *` | `'0 0 3,20W,L,L-10,L-2W * *'` |
| `0 30 9 LW * *` (six fields) | `'30 9 LW * *'` |

Seconds are omitted by default, as today; `stringify(true)` includes them. Re-parsing the output of `stringify(true)` must give the same schedule. Fields that use none of the new items are rendered exactly as today.

## Compatibility requirements

- Behavior of every expression that does not use the new forms is unchanged. The existing test suite must pass.
- `npm run build` (TypeScript compile) and `npm run lint` must pass.
- No new runtime dependencies. No changes to the public signatures of existing methods.

## Constraints and exclusions

- Out of scope: the new forms combined with `H` hashing, lowercase `w`/`l`, numbers written with a leading zero (such as `01W` or `L-02`), ranges that use `L` as a bound (such as `20-L`), and any change to the day-of-week `L`/`#` syntax. Behavior for these is unspecified and will not be tested.
- Do not edit or delete existing tests. You may add new tests, and updating `README.md` to document the feature is encouraged.
- The work must be possible offline; all dependencies are already installed.

## Acceptance criteria

- **AC1** `nW`, `LW`, `L-n` and `L-nW` parse in the day-of-month field, alone and inside lists mixed with existing items.
- **AC2** `next()` yields the dates defined in §2 for `nW`: weekday, Saturday, Sunday, the 1st-is-Saturday exception, the last-day-is-Sunday exception, and months shorter than `n`.
- **AC3** `LW` yields the last weekday of every month, including months that end on Saturday or Sunday and February in leap and non-leap years.
- **AC4** Lists combine items with OR and never produce duplicate dates.
- **AC5** `prev()`, `take(-k)`, `hasNext()`/`hasPrev()`, the iterator, `includesDate()`, date bounds and `reset()` agree with `next()`.
- **AC6** The day-of-week OR rule and strict-mode rules apply as in §3.
- **AC7** Results follow the configured timezone.
- **AC8** Each invalid input in §4 throws, and the single-fixed-month rule in §3 holds.
- **AC9** `fields.dayOfMonth.values`/`serialize()` expose the items as described. `CronDayOfMonth`, `CronFieldCollection.from` and `fieldsToExpression` work with them, and `DayOfMonthRange` accepts them at compile time.
- **AC10** `stringify()` produces the canonical form of §6, and its output re-parses to the same schedule.
- **AC11** Crontab files containing the new syntax parse via `CronFileParser`.
- **AC12** Existing tests, `npm run build` and `npm run lint` pass. Results are deterministic across repeated runs.
- **AC13** `L-n` and `L-nW` yield the dates defined in §2, including months where `lastDay - n` is less than 1, February in leap and non-leap years, and `L-nW` targets on a Saturday the 1st or on a Sunday.
