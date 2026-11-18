import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/app/app.dart';
import 'package:qout/core/env/app_env.dart';

void main() {
  // Resolve before runApp so a bad flavor or URL fails at startup.
  final env = AppEnv.fromBuild();
  LicenseRegistry.addLicense(_bundledFontLicenses);
  runApp(
    ProviderScope(
      overrides: [appEnvProvider.overrideWithValue(env)],
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
