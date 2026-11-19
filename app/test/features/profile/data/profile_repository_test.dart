import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/health/profile.dart';

void main() {
  late AppDatabase database;
  late DateTime now;
  late ProfileRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 19, 12);
    repository = ProfileRepository(
      dao: database.profileDao,
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  final profile = Profile(
    sex: Sex.female,
    age: 34,
    heightCm: 165.5,
    weightKg: 61.2,
    activity: ActivityLevel.active,
    allergens: const {Allergen.sesame, Allergen.milk},
  );

  test('a new phone: onboarding not finished, no profile', () async {
    expect(await repository.onboardingCompleted(), isFalse);
    expect(await repository.get(), isNull);
  });

  test('skipping finishes onboarding without a profile', () async {
    await repository.completeOnboarding();
    expect(await repository.onboardingCompleted(), isTrue);
    expect(await repository.get(), isNull);
    // Finishing again keeps the first time.
    final first = (await database.profileDao.get())!.onboardingCompletedAt;
    now = now.add(const Duration(days: 1));
    await repository.completeOnboarding();
    expect((await database.profileDao.get())!.onboardingCompletedAt, first);
  });

  test('saving finishes onboarding and reads back the same profile', () async {
    await repository.save(profile);
    expect(await repository.onboardingCompleted(), isTrue);
    expect(await repository.get(), profile);

    final row = (await database.profileDao.get())!;
    expect(row.sex, 'female');
    expect(row.pal, '1.8');
    expect(row.allergens, '["milk","sesame"]'); // Annex II order
    expect(row.ageEnteredAt, now);
  });

  test('sex not given is kept as not given', () async {
    final unsaid = Profile(
      sex: null,
      age: 40,
      heightCm: 170,
      weightKg: 70,
      activity: ActivityLevel.lowActive,
    );
    await repository.save(unsaid);
    expect((await repository.get())!.sex, isNull);
  });

  test('the age grows with time', () async {
    await repository.save(profile);
    now = DateTime.utc(2027, 11, 18, 12);
    expect((await repository.get())!.age, 34);
    now = DateTime.utc(2027, 11, 19, 12);
    expect((await repository.get())!.age, 35);
  });

  test('watch follows saves and deletes', () async {
    final seen = <Profile?>[];
    final subscription = repository.watch().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    await repository.save(profile);
    await pumpEventQueue();
    await repository.delete();
    await pumpEventQueue();
    expect(seen, [null, profile, null]);
  });

  test(
    'deleting keeps onboarding finished and clears everything personal',
    () async {
      await repository.save(profile);
      await repository.delete();
      expect(await repository.onboardingCompleted(), isTrue);
      expect(await repository.get(), isNull);
      final row = (await database.profileDao.get())!;
      expect(
        (row.sex, row.age, row.heightCm, row.weightKg, row.pal, row.allergens),
        (null, null, null, null, null, '[]'),
      );
      expect(row.avoidedAdditives, '[]');
    },
  );

  group('a damaged row reads as no profile', () {
    Future<void> damage(LocalProfileCompanion change) async {
      await repository.save(profile);
      await database.update(database.localProfile).write(change);
    }

    test('unknown activity level', () async {
      await damage(const LocalProfileCompanion(pal: Value('3.0')));
      expect(await repository.get(), isNull);
    });

    test('allergens not a JSON list', () async {
      await damage(const LocalProfileCompanion(allergens: Value('milk')));
      expect(await repository.get(), isNull);
    });

    test('a field missing', () async {
      await damage(const LocalProfileCompanion(weightKg: Value(null)));
      expect(await repository.get(), isNull);
    });

    test('unknown allergen keys are dropped, the rest kept', () async {
      await damage(
        const LocalProfileCompanion(allergens: Value('["milk", "kiwi", 3]')),
      );
      expect((await repository.get())!.allergens, {Allergen.milk});
    });
  });
}
