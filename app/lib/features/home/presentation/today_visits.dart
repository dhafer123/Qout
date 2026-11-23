import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/router.dart';

/// Counts each time Today comes back into view (T43h): switching to its tab,
/// or coming back to it from a screen on top (a product, the scanner). Today
/// replays its numbers on each change.
final todayVisitsProvider = NotifierProvider<TodayVisits, int>(
  TodayVisits.new,
);

class TodayVisits extends Notifier<int> {
  @override
  int build() {
    final router = ref.watch(routerProvider);
    var onToday = _onToday(router);
    void changed() {
      final now = _onToday(router);
      // After the navigation, not while the tree may be building.
      if (now && !onToday) scheduleMicrotask(() => state++);
      onToday = now;
    }

    router.routerDelegate.addListener(changed);
    ref.onDispose(() => router.routerDelegate.removeListener(changed));
    return 0;
  }

  /// Whether the screen on top is Today.
  static bool _onToday(GoRouter router) {
    try {
      return router.state.matchedLocation == AppRoutes.home;
    } on Object {
      // No route yet (the router is starting).
      return false;
    }
  }
}
