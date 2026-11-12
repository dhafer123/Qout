# Engine validation: `nutriscore-2023.2`

Generated 2026-11-12 from the development database. Our grade (Python engine `nutriscore-2023.2`) compared with Open Food Facts' own Nutri-Score grade (2023 algorithm), for every product OFF grades.

> **Small sample: 38 products graded by both** (fewer than 300). The numbers below are not representative; regenerate after the full Open Food Facts import (`python -m app.worker run export`).

## Summary

| | Products |
|---|---:|
| Scorable (known category, not hidden) | 78 |
| Scored with `nutriscore-2023.2` | 78 |
| Graded by OFF | 43 |
| Graded by both | 38 |
| **Same grade** | **38 (100.0 %)** |
| Within one grade | 38 (100.0 %) |
| OFF grades, we report insufficient data | 5 |

## Confusion matrix

Rows: our grade. Columns: OFF's grade.

| Ours \ OFF | A | B | C | D | E |
|---|---:|---:|---:|---:|---:|
| A | **5** | · | · | · | · |
| B | · | · | · | · | · |
| C | · | · | **3** | · | · |
| D | · | · | · | **10** | · |
| E | · | · | · | · | **20** |
| Insufficient data | · | 1 | 1 | 1 | 2 |

## Agreement by category

| Category | Graded by both | Same grade |
|---|---:|---:|
| general | 23 | 23 (100.0 %) |
| cheese | 3 | 3 (100.0 %) |
| beverage | 10 | 10 (100.0 %) |
| water | 2 | 2 (100.0 %) |

## Agreement by OFF estimation

OFF marks a grade as estimated when some inputs (usually the fruit/vegetable share) come from the ingredient list rather than the label.

| OFF inputs | Graded by both | Same grade |
|---|---:|---:|
| not estimated | 37 | 37 (100.0 %) |
| estimated | 1 | 1 (100.0 %) |

## Mismatches (top 25)

None.

## OFF grades, we report insufficient data (first 25)

| EAN | Product | Category | OFF | OFF estimated | Our missing inputs |
|---|---|---|---|---|---|
| 5900617036728 | Fit cereal biscuits | general | C | not estimated | fvl_percent |
| 6191448300518 | Maïs moulu | fats_oils_nuts_seeds | B | estimated | fvl_percent, protein_g, salt_g, saturated_fat_g, sugars_g, total_fat_g |
| 6191508400622 | Thon en morceaux à l'huile végétale | general | E | estimated | energy_kj, protein_g, salt_g, saturated_fat_g, sugars_g |
| 6191585701087 | Mon Carré | cheese | D | not estimated | fvl_percent |
| 6194005420186 | Crème à tartiner aux noisettes | general | E | estimated | energy_kj, protein_g, salt_g, saturated_fat_g, sugars_g |
