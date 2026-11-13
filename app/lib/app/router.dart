import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/features/auth/presentation/sign_in_screen.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/presentation/product_screen.dart';
import 'package:qout/features/scan/presentation/scan_screen.dart';

/// Route paths, in one place.
abstract final class AppRoutes {
  static const home = '/';
  static const scan = '/scan';
  static const productPattern = '/product/:ean';
  static const signIn = '/sign-in';

  static String product(String ean) => '/product/$ean';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => ScanScreen(
          onScanned: (context, ean) {
            // History is a convenience: a failed write must not block the
            // result.
            unawaited(
              ref
                  .read(scanHistoryRepositoryProvider)
                  .record(ean)
                  .catchError((Object _) {}),
            );
            // Replace the scanner: back from the product goes home.
            context.pushReplacement(AppRoutes.product(ean));
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) =>
            SignInScreen(reason: state.extra as String?),
      ),
      GoRoute(
        path: AppRoutes.productPattern,
        builder: (context, state) =>
            ProductScreen(ean: state.pathParameters['ean']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
