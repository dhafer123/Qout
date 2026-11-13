# Nutri-Score specification (updated algorithm, 2023)

These are the **only** sources for scoring thresholds and constants in Qout (see `CLAUDE.md`,
rule 2). Every value in `scoring-spec/` and in the scoring engines must trace back to one of them.

## Sources

| File | Document | Publisher / date | Role |
|---|---|---|---|
| `nutri-score-qa-v11.pdf` | Q&A for the updated Nutri-Score algorithm, V11 | Santé publique France | **Primary.** Point tables (Tables 5–10), calculation rules, grade table (p. 32, an image), product categories |
| `nutri-score-foods-report-2022.pdf` | Update report from the Scientific Committee, 2022 | Scientific Committee, voted 29 June 2022 | Confirms foods and fats tables (recap, pp. 130–134) |
| `nutri-score-beverages-report-2023.pdf` | Second update report (beverages), V2 2023 | Scientific Committee, voted 1 February 2023 | Confirms beverage tables (p. 73) |
| `nutri-score-calculator-2024-04-04.xlsx` | Official calculator for the updated algorithm | Santé publique France, 2024-04-04 | Exact comparison operators; official example results used as golden cases |

Downloaded from <https://www.santepubliquefrance.fr/en/nutrition-and-physical-activity/nutri-score>
(beverages report: <https://edepot.wur.nl/629571>).

## Where each rule lives

| Category | N component | P component | Score rule | Grades |
|---|---|---|---|---|
| General foods | Q&A Table 5 | Q&A Table 6 | N < 11: N − P; else N − fibre − FVL | A ≤ 0, B 1–2, C 3–10, D 11–18, E ≥ 19 (2022 report §1.8.2, p. 50) |
| Red meat | Table 5 | Table 6, protein capped at 2 points | as general | as general foods |
| Cheese | Table 5 | Table 6 | always N − P | as general foods |
| Fats, oils, nuts and seeds | Q&A Table 7 (energy from saturates = saturates × 37; saturates/fat ratio in %) | Q&A Table 8 | N < 7: N − P; else N − fibre − FVL | A ≤ −6, B −5 to 2, C 3–10, D 11–18, E ≥ 19 (2022 report §2.4.3, p. 73) |
| Beverages | Q&A Table 9 (+4 points if non-nutritive sweeteners) | Q&A Table 10 | always N − P | B ≤ 2, C 3–6, D 7–9, E ≥ 10; never A (2023 report §6.7.3, p. 48) |
| Water | — | — | — | always A |

The Q&A grade table (p. 32) is an image; the grade bands above are quoted from the reports and match the calculator's formulas.

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
   Exception: fibre (decision 8).
6. **Water** (mineral, spring, table water without additions) is always A and takes no inputs.
   Flavoured waters are beverages and cannot be A (Q&A p. 16).
7. **Rounding:** none. Points use the declared values as given (Q&A p. 11–13).
   The calculator's "General foods" sheet alone rounds protein to 2 decimals before
   scoring (`ROUND(J, 2)`); we do not. Results differ only for protein declared with 3+
   decimals just above a threshold (e.g. 2.404 g: 1 point here, 0 in that sheet).
8. **Undeclared fibre counts as 0 points** (decided 2026-11-12, not from the documents, which
   do not cover it). Fibre is optional on EU labels (Regulation (EU) 1169/2011, Article 30) and
   is usually left out of products with almost none (cheese, meat, soft drinks), so the strict
   reading of decision 5 would leave many real products ungraded. Fibre points can only lower
   the score, so 0 points gives the worst grade the declared values allow: the true grade is the
   same or better, never worse. Results record the assumption (`assumed_zero: ["fibre_g"]`) so
   it can be shown to users. Only fibre: any other missing input still gives insufficient data,
   and then the missing list does not mention fibre. Engine version `nutriscore-2023.2`.

## Constants for later tasks

- Salt ↔ sodium: salt = sodium × 2.5 (Q&A p. 12; calculator "Conversion tool").
- kcal → kJ: the calculator's conversion tool uses kJ = ROUND(kcal × 4.2, 0), halves rounded
  away from zero (Excel). Engines take kJ; use this factor only if a source gives kcal alone.
- Non-nutritive sweeteners: sugar alcohols E420, E421, E953, E956, E964, E965, E966, E967, E968
  do **not** count (calculator sheet "Non-nutritive sweeteners"; Q&A Appendix 3).
- Alcoholic beverages above 1.2 % alcohol are out of scope (beverages report, p. 72).
- **Display only:** the app shows energy as kJ and kcal, with kcal = kJ / 4.184 (the
  thermochemical calorie, 1 kcal = 4.184 kJ exactly; decided 2026-11-13). Never used for
  scoring, which takes kJ; for kcal→kJ inputs the calculator's 4.2 above still applies.

# Additives and NOVA (T10)

## Sources

| File | Document | Publisher / date | Role |
|---|---|---|---|
| `off-additives-taxonomy-7fbee09.txt` | Additives taxonomy (`taxonomies/additives.txt`) | Open Food Facts, `openfoodfacts-server` commit `7fbee09`, 2026-11-12 | Additive codes, English names, EFSA overexposure risk |

Downloaded from
<https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/7fbee094fb9d89e98c49ab4b2102c7b48b1a7a05/taxonomies/additives.txt>.
© Open Food Facts contributors. The file comes from an AGPL-3.0 repository; Open Food Facts
data is published under the Open Database License (ODbL). Attribution is required either way;
the exact licence of the taxonomy is to be confirmed before the public release (T37).

The backend does not read this file at runtime: `uv run python -m app.modules.scoring.taxonomy`
generates `backend/app/modules/scoring/data/additives.json` from it, and a test fails if the two
are out of sync.

## Additive risk flag

The flag is the taxonomy's `efsa_evaluation_overexposure_risk`, which summarises EFSA's
re-evaluation opinion for the additive (linked in `efsa_evaluation_url`):

| Taxonomy value | Qout flag | Meaning |
|---|---|---|
| `en:high` | `high` | EFSA found a high risk that part of the population exceeds the acceptable daily intake |
| `en:moderate` | `moderate` | moderate risk of exceeding it |
| `en:no` | `none` | no risk of exceeding it found |
| (absent) | `unknown` | no flag in the source; **not** the same as "no risk" |

Decisions:

1. **Sub-additives inherit their parent's flag** when they have none of their own (e.g. E339(i)
   from E339, phosphates, `high`): EFSA evaluates these as one group. Applies to 37 entries
   (65 have a flag of their own, 624 stay unknown);
   the result records which code the flag came from.
2. **Only E-numbered entries** are used (726). Generic entries such as "Exxx" or "E14XX" are
   skipped.
3. **Open Food Facts tags** (`en:e160ai`) match taxonomy codes (`E160a(i)`) by comparing
   lower-case letters and digits only. A tag that is not in the taxonomy is kept with risk
   `unknown`.

## NOVA

Not computed: the NOVA group (1–4) is taken from the Open Food Facts product field
`nova_group`. Any other value (missing, out of range, not a number) means unknown.
Groups: 1 unprocessed or minimally processed foods, 2 processed culinary ingredients,
3 processed foods, 4 ultra-processed foods (NOVA classification, as used by Open Food Facts).
