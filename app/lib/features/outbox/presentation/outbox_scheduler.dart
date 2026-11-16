import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/features/auth/data/auth_repository.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/outbox/data/outbox.dart';

/// Starts outbox runs: [sync] sends what is due now; afterwards a timer waits
/// for the next retry time while the app runs. Sending while the app is
/// closed would need a background-work package (not used: T30 decision).
abstract interface class OutboxTrigger {
  Future<void> sync();

  /// After signing in: entries that needed it are sent again.
  Future<void> signedIn();
}

class OutboxScheduler implements OutboxTrigger {
  OutboxScheduler({
    required Outbox outbox,
    required OutboxDao dao,
    DateTime Function()? clock,
    Timer Function(Duration wait, void Function() callback)? timer,
  }) : _outbox = outbox,
       _dao = dao,
       _clock = clock ?? DateTime.now,
       _newTimer = timer ?? Timer.new;

  final Outbox _outbox;
  final OutboxDao _dao;
  final DateTime Function() _clock;
  final Timer Function(Duration, void Function()) _newTimer;
  Timer? _timer;
  bool _disposed = false;

  @override
  Future<void> sync() async {
    await _outbox.run();
    if (_disposed) return;
    final next = await _outbox.nextAttempt();
    if (_disposed) return;
    _timer?.cancel();
    _timer = next == null
        ? null
        : _newTimer(_wait(next), () => unawaited(sync()));
  }

  Duration _wait(DateTime next) {
    final wait = next.difference(_clock());
    return wait.isNegative ? Duration.zero : wait;
  }

  @override
  Future<void> signedIn() async {
    await _dao.resumeAfterSignIn();
    await sync();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

final Provider<OutboxTrigger> outboxTriggerProvider = Provider<OutboxTrigger>(
  (ref) {
    final scheduler = OutboxScheduler(
      outbox: ref.watch(outboxProvider),
      dao: ref.watch(appDatabaseProvider).outboxDao,
    );
    ref.onDispose(scheduler.dispose);
    return scheduler;
  },
);

/// Syncs the outbox when the app starts, comes back to the foreground, and
/// when the user signs in.
class OutboxSyncHost extends ConsumerStatefulWidget {
  const OutboxSyncHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OutboxSyncHost> createState() => _OutboxSyncHostState();
}

class _OutboxSyncHostState extends ConsumerState<OutboxSyncHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }

  /// A failed run is not the app's problem: entries keep their state.
  Future<void> _sync() =>
      ref.read(outboxTriggerProvider).sync().catchError((Object _) {});

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      final was = previous?.valueOrNull;
      if (next.valueOrNull is SignedIn && was is! SignedIn && was != null) {
        unawaited(
          ref.read(outboxTriggerProvider).signedIn().catchError((Object _) {}),
        );
      }
    });
    return widget.child;
  }
}
