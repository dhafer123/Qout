import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/app.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/auth/data/token_store.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/outbox/data/outbox_files.dart';
import 'package:qout/features/outbox/presentation/outbox_scheduler.dart';
import 'package:qout/features/outbox/presentation/outbox_screen.dart';
import 'package:qout/features/product/data/alternatives_repository.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/health/profile.dart';

import 'fake_alternatives_repository.dart';
import 'fake_outbox.dart';
import 'fake_scan_history_repository.dart';
import 'in_memory_token_store.dart';

extension PumpQoutApp on WidgetTester {
  /// Pumps the full app with a fixed [AppEnv] (no build flavor in tests), a
  /// local [database] (a fresh in-memory one by default), a scan [history]
  /// and [alternatives] (empty fakes by default), an outbox that keeps
  /// photos without files ([outboxFiles]) and whose automatic syncs only
  /// count ([outboxTrigger]: tests send with `Outbox` itself), the queue as
  /// [outboxEntries] (empty by default; pass `database.outboxDao.watchAll()`
  /// for the real one, then call [unmountQoutApp]), whether onboarding was
  /// finished at start ([onboarded]: the welcome screens when false), the
  /// [profile] and [avoidedAdditives] (fixed values by default; with
  /// [liveProfile], read from the database and followed as it changes: call
  /// [unmountQoutApp] at the end), and any extra provider [overrides] (fake
  /// repositories).
  Future<void> pumpQoutApp({
    AppFlavor flavor = AppFlavor.dev,
    AppDatabase? database,
    FakeScanHistoryRepository? history,
    FakeAlternativesRepository? alternatives,
    InMemoryTokenStore? tokens,
    FakeOutboxFiles? outboxFiles,
    OutboxTrigger? outboxTrigger,
    Stream<List<OutboxRow>>? outboxEntries,
    bool onboarded = true,
    Profile? profile,
    Set<String> avoidedAdditives = const {},
    bool liveProfile = false,
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
          onboardingCompletedAtStartProvider.overrideWithValue(onboarded),
          // Not the drift streams by default (see [unmountQoutApp]).
          if (!liveProfile) ...[
            profileProvider.overrideWith((ref) => Stream.value(profile)),
            avoidedAdditivesProvider.overrideWith(
              (ref) => Stream.value(avoidedAdditives),
            ),
          ],
          scanHistoryRepositoryProvider.overrideWithValue(
            history ?? FakeScanHistoryRepository(),
          ),
          // No platform secure storage in tests: signed out unless given.
          tokenStoreProvider.overrideWithValue(tokens ?? InMemoryTokenStore()),
          // Never the network: no alternatives unless a test gives some.
          alternativesRepositoryProvider.overrideWithValue(
            alternatives ?? FakeAlternativesRepository(),
          ),
          outboxFilesProvider.overrideWithValue(
            outboxFiles ?? FakeOutboxFiles(),
          ),
          outboxTriggerProvider.overrideWithValue(
            outboxTrigger ?? FakeOutboxTrigger(),
          ),
          // Not the drift stream by default (see [unmountQoutApp]).
          outboxEntriesProvider.overrideWith(
            (ref) => outboxEntries ?? Stream.value(const []),
          ),
          ...overrides,
        ],
        child: const QoutApp(),
      ),
    );
    await pumpAndSettle();
  }

  /// Unmounts the app and lets drift close its query streams. Needed at the
  /// end of a test that watched the real database (`outboxEntries:`):
  /// closing a drift stream schedules a zero timer, and a timer still pending
  /// when the test ends fails it.
  Future<void> unmountQoutApp() async {
    await pumpWidget(const SizedBox.shrink());
    await pump(Duration.zero);
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
