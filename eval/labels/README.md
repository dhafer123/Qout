# Label evaluation set

Real Tunisian nutrition labels, used to measure the label parser
(`backend/app/modules/contributions/label_parser.py`, T26) on what ML Kit really reads on a
phone. The parser's unit tests use hand-written OCR text (`backend/tests/fixtures/labels/`);
this set checks those assumptions against reality.

For each label `<id>` (`tn-001`, `tn-002`, ...):

| File | Content |
|---|---|
| `<id>.txt` | OCR text exactly as ML Kit returned it (`RecognizedText.text`, the same text the app sends to `POST /v1/labels/parse`). Never edited. |
| `<id>.jpg` | Own photos only: the photo, reduced (longest side 1600 px), so the ground truth can be checked. |
| `<id>.json` | Ground truth: what the label prints, read from the photo by a person. |

Labels come from two sources (`source` in the JSON, and a table in the report):

- `own`: photographed for this set with the app (below).
- `open-food-facts`: photos of Tunisian products taken by Open Food Facts contributors
  (© Open Food Facts contributors, CC BY-SA 3.0). The photos are **not** in git: each label
  links to its photo (`photo_url`) and product (`ean`).

## Open Food Facts photos

From `backend/`, download the nutrition photos of products made in Tunisia (barcode 619…),
most scanned first, at most 2 per brand, full size, waters skipped:

```sh
uv run python -m scripts.fetch_off_labels --count 60   # into backend/var/off-labels/ (git-ignored)
```

`manifest.json` there lists each product with OFF's own values (contributor-typed: useful to
cross-check, but the photo is the truth). Push the inbox to the phone (the dev build is
debuggable, so `run-as` can write the app's folder), from the repo root in Git Bash:

```sh
export MSYS_NO_PATHCONV=1
D=/sdcard/Android/data/tn.qout.app.dev/files/label-eval
adb push backend/var/off-labels/inbox/. /data/local/tmp/qout-inbox/
adb shell chmod -R a+rX /data/local/tmp/qout-inbox
adb shell run-as tn.qout.app.dev sh -c "'mkdir -p $D/inbox && cp /data/local/tmp/qout-inbox/* $D/inbox/'"
adb shell rm -r /data/local/tmp/qout-inbox
```

In **Label OCR (dev)**, tap **Read inbox**: each photo is reduced to 1600 px like a camera
photo, read by ML Kit and saved as `<id>.txt` + `<id>.json` (product, brand, EAN, source
and photo URL filled in), then removed from the inbox. Pull as below.

## Capturing

1. Run the dev flavor on a phone (`flutter run --flavor dev` from `app/`). In the home
   menu, open **Label OCR** (dev builds only).
2. Photograph the nutrition table the way a user would: phone straight, table filling the
   frame, no glare. Take each label once; don't retake for a better OCR result.
3. The screen shows the text and saves `<id>.txt`, `<id>.jpg` and a `<id>.json` template in
   the app's folder. Numbering continues from the last saved label.
4. Copy them to the PC, from the repo root:

   ```sh
   adb pull /sdcard/Android/data/tn.qout.app.dev/files/label-eval/. eval/labels/
   ```

   In Git Bash, run `export MSYS_NO_PATHCONV=1` first: otherwise Git Bash turns the phone
   path into a Windows path. Skip the `inbox/` folder if one comes along.

Aim for variety: product categories (biscuits, dairy, cheese, drinks, oils, canned food,
snacks, spreads) and layouts (plain table, per 100 g + per portion columns, inline text,
French + Arabic, Arabic only, curved bottles, small print, per portion only). No people or
other private things in the photos.

## Ground truth (`<id>.json`)

```json
{
  "reviewed": true,
  "product": "Gaufrettes chocolat",
  "brand": "Marque",
  "ean": "6191234567890",
  "languages": ["fr", "ar"],
  "layout": ["columns", "bilingual"],
  "basis": "per_100g",
  "values": {
    "energy_kj": "1958",
    "energy_kcal": "467",
    "total_fat_g": "18",
    "saturated_fat_g": "8.2",
    "carbohydrates_g": "68",
    "sugars_g": "29",
    "fibre_g": "2.1",
    "protein_g": "6.5",
    "salt_g": "0.62"
  },
  "approximate": [],
  "notes": null
}
```

- `reviewed`: `false` in the template; set `true` once the values are checked against the
  photo. Labels not reviewed are left out of the report (and listed). Every committed label
  must be reviewed (a backend test checks it).
- `values`: **only what the label prints in its per-100 g or per-100 mL column**, as
  strings, decimal point, as written (`"0.62"`, `"1.0"`). Fields: `energy_kj`,
  `energy_kcal`, `total_fat_g`, `saturated_fat_g`, `carbohydrates_g`, `sugars_g`,
  `fibre_g`, `protein_g`, `salt_g`, `sodium_g`.
  - Not printed: leave the field out. Don't compute salt from sodium or kJ from kcal; the
    parser derives those itself and they are not counted against it.
  - Sodium in mg: convert to grams (`320 mg` → `"0.32"`).
  - `< 0.5` → `"0.5"` and the field in `approximate`; `traces` → `"0"` and the field in
    `approximate`.
- `basis`: `per_100g` or `per_100ml`; `null` when the label has no per-100 column (per
  portion only), then `values` is empty: the parser should refuse it.
- `languages`: two-letter codes of the languages on the table (`fr`, `ar`, `en`, ...).
  ML Kit on the phone reads Latin script only, so Arabic text comes out empty or garbled;
  that is recorded as it is.
- `layout`: free lower-case tags for the report's breakdown. Use these when they apply:
  `inline` (values in running text), `columns` (per 100 + per portion), `bilingual`,
  `curved`, `glare`, `small-print`, `per-portion-only`.
- `source`: `own` (default) or `open-food-facts`; an Open Food Facts label needs its
  `photo_url` (https, openfoodfacts.org) and `ean`.
- `product`, `brand`, `ean`, `notes`: optional, for people reading the report.

## Running the evaluation

From `backend/`:

```sh
uv run python -m scripts.eval_parser    # writes docs/reports/label-parser-eval-rules-<date>.md
```

The report gives field accuracy (printed fields read correctly), precision, labels fully
correct, the parser's `ok` against the ground truth (ok but wrong is the costly case: the
LLM fallback of T28 only runs when `ok` is false), per-field and per-tag breakdowns, and
every label not fully correct with expected and read values.
