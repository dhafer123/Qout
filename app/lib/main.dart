import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/app/app.dart';
import 'package:qout/core/env/app_env.dart';

void main() {
  // Resolve before runApp so a bad flavor or URL fails at startup.
  final env = AppEnv.fromBuild();
  runApp(
    ProviderScope(
      overrides: [appEnvProvider.overrideWithValue(env)],
      child: const QoutApp(),
    ),
  );
}
