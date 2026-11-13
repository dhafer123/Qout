import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/app.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/home/presentation/home_screen.dart';

extension PumpQoutApp on WidgetTester {
  /// Pumps the full app with a fixed [AppEnv] (no build flavor in tests) and
  /// any extra provider [overrides] (fake repositories, in-memory database).
  Future<void> pumpQoutApp({
    AppFlavor flavor = AppFlavor.dev,
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: [
          appEnvProvider.overrideWithValue(
            AppEnv.resolve(flavorName: flavor.name),
          ),
          ...overrides,
        ],
        child: const QoutApp(),
      ),
    );
    await pumpAndSettle();
  }

  /// Opens [location] on top of the home screen, as navigating would.
  Future<void> pushRoute(String location) async {
    unawaited(GoRouter.of(element(find.byType(HomeScreen))).push(location));
    await pump();
    await pump(const Duration(milliseconds: 500)); // page transition
  }
}
