import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/api/qout_api.dart' show ProductDetail;
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/features/product/domain/product_facts.dart';
import 'package:qout/features/product/domain/score_explanation.dart';
import 'package:qout/health/advice.dart' show Nutrient, PortionUnit;
import 'package:qout/health/diary.dart';
import 'package:qout/health/energy.dart';

/// The food diary on the phone (T42). Entries keep a copy of the product's
/// label, so the diary works offline and doesn't change when the product is
/// updated later.
class DiaryRepository {
  DiaryRepository({required DiaryDao dao, DateTime Function()? clock})
    : _dao = dao,
      _clock = clock ?? DateTime.now;

  final DiaryDao _dao;
  final DateTime Function() _clock;

  /// The entries of the day [day] falls on (local), as they change.
  Stream<List<DiaryEntry>> watchDay(DateTime day) {
    final start = dayOf(day);
    return watchBetween(
      start,
      DateTime(start.year, start.month, start.day + 1),
    );
  }

  /// The entries with [from] <= eaten < [to], as they change.
  Stream<List<DiaryEntry>> watchBetween(DateTime from, DateTime to) =>
      _dao.watchBetween(from, to).map((rows) => rows.map(_entry).toList());

  /// Logs [amount] (g or mL, the label's basis) of [product] for [meal] on
  /// [day] (today by default).
  Future<void> logProduct(
    ProductDetail product, {
    required double amount,
    required Meal meal,
    DateTime? day,
  }) => _dao.add(
    _companion(
      diaryEntryOf(
        product,
        amount: amount,
        meal: meal,
        eatenAt: eatenAtFor(day, _clock()),
      ),
    ),
  );

  /// Logs food without a barcode: only its energy counts.
  Future<void> quickAdd({
    required double kcal,
    required Meal meal,
    String? name,
    DateTime? day,
  }) => _dao.add(
    _companion(
      quickAddEntry(
        kcal: kcal,
        meal: meal,
        name: name,
        eatenAt: eatenAtFor(day, _clock()),
      ),
    ),
  );

  /// Saves a changed day, meal or amount.
  Future<void> change(DiaryEntry entry) => _dao.change(
    entry.id,
    eatenAt: entry.eatenAt,
    meal: _mealOut(entry.meal),
    amount: entry.amount,
  );

  Future<void> remove(DiaryEntry entry) => _dao.remove(entry.id);

  /// Puts back an entry removed by mistake (Undo).
  Future<void> restore(DiaryEntry entry) => _dao.restore(_row(entry));

  /// Deletes the whole diary.
  Future<void> clear() => _dao.clear();

  static DiaryMeal _mealOut(Meal meal) => DiaryMeal.values[meal.index];

  static DiaryEntry _entry(DiaryRow row) => DiaryEntry(
    id: row.id,
    eatenAt: row.eatenAt,
    meal: Meal.values[row.meal.index],
    ean: row.ean,
    name: row.name,
    brand: row.brand,
    imageUrl: row.imageUrl,
    grade: row.grade,
    novaGroup: row.novaGroup,
    unit: switch (row.unit) {
      'g' => PortionUnit.gram,
      'ml' => PortionUnit.millilitre,
      _ => null,
    },
    amount: row.amount,
    servingQuantity: row.servingQuantity,
    values: {
      Nutrient.energy: ?row.energyKj,
      Nutrient.fat: ?row.fatG,
      Nutrient.saturates: ?row.saturatesG,
      Nutrient.sugars: ?row.sugarsG,
      Nutrient.salt: ?row.saltG,
    },
  );

  static DiaryEntriesCompanion _companion(DiaryEntry entry) =>
      _row(entry).toCompanion(true).copyWith(id: const Value.absent());

  static DiaryRow _row(DiaryEntry entry) => DiaryRow(
    id: entry.id,
    eatenAt: entry.eatenAt.toUtc(),
    meal: _mealOut(entry.meal),
    ean: entry.ean,
    name: entry.name,
    brand: entry.brand,
    imageUrl: entry.imageUrl,
    grade: entry.grade,
    novaGroup: entry.novaGroup,
    unit: switch (entry.unit) {
      PortionUnit.gram => 'g',
      PortionUnit.millilitre => 'ml',
      null => null,
    },
    amount: entry.amount,
    servingQuantity: entry.servingQuantity,
    energyKj: entry.values[Nutrient.energy],
    fatG: entry.values[Nutrient.fat],
    saturatesG: entry.values[Nutrient.saturates],
    sugarsG: entry.values[Nutrient.sugars],
    saltG: entry.values[Nutrient.salt],
  );
}

/// [day] at [now]'s time of day (or [now] when [day] is null), in UTC: the
/// moment an entry logged now for [day] counts for.
DateTime eatenAtFor(DateTime? day, DateTime now) {
  if (day == null) return now.toUtc();
  final d = dayOf(day);
  final local = now.toLocal();
  return DateTime(
    d.year,
    d.month,
    d.day,
    local.hour,
    local.minute,
    local.second,
  ).toUtc();
}

/// The diary entry for [amount] of [product]: a copy of its label (values
/// per 100 g or 100 mL, serving, grade, NOVA group) as it is now.
DiaryEntry diaryEntryOf(
  ProductDetail product, {
  required double amount,
  required Meal meal,
  required DateTime eatenAt,
  int id = 0,
}) {
  final facts = productFacts(product);
  final grade = explainScore(product).displayGrade?.value;
  return DiaryEntry(
    id: id,
    eatenAt: eatenAt,
    meal: meal,
    ean: product.ean,
    name: product.name,
    brand: product.brand,
    imageUrl: product.imageUrl,
    grade: grade == null || grade.isEmpty ? null : grade,
    novaGroup: product.novaGroup,
    unit: facts.basis ?? PortionUnit.gram,
    amount: amount,
    servingQuantity: facts.servingUnit == facts.basis
        ? facts.servingQuantity
        : null,
    values: facts.per100,
  );
}

/// A quick add: only the energy of [kcal] (stored in kJ).
DiaryEntry quickAddEntry({
  required double kcal,
  required Meal meal,
  required DateTime eatenAt,
  String? name,
  int id = 0,
}) => DiaryEntry(
  id: id,
  eatenAt: eatenAt,
  meal: meal,
  name: name,
  values: {Nutrient.energy: kcal * kjPerKcalForDisplay},
);

final Provider<DiaryRepository> diaryRepositoryProvider =
    Provider<DiaryRepository>(
      (ref) => DiaryRepository(dao: ref.watch(appDatabaseProvider).diaryDao),
    );

/// The entries of one day (local midnight), live.
final AutoDisposeStreamProviderFamily<List<DiaryEntry>, DateTime>
diaryDayProvider = StreamProvider.autoDispose
    .family<List<DiaryEntry>, DateTime>(
      (ref, day) => ref.watch(diaryRepositoryProvider).watchDay(day),
    );
