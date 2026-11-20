import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/app/app.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/profile/data/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolve before runApp so a bad flavor or URL fails at startup.
  final env = AppEnv.fromBuild();
  // Draw behind the system bars on every Android version, as Android 15+
  // requires anyway; screens keep their content clear of them.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  LicenseRegistry.addLicense(_bundledFontLicenses);
  // Read before the first frame (the splash screen stays meanwhile), so the
  // first screen is the right one: welcome on the first run, the profile
  // form while none is saved, else home.
  final database = AppDatabase.open();
  final start = await ProfileRepository(
    dao: database.profileDao,
  ).startScreen().catchError((Object _) => StartScreen.home);
  runApp(
    ProviderScope(
      overrides: [
        appEnvProvider.overrideWithValue(env),
        appDatabaseProvider.overrideWithValue(database),
        startScreenProvider.overrideWithValue(start),
      ],
      child: const QoutApp(),
    ),
  );
}

/// The Inter font ships with the app (SIL Open Font License): list its
/// licence on the app's licence page.
Stream<LicenseEntry> _bundledFontLicenses() async* {
  final text = await rootBundle.loadString('assets/fonts/inter/OFL.txt');
  yield LicenseEntryWithLineBreaks(const ['Inter'], text);
}
