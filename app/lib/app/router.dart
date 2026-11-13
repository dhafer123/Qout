import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/presentation/product_screen.dart';
import 'package:qout/features/scan/presentation/scan_screen.dart';

/// Route paths, in one place.
abstract final class AppRoutes {
  static const home = '/';
  static const scan = '/scan';
  static const productPattern = '/product/:ean';

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
          // Replace the scanner: back from the product goes home.
          onScanned: (context, ean) =>
              context.pushReplacement(AppRoutes.product(ean)),
        ),
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
