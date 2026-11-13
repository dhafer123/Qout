import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/app.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/data/alternatives_repository.dart';

import 'fake_alternatives_repository.dart';
import 'fake_scan_history_repository.dart';

extension PumpQoutApp on WidgetTester {
  /// Pumps the full app with a fixed [AppEnv] (no build flavor in tests), a
  /// local [database] (a fresh in-memory one by default), a scan [history]
  /// and [alternatives] (empty fakes by default) and any extra provider
  /// [overrides] (fake repositories).
  Future<void> pumpQoutApp({
    AppFlavor flavor = AppFlavor.dev,
    AppDatabase? database,
    FakeScanHistoryRepository? history,
    FakeAlternativesRepository? alternatives,
    List<Override> overrides = const [],
  }) async {
    final db = database ?? _memoryDatabase();
    await pumpWidget(
      ProviderScope(
        overrides: [
          appEnvProvider.overrideWithValue(
            AppEnv.resolve(flavorName: flavor.name),
          ),
          appDatabaseProvider.overrideWithValue(db),
          scanHistoryRepositoryProvider.overrideWithValue(
            history ?? FakeScanHistoryRepository(),
          ),
          // Never the network: no alternatives unless a test gives some.
          alternativesRepositoryProvider.overrideWithValue(
            alternatives ?? FakeAlternativesRepository(),
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

AppDatabase _memoryDatabase() {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  return database;
}
