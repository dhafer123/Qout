"""Rule-based nutrition label parser (T26): OCR text -> values per 100 g or 100 mL.

The text comes from ML Kit on the phone: one line per text line, in reading order, but a
table is often returned column by column (all nutrient names, then all values). Labels are
French, English or Arabic (Tunisian labels are often bilingual). Pure functions only.

Steps:

1. Normalise: lower case, accents and Arabic diacritics dropped, Arabic-Indic digits and
   the Arabic decimal comma read as digits, OCR lookalikes inside numbers fixed (`1O,5` ->
   `10,5`, `l`/`i` -> `1`), thousands separators in energies joined (`1 520 kJ`).
2. Header lines (`pour 100 g`, `par portion (30 g)`, `%AR`) give the columns' order and the
   basis (g or mL). The per-100 column is always the one read; a table declared per
   portion only is refused, not converted.
3. Nutrient lines are found by keywords; the numbers after a keyword (up to the next one)
   are its values. Names without values are matched in order with lines of values without
   names (column by column reading).
4. Missing salt is derived from sodium (x 2.5) and missing kJ from kcal (x 4.2), the
   documented factors (docs/specs/README.md).
5. Sanity checks (docs/specs/README.md, "Label parser energy check"): amounts ≤ 100 g,
   sugars ≤ carbohydrate, saturates ≤ fat, sum of macros ≤ 102 g, kJ consistent with kcal,
   energy consistent with the macros (Annex XIV factors, ±15 % or 20 kcal).

`LabelParse.ok` is False when a mandatory value is missing or a check fails: then the
fallback parser (T28) is tried, and the contributor reviews every value anyway.
"""

import re
import unicodedata
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation
from enum import StrEnum

from app.modules.contributions.models import ParserUsed
from app.modules.contributions.schemas import LabelIssueRead, LabelReading, LabelValues
from app.modules.ingestion.off_normaliser import ENERGY_SLACK_KJ, KJ_PER_KCAL_RANGE
from app.modules.products.models import NutritionBasis
from app.modules.scoring.conversions import KJ_PER_KCAL, SALT_PER_SODIUM


class LabelField(StrEnum):
    """What the parser reads. Carbohydrate, kcal and sodium are not stored on products but
    are needed for the checks (and shown to the contributor)."""

    ENERGY_KJ = "energy_kj"
    ENERGY_KCAL = "energy_kcal"
    FAT = "total_fat_g"
    SATURATED_FAT = "saturated_fat_g"
    CARBOHYDRATES = "carbohydrates_g"
    SUGARS = "sugars_g"
    FIBRE = "fibre_g"
    PROTEIN = "protein_g"
    SALT = "salt_g"
    SODIUM = "sodium_g"


GRAM_FIELDS = (
    LabelField.FAT,
    LabelField.SATURATED_FAT,
    LabelField.CARBOHYDRATES,
    LabelField.SUGARS,
    LabelField.FIBRE,
    LabelField.PROTEIN,
    LabelField.SALT,
    LabelField.SODIUM,
)


class LabelIssueCode(StrEnum):
    NO_NUTRITION_TABLE = "no_nutrition_table"
    MISSING = "missing"
    PER_PORTION_ONLY = "per_portion_only"
    BASIS_UNKNOWN = "basis_unknown"
    COLUMN_UNCERTAIN = "column_uncertain"
    ENERGY_UNIT_UNKNOWN = "energy_unit_unknown"
    AMOUNT_OVER_100 = "amount_over_100"
    SUGARS_OVER_CARBOHYDRATES = "sugars_over_carbohydrates"
    SATURATED_OVER_FAT = "saturated_over_fat"
    MACROS_OVER_100 = "macros_over_100"
    ENERGY_UNITS_MISMATCH = "energy_units_mismatch"
    ENERGY_MACROS_MISMATCH = "energy_macros_mismatch"


_WARNINGS = frozenset({LabelIssueCode.BASIS_UNKNOWN})
"""Worth telling the contributor, but the values are fine."""


@dataclass(frozen=True)
class LabelIssue:
    code: LabelIssueCode
    field: LabelField | None = None

    @property
    def blocking(self) -> bool:
        return self.code not in _WARNINGS


@dataclass(frozen=True)
class LabelParse:
    values: dict[LabelField, Decimal]
    """Read or derived, per 100 g / 100 mL."""
    basis: NutritionBasis | None
    derived: frozenset[LabelField] = frozenset()
    """Computed from another value (salt from sodium, kJ from kcal)."""
    approximate: frozenset[LabelField] = frozenset()
    """Written as "< x" (read as x) or "traces" (read as 0)."""
    issues: tuple[LabelIssue, ...] = ()

    @property
    def ok(self) -> bool:
        return not any(issue.blocking for issue in self.issues)


# ---------------------------------------------------------------- constants

MANDATORY = (  # Regulation (EU) 1169/2011, Article 30(1)
    LabelField.FAT,
    LabelField.SATURATED_FAT,
    LabelField.CARBOHYDRATES,
    LabelField.SUGARS,
    LabelField.PROTEIN,
    LabelField.SALT,
)
_HUNDRED = Decimal(100)
_MACROS_LIMIT = Decimal(102)  # 100 g plus 2 g for rounding (docs/specs/README.md)
_ENERGY_TOLERANCE = Decimal("0.15")
_ENERGY_SLACK_KCAL = Decimal(20)
_KCAL_FACTORS = {  # Regulation (EU) 1169/2011, Annex XIV
    LabelField.CARBOHYDRATES: Decimal(4),
    LabelField.PROTEIN: Decimal(4),
    LabelField.FAT: Decimal(9),
    LabelField.FIBRE: Decimal(2),
}
_KJ_FACTORS = {
    LabelField.CARBOHYDRATES: Decimal(17),
    LabelField.PROTEIN: Decimal(17),
    LabelField.FAT: Decimal(37),
    LabelField.FIBRE: Decimal(8),
}
_MACRO_SUM = (
    LabelField.FAT,
    LabelField.CARBOHYDRATES,
    LabelField.PROTEIN,
    LabelField.FIBRE,
    LabelField.SALT,
)


class _Nutrient(StrEnum):
    """What a keyword names (energy gives both kJ and kcal)."""

    ENERGY = "energy"
    FAT = "fat"
    SATURATED_FAT = "saturated_fat"
    CARBOHYDRATES = "carbohydrates"
    SUGARS = "sugars"
    FIBRE = "fibre"
    PROTEIN = "protein"
    SALT = "salt"
    SODIUM = "sodium"


_GRAM_FIELD = {
    _Nutrient.FAT: LabelField.FAT,
    _Nutrient.SATURATED_FAT: LabelField.SATURATED_FAT,
    _Nutrient.CARBOHYDRATES: LabelField.CARBOHYDRATES,
    _Nutrient.SUGARS: LabelField.SUGARS,
    _Nutrient.FIBRE: LabelField.FIBRE,
    _Nutrient.PROTEIN: LabelField.PROTEIN,
    _Nutrient.SALT: LabelField.SALT,
    _Nutrient.SODIUM: LabelField.SODIUM,
}

_AR = "(?:ال)?"  # Arabic definite article
# Most specific first: an earlier keyword's match wins where two overlap.
_KEYWORDS: tuple[tuple[_Nutrient, re.Pattern[str]], ...] = tuple(
    (nutrient, re.compile(pattern))
    for nutrient, pattern in (
        (
            _Nutrient.SATURATED_FAT,
            rf"acides? gras satures?|\bsatures?\b|\bsaturate[sd]?(?: fat)?\b|{_AR}دهون {_AR}مشبعة"
            rf"|{_AR}مشبعة",
        ),
        (_Nutrient.SUGARS, rf"\bsucres?\b|\bsugars?\b|{_AR}سكريات|{_AR}سكر\b"),
        (_Nutrient.CARBOHYDRATES, rf"\bglucides\b|\bcarbohydrates?\b|{_AR}كربوهيدرات|{_AR}نشويات"),
        (
            _Nutrient.FAT,
            rf"matieres? grasses|\bgraisses\b|\blipides\b|\bfats?\b|{_AR}دهون|{_AR}دسم",
        ),
        (_Nutrient.FIBRE, rf"\bfib(?:re|er)s?(?: alimentaires)?\b|{_AR}الياف"),
        (_Nutrient.PROTEIN, rf"\bproteines?\b|\bproteins?\b|{_AR}بروتين(?:ات)?"),
        (_Nutrient.SODIUM, rf"\bsodium\b|{_AR}صوديوم"),
        (_Nutrient.SALT, rf"\bsel\b|\bsalt\b|{_AR}ملح"),
        (
            _Nutrient.ENERGY,
            rf"valeur energetique|\benerg(?:ie|y|etique)\b|{_AR}طاقة|{_AR}سعرات(?: حرارية)?",
        ),
    )
)

_PER_100 = re.compile(r"\b100\s*(?P<unit>grammes?|gr|g|ml|غرام|غ|مل)(?![a-zء-ي])")
_PORTION = re.compile(r"\bportion\b|\bserving\b|\bpar part\b|حصة|للحصة")
_PERCENT_COLUMN = re.compile(
    r"%\s*(?:ar|vnr|ri|rda|dv|ajr)\b|\b(?:ar|vnr|ri|ajr)\b\s*\*?|apports? de reference"
    r"|reference intake"
)
_TRACES = re.compile(r"\btraces?\b|اثار")

# Numbers: OCR lookalikes (o -> 0, i/l -> 1) are fixed only inside tokens that already
# hold a digit (or `o,5`), never inside words.
_NOISY_NUMBER = re.compile(
    r"(?<![a-zء-ي])(?=[0-9oil]*[0-9]|[oil][.,][0-9])[0-9oil]+(?:[.,][0-9oil]+)?"
)
_LOOKALIKES = str.maketrans({"o": "0", "i": "1", "l": "1"})
_THOUSANDS = re.compile(r"\b(\d{1,2})[ .](\d{3})(?=\s*(?:kj|kcal)(?![a-z]))")
_VALUE = re.compile(
    r"(?P<bound><|≤|moins de|less than|اقل من)?\s*"
    r"(?P<number>\d+(?:[.,]\d+)?)\s*"
    r"(?P<unit>mg|g|gr|kj|kcal|ml|%|ملغ|مغ|غ|كيلو ?جول|كيلو ?كالوري)?(?![a-z])"
)
_UNITS = {
    "gr": "g",
    "غ": "g",
    "ملغ": "mg",
    "مغ": "mg",
    "كيلوجول": "kj",
    "كيلو جول": "kj",
    "كيلوكالوري": "kcal",
    "كيلو كالوري": "kcal",
}
_ENERGY_UNIT_MENTION = re.compile(r"\bkj\b|\bkcal\b")
_DIGITS = str.maketrans(
    {
        **{chr(0x0660 + i): str(i) for i in range(10)},  # Arabic-Indic
        **{chr(0x06F0 + i): str(i) for i in range(10)},  # Extended Arabic-Indic
        chr(0x066B): ",",  # Arabic decimal separator
        chr(0x066C): "",  # Arabic thousands separator
        chr(0x0640): "",  # tatweel
        chr(0x0649): chr(0x064A),  # alef maksura -> yeh
    }
)


# ---------------------------------------------------------------- text


def normalize(text: str) -> str:
    """Lower case without accents or Arabic diacritics, digits and number noise fixed."""
    decomposed = unicodedata.normalize("NFKD", text.translate(_DIGITS))
    plain = "".join(c for c in decomposed if unicodedata.category(c) != "Mn").lower()
    fixed = _NOISY_NUMBER.sub(lambda m: m.group(0).translate(_LOOKALIKES), plain)
    return _THOUSANDS.sub(r"\1\2", fixed)


@dataclass(frozen=True)
class _Value:
    number: Decimal
    unit: str | None
    bound: bool


def _values(text: str) -> list[_Value]:
    values = []
    for match in _VALUE.finditer(text):
        try:
            number = Decimal(match["number"].replace(",", "."))
        except InvalidOperation:  # pragma: no cover - the pattern only matches numbers
            continue
        unit = match["unit"]
        values.append(
            _Value(number, _UNITS.get(unit, unit) if unit else None, bool(match["bound"]))
        )
    return values


@dataclass(frozen=True)
class _Keyword:
    nutrient: _Nutrient
    start: int
    end: int


def _keywords(line: str) -> list[_Keyword]:
    """Non-overlapping keyword matches, left to right; the same nutrient named twice in a
    row (`Sel / الملح`) counts once."""
    found: list[_Keyword] = []
    for nutrient, pattern in _KEYWORDS:
        for match in pattern.finditer(line):
            if all(match.end() <= k.start or match.start() >= k.end for k in found):
                found.append(_Keyword(nutrient, match.start(), match.end()))
    found.sort(key=lambda k: k.start)
    merged: list[_Keyword] = []
    for keyword in found:
        if merged and merged[-1].nutrient == keyword.nutrient:
            continue
        merged.append(keyword)
    return merged


# ---------------------------------------------------------------- columns


class _Column(StrEnum):
    PER_100 = "per_100"
    PORTION = "portion"
    PERCENT = "percent"


@dataclass
class _Layout:
    columns: list[_Column] = field(default_factory=list)
    basis: NutritionBasis | None = None

    def add_header(self, line: str) -> None:
        found: list[tuple[int, _Column]] = []
        per_100 = _PER_100.search(line)
        if per_100 is not None:
            found.append((per_100.start(), _Column.PER_100))
            if self.basis is None:
                unit = per_100["unit"]
                self.basis = (
                    NutritionBasis.PER_100ML if unit in ("ml", "مل") else NutritionBasis.PER_100G
                )
        found += [(m.start(), _Column.PORTION) for m in _PORTION.finditer(line)][:1]
        found += [(m.start(), _Column.PERCENT) for m in _PERCENT_COLUMN.finditer(line)][:1]
        for _, column in sorted(found):
            if column not in self.columns:
                self.columns.append(column)

    @property
    def per_portion_only(self) -> bool:
        return _Column.PORTION in self.columns and _Column.PER_100 not in self.columns

    @property
    def index(self) -> int:
        """Position of the per-100 value among a row's values (percentages left out)."""
        amounts = [c for c in self.columns if c != _Column.PERCENT]
        return amounts.index(_Column.PER_100) if _Column.PER_100 in amounts else 0


def _is_header(line: str) -> bool:
    return bool(_PER_100.search(line) or _PORTION.search(line) or _PERCENT_COLUMN.search(line))


# ---------------------------------------------------------------- parsing


@dataclass
class _Reading:
    values: dict[LabelField, Decimal] = field(default_factory=dict)
    approximate: set[LabelField] = field(default_factory=set)
    derived: set[LabelField] = field(default_factory=set)
    issues: list[LabelIssue] = field(default_factory=list)

    def set(self, target: LabelField, value: _Value) -> None:
        if target in self.values:
            return  # first occurrence wins (bilingual labels repeat the table)
        number = value.number / 1000 if value.unit == "mg" else value.number
        self.values[target] = number
        if value.bound:
            self.approximate.add(target)

    def issue(self, code: LabelIssueCode, target: LabelField | None = None) -> None:
        if LabelIssue(code, target) not in self.issues:
            self.issues.append(LabelIssue(code, target))


def _pick(values: Sequence[_Value], index: int) -> _Value | None:
    return values[index] if index < len(values) else None


def _read_amount(
    reading: _Reading, nutrient: _Nutrient, segment: str, values: list[_Value], index: int
) -> None:
    target = _GRAM_FIELD[nutrient]
    amounts = [v for v in values if v.unit in (None, "g", "mg")]
    if not amounts:
        if _TRACES.search(segment):
            reading.set(target, _Value(Decimal(0), "g", bound=True))
        return
    value = _pick(amounts, index)
    if value is None:
        reading.issue(LabelIssueCode.COLUMN_UNCERTAIN, target)
        return
    reading.set(target, value)


def _read_energy(reading: _Reading, segment: str, values: list[_Value], index: int) -> None:
    kj = [v for v in values if v.unit == "kj"]
    kcal = [v for v in values if v.unit == "kcal"]
    unitless = [v for v in values if v.unit is None]
    if unitless and not (kj or kcal):
        # `Energie (kJ/kcal) 1520/362`: units named once, before the numbers.
        mentions = _ENERGY_UNIT_MENTION.findall(segment)
        if not mentions:
            reading.issue(LabelIssueCode.ENERGY_UNIT_UNKNOWN, LabelField.ENERGY_KJ)
            return
        for position, value in enumerate(unitless):
            unit = mentions[position % len(mentions)]
            (kj if unit == "kj" else kcal).append(value)
    for unit_values, target in ((kj, LabelField.ENERGY_KJ), (kcal, LabelField.ENERGY_KCAL)):
        if unit_values:
            picked = _pick(unit_values, index)
            if picked is None:
                reading.issue(LabelIssueCode.COLUMN_UNCERTAIN, target)
            else:
                reading.set(target, picked)


def _read(
    reading: _Reading, nutrient: _Nutrient, segment: str, values: list[_Value], index: int
) -> None:
    values = [v for v in values if v.unit != "%"]
    if nutrient == _Nutrient.ENERGY:
        _read_energy(reading, segment, values, index)
    else:
        _read_amount(reading, nutrient, segment, values, index)


def _value_groups(lines: Iterable[str]) -> list[tuple[str, list[_Value]]]:
    """Lines of values without names, as read column by column. A kcal-only line right
    after a kJ-only line is the same energy row; lines of percentages are another column."""
    groups: list[tuple[str, list[_Value]]] = []
    for line in lines:
        values = _values(line)
        if not values or all(v.unit == "%" for v in values):
            continue
        units = {v.unit for v in values}
        if groups and units == {"kcal"} and {v.unit for v in groups[-1][1]} == {"kj"}:
            text, previous = groups[-1]
            groups[-1] = (f"{text} {line}", previous + values)
            continue
        groups.append((line, values))
    return groups


@dataclass
class _Scan:
    """One pass over the lines: columns, values read, and what is left for matching
    column by column."""

    layout: _Layout = field(default_factory=_Layout)
    reading: _Reading = field(default_factory=_Reading)
    pending: list[tuple[_Nutrient, str]] = field(default_factory=list)
    """Names without values, with their label text."""
    orphans: list[str] = field(default_factory=list)
    """Lines of values without names."""
    rows: int = 0

    def line(self, line: str) -> None:
        keywords = _keywords(line)
        if not keywords:
            if _is_header(line):
                self.layout.add_header(line)
            elif _values(line):
                self.orphans.append(line)
            return
        for position, keyword in enumerate(keywords):
            end = keywords[position + 1].start if position + 1 < len(keywords) else len(line)
            self.segment(keyword.nutrient, line[keyword.end : end])

    def segment(self, nutrient: _Nutrient, segment: str) -> None:
        values = _values(segment)
        if not values and not _TRACES.search(segment):
            if not self.pending or self.pending[-1][0] != nutrient:
                self.pending.append((nutrient, segment))
            return
        self.rows += 1
        if not self.layout.per_portion_only:
            _read(self.reading, nutrient, segment, values, self.layout.index)


def parse_label(text: str) -> LabelParse:
    """Read a nutrition table from OCR text. Never raises."""
    scan = _Scan()
    for raw in text.splitlines():
        line = normalize(raw).strip()
        if line:
            scan.line(line)
    layout, reading = scan.layout, scan.reading
    if layout.per_portion_only:
        return LabelParse(
            values={}, basis=None, issues=(LabelIssue(LabelIssueCode.PER_PORTION_ONLY),)
        )
    if scan.pending:
        groups = _value_groups(scan.orphans)
        scan.rows += _match_columns(reading, scan.pending, groups, layout.index)
    if scan.rows == 0 or not (reading.values or reading.issues):
        return LabelParse(
            values={}, basis=None, issues=(LabelIssue(LabelIssueCode.NO_NUTRITION_TABLE),)
        )
    return _finish(reading, layout.basis)


def checked_parse(
    values: Mapping[LabelField, Decimal],
    basis: NutritionBasis | None,
    approximate: Iterable[LabelField] = (),
) -> LabelParse:
    """Values read by another parser (the LLM fallback, T28), given the same derivations
    and sanity checks as the rule-based parser's."""
    reading = _Reading(values=dict(values), approximate=set(approximate) & set(values))
    return _finish(reading, basis)


def _finish(reading: _Reading, basis: NutritionBasis | None) -> LabelParse:
    _derive(reading)
    _check(reading)
    if basis is None:
        reading.issue(LabelIssueCode.BASIS_UNKNOWN)
    return LabelParse(
        values=dict(reading.values),
        basis=basis,
        derived=frozenset(reading.derived),
        approximate=frozenset(reading.approximate),
        issues=tuple(reading.issues),
    )


def _match_columns(
    reading: _Reading,
    pending: list[tuple[_Nutrient, str]],
    groups: list[tuple[str, list[_Value]]],
    index: int,
) -> int:
    """Names read without values, matched in order with lines of values: the per-100
    column is the `index`-th block of `len(names)` lines."""
    names = [(n, label) for n, label in pending if not _already_read(reading, n)]
    if not names or not groups:
        return 0  # names in running text (an ingredients list), not a table
    first = index * len(names)
    if len(groups) < first + len(names):
        for nutrient, _ in names:
            reading.issue(LabelIssueCode.COLUMN_UNCERTAIN, _target(nutrient))
        return 0
    block = groups[first : first + len(names)]
    for (nutrient, label), (text, values) in zip(names, block, strict=True):
        _read(reading, nutrient, f"{label} {text}", values, 0)
    return len(names)


def _target(nutrient: _Nutrient) -> LabelField:
    return LabelField.ENERGY_KJ if nutrient == _Nutrient.ENERGY else _GRAM_FIELD[nutrient]


def _already_read(reading: _Reading, nutrient: _Nutrient) -> bool:
    if nutrient == _Nutrient.ENERGY:
        return LabelField.ENERGY_KJ in reading.values or LabelField.ENERGY_KCAL in reading.values
    return _GRAM_FIELD[nutrient] in reading.values


# ---------------------------------------------------------------- derivations and checks


def _derive(reading: _Reading) -> None:
    values = reading.values
    if LabelField.SALT not in values and LabelField.SODIUM in values:
        values[LabelField.SALT] = values[LabelField.SODIUM] * SALT_PER_SODIUM
        reading.derived.add(LabelField.SALT)
        if LabelField.SODIUM in reading.approximate:
            reading.approximate.add(LabelField.SALT)
    if LabelField.ENERGY_KJ not in values and LabelField.ENERGY_KCAL in values:
        values[LabelField.ENERGY_KJ] = (values[LabelField.ENERGY_KCAL] * KJ_PER_KCAL).quantize(
            Decimal(1), rounding=ROUND_HALF_UP
        )
        reading.derived.add(LabelField.ENERGY_KJ)


def _check(reading: _Reading) -> None:
    values = reading.values
    if LabelField.ENERGY_KJ not in values:
        reading.issue(LabelIssueCode.MISSING, LabelField.ENERGY_KJ)
    for target in MANDATORY:
        if target not in values:
            reading.issue(LabelIssueCode.MISSING, target)
    for target in GRAM_FIELDS:
        if values.get(target, Decimal(0)) > _HUNDRED:
            reading.issue(LabelIssueCode.AMOUNT_OVER_100, target)
    if _greater(values, LabelField.SUGARS, LabelField.CARBOHYDRATES):
        reading.issue(LabelIssueCode.SUGARS_OVER_CARBOHYDRATES, LabelField.SUGARS)
    if _greater(values, LabelField.SATURATED_FAT, LabelField.FAT):
        reading.issue(LabelIssueCode.SATURATED_OVER_FAT, LabelField.SATURATED_FAT)
    if sum((values.get(f, Decimal(0)) for f in _MACRO_SUM), Decimal(0)) > _MACROS_LIMIT:
        reading.issue(LabelIssueCode.MACROS_OVER_100)
    _check_energy(reading)


def _greater(values: dict[LabelField, Decimal], part: LabelField, whole: LabelField) -> bool:
    return part in values and whole in values and values[part] > values[whole]


def _check_energy(reading: _Reading) -> None:
    values = reading.values
    kj, kcal = values.get(LabelField.ENERGY_KJ), values.get(LabelField.ENERGY_KCAL)
    if kj is not None and kcal is not None and LabelField.ENERGY_KJ not in reading.derived:
        low, high = KJ_PER_KCAL_RANGE
        if not low * kcal - ENERGY_SLACK_KJ <= kj <= high * kcal + ENERGY_SLACK_KJ:
            reading.issue(LabelIssueCode.ENERGY_UNITS_MISMATCH, LabelField.ENERGY_KJ)
            return
    if any(f not in values for f in (LabelField.FAT, LabelField.CARBOHYDRATES, LabelField.PROTEIN)):
        return  # reported as missing
    if kcal is not None:
        declared, factors, slack, target = (
            kcal,
            _KCAL_FACTORS,
            _ENERGY_SLACK_KCAL,
            LabelField.ENERGY_KCAL,
        )
    elif kj is not None:
        declared, factors, target = kj, _KJ_FACTORS, LabelField.ENERGY_KJ
        slack = _ENERGY_SLACK_KCAL * KJ_PER_KCAL
    else:
        return
    expected = sum(
        (factor * values.get(macro, Decimal(0)) for macro, factor in factors.items()), Decimal(0)
    )
    if abs(declared - expected) > max(_ENERGY_TOLERANCE * declared, slack):
        reading.issue(LabelIssueCode.ENERGY_MACROS_MISMATCH, target)


# ---------------------------------------------------------------- API result


def label_reading(parse: LabelParse, parser_used: ParserUsed = ParserUsed.RULES) -> LabelReading:
    return LabelReading(
        parser_used=parser_used,
        ok=parse.ok,
        basis=parse.basis,
        values=LabelValues(**{f.value: float(v) for f, v in parse.values.items()}),
        derived=sorted(parse.derived),
        approximate=sorted(parse.approximate),
        issues=[
            LabelIssueRead(
                code=issue.code.value,
                field=None if issue.field is None else issue.field.value,
                blocking=issue.blocking,
            )
            for issue in parse.issues
        ],
    )
