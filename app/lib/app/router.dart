import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/auth/presentation/sign_in_screen.dart';
import 'package:qout/features/contribute/presentation/contribute_screen.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/label_eval/presentation/label_eval_screen.dart';
import 'package:qout/features/outbox/presentation/outbox_screen.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/presentation/product_screen.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/profile/presentation/profile_edit_screen.dart';
import 'package:qout/features/profile/presentation/profile_screen.dart';
import 'package:qout/features/profile/presentation/welcome_screen.dart';
import 'package:qout/features/scan/presentation/scan_screen.dart';

/// Route paths, in one place.
abstract final class AppRoutes {
  static const home = '/';
  static const scan = '/scan';
  static const productPattern = '/product/:ean';
  static const signIn = '/sign-in';
  static const contributePattern = '/contribute/:ean';
  static const outbox = '/outbox';
  static const welcome = '/welcome';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';

  /// Dev flavor only (label evaluation set, T27).
  static const labelOcr = '/dev/label-ocr';

  static String product(String ean) => '/product/$ean';
  static String contribute(String ean) => '/contribute/$ean';
}

final routerProvider = Provider<GoRouter>((ref) {
  final dev = ref.watch(appEnvProvider).flavor == AppFlavor.dev;
  final router = GoRouter(
    // First run: the welcome screens (T39).
    initialLocation: ref.read(onboardingCompletedAtStartProvider)
        ? AppRoutes.home
        : AppRoutes.welcome,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => ScanScreen(
          // Start loading while the success animation plays: the product
          // screen then finds it saved on the phone.
          onAccepted: (ean) => unawaited(
            ref
                .read(productRepositoryProvider)
                .get(ean)
                .first
                .then<void>((_) {}, onError: (Object _) {}),
          ),
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
      GoRoute(
        path: AppRoutes.contributePattern,
        builder: (context, state) =>
            ContributeScreen(ean: state.pathParameters['ean']!),
      ),
      GoRoute(
        path: AppRoutes.outbox,
        builder: (context, state) => const OutboxScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, state) =>
            ProfileEditScreen(firstRun: state.extra == firstRunEdit),
      ),
      if (dev)
        GoRoute(
          path: AppRoutes.labelOcr,
          builder: (context, state) => const LabelEvalScreen(),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
