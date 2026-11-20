import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/diary/data/diary_repository.dart';
import 'package:qout/health/advice.dart' show Nutrient, PortionUnit;
import 'package:qout/health/diary.dart';

import '../../../helpers/fixtures.dart';

void main() {
  late AppDatabase database;
  late DiaryRepository repository;
  final now = DateTime(2026, 11, 20, 13, 5);
  final today = DateTime(2026, 11, 20);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DiaryRepository(dao: database.diaryDao, clock: () => now);
  });

  tearDown(() => database.close());

  Future<List<DiaryEntry>> day(DateTime d) => repository.watchDay(d).first;

  test('a product keeps a copy of its label and the amount eaten', () async {
    final product = recordedProduct('product-serving-allergens');
    await repository.logProduct(product, amount: 21.7, meal: Meal.snack);

    final entry = (await day(today)).single;
    expect(entry.ean, '6194002510064');
    expect(entry.name, product.name);
    expect(entry.meal, Meal.snack);
    expect(entry.unit, PortionUnit.gram);
    expect(entry.amount, 21.7);
    expect(entry.servingQuantity, 21.7);
    expect(entry.values[Nutrient.energy], 1980);
    expect(entry.values[Nutrient.sugars], 23);
    expect(entry.eaten[Nutrient.energy], closeTo(1980 * 0.217, 1e-9));
    expect(entry.eatenAt.toLocal(), now);
  });

  test('the grade and NOVA group as they were', () async {
    await repository.logProduct(
      recordedProduct('product-general-graded'),
      amount: 30,
      meal: Meal.lunch,
    );
    final entry = (await day(today)).single;
    expect(entry.grade, 'E');
    expect(entry.servingQuantity, isNull); // the label gives none
  });

  test('a quick add: its kcal stored as kJ, nothing else', () async {
    await repository.quickAdd(kcal: 200, meal: Meal.dinner, name: 'Couscous');
    final entry = (await day(today)).single;
    expect(entry.isQuickAdd, isTrue);
    expect(entry.name, 'Couscous');
    expect(entry.values.keys, [Nutrient.energy]);
    expect(entry.values[Nutrient.energy], closeTo(836.8, 1e-9));
  });

  test('logged for another day: counted on that day only', () async {
    final yesterday = DateTime(2026, 11, 19);
    await repository.quickAdd(kcal: 100, meal: Meal.snack, day: yesterday);
    expect(await day(today), isEmpty);
    final entry = (await day(yesterday)).single;
    expect(entry.eatenAt.toLocal(), DateTime(2026, 11, 19, 13, 5));
  });

  test('a day runs from local midnight to the next', () async {
    await repository.quickAdd(
      kcal: 1,
      meal: Meal.breakfast,
      day: DateTime(2026, 11, 21),
    );
    expect(await day(today), isEmpty);
    expect(await day(DateTime(2026, 11, 21, 23, 59)), hasLength(1));
  });

  test('change, remove and restore', () async {
    await repository.logProduct(
      recordedProduct('product-water'),
      amount: 250,
      meal: Meal.lunch,
    );
    final entry = (await day(today)).single;

    await repository.change(entry.copyWith(amount: 500, meal: Meal.dinner));
    final changed = (await day(today)).single;
    expect((changed.amount, changed.meal), (500.0, Meal.dinner));

    await repository.remove(changed);
    expect(await day(today), isEmpty);

    await repository.restore(changed);
    expect((await day(today)).single, changed);
  });

  test('clear deletes the whole diary', () async {
    await repository.quickAdd(kcal: 100, meal: Meal.snack);
    await repository.quickAdd(
      kcal: 100,
      meal: Meal.snack,
      day: DateTime(2026, 11, 2),
    );
    await repository.clear();
    expect(
      await repository.watchBetween(DateTime(2026), DateTime(2027)).first,
      isEmpty,
    );
  });

  test('eatenAtFor: the day chosen, at the current time', () {
    expect(eatenAtFor(null, now), now.toUtc());
    expect(
      eatenAtFor(DateTime(2026, 11, 18, 2), now).toLocal(),
      DateTime(2026, 11, 18, 13, 5),
    );
  });
}
