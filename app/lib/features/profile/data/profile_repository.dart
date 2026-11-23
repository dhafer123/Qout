import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/features/profile/data/profile_photo_store.dart';
import 'package:qout/features/profile/domain/profile_form.dart'
    show normalizeFirstName;
import 'package:qout/health/needs.dart';
import 'package:qout/health/profile.dart';

/// The user's profile and whether onboarding is finished, on the phone only
/// (never sent to the backend).
class ProfileRepository {
  ProfileRepository({
    required ProfileDao dao,
    ProfilePhotoStore? photos,
    DateTime Function()? clock,
  }) : _dao = dao,
       _photos = photos ?? FolderProfilePhotoStore.documents(),
       _clock = clock ?? DateTime.now;

  final ProfileDao _dao;
  final ProfilePhotoStore _photos;
  final DateTime Function() _clock;

  /// Whether the welcome screens were finished (skipped or not).
  Future<bool> onboardingCompleted() async => (await _dao.get()) != null;

  /// The first screen at app start: the profile is required (T31e), so
  /// home only once one is saved.
  Future<StartScreen> startScreen() async {
    final row = await _dao.get();
    if (row == null) return StartScreen.welcome;
    return _profile(row) == null ? StartScreen.profileForm : StartScreen.home;
  }

  Future<void> completeOnboarding() => _dao.completeOnboarding(_clock());

  /// The profile as it is now (the age grows with time), null when there is
  /// none or it can't be read.
  Stream<Profile?> watch() => _dao.watch().map(_profile);

  Future<Profile?> get() async => _profile(await _dao.get());

  /// Saves [profile]; its age counts from now.
  Future<void> save(Profile profile) {
    final now = _clock();
    return _dao.saveProfile(
      sex: profile.sex?.value,
      age: profile.age,
      ageEnteredAt: now,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      pal: profile.activity.value,
      allergens: jsonEncode([
        for (final allergen in Allergen.values)
          if (profile.allergens.contains(allergen)) allergen.key,
      ]),
      now: now,
    );
  }

  /// Deletes everything personal, the photo included; the welcome screens
  /// don't come back.
  Future<void> delete() async {
    final photo = (await _dao.get())?.photoFile;
    await _dao.clearProfile();
    if (photo != null) await _photos.remove(photo);
  }

  /// The profile photo (T43c), live; null when none is set or its file is
  /// gone.
  Stream<File?> watchPhoto() => _dao
      .watch()
      .map((row) => row?.photoFile)
      .distinct()
      .asyncMap((name) async => name == null ? null : _photos.find(name));

  /// Keeps a copy of the photo at [path] as the profile photo, replacing
  /// (and deleting) any previous one.
  Future<void> setPhoto(String path) async {
    final previous = (await _dao.get())?.photoFile;
    final name = await _photos.add(path);
    try {
      await _dao.savePhotoFile(name, now: _clock());
    } on Object {
      await _photos.remove(name);
      rethrow;
    }
    if (previous != null) await _photos.remove(previous);
  }

  /// Removes the profile photo; the initial shows again.
  Future<void> removePhoto() async {
    final previous = (await _dao.get())?.photoFile;
    if (previous == null) return;
    await _dao.savePhotoFile(null, now: _clock());
    await _photos.remove(previous);
  }

  /// The first name for the greeting (T41), live; null when not given.
  Stream<String?> watchFirstName() => _dao.watch().map((row) => row?.firstName);

  /// Saves the first name as typed ([normalizeFirstName]; empty: none).
  Future<void> saveFirstName(String text) =>
      _dao.saveFirstName(normalizeFirstName(text), now: _clock());

  /// The additive codes the user chose to avoid (T40), live.
  Stream<Set<String>> watchAvoidedAdditives() =>
      _dao.watch().map((row) => _codes(row?.avoidedAdditives));

  /// Adds [code] to the additives to avoid, or removes it.
  Future<void> setAvoided(String code, {required bool avoid}) async {
    final codes = _codes((await _dao.get())?.avoidedAdditives);
    if (avoid) {
      codes.add(code);
    } else {
      codes.remove(code);
    }
    await _dao.saveAvoidedAdditives(
      jsonEncode(codes.toList()..sort()),
      now: _clock(),
    );
  }

  static Set<String> _codes(String? json) {
    if (json == null) return {};
    try {
      return {
        for (final code in jsonDecode(json) as List<Object?>)
          if (code is String) code,
      };
    } on Object {
      return {}; // damaged: as if none
    }
  }

  Profile? _profile(LocalProfileRow? row) {
    if (row == null) return null;
    final (age, enteredAt, height, weight, pal) = (
      row.age,
      row.ageEnteredAt,
      row.heightCm,
      row.weightKg,
      row.pal,
    );
    if (age == null ||
        enteredAt == null ||
        height == null ||
        weight == null ||
        pal == null) {
      return null;
    }
    try {
      return Profile(
        sex: Sex.parse(row.sex),
        age: ageNow(ageWhenEntered: age, enteredAt: enteredAt, now: _clock()),
        heightCm: height,
        weightKg: weight,
        activity: ActivityLevel.parse(pal),
        allergens: {
          for (final key in (jsonDecode(row.allergens) as List<Object?>))
            if (key is String) ?Allergen.fromKey(key),
        },
      );
    } on Object {
      // A damaged row (or an age grown past the checks): as if none.
      return null;
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    dao: ref.watch(appDatabaseProvider).profileDao,
    photos: ref.watch(profilePhotoStoreProvider),
  ),
);

/// Where the app opens.
enum StartScreen {
  /// First run: the welcome pages, then the profile form.
  welcome,

  /// The welcome pages were seen but no profile is saved (skipped before
  /// it was required, or deleted): the form straight away.
  profileForm,

  home,
}

/// The first screen, decided when the app started: read in `main()` before
/// the first frame, so the first screen is right at once.
final startScreenProvider = Provider<StartScreen>(
  (ref) => throw UnimplementedError('read in main() and overridden'),
);

/// The profile, live.
final profileProvider = StreamProvider<Profile?>(
  (ref) => ref.watch(profileRepositoryProvider).watch(),
);

/// The first name for the greeting, live (T41).
final firstNameProvider = StreamProvider<String?>(
  (ref) => ref.watch(profileRepositoryProvider).watchFirstName(),
);

/// The profile photo, live (T43c).
final profilePhotoProvider = StreamProvider<File?>(
  (ref) => ref.watch(profileRepositoryProvider).watchPhoto(),
);

/// The additive codes to avoid, live.
final avoidedAdditivesProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(profileRepositoryProvider).watchAvoidedAdditives(),
);

/// The daily needs for the profile (the EU reference intakes without one).
final dailyNeedsProvider = Provider<AsyncValue<DailyNeeds>>(
  (ref) => ref.watch(profileProvider).whenData(computeNeeds),
);
