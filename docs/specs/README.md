# Nutri-Score specification (updated algorithm, 2023)

These are the **only** sources for scoring thresholds and constants in Qout (see `CLAUDE.md`,
rule 2). Every value in `scoring-spec/` and in the scoring engines must trace back to one of them.

## Sources

| File | Document | Publisher / date | Role |
|---|---|---|---|
| `nutri-score-qa-v11.pdf` | Q&A for the updated Nutri-Score algorithm, V11 | Santé publique France | **Primary.** Point tables (Tables 5–10), calculation rules, grade table (p. 32), product categories |
| `nutri-score-foods-report-2022.pdf` | Update report from the Scientific Committee, 2022 | Scientific Committee, voted 29 June 2022 | Confirms foods and fats tables (recap, pp. 130–134) |
| `nutri-score-beverages-report-2023.pdf` | Second update report (beverages), V2 2023 | Scientific Committee, voted 1 February 2023 | Confirms beverage tables (p. 73) |
| `nutri-score-calculator-2024-04-04.xlsx` | Official calculator for the updated algorithm | Santé publique France, 2024-04-04 | Exact comparison operators; official example results used as golden cases |

Downloaded from <https://www.santepubliquefrance.fr/en/nutrition-and-physical-activity/nutri-score>
(beverages report: <https://edepot.wur.nl/629571>).

## Where each rule lives

| Category | N component | P component | Score rule | Grades |
|---|---|---|---|---|
| General foods | Q&A Table 5 | Q&A Table 6 | N < 11: N − P; else N − fibre − FVL | Q&A p. 32, "Foods" |
| Red meat | Table 5 | Table 6, protein capped at 2 points | as general | "Foods" |
| Cheese | Table 5 | Table 6 | always N − P | "Foods" |
| Fats, oils, nuts and seeds | Q&A Table 7 (energy from saturates = saturates × 37; saturates/fat ratio in %) | Q&A Table 8 | N < 7: N − P; else N − fibre − FVL | "Animal and vegetable fats, nuts and seeds" |
| Beverages | Q&A Table 9 (+4 points if non-nutritive sweeteners) | Q&A Table 10 | always N − P | "Beverages" (B to E only) |
| Water | — | — | — | always A |

Category membership (what counts as cheese, red meat, beverage, fats/nuts/seeds) is defined
in the Q&A, pp. 16–21. Choosing the category is an input to the engine, not part of scoring.

## Interpretation decisions

The documents disagree or are silent in a few places. These decisions apply to every engine and
golden case:

1. **A value exactly on a threshold gets the lower points.** Tables are read as
   "0 points: ≤ t₁; 1 point: > t₁" everywhere. Q&A Tables 5–6 print some first rows as
   "< 335 / > 335", "< 1", "< 40", leaving exact values uncovered; the 2022 report prints
   "≤ 1" and "≤ 40", and the calculator uses `<=` for every one of them, including energy 335.
2. **Saturates/fat ratio (fats category) is the exception:** Table 7 is written with "<", so a
   ratio exactly on a threshold gets the **higher** points (ratio 10 % → 1 point; ≥ 64 % → 10).
   All three documents agree.
3. **Beverage salt exactly 3.2 g/100 mL → 15 points.** Q&A Table 9 and the beverages report say
   "> 3.2" for 16 points; the calculator uses `< 3.2` in that one cell only (a typo).
4. **Fats category with total fat = 0:** the saturates/fat ratio is undefined and no document
   covers it. The engine reports insufficient data instead of guessing.
5. **Missing input → insufficient data.** The calculator returns "missing data" when any input
   used by the category is blank; engines list the missing fields instead of guessing.
6. **Water** (mineral, spring, table water without additions) is always A and takes no inputs.
   Flavoured waters are beverages and cannot be A (Q&A p. 16).
7. **Rounding:** none. Points use the declared values as given (Q&A p. 11–13).

## Constants for later tasks

- Salt ↔ sodium: salt = sodium × 2.5 (Q&A p. 12; calculator "Conversion tool").
- kcal → kJ: the calculator's conversion tool uses kJ = round(kcal × 4.2). Engines take kJ;
  use this factor only if a source gives kcal alone.
- Non-nutritive sweeteners: sugar alcohols E420, E421, E953, E956, E964, E965, E966, E967, E968
  do **not** count (calculator sheet "Non-nutritive sweeteners"; Q&A Appendix 3).
- Alcoholic beverages above 1.2 % alcohol are out of scope (beverages report, p. 72).
