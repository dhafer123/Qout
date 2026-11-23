import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/health/profile.dart';

import '../../../helpers/fake_profile_photo_store.dart';

class _MockProfileDao extends Mock implements ProfileDao {}

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2026)));

  late AppDatabase database;
  late DateTime now;
  late ProfileRepository repository;
  late FakeProfilePhotoStore photos;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 19, 12);
    photos = FakeProfilePhotoStore();
    repository = ProfileRepository(
      dao: database.profileDao,
      photos: photos,
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

  group('additives to avoid', () {
    test('added and removed, kept sorted, even without a profile', () async {
      await repository.setAvoided('E450', avoid: true);
      await repository.setAvoided('E330', avoid: true);
      await repository.setAvoided('E330', avoid: true); // once
      expect(
        (await database.profileDao.get())!.avoidedAdditives,
        '["E330","E450"]',
      );
      expect(await repository.onboardingCompleted(), isTrue);
      expect(await repository.get(), isNull);

      await repository.setAvoided('E450', avoid: false);
      expect(await repository.watchAvoidedAdditives().first, {'E330'});
    });

    test('saving the profile keeps them; deleting it clears them', () async {
      await repository.setAvoided('E250', avoid: true);
      await repository.save(profile);
      expect(await repository.watchAvoidedAdditives().first, {'E250'});
      await repository.delete();
      expect(await repository.watchAvoidedAdditives().first, isEmpty);
    });

    test('none before onboarding; a damaged list reads as none', () async {
      expect(await repository.watchAvoidedAdditives().first, isEmpty);
      await repository.completeOnboarding();
      await database
          .update(database.localProfile)
          .write(const LocalProfileCompanion(avoidedAdditives: Value('E330')));
      expect(await repository.watchAvoidedAdditives().first, isEmpty);
      await repository.setAvoided('E330', avoid: true); // starts over
      expect(await repository.watchAvoidedAdditives().first, {'E330'});
    });
  });

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

  group('photo', () {
    test('none at first', () async {
      expect(await repository.watchPhoto().first, isNull);
    });

    test('set: kept and shown, finishing onboarding if needed', () async {
      await repository.setPhoto('/tmp/picked.jpg');
      expect(photos.files, {'photo-1.jpg': '/tmp/picked.jpg'});
      expect(
        (await repository.watchPhoto().first)!.path,
        endsWith('photo-1.jpg'),
      );
      expect(await repository.onboardingCompleted(), isTrue);
    });

    test('replacing deletes the previous file', () async {
      await repository.setPhoto('/tmp/a.jpg');
      await repository.setPhoto('/tmp/b.jpg');
      expect(photos.files.keys, ['photo-2.jpg']);
      expect(
        (await repository.watchPhoto().first)!.path,
        endsWith('photo-2.jpg'),
      );
    });

    test('remove: the file and the name go', () async {
      await repository.setPhoto('/tmp/a.jpg');
      await repository.removePhoto();
      expect(photos.files, isEmpty);
      expect(await repository.watchPhoto().first, isNull);
      // Nothing to remove: fine.
      await repository.removePhoto();
    });

    test('a file gone missing reads as no photo', () async {
      await repository.setPhoto('/tmp/a.jpg');
      photos.files.clear();
      expect(await repository.watchPhoto().first, isNull);
    });

    test('deleting the profile deletes the photo', () async {
      await repository.save(profile);
      await repository.setPhoto('/tmp/a.jpg');
      await repository.delete();
      expect(photos.files, isEmpty);
      expect(await repository.watchPhoto().first, isNull);
    });

    test('a failed save removes the copy, keeps the previous photo', () async {
      final dao = _MockProfileDao();
      when(dao.get).thenAnswer(
        (_) async => LocalProfileRow(
          id: 1,
          onboardingCompletedAt: now,
          allergens: '[]',
          avoidedAdditives: '[]',
          photoFile: 'photo-0.jpg',
        ),
      );
      when(
        () => dao.savePhotoFile(any(), now: any(named: 'now')),
      ).thenThrow(StateError('disk full'));
      photos.files['photo-0.jpg'] = '/tmp/old.jpg';

      await expectLater(
        ProfileRepository(dao: dao, photos: photos).setPhoto('/tmp/new.jpg'),
        throwsStateError,
      );
      expect(photos.files.keys, ['photo-0.jpg']);
    });
  });
}
