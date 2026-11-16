# Label parser evaluation: `rules`

Generated 2026-11-16 from `eval/labels/` (56 labels of products made in Tunisia, photos by Open Food Facts contributors): 56 labels, OCR text from ML Kit on the phone, ground truth read from the photos by hand. Values are compared as exact decimals with what the label prints per 100 g or 100 mL.

## Summary

| | Result |
|---|---:|
| Labels | 56 |
| **Field accuracy** (printed fields read correctly) | **34 / 393 (8.7 %)** |
| Field precision (values returned that are correct) | 34 / 190 (17.9 %) |
| Labels fully correct | 3 / 56 (5.4 %) |
| Basis correct | 38 / 56 (67.9 %) |
| Approximate marks correct | 48 / 56 (85.7 %) |
| **Parser ok but not fully correct** | **0** |

## Parser `ok` against the ground truth

`ok` False sends the label to the fallback parser (T28) and flags it to the contributor. Ok but not fully correct: wrong values that nothing catches.

| | Fully correct | Not fully correct |
|---|---:|---:|
| Parser ok | 0 | **0** |
| Parser not ok | 3 | 53 |

## By field

| Field | Printed | Correct | Wrong | Missed | Spurious | Accuracy |
|---|---:|---:|---:|---:|---:|---:|
| energy_kj | 44 | 5 | 3 | 36 | 0 | 11.4 % |
| energy_kcal | 49 | 7 | 1 | 41 | 0 | 14.3 % |
| total_fat_g | 52 | 6 | 24 | 22 | 0 | 11.5 % |
| saturated_fat_g | 37 | 1 | 21 | 15 | 2 | 2.7 % |
| carbohydrates_g | 52 | 2 | 21 | 29 | 2 | 3.8 % |
| sugars_g | 34 | 2 | 19 | 13 | 0 | 5.9 % |
| fibre_g | 29 | 3 | 14 | 12 | 2 | 10.3 % |
| protein_g | 52 | 3 | 21 | 28 | 2 | 5.8 % |
| salt_g | 22 | 4 | 11 | 7 | 0 | 18.2 % |
| sodium_g | 22 | 1 | 10 | 11 | 3 | 4.5 % |

## By language

A label can have several language tags.

| Language | Labels | Fully correct | Field accuracy |
|---|---:|---:|---:|
| ar | 45 | 2 / 45 (4.4 %) | 5.4 % |
| de | 1 | 0 / 1 (0.0 %) | 22.2 % |
| en | 37 | 2 / 37 (5.4 %) | 11.9 % |
| fr | 46 | 1 / 46 (2.2 %) | 10.3 % |
| nl | 2 | 0 / 2 (0.0 %) | 0.0 % |
| pt | 1 | 0 / 1 (0.0 %) | 0.0 % |

## By layout

A label can have several layout tags.

| Layout | Labels | Fully correct | Field accuracy |
|---|---:|---:|---:|
| arabic-only | 2 | 1 / 2 (50.0 %) | 0.0 % |
| bilingual | 42 | 1 / 42 (2.4 %) | 5.7 % |
| blur | 5 | 0 / 5 (0.0 %) | 0.0 % |
| columns | 9 | 0 / 9 (0.0 %) | 1.4 % |
| cropped | 2 | 0 / 2 (0.0 %) | 18.2 % |
| curved | 7 | 0 / 7 (0.0 %) | 3.9 % |
| glare | 7 | 0 / 7 (0.0 %) | 18.5 % |
| horizontal | 2 | 0 / 2 (0.0 %) | 11.1 % |
| inline | 1 | 0 / 1 (0.0 %) | 33.3 % |
| no-basis-in-photo | 1 | 0 / 1 (0.0 %) | 0.0 % |
| per-portion-only | 4 | 2 / 4 (50.0 %) | - |
| small-print | 4 | 0 / 4 (0.0 %) | 2.9 % |
| tiles | 4 | 0 / 4 (0.0 %) | 0.0 % |
| two-column | 1 | 0 / 1 (0.0 %) | 12.5 % |
| us-style | 7 | 0 / 7 (0.0 %) | 23.3 % |

## By photo source

`own`: taken for this set with the app. `open-food-facts`: Open Food Facts contributors' photos (© Open Food Facts contributors, CC BY-SA 3.0; each label below links to its photo).

| Source | Labels | Fully correct | Field accuracy |
|---|---:|---:|---:|
| open-food-facts | 56 | 3 / 56 (5.4 %) | 8.7 % |

## Issues reported by the parser

| Issue | Labels |
|---|---:|
| amount_over_100 | 26 |
| basis_unknown | 11 |
| column_uncertain | 3 |
| energy_macros_mismatch | 3 |
| energy_unit_unknown | 11 |
| energy_units_mismatch | 1 |
| macros_over_100 | 24 |
| missing | 42 |
| no_nutrition_table | 6 |
| per_portion_only | 5 |
| saturated_over_fat | 5 |
| sugars_over_carbohydrates | 8 |

## Labels not fully correct

### tn-002: Huile d'olive vierge extra 250 mL · Terra d'Elyssa

Tags: fr, columns, small-print. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), missing (saturated_fat_g), missing (carbohydrates_g), amount_over_100 (total_fat_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/150/990/0701/nutrition_fr.7.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 3449 | - |
| energy_kcal | missed | 824 | - |
| total_fat_g | wrong | 100.0 | 814 |
| saturated_fat_g | missed | 19.10 | - |
| carbohydrates_g | missed | 0.0 | - |
| sugars_g | wrong | 0.0 | 100.0 |
| protein_g | wrong | 0.0 | 19.10 |
| salt_g | wrong | 0.0 | 63.35 |

### tn-007: p'tit Matin · LBM

Tags: fr, en, ar, bilingual, no-basis-in-photo. Parser ok: no. Issues: missing (energy_kj), missing (saturated_fat_g), missing (sugars_g), missing (salt_g), amount_over_100 (carbohydrates_g), amount_over_100 (protein_g), macros_over_100, basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/130/740/0083/nutrition_fr.23.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1898.9 | - |
| energy_kcal | missed | 454.3 | - |
| total_fat_g | wrong | 15.5 | 6.79 |
| carbohydrates_g | wrong | 72 | 1898 |
| protein_g | wrong | 6.7 | 454.3 |

### tn-008: P'tit matin · LBM

Tags: fr, en, pt, ar, bilingual. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), missing (saturated_fat_g), missing (sugars_g), missing (salt_g), amount_over_100 (total_fat_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/130/740/1233/nutrition_fr.15.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1555 | - |
| energy_kcal | missed | 373 | - |
| total_fat_g | wrong | 9.55 | 1555 |
| carbohydrates_g | wrong | 63.98 | 1.79 |
| fibre_g | wrong | 4.23 | 63.98 |
| protein_g | wrong | 7.79 | 9.55 |

### tn-010: UP · Biskart

Tags: ar, fr, en, bilingual. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), amount_over_100 (saturated_fat_g), amount_over_100 (sugars_g), sugars_over_carbohydrates (sugars_g), saturated_over_fat (saturated_fat_g).

Photo: <https://images.openfoodfacts.org/images/products/619/132/760/0012/nutrition_fr.29.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kcal | missed | 410 | - |
| saturated_fat_g | wrong | 5.5 | 10155 |
| sugars_g | wrong | 21 | 218 |
| protein_g | wrong | 6 | 5 |

### tn-012: goldina plus · GIAS

Tags: fr, en, ar, bilingual, blur. Parser ok: no. Issues: missing (energy_kj), missing (carbohydrates_g), missing (sugars_g), missing (protein_g), missing (salt_g).

Photo: <https://images.openfoodfacts.org/images/products/619/140/290/1270/nutrition_fr.41.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 2217 | - |
| energy_kcal | missed | 539 | - |
| total_fat_g | wrong | 59 | 100 |
| saturated_fat_g | wrong | 25 | 100 |
| carbohydrates_g | missed | 1 | - |
| fibre_g | missed | 0 | - |
| protein_g | missed | 1 | - |
| sodium_g | missed | 0.15 | - |

### tn-013: Biscottes multi-cerial · Mama Mia

Tags: fr, en, ar, bilingual. Parser ok: no. Issues: no_nutrition_table.

Photo: <https://images.openfoodfacts.org/images/products/619/142/760/0745/nutrition_fr.19.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1102 | - |
| energy_kcal | missed | 261.93 | - |
| total_fat_g | missed | 8.73 | - |
| carbohydrates_g | missed | 36.79 | - |
| fibre_g | missed | 3.26 | - |
| protein_g | missed | 9.05 | - |
| salt_g | missed | 1.23 | - |

### tn-014: Toast artisanal · Mama mia

Tags: ar, fr, en, bilingual, columns. Parser ok: no. Issues: missing (saturated_fat_g), missing (sugars_g), missing (protein_g).

Photo: <https://images.openfoodfacts.org/images/products/619/142/760/0974/nutrition_fr.25.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | wrong | 899 | 903 |
| total_fat_g | wrong | 7 | 29 |
| carbohydrates_g | wrong | 29 | 0.15 |
| fibre_g | wrong | 3.3 | 2 |
| protein_g | missed | 9 | - |
| salt_g | wrong | 0.15 | 3.3 |

### tn-016: Crème fraîche · Natilait

Tags: fr, ar, bilingual. Parser ok: no. Issues: no_nutrition_table.

Photo: <https://images.openfoodfacts.org/images/products/619/144/250/0358/nutrition_fr.32.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1196 | - |
| energy_kcal | missed | 290 | - |
| total_fat_g | missed | 31 | - |
| carbohydrates_g | missed | 2.8 | - |
| protein_g | missed | 2.4 | - |

### tn-018: Lait demi- écrémé UHT · Vitalait

Tags: fr, ar, bilingual, glare. Parser ok: no. Issues: missing (energy_kj), missing (total_fat_g), missing (carbohydrates_g), missing (sugars_g), missing (salt_g), basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/150/722/0214/nutrition_fr.80.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 181 | - |
| energy_kcal | missed | 43 | - |
| total_fat_g | missed | 1.5 | - |
| saturated_fat_g | wrong | 0.95 | 10 |
| carbohydrates_g | missed | 4.4 | - |
| sugars_g | missed | 4.4 | - |
| protein_g | wrong | 3 | 9 |
| salt_g | missed | 0.15 | - |

### tn-019: Yaourt Fruits Des Bois · Vitalait

Tags: fr, ar, bilingual, curved. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), missing (carbohydrates_g), amount_over_100 (saturated_fat_g), saturated_over_fat (saturated_fat_g), macros_over_100, basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/150/724/9833/nutrition_fr.29.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 385 | - |
| energy_kcal | missed | 91 | - |
| total_fat_g | wrong | 2.6 | 100 |
| saturated_fat_g | wrong | 1.7 | 385 |
| carbohydrates_g | missed | 14 | - |
| sugars_g | wrong | 13.9 | 2.6 |
| protein_g | wrong | 3.1 | 7 |
| salt_g | wrong | 0.11 | 13.9 |

### tn-021: Huile d'olive vierge extra · Terra Delyssa

Tags: en, fr, per-portion-only, bilingual. Parser ok: no. Issues: missing (energy_kj), missing (total_fat_g), missing (sugars_g), amount_over_100 (saturated_fat_g), basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/150/990/3627/nutrition_fr.50.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| saturated_fat_g | spurious | - | 120 |
| carbohydrates_g | spurious | - | 14 |
| fibre_g | spurious | - | 2.67 |
| protein_g | spurious | - | 0 |
| sodium_g | spurious | - | 0 |

### tn-022: Carré president 6 portion · Lactalis

Tags: fr, ar, bilingual. Parser ok: no. Issues: missing (energy_kj), missing (saturated_fat_g), missing (sugars_g), missing (protein_g), missing (salt_g), amount_over_100 (total_fat_g), amount_over_100 (carbohydrates_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/151/350/2014/nutrition_fr.9.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1286.76 | - |
| energy_kcal | missed | 307.06 | - |
| total_fat_g | wrong | 30.26 | 307.06 |
| carbohydrates_g | wrong | 0.18 | 1286 |
| protein_g | missed | 8.5 | - |

### tn-023: Orangina et sa pulpe! · Orangina

Tags: fr, ar, per-portion-only, bilingual. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), missing (total_fat_g), missing (sugars_g), amount_over_100 (carbohydrates_g), amount_over_100 (fibre_g), amount_over_100 (protein_g), amount_over_100 (salt_g), macros_over_100, basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/152/520/0182/nutrition_fr.14.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| saturated_fat_g | spurious | - | 0 |
| carbohydrates_g | spurious | - | 659 |
| fibre_g | spurious | - | 376 |
| protein_g | spurious | - | 155 |
| sodium_g | spurious | - | 72 |

### tn-024: Nectar multivitaminé · Delice

Tags: fr, en, ar, bilingual. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), sugars_over_carbohydrates (sugars_g), saturated_over_fat (saturated_fat_g).

Photo: <https://images.openfoodfacts.org/images/products/619/153/480/2117/nutrition_fr.29.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 216 | - |
| energy_kcal | missed | 51 | - |
| total_fat_g | wrong | 0 | 3 |
| saturated_fat_g | wrong | 0 | 5 |
| carbohydrates_g | wrong | 12.7 | 9 |
| sugars_g | wrong | 12.7 | 10 |
| fibre_g | wrong | 0 | 0.00045 |
| protein_g | wrong | 0 | 0.006 |
| salt_g | wrong | 0 | 0.035 |

### tn-025: Déli'o menthe · Délice

Tags: fr, en, ar, bilingual, curved, glare. Parser ok: no. Issues: missing (energy_kj), missing (sugars_g), missing (protein_g), missing (salt_g), amount_over_100 (total_fat_g), macros_over_100, basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/153/480/2506/nutrition_fr.29.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100ml, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 132.6 | - |
| energy_kcal | missed | 31 | - |
| total_fat_g | wrong | 0 | 6191534 |
| saturated_fat_g | wrong | 0 | 80 |
| carbohydrates_g | wrong | 7.8 | 100 |
| sugars_g | missed | 7.78 | - |
| protein_g | missed | 0 | - |
| salt_g | missed | 0 | - |

### tn-026: Harrisa Du Cap bon · Carthage food

Tags: fr, nl, en, curved. Parser ok: no. Issues: missing (energy_kj), missing (total_fat_g), missing (protein_g), amount_over_100 (carbohydrates_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/153/770/0090/nutrition_fr.36.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 297 | - |
| energy_kcal | missed | 71 | - |
| total_fat_g | missed | 2.2 | - |
| saturated_fat_g | wrong | 0.61 | 22 |
| carbohydrates_g | wrong | 10.88 | 1088 |
| sugars_g | wrong | 5.24 | 21 |
| protein_g | missed | 2.1 | - |
| salt_g | wrong | 1.89 | 61 |

### tn-027: Thon entier à l'huile végétale · BK FOOD

Tags: fr, ar, bilingual. Parser ok: no. Issues: no_nutrition_table.

Photo: <https://images.openfoodfacts.org/images/products/619/157/180/0961/nutrition_fr.17.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 704.17 | - |
| energy_kcal | missed | 168.3 | - |
| total_fat_g | missed | 7.1 | - |
| saturated_fat_g | missed | 1.78 | - |
| carbohydrates_g | missed | 0 | - |
| protein_g | missed | 26.1 | - |
| sodium_g | missed | 0.71 | - |

### tn-028: margarine · Regina

Tags: fr, en, ar, bilingual. Parser ok: no. Issues: missing (energy_kj), missing (saturated_fat_g), missing (carbohydrates_g), missing (sugars_g), missing (protein_g).

Photo: <https://images.openfoodfacts.org/images/products/619/157/460/0100/nutrition_fr.7.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 3138 | - |
| energy_kcal | missed | 750 | - |
| total_fat_g | wrong | 80 | 3 |
| saturated_fat_g | missed | 33.5 | - |
| carbohydrates_g | missed | 0 | - |
| fibre_g | wrong | 0 | 5 |
| protein_g | missed | 0 | - |
| sodium_g | wrong | 0.006 | 6 |

### tn-029: Croquette · TOM

Tags: en, ar, bilingual, columns. Parser ok: no. Issues: missing (energy_kj), missing (saturated_fat_g), missing (carbohydrates_g), amount_over_100 (sugars_g), amount_over_100 (salt_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/400/050/0395/nutrition_fr.9.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1993.18 | - |
| total_fat_g | wrong | 15.76 | 7.274 |
| saturated_fat_g | missed | 7.25 | - |
| carbohydrates_g | missed | 76.00 | - |
| sugars_g | wrong | 47.12 | 1993.1811168 |
| fibre_g | wrong | 8.67 | 76.00 |
| protein_g | wrong | 7.27 | 100 |
| sodium_g | wrong | 0.92939 | 47.12 |

### tn-030: Chocotom · L'Appetissante

Tags: en, ar, bilingual, columns, blur. Parser ok: no. Issues: missing (energy_kj), missing (saturated_fat_g), missing (carbohydrates_g), missing (protein_g), missing (salt_g), amount_over_100 (total_fat_g), amount_over_100 (sugars_g), macros_over_100, basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/400/052/1017/nutrition_fr.46.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1979.28 | - |
| total_fat_g | wrong | 15.25 | 1525 |
| saturated_fat_g | missed | 8.39 | - |
| carbohydrates_g | missed | 77.47 | - |
| sugars_g | wrong | 48.03 | 1018 |
| fibre_g | missed | 7.55 | - |
| protein_g | missed | 5.95 | - |
| sodium_g | missed | 0.44449 | - |

### tn-031: Choco Tom gaufrettes · Tom

Tags: en, ar, bilingual, columns, blur. Parser ok: no. Issues: per_portion_only.

Photo: <https://images.openfoodfacts.org/images/products/619/400/052/1895/nutrition_fr.55.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 2171.5 | - |
| total_fat_g | missed | 28.96 | - |
| saturated_fat_g | missed | 16.07 | - |
| carbohydrates_g | missed | 57.6 | - |
| sugars_g | missed | 37.15 | - |
| fibre_g | missed | 9.45 | - |
| protein_g | missed | 7.12 | - |
| sodium_g | missed | 0.326 | - |

### tn-032: Margarine pasteurisée · jadida

Tags: fr, ar, bilingual, glare. Parser ok: no. Issues: missing (energy_kj), missing (carbohydrates_g), missing (sugars_g), missing (protein_g), amount_over_100 (salt_g), amount_over_100 (sodium_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/400/080/2000/nutrition_ar.50.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 3165 | - |
| energy_kcal | missed | 756 | - |
| total_fat_g | wrong | 80 | 0.1 |
| saturated_fat_g | wrong | 28 | 0 |
| carbohydrates_g | missed | 0.1 | - |
| fibre_g | wrong | 0.1 | 80 |
| protein_g | missed | 0.1 | - |
| sodium_g | wrong | 0.2 | 828 |

### tn-033: Margarine pasteurisée · jadida

Tags: fr, ar, bilingual. Parser ok: no. Issues: missing (energy_kj), missing (carbohydrates_g), missing (sugars_g), missing (protein_g), macros_over_100, basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/400/080/2383/nutrition_fr.48.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 3165 | - |
| energy_kcal | missed | 756 | - |
| total_fat_g | wrong | 80 | 0.1 |
| saturated_fat_g | wrong | 28 | 0.1 |
| carbohydrates_g | missed | 0.1 | - |
| fibre_g | wrong | 0.1 | 80 |
| protein_g | missed | 0.1 | - |
| sodium_g | wrong | 0.2 | 28 |

### tn-034: Harissa du Cap Bon · Neblia

Tags: en, fr, de, curved. Parser ok: no. Issues: sugars_over_carbohydrates (sugars_g), energy_macros_mismatch (energy_kcal).

Photo: <https://images.openfoodfacts.org/images/products/619/400/145/0026/nutrition_fr.24.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| total_fat_g | wrong | 0.5 | 0.2 |
| saturated_fat_g | wrong | 0.1 | 0.12 |
| carbohydrates_g | wrong | 9.6 | 0.0007 |
| sugars_g | wrong | 6.2 | 0.0027 |
| fibre_g | wrong | 3.8 | 0.58 |
| protein_g | wrong | 3.9 | 0.1 |
| salt_g | wrong | 2.18 | 9.6 |

### tn-035: Flocons d´avoine · Gepro's

Tags: en, ar, bilingual, us-style. Parser ok: no. Issues: missing (energy_kj), missing (protein_g), amount_over_100 (total_fat_g), amount_over_100 (saturated_fat_g), amount_over_100 (sugars_g), amount_over_100 (salt_g), amount_over_100 (sodium_g), sugars_over_carbohydrates (sugars_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/400/164/1080/nutrition_fr.5.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kcal | missed | 361 | - |
| total_fat_g | wrong | 7.1 | 2400 |
| saturated_fat_g | wrong | 1.3 | 300 |
| carbohydrates_g | wrong | 59.8 | 25 |
| sugars_g | wrong | 1 | 3500 |
| fibre_g | wrong | 5.6 | 49.05 |
| protein_g | missed | 11.7 | - |
| sodium_g | wrong | 0.008 | 237.62 |

### tn-036: Boissons au jus cocktail · Stil

Tags: fr, ar, bilingual. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), missing (total_fat_g), missing (carbohydrates_g), missing (sugars_g), amount_over_100 (saturated_fat_g).

Photo: <https://images.openfoodfacts.org/images/products/619/400/180/1057/nutrition_fr.30.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 179.24 | - |
| energy_kcal | missed | 42.84 | - |
| total_fat_g | missed | 0.1 | - |
| saturated_fat_g | wrong | 0 | 179.24 |
| carbohydrates_g | missed | 10.6 | - |
| sugars_g | missed | 10.1 | - |
| fibre_g | wrong | 0.18 | 10.59 |
| protein_g | wrong | 0.11 | 25 |
| sodium_g | wrong | 0.00146 | 0.119 |

### tn-037: Fourré · Kif

Tags: fr, ar, en, bilingual, us-style. Parser ok: no. Issues: per_portion_only.

Photo: <https://images.openfoodfacts.org/images/products/619/400/251/0064/nutrition_fr.86.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1980 | - |
| energy_kcal | missed | 473 | - |
| total_fat_g | missed | 23 | - |
| saturated_fat_g | missed | 10.9 | - |
| carbohydrates_g | missed | 58 | - |
| sugars_g | missed | 23 | - |
| fibre_g | missed | 4.0 | - |
| protein_g | missed | 6.4 | - |
| salt_g | missed | 0.31 | - |
| sodium_g | missed | 0.1231 | - |

### tn-038: Binto · Kif

Tags: fr, en, us-style. Parser ok: no. Issues: amount_over_100 (sodium_g), sugars_over_carbohydrates (sugars_g), energy_macros_mismatch (energy_kcal).

Photo: <https://images.openfoodfacts.org/images/products/619/400/251/0071/nutrition_fr.22.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| saturated_fat_g | wrong | 11.8 | 11 |
| carbohydrates_g | wrong | 57 | 25 |
| sugars_g | wrong | 25 | 57 |
| sodium_g | wrong | 0.11376 | 113.76 |

### tn-039: Yaourt saveur Fraise · Danone

Tags: ar, fr, tiles. Parser ok: no. Issues: missing (energy_kj), missing (total_fat_g), missing (saturated_fat_g), missing (carbohydrates_g), missing (sugars_g), missing (salt_g), amount_over_100 (protein_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/400/380/0119/nutrition_fr.20.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 402.3 | - |
| energy_kcal | missed | 96.1 | - |
| total_fat_g | missed | 2.5 | - |
| carbohydrates_g | missed | 15.1 | - |
| protein_g | wrong | 3.3 | 810 |

### tn-040: Le Nature · Danone

Tags: ar, fr, tiles, curved. Parser ok: no. Issues: missing (energy_kj), missing (saturated_fat_g), missing (carbohydrates_g), missing (sugars_g), missing (salt_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/400/380/0317/nutrition_fr.46.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 285 | - |
| energy_kcal | missed | 68 | - |
| total_fat_g | wrong | 3.6 | 3.69 |
| carbohydrates_g | missed | 5.4 | - |
| protein_g | wrong | 3.6 | 100 |

### tn-041: Grain d'or (miel) · Nestlé

Tags: ar, arabic-only, columns. Parser ok: no. Issues: per_portion_only.

Photo: <https://images.openfoodfacts.org/images/products/619/400/529/6484/nutrition_fr.10.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1650 | - |
| energy_kcal | missed | 382 | - |
| total_fat_g | missed | 3.9 | - |
| saturated_fat_g | missed | 1.7 | - |
| carbohydrates_g | missed | 74.5 | - |
| sugars_g | missed | 17.5 | - |
| fibre_g | missed | 4.3 | - |
| protein_g | missed | 12.3 | - |
| sodium_g | missed | 0.18 | - |

### tn-042: Tris · Saïd

Tags: fr, en, ar, bilingual, tiles, blur. Parser ok: no. Issues: no_nutrition_table.

Photo: <https://images.openfoodfacts.org/images/products/619/400/541/2037/nutrition_ar.29.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 2194 | - |
| energy_kcal | missed | 525 | - |
| total_fat_g | missed | 32 | - |
| saturated_fat_g | missed | 17 | - |
| carbohydrates_g | missed | 57 | - |
| sugars_g | missed | 42 | - |
| protein_g | missed | 7.4 | - |
| salt_g | missed | 0.19 | - |

### tn-043: Choco poudre Saïd · Saïd

Tags: ar, fr, en, bilingual. Parser ok: no. Issues: missing (carbohydrates_g), missing (protein_g), amount_over_100 (salt_g), saturated_over_fat (saturated_fat_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/400/542/0049/nutrition_en.13.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | wrong | 1615 | 1609 |
| total_fat_g | wrong | 3 | 0 |
| saturated_fat_g | wrong | 1.9 | 6 |
| carbohydrates_g | missed | 77 | - |
| sugars_g | wrong | 73 | 39 |
| protein_g | missed | 6.4 | - |
| salt_g | wrong | 0.08 | 199 |

### tn-044: Crème à tartiner Noisette Said · Mille Recettes

Tags: fr, en, ar, bilingual, two-column. Parser ok: no. Issues: missing (energy_kj), missing (total_fat_g), amount_over_100 (saturated_fat_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/400/542/0070/nutrition_fr.7.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 2336.62 | - |
| energy_kcal | missed | 559 | - |
| total_fat_g | missed | 36.4 | - |
| saturated_fat_g | wrong | 3.56 | 2336.62 |
| carbohydrates_g | wrong | 52.1 | 51.96 |
| sugars_g | wrong | 51.96 | 4.8 |
| protein_g | wrong | 4.8 | 99 |

### tn-045: Crème à tartiner Noisette Said · Mille Recettes

Tags: fr, en, ar, bilingual, glare. Parser ok: no. Issues: missing (total_fat_g), missing (saturated_fat_g), missing (sugars_g), missing (protein_g), missing (salt_g).

Photo: <https://images.openfoodfacts.org/images/products/619/400/542/0155/nutrition_en.13.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kcal | missed | 559 | - |
| total_fat_g | missed | 36.4 | - |
| carbohydrates_g | wrong | 52.1 | 36.4 |
| protein_g | missed | 4.8 | - |

### tn-046: Sensations - Chocolat Extra Fin Noir · Maestro

Tags: fr, en, ar, bilingual, columns, small-print. Parser ok: no. Issues: missing (energy_kj), amount_over_100 (total_fat_g), amount_over_100 (protein_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/400/544/3031/nutrition_fr.60.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 2392 | - |
| energy_kcal | missed | 575 | - |
| total_fat_g | wrong | 38 | 476 |
| saturated_fat_g | wrong | 23 | 0 |
| carbohydrates_g | wrong | 45 | 10 |
| sugars_g | wrong | 43 | 0 |
| fibre_g | wrong | 7.4 | 38 |
| protein_g | wrong | 4.8 | 2392 |
| salt_g | wrong | 0.08 | 23 |

### tn-047: Dégustation - Chocolat Noir 72% Cacao · Maestro

Tags: ar, fr, en, bilingual, columns. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), missing (total_fat_g), amount_over_100 (saturated_fat_g), amount_over_100 (fibre_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/400/544/6100/nutrition_fr.65.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 2332 | - |
| energy_kcal | missed | 562 | - |
| total_fat_g | missed | 39 | - |
| saturated_fat_g | wrong | 23 | 2332 |
| carbohydrates_g | wrong | 32 | 39 |
| sugars_g | wrong | 28 | 23 |
| fibre_g | wrong | 11 | 139 |
| protein_g | wrong | 8 | 9 |
| salt_g | wrong | 0.08 | 9 |

### tn-048: Boisson au jus De Fruits multivitaminé · Tropico

Tags: en, glare. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), missing (total_fat_g), missing (carbohydrates_g).

Photo: <https://images.openfoodfacts.org/images/products/619/400/788/0018/nutrition_fr.23.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 229.5 | - |
| energy_kcal | missed | 53 | - |
| total_fat_g | missed | 0.05 | - |
| saturated_fat_g | wrong | 0.01 | 0.12 |
| carbohydrates_g | missed | 12 | - |
| sugars_g | wrong | 10.65 | 12 |
| protein_g | wrong | 0.12 | 10.65 |
| sodium_g | wrong | 0.00702 | 0.05 |

### tn-050: Start · saïda

Tags: en, fr, ar, bilingual, us-style, small-print. Parser ok: no. Issues: missing (energy_kj), missing (saturated_fat_g), missing (carbohydrates_g), missing (protein_g), amount_over_100 (salt_g), amount_over_100 (sodium_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/400/851/5520/nutrition_fr.62.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kcal | missed | 483 | - |
| total_fat_g | wrong | 17.3 | 0.075 |
| saturated_fat_g | missed | 7.5 | - |
| carbohydrates_g | missed | 74.2 | - |
| fibre_g | missed | 2.4 | - |
| protein_g | missed | 6.5 | - |
| sodium_g | wrong | 0.156 | 156 |

### tn-052: Prince creme vanille carousel · LU

Tags: fr, nl, columns, blur. Parser ok: no. Issues: no_nutrition_table.

Photo: <https://images.openfoodfacts.org/images/products/619/400/853/3920/nutrition_nl.25.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 2146 | - |
| energy_kcal | missed | 513 | - |
| total_fat_g | missed | 23 | - |
| saturated_fat_g | missed | 12 | - |
| carbohydrates_g | missed | 70 | - |
| sugars_g | missed | 32 | - |
| protein_g | missed | 5.0 | - |
| salt_g | missed | 0.25 | - |

### tn-053: Major ( chocolat ) · Saïda

Tags: en, fr, ar, bilingual, us-style. Parser ok: no. Issues: column_uncertain (total_fat_g), column_uncertain (saturated_fat_g), column_uncertain (sodium_g), column_uncertain (carbohydrates_g), column_uncertain (fibre_g), column_uncertain (sugars_g), missing (energy_kj), missing (carbohydrates_g), missing (sugars_g), missing (protein_g), missing (salt_g).

Photo: <https://images.openfoodfacts.org/images/products/619/400/853/4019/nutrition_fr.56.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kcal | missed | 476.2 | - |
| saturated_fat_g | wrong | 10.7 | 5.6 |
| carbohydrates_g | missed | 69.4 | - |
| sugars_g | missed | 31.1 | - |
| fibre_g | missed | 2.6 | - |
| protein_g | missed | 5.6 | - |
| sodium_g | missed | 0.1381 | - |

### tn-054: Fell 2 sans gluten · Spiga

Tags: fr, ar, bilingual. Parser ok: no. Issues: missing (energy_kj), missing (total_fat_g), missing (saturated_fat_g), missing (sugars_g).

Photo: <https://images.openfoodfacts.org/images/products/619/401/186/2543/nutrition_fr.5.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1510 | - |
| energy_kcal | missed | 356 | - |
| total_fat_g | missed | 1.5 | - |
| carbohydrates_g | wrong | 78.6 | 1.5 |
| sugars_g | missed | 0.55 | - |
| fibre_g | wrong | 1.65 | 78.6 |
| protein_g | wrong | 6.2 | 0.55 |
| salt_g | wrong | 0.01 | 1.65 |

### tn-055: Etoile · Spiga

Tags: en, fr, us-style, glare. Parser ok: no. Issues: missing (energy_kj), basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/401/187/3280/nutrition_fr.7.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kcal | missed | 376 | - |
| carbohydrates_g | wrong | 77.43 | 7 |

### tn-056: Chamia Nature · Le Moulin

Tags: en, fr, ar, bilingual. Parser ok: no. Issues: missing (energy_kj), missing (saturated_fat_g), missing (carbohydrates_g), missing (protein_g), amount_over_100 (salt_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/401/750/3785/nutrition_fr.28.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 2100 | - |
| energy_kcal | missed | 502 | - |
| total_fat_g | wrong | 30.1 | 1 |
| saturated_fat_g | missed | 4.5 | - |
| carbohydrates_g | missed | 45 | - |
| sugars_g | wrong | 39.2 | 100 |
| protein_g | missed | 12.6 | - |
| salt_g | wrong | 0.167 | 210 |

### tn-057: Chewing-gum Florida fourrè · Florida

Tags: en, ar, bilingual. Parser ok: no. Issues: column_uncertain (carbohydrates_g), column_uncertain (total_fat_g), column_uncertain (sugars_g), column_uncertain (protein_g), column_uncertain (sodium_g), missing (energy_kj), missing (total_fat_g), missing (saturated_fat_g), missing (carbohydrates_g), missing (sugars_g), missing (protein_g), missing (salt_g).

Photo: <https://images.openfoodfacts.org/images/products/619/401/750/6113/nutrition_en.9.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1338 | - |
| energy_kcal | missed | 320 | - |
| total_fat_g | missed | 0 | - |
| carbohydrates_g | missed | 80 | - |
| sugars_g | missed | 76 | - |
| protein_g | missed | 0 | - |
| sodium_g | missed | 0 | - |

### tn-059: Boga Lim · Boga

Tags: fr, ar, bilingual, horizontal, tiles. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), missing (saturated_fat_g), amount_over_100 (sugars_g), amount_over_100 (salt_g), amount_over_100 (sodium_g), sugars_over_carbohydrates (sugars_g), macros_over_100, basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/401/960/5241/nutrition_fr.32.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100ml, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 128.07 | - |
| energy_kcal | missed | 30.59 | - |
| total_fat_g | wrong | 0.1 | 19.10 |
| saturated_fat_g | missed | 0.1 | - |
| carbohydrates_g | wrong | 7.64 | 10 |
| sugars_g | wrong | 7.64 | 128.07 |
| fibre_g | missed | 0.1 | - |
| protein_g | wrong | 0.1 | 25 |
| sodium_g | wrong | 0.00329 | 212 |

### tn-060: Boga - pomme cidre · Boga

Tags: fr, ar, bilingual, horizontal. Parser ok: no. Issues: column_uncertain (carbohydrates_g), column_uncertain (sugars_g), column_uncertain (protein_g), column_uncertain (sodium_g), column_uncertain (fibre_g), column_uncertain (saturated_fat_g), missing (total_fat_g), missing (saturated_fat_g), missing (carbohydrates_g), missing (sugars_g), missing (protein_g), missing (salt_g).

Photo: <https://images.openfoodfacts.org/images/products/619/401/960/5258/nutrition_fr.56.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| total_fat_g | missed | 0.1 | - |
| saturated_fat_g | missed | 0.1 | - |
| carbohydrates_g | missed | 7.08 | - |
| sugars_g | missed | 7.08 | - |
| fibre_g | missed | 0.1 | - |
| protein_g | missed | 0.1 | - |
| sodium_g | missed | 0.00369 | - |

### tn-061: Browniz · Moulin d'Or

Tags: fr, ar, en, bilingual, cropped. Parser ok: no. Issues: missing (energy_kj), missing (saturated_fat_g), missing (carbohydrates_g), missing (sugars_g), missing (protein_g), missing (salt_g), basis_unknown.

Photo: <https://images.openfoodfacts.org/images/products/619/402/111/1426/nutrition_fr.33.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 1769 | - |
| energy_kcal | missed | 423 | - |
| carbohydrates_g | missed | 54 | - |
| protein_g | missed | 6 | - |
| sodium_g | missed | 0.2 | - |

### tn-062: Lait demi écrémé UHT · délice

Tags: ar, fr, bilingual. Parser ok: no. Issues: energy_unit_unknown (energy_kj), missing (energy_kj), missing (total_fat_g), missing (saturated_fat_g), missing (sugars_g), missing (salt_g).

Photo: <https://images.openfoodfacts.org/images/products/619/404/300/1668/nutrition_fr.80.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | missed | 183 | - |
| energy_kcal | missed | 43.5 | - |
| total_fat_g | missed | 1.5 | - |
| carbohydrates_g | wrong | 4.5 | 4.59 |
| protein_g | wrong | 3 | 15 |

### tn-063: landor crème emental · landor

Tags: en, ar, bilingual, us-style. Parser ok: no. Issues: per_portion_only.

Photo: <https://images.openfoodfacts.org/images/products/619/404/940/4029/nutrition_fr.13.full.jpg> (Open Food Facts, CC BY-SA 3.0).

Basis: expected per_100g, read none (per portion only).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kcal | missed | 197 | - |
| total_fat_g | missed | 17 | - |
| saturated_fat_g | missed | 9 | - |
| carbohydrates_g | missed | 2 | - |
| sugars_g | missed | 2 | - |
| fibre_g | missed | 0 | - |
| protein_g | missed | 9 | - |
| sodium_g | missed | 0.8 | - |

### tn-064: Double Concentré de Tomates · Sicam

Tags: fr, en, inline, glare. Parser ok: no. Issues: sugars_over_carbohydrates (sugars_g), saturated_over_fat (saturated_fat_g), energy_macros_mismatch (energy_kcal).

Photo: <https://images.openfoodfacts.org/images/products/619/405/550/0135/nutrition_ar.58.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| total_fat_g | wrong | 0.1 | 0.19 |
| saturated_fat_g | wrong | 0.016 | 1 |
| carbohydrates_g | wrong | 29.51 | 0.01 |
| sugars_g | wrong | 25 | 0.05 |
| fibre_g | wrong | 1.4 | 29.5 |
| protein_g | wrong | 4 | 25 |
| sodium_g | spurious | - | 14 |

### tn-065: Harissa du Cap Bon · SICAM

Tags: fr, en, curved, small-print. Parser ok: no. Issues: missing (protein_g), missing (salt_g), amount_over_100 (total_fat_g), amount_over_100 (carbohydrates_g), amount_over_100 (sugars_g), sugars_over_carbohydrates (sugars_g), macros_over_100, energy_units_mismatch (energy_kj).

Photo: <https://images.openfoodfacts.org/images/products/619/405/550/0234/nutrition_fr.62.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kj | wrong | 327.38 | 38 |
| energy_kcal | wrong | 78.18 | 7818 |
| total_fat_g | wrong | 1.35 | 138 |
| saturated_fat_g | wrong | 0.25 | 54 |
| carbohydrates_g | wrong | 12.21 | 460 |
| sugars_g | wrong | 4.73 | 12719 |
| fibre_g | missed | 1.99 | - |
| protein_g | missed | 2.61 | - |
| salt_g | missed | 2.75 | - |

### tn-066: crème à tartiner aux noisettes · Auchan

Tags: fr, en, ar, bilingual, curved, cropped. Parser ok: no. Issues: missing (energy_kj), missing (total_fat_g), missing (saturated_fat_g), missing (sugars_g), missing (salt_g), amount_over_100 (protein_g), macros_over_100.

Photo: <https://images.openfoodfacts.org/images/products/619/900/100/2053/nutrition_fr.7.full.jpg> (Open Food Facts, CC BY-SA 3.0).

| Field | Outcome | Expected | Read |
|---|---|---:|---:|
| energy_kcal | missed | 549.44 | - |
| total_fat_g | missed | 34.52 | - |
| carbohydrates_g | wrong | 56.30 | 3.399 |
| protein_g | wrong | 3.39 | 549.44 |
