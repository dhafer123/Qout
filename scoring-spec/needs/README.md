# Daily needs: shared cases

Test cases for the daily needs calculation used by personal advice (T39, T40): a profile in,
the daily energy, the daily amounts the advice compares products with, and the BMI out. The
app computes needs on the phone (the profile never leaves it), so the Dart implementation runs
every file here; a backend implementation, if one is ever added, must too.

These files are separate from [`../golden/`](../golden/), which holds Nutri-Score cases only.

The rules behind every number are in [`docs/specs/README.md`](../../docs/specs/README.md),
section "Health advice": sources, page references and decisions H1–H7.

## Files

- [`schema.json`](schema.json): JSON Schema 2020-12 for the files in `cases/`;
  `$defs/efsa_table` describes `efsa-table-12.json`.
- [`efsa-table-12.json`](efsa-table-12.json): EFSA's own Average Requirements for energy
  (Table 12), 2 sexes × 6 age bands × 4 activity levels. Input: each band's reference body
  from EFSA Table 4 (median measured height, body mass for a BMI of 22) and the band's first
  year of age. The computed energy must be within `tolerance_kj` (100 kJ) of `energy_mj` × 1000:
  EFSA reports the median of individual values rounded to 0.1 MJ, not the value of the median
  person (recomputing from the medians differs by at most 62 kJ).
- `cases/<kind>--<slug>.json`: exact cases, every field must match.
  - `personal--…`: computed from a profile (each Henry equation, the age boundaries 29/30 and
    59/60, the oldest age 79, every activity level).
  - `reference--…`: EU reference intakes instead (no profile, sex not given, age 80+).
  - `bmi--…`: the WHO category boundaries, and the display rounding just below them.

## Format

```json
{
  "id": "personal--male-25-sedentary",
  "description": "Man, 25, low active: Henry 18-30 equation.",
  "source": "EFSA 2013 Appendix 2 (Henry, body mass and height); …",
  "input": { "sex": "male", "age": 25, "height_cm": 180, "weight_kg": 75.0, "pal": 1.4 },
  "expected": {
    "basis": "personal", "energy_kj": 10263, "fat_g": 97, "saturates_g": 28,
    "sugars_g": 90, "salt_g": 5, "bmi": 23.1, "bmi_category": "normal"
  }
}
```

- **Input:** `sex` (`male`, `female`, or `null` when not given), `age` in whole years (18–120),
  `height_cm` (100–250), `weight_kg` (30–300), `pal` (1.4, 1.6, 1.8 or 2.0). `null` instead of
  the object: the profile was skipped.
- **Expected:** `basis` (`personal` or `reference`), daily `energy_kj`, `fat_g`,
  `saturates_g`, `sugars_g`, `salt_g` (whole numbers), `bmi` (rounded down to 0.1, `null`
  without a profile) and `bmi_category` (`underweight`, `normal`, `preobese`,
  `obese_class_1`, `obese_class_2`, `obese_class_3`, or `null`).

How the expected values follow from the rules (worked example, the case above):
REE = 0.0600 × 75.0 + 1.31 × 1.80 + 0.473 = 7.331 MJ/day; energy = 7.331 × 1.4 × 1000 =
10 263.4 → 10 263 kJ; fat = 0.35 × 10 263 / 37 = 97.08 → 97 g; saturates = 0.10 × 10 263 / 37
= 27.74 → 28 g; BMI = 75.0 / 1.80² = 23.148 → 23.1, normal.

## Adding a case

Create `cases/<kind>--<slug>.json` with `source` pointing at the rule it tests, computed with
exact decimals and the rounding of decisions H4 and H6. The Dart test (T39) validates every
file against the schema and checks the results.
