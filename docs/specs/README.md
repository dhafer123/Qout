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
- **Label parser energy check (T26; data quality, never scoring):** energy conversion
  factors from Regulation (EU) 1169/2011, Annex XIV: carbohydrate (except polyols) 17 kJ /
  4 kcal per g, protein 17 kJ / 4 kcal, fat 37 kJ / 9 kcal, fibre 8 kJ / 2 kcal. Expected
  energy = factors × declared carbohydrate, protein, fat and fibre (fibre 0 if undeclared);
  the declared energy passes if within ±15 % of itself or ±20 kcal (84 kJ, by the 4.2
  factor above), whichever is larger (decided 2026-11-15: labels round each value, and
  polyols, alcohol and organic acids are rarely declared). kJ is checked against the kJ
  factors when kcal is not declared. Further parser heuristics (decided 2026-11-15): each
  amount ≤ 100 g; sugars ≤ carbohydrate; saturates ≤ fat; fat + carbohydrate + protein +
  fibre + salt ≤ 102 g (2 g for rounding); a value written "< x" is read as x and marked
  approximate; "traces" is read as 0 and marked approximate; values declared per portion
  only are refused, not converted.
- **LLM fallback parser (T28; data quality, never scoring):** its values get every check
  above, plus a grounding rule (decided 2026-11-16): each value's digits must appear in a
  number of the OCR text, as the rules parser normalises it (`0.5` matches `0,50`; `21`
  matches `218`, an OCR misreading of `21g`). A value that isn't in the text rejects the
  whole reading. Zero for "traces" (marked approximate) is exempt. The model returns
  amounts as printed with their unit; mg → g (÷ 1000) is done in code, never by the model.
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

# Health advice (T38)

Daily needs and the daily amounts that personal advice compares products with (T39, T40).
Every number below comes from these sources; the shared cases are in
[`scoring-spec/needs/`](../../scoring-spec/needs/README.md).

## Sources

| File | Document | Publisher / date | Role | In git |
|---|---|---|---|---|
| `efsa-drv-energy-2013.pdf` | Scientific Opinion on Dietary Reference Values for energy, EFSA Journal 2013;11(1):3005 | EFSA NDA Panel, 2013 | **Primary for energy.** Henry (2005) equations (Appendix 2, p. 72), reference bodies (Table 4, p. 32), PAL values and lifestyles (§5.3.1.2 and Table 5, pp. 34–35), AR for adults (Table 12, p. 46) | no |
| `efsa-drv-summary-2017.pdf` | Summary of Dietary Reference Values, version 4 | EFSA, September 2017 | Same ARs (Table 1, p. 2); total fat reference intake range 20–35 % of energy, saturates "as low as possible" (Table 3, p. 4) | no |
| `eu-1169-2011.pdf` | Regulation (EU) No 1169/2011 on food information to consumers | Official Journal L 304, 22.11.2011 | Reference intakes for an average adult (Annex XIII Part B, p. L 304/61); energy conversion factors (Annex XIV, p. L 304/62) | yes |
| `who-sugars-guideline-2015.pdf` | Guideline: Sugars intake for adults and children | WHO, 2015 | Free sugars < 10 % of energy, strong recommendation (PDF p. 12, printed p. 4); definition of free sugars | no |
| `who-sodium-guideline-2012.pdf` | Guideline: Sodium intake for adults and children | WHO, 2012 (reprinted 2014) | Sodium < 2 g/day (5 g/day salt) for adults, strong recommendation (PDF p. 10) | no |
| `who-sfa-tfa-guideline-2023.pdf` | Saturated fatty acid and trans-fatty acid intake for adults and children: WHO guideline | WHO, 2023 | Saturated fat reduced to 10 % of energy, strong recommendation 1; "less than 10 %" is only conditional, recommendation 2 (PDF p. 11, printed p. ix) | yes |
| `who-trs-894.pdf` | Obesity: preventing and managing the global epidemic, Technical Report Series 894 | WHO, 2000 | BMI classification of adults (Table 2.1, PDF p. 21) | no |

Downloaded on 2026-11-19 from:

- EFSA opinion: <https://www.efsa.europa.eu/en/efsajournal/pub/3005> (PDF via
  <https://efsa.onlinelibrary.wiley.com/doi/pdf/10.2903/j.efsa.2013.3005>)
- EFSA summary: <https://www.efsa.europa.eu/sites/default/files/assets/DRV_Summary_tables_jan_17.pdf>
- Regulation 1169/2011: <https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX:32011R1169>
- WHO sugars: <https://www.who.int/publications/i/item/9789241549028>
- WHO sodium: <https://www.who.int/publications/i/item/9789241504836>
- WHO saturated and trans fats: <https://www.who.int/publications/i/item/9789240073630>
- WHO TRS 894: <https://iris.who.int/handle/10665/42330>

**Not in git.** The WHO sugars and sodium guidelines and TRS 894 say "All rights reserved",
and the reuse terms of the two EFSA files were not confirmed, so these five stay in this
folder locally (git-ignored). Download them from the links above and compare:

| File | SHA-256 |
|---|---|
| `efsa-drv-energy-2013.pdf` | `afa3a3d08747fde155fb3eb296683730cb7eb6d3139c6d85af2865208cc6e14a` |
| `efsa-drv-summary-2017.pdf` | `0786be9b090eb97eb87c9f1c4388d3cde4371da528246553b4631e9bee1a59bc` |
| `who-sugars-guideline-2015.pdf` | `0e81d49cffe12469c184a9d377c9ff80fa26f1f08d66b42fed40f1054b67b209` |
| `who-sodium-guideline-2012.pdf` | `1f42c807c29ae255b31554afafaed683d5598414a1e5cc2a4b89190c72e2f369` |
| `who-trs-894.pdf` | `265f1fe7a9607f71d13001d573fc418e58b3309485330b84ae0b397ace78c114` |

The EFSA opinion's copy carries the publisher's download stamp on every page; another
download has a different stamp and checksum but the same content. In git: Regulation
1169/2011 (EU legal texts may be reused) and the 2023 WHO guideline (CC BY-NC-SA 3.0 IGO:
attribution, non-commercial, share-alike).

## Where each rule lives

**Daily energy (personal).** Resting energy expenditure (REE) from the Henry (2005)
equations with body mass and height, as EFSA used them (Table 12, footnote a), times the
physical activity level (PAL):

| Sex | Age (years) | Henry equation (EFSA Appendix 2, p. 72) | REE in MJ/day |
|---|---|---|---|
| Male | 18–29 | 18–30 y | 0.0600 × BM + 1.31 × HT + 0.473 |
| Male | 30–59 | 30–60 y | 0.0476 × BM + 2.26 × HT − 0.574 |
| Male | 60–79 | ≥ 60 y | 0.0478 × BM + 2.26 × HT − 1.07 |
| Female | 18–29 | 18–30 y | 0.0433 × BM + 2.57 × HT − 1.18 |
| Female | 30–59 | 30–60 y | 0.0342 × BM + 2.10 × HT − 0.0486 |
| Female | 60–79 | ≥ 60 y | 0.0356 × BM + 1.76 × HT + 0.0448 |

BM = body mass in kg, HT = height in metres. Henry's age bands overlap at 30 and 60; EFSA
uses the 18–30 equation for 18–29 years, 30–60 for 30–59, and ≥ 60 for 60–79 (Table 12,
footnote a). Energy (kJ/day) = REE × PAL × 1000.

PAL values and EFSA's lifestyles (§5.3.1.2, p. 35): **1.4** low active (sedentary),
**1.6** moderately active, **1.8** active, **2.0** very active. EFSA also names "highly
active" (> 2.0) without a value; Qout offers the four values only. Table 5 (p. 35) gives
example lifestyles for the wording in the app (e.g. office work without exercise: 1.5).

Check: with Table 4's reference bodies the equations reproduce all 48 ARs of Table 12
within 62 kJ (`scoring-spec/needs/efsa-table-12.json`, tolerance 100 kJ).

**Daily amounts for advice.**

| Amount | With a personal energy E (kJ) | Source | Without a personal energy | Source |
|---|---|---|---|---|
| Energy | E | EFSA, above | 8400 kJ | Annex XIII Part B |
| Fat | 0.35 × E / 37 g (upper end of 20–35 % of energy; 37 kJ per g of fat) | EFSA summary Table 3; Annex XIV | 70 g | Annex XIII Part B |
| Saturates | 0.10 × E / 37 g (10 % of energy) | WHO SFA 2023, rec. 1; Annex XIV | 20 g | Annex XIII Part B |
| Sugars | 90 g | Annex XIII Part B (decision H5) | 90 g | Annex XIII Part B |
| Salt | 5 g | WHO sodium 2012 | 6 g | Annex XIII Part B |

**BMI** = body mass (kg) / height (m)², classified with WHO TRS 894 Table 2.1: underweight
< 18.5; normal range 18.5–24.99; pre-obese 25–29.99; obese class I 30–34.99, class II
35–39.99, class III ≥ 40. WHO notes that BMI may not reflect the same fatness in every
population (table footnote a).

## Decisions (H1–H7)

Decided 2026-11-19 with the T38 plan:

- **H1. Adults only; personal energy for 18–79 years.** The profile accepts ages 18 and
  over. EFSA gives no adult values from 80 years (summary Table 1, footnote b), so from 80 the
  EU reference intakes are used (basis `reference`), with a note in the app.
- **H2. Sex.** The equations are sex-specific: male, female, or not given; not given uses
  the EU reference intakes.
- **H3. No pregnancy or breastfeeding in v1.** EFSA gives energy additions (Table 15), but
  advice for pregnancy goes beyond energy; the app says so instead of computing.
- **H4. Body mass as entered; rounding.** Energy is computed for the body mass the user
  enters (the energy needed to keep the current weight), not for a BMI of 22 as in EFSA's
  population tables: no weight-loss or weight-gain targets (no sourced rule for them).
  Arithmetic in exact decimals; energy rounded to whole kJ, then fat and saturates computed
  from that rounded energy and rounded to whole grams, halves rounded up. The app shows kcal
  with Qout's existing display rule (kJ / 4.184); EFSA's footnote uses 1 MJ = 238.83 kcal
  (the international table calorie), a difference below 0.1 %.
- **H5. Sugars: the EU reference intake, not the WHO limit.** WHO's < 10 % applies to *free*
  sugars; labels and Open Food Facts declare *total* sugars (including those naturally in
  milk and fruit), which cannot be split. Advice compares total sugars with Annex XIII's 90 g
  and may quote WHO's free-sugar recommendation as explanation only, never as a number
  applied to a label.
- **H6. BMI display.** Classified on the exact value (the table's 18.50–24.99 band read as
  18.5 ≤ BMI < 25, and so on); shown rounded **down** to 0.1 so the number shown always lies in
  its own category (18.475 is shown 18.4, underweight). Shown on the profile only, in neutral
  wording, not used for advice in v1. No health conditions (diabetes, blood pressure) in v1:
  that would be medical advice.
- **H7. Input checks.** Age 18–120 whole years, height 100–250 cm, body mass 30–300 kg, PAL
  one of 1.4/1.6/1.8/2.0. These only catch typing errors; they are not nutrition values.

# Allergens and servings (T40)

## Sources

| File | Document | Publisher / date | Role |
|---|---|---|---|
| `eu-1169-2011.pdf` | Regulation (EU) No 1169/2011 | Official Journal L 304, 22.11.2011 | The 14 substances or products causing allergies or intolerances (Annex II, p. L 304/43) |
| `off-allergens-taxonomy-7fbee09.txt` | Allergens taxonomy (`taxonomies/allergens.txt`) | Open Food Facts, `openfoodfacts-server` commit `7fbee09` | The canonical tags Open Food Facts uses in `allergens_tags` and `traces_tags` |

Downloaded from
<https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/7fbee094fb9d89e98c49ab4b2102c7b48b1a7a05/taxonomies/allergens.txt>.
© Open Food Facts contributors (same licence note as the additives taxonomy above).

## Allergen tags

Open Food Facts lists what a product contains (`allergens_tags`) and what it may contain
(`traces_tags`, "may contain traces of"). Qout keeps only the 14 allergens of Annex II, under
the keys the app's profile uses:

| Annex II | Open Food Facts tag (taxonomy line) | Key |
|---|---|---|
| 1. Cereals containing gluten | `en:gluten` (l. 48) | `gluten` |
| 2. Crustaceans | `en:crustaceans` (l. 86) | `crustaceans` |
| 3. Eggs | `en:eggs` (l. 117) | `eggs` |
| 4. Fish | `en:fish` (l. 154) | `fish` |
| 5. Peanuts | `en:peanuts` (l. 227) | `peanuts` |
| 6. Soybeans | `en:soybeans` (l. 263) | `soybeans` |
| 7. Milk | `en:milk` (l. 299) | `milk` |
| 8. Nuts | `en:nuts` (l. 335) | `nuts` |
| 9. Celery | `en:celery` (l. 372) | `celery` |
| 10. Mustard | `en:mustard` (l. 409) | `mustard` |
| 11. Sesame seeds | `en:sesame-seeds` (l. 445) | `sesame` |
| 12. Sulphur dioxide and sulphites | `en:sulphur-dioxide-and-sulphites` (l. 487) | `sulphites` |
| 13. Lupin | `en:lupin` (l. 520) | `lupin` |
| 14. Molluscs | `en:molluscs` (l. 553) | `molluscs` |

Decisions (2026-11-19, T40):

1. **Other tags are dropped:** allergens outside Annex II (kiwi, banana, gelatin…) and
   untranslated tags (`fr:avoine`). The lists are stored in Annex II order, without
   duplicates.
2. **Empty is not "none".** An empty list means Open Food Facts lists none, which may only
   mean nobody entered them: the app says so and asks to check the label. `null` means the
   fields were not imported yet (products stored before T40, until the backfill).

## Serving

From `serving_quantity` (a number), `serving_quantity_unit` (`g` or `ml`) and `serving_size`
(the label's words, e.g. "1 portion (13.8 g)"). Decision (2026-11-19, T40): a serving is used
for shares only when its unit matches the nutrition basis (g with per 100 g, mL with per
100 mL) and its amount is above 0 and at most 1000; otherwise the app uses 100 g or 100 mL.
The 1000 limit only catches bad data; it is not a nutrition value. Contributed products have
no serving.

# Advice texts (T40)

The "For you" section on the product screen shows only these sentences, chosen by the rules
below; nothing is generated. `{…}` are filled in by the app.

| Id | Shown when | Text | Source |
|---|---|---|---|
| `allergen_contains` | one of the user's allergens is in the product's allergens | Contains {allergen}, which you listed as an allergy. | Open Food Facts `allergens_tags`; Annex II |
| `allergen_may_contain` | one of the user's allergens is in the product's traces (and not in its allergens) | May contain traces of {allergen}, which you listed as an allergy. | Open Food Facts `traces_tags`; Annex II |
| `allergens_none_listed` | the user listed allergies and the product's allergen list is empty | Open Food Facts lists no allergens for this product. Check the label. | Decision 2 above |
| `additive_avoided` | the product has an additive the user chose to avoid | Contains {code} {name}, which you chose to avoid. | The user's own list |
| `additive_high_risk` | an additive's EFSA flag is high | {code} {name}: EFSA found a high risk that some people take in more than the acceptable daily intake. | Additive risk flag (T10) |
| `additive_moderate_risk` | an additive's EFSA flag is moderate | {code} {name}: EFSA found a moderate risk that some people take in more than the acceptable daily intake. | Additive risk flag (T10) |
| `shares_personal` | heading of the shares, with a personal energy | {portion} gives this share of your daily needs: | Health advice, daily amounts |
| `shares_reference` | heading of the shares, without one | {portion} gives this share of the reference intake for an average adult: | Annex XIII Part B |
| `no_nutrition` | no nutrition values | No nutrition values yet, so shares can't be shown. | — |
| `set_up_profile` | no profile | Set up your profile to compare with your own needs. | — |
| `not_medical_advice` | always, last | General information, not medical advice. | — |

**Shares.** For energy, fat, saturates, sugars and salt: the amount per 100 g or 100 mL ×
portion / 100, divided by the daily amount (section "Health advice"), as a whole percent
rounded half up; a share above 0 that rounds to 0 is shown "< 1 %". A nutrient that is not
declared is left out. `{portion}` is "1 serving ({amount} g)" or "1 serving ({amount} mL)"
when the serving is used, else "100 g" or "100 mL"; the label's own words (`serving_size`)
are shown under it when present.

No "high in" or "low in" verdicts: they need official thresholds that are not pinned here.
