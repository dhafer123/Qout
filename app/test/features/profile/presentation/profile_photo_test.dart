import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/photos/label_photo_picker.dart' show PhotoSource;
import 'package:qout/features/profile/data/profile_photo_picker.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/profile/presentation/profile_avatar.dart';
import 'package:qout/health/profile.dart';

import '../../../helpers/fake_profile_photo_store.dart';
import '../../../helpers/pump_app.dart';

final _profile = Profile(
  sex: Sex.male,
  age: 23,
  heightCm: 178,
  weightKg: 65,
  activity: ActivityLevel.active,
);

void main() {
  late AppDatabase database;
  late FakeProfilePhotoStore photos;
  late ProfileRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    photos = FakeProfilePhotoStore();
    repository = ProfileRepository(dao: database.profileDao, photos: photos);
  });

  tearDown(() => database.close());

  /// The sources asked for; the picker returns [picked] (null: cancelled)
  /// or throws [error].
  final asked = <PhotoSource>[];

  Future<void> open(
    WidgetTester tester, {
    String route = AppRoutes.profile,
    String? picked = '/picked/me.jpg',
    Error? error,
  }) async {
    asked.clear();
    await tester.runAsync(() async {
      await repository.save(_profile);
      await repository.saveFirstName('Dhafer');
    });
    tester.view
      ..physicalSize = const Size(500, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(
      database: database,
      liveProfile: true,
      photos: photos,
      overrides: [
        profilePhotoPickerProvider.overrideWithValue((source) async {
          asked.add(source);
          if (error != null) throw error;
          return picked;
        }),
      ],
    );
    await tester.pushRoute(route);
    await tester.pumpAndSettle();
  }

  Finder photo() => find.byKey(const ValueKey('profile-photo'));
  Finder button() => find.byKey(const ValueKey('profile-photo-button'));

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(button());
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }

  testWidgets('the initial until a photo is chosen', (tester) async {
    await open(tester);
    expect(photo(), findsNothing);
    expect(find.text('D'), findsWidgets);
    await tester.unmountQoutApp();
  });

  testWidgets('the menu: take, choose; remove only with a photo', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(button());
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing);
    expect(find.text('It stays on this phone.'), findsOneWidget);
    await tester.unmountQoutApp();
  });

  testWidgets('from the gallery: shown on Profile and on Today', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, 'Choose from gallery');

    expect(asked, [PhotoSource.gallery]);
    expect(photos.files.values, ['/picked/me.jpg']);
    expect(photo(), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-today')));
    await tester.pumpAndSettle();
    expect(photo(), findsOneWidget);
    await tester.unmountQoutApp();
  });

  testWidgets('from the camera', (tester) async {
    await open(tester);
    await choose(tester, 'Take a photo');
    expect(asked, [PhotoSource.camera]);
    expect(photo(), findsOneWidget);
    await tester.unmountQoutApp();
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    await open(tester, picked: null);
    await choose(tester, 'Choose from gallery');
    expect(photos.files, isEmpty);
    expect(photo(), findsNothing);
    await tester.unmountQoutApp();
  });

  testWidgets('a picker failure says so', (tester) async {
    await open(tester, error: StateError('camera denied'));
    await choose(tester, 'Take a photo');
    expect(find.text('The photo could not be changed'), findsOneWidget);
    expect(photo(), findsNothing);
    await tester.unmountQoutApp();
  });

  testWidgets('replace, then remove: the initial comes back', (tester) async {
    await open(tester);
    await choose(tester, 'Choose from gallery');
    await choose(tester, 'Take a photo');
    expect(photos.files.keys, ['photo-2.jpg']);

    await choose(tester, 'Remove photo');
    expect(photos.files, isEmpty);
    expect(photo(), findsNothing);
    expect(find.text('D'), findsWidgets);
    await tester.unmountQoutApp();
  });

  testWidgets('a photo file gone missing shows the initial', (tester) async {
    await tester.runAsync(() async {
      await repository.setPhoto('/picked/old.jpg');
    });
    photos.files.clear();
    await open(tester);
    expect(photo(), findsNothing);
    expect(find.text('D'), findsWidgets);
    await tester.unmountQoutApp();
  });

  testWidgets('a photo that cannot be drawn shows the initial', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, 'Choose from gallery');
    await tester.unmountQoutApp();

    // The same database, now with an image that fails to decode.
    await tester.pumpQoutApp(
      database: database,
      liveProfile: true,
      photos: photos,
      overrides: [
        profilePhotoImageProvider.overrideWithValue(
          (_) => MemoryImage(Uint8List.fromList([1, 2, 3])),
        ),
      ],
    );
    await tester.pushRoute(AppRoutes.profile);
    await tester.pumpAndSettle();
    expect(find.text('D'), findsWidgets);
    await tester.unmountQoutApp();
  });

  testWidgets('deleting the profile deletes the photo', (tester) async {
    await open(tester);
    await choose(tester, 'Choose from gallery');
    await tester.scrollUntilVisible(
      find.text('Delete my profile'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete my profile'));
    await tester.pumpAndSettle();
    expect(find.textContaining('your photo'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(photos.files, isEmpty);
    await tester.unmountQoutApp();
  });

  testWidgets('labelled for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    expect(find.bySemanticsLabel('Add a profile photo'), findsOneWidget);
    await choose(tester, 'Choose from gallery');
    expect(find.bySemanticsLabel('Change profile photo'), findsOneWidget);
    handle.dispose();
    await tester.unmountQoutApp();
  });
}
