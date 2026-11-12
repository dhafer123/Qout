# Scoring spec: golden cases

Shared test cases for the Nutri-Score engines. The Python engine (`backend/app/modules/scoring`)
and the Dart engine (`app/`) must both produce exactly the `expected` block of every file in
`golden/`.

The rules behind every number are in [`docs/specs/`](../docs/specs/README.md): the official
Q&A (V11), the Scientific Committee reports and the official calculator. Interpretation
decisions (exact-threshold values, the beverage salt typo, total fat = 0, missing data) are
listed there and referenced by number in the cases.

## Format

One JSON file per case, validated by [`schema.json`](schema.json) (JSON Schema 2020-12).
File name = `id` = `<category>--<slug>.json`.

```json
{
  "id": "red_meat--high-protein-capped",
  "description": "Protein 20 g would give 7 points; red meat is capped at 2.",
  "source": "Q&A Table 6, footnote (red meat)",
  "category": "red_meat",
  "input": { "energy_kj": 600, "saturated_fat_g": 1.5, "sugars_g": 0, "salt_g": 0.3,
             "fibre_g": 0, "protein_g": 20, "fvl_percent": 0 },
  "expected": {
    "negative": { "energy": 1, "sugars": 0, "saturated_fat": 1, "salt": 1 },
    "positive": { "protein": 2, "fibre": 0, "fvl": 0 },
    "negative_total": 3, "positive_total": 2, "protein_counted": true,
    "score": 1, "grade": "B"
  }
}
```

- **Categories:** `general`, `red_meat`, `cheese`, `fats_oils_nuts_seeds`, `beverage`, `water`.
- **Input** (per 100 g, or 100 mL for beverages): `energy_kj`, `sugars_g`, `saturated_fat_g`,
  `salt_g`, `fibre_g`, `protein_g`, `fvl_percent`; plus `total_fat_g` (fats category only) and
  `non_nutritive_sweeteners` (beverages only). Water takes no input. Salt, not sodium.
- **Expected** is one of:
  - a scored result: points per component, `negative_total` (N), `positive_total` (P, all three
    positive components), `protein_counted` (false when protein is left out of the score),
    `score`, `grade`. Fats use `energy_from_saturates` and `saturated_fat_ratio` instead of
    `energy` and `saturated_fat`; beverages add `non_nutritive_sweeteners` (0 or 4);
  - `{"grade": "A"}` for water;
  - `{"insufficient_data": [...]}`: the missing (or unusable) inputs, sorted.
- **Undeclared fibre** (decision 8): `fibre_g` may be absent from a scored case's input; it then
  counts as 0 points and the result adds `"assumed_zero": ["fibre_g"]`. The key is present if
  and only if fibre was undeclared.

## Where the cases come from

- `source: "calculator: <sheet> row <n> (official result)"`: the example products shipped in
  the official calculator, with the calculator's own results.
- Other sources (`Q&A Table …`): boundary cases written for this project. Expected values were
  computed from the cited tables and cross-checked against a reference implementation that
  reproduces every official calculator example.

## Adding a case

1. Create `golden/<category>--<slug>.json`, with `source` pointing at the table or rule it tests.
2. Run `uv run pytest tests/unit/test_golden_cases.py` from `backend/`: it validates the file
   against the schema, the file name, and that the points add up.

## Parity between the engines

Golden cases pin known answers; the parity check makes sure the Python and Dart engines
also agree everywhere else. `parity/inputs.json` (generated, committed) holds every golden
input, every threshold of every table with values exactly on and 0.001 either side of it
(including the fats saturates/fat ratio and energy from saturates), and 600 random products
per category, some with missing fields. Both engines score it; CI job `scoring-parity`
fails on any difference.

```bash
# from backend/ (WSL)
uv run python -m app.modules.scoring.parity run /tmp/py.json
# from app/
dart run tool/scoring_parity.dart ../py-dart.json
# from backend/
uv run python -m app.modules.scoring.parity compare /tmp/py.json ../py-dart.json
```

After changing the generator or a golden case, regenerate the inputs with
`uv run python -m app.modules.scoring.parity generate`; a backend test fails until you do.
