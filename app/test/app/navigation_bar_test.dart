import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/app_shell.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/history/presentation/scan_history_list.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/health/profile.dart';

import '../helpers/fake_product_repository.dart';
import '../helpers/fake_scan_history_repository.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

/// Regression (T31d): the app draws behind the system navigation bar
/// (Android 15+), so every scrolling screen must end above it. Found on a
/// phone with 3-button navigation, where "Delete my profile" and "Scan
/// another barcode" sat under the bar.
void main() {
  const screen = Size(360, 640);
  const navigationBar = 48.0;

  Future<void> configure(WidgetTester tester) async {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 24, bottom: navigationBar)
      ..viewPadding = const FakeViewPadding(top: 24, bottom: navigationBar);
    addTearDown(tester.view.reset);
  }

  Future<void> scrollToEnd(WidgetTester tester, {Finder? scrollable}) async {
    await tester.fling(
      scrollable ?? find.byType(Scrollable).first,
      const Offset(0, -20000),
      8000,
    );
    await tester.pumpAndSettle();
  }

  Finder button(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );

  /// Above the system navigation bar, and above the app's tab bar on the
  /// tabs (T41).
  void expectAboveNavigationBar(WidgetTester tester, Finder finder) {
    expect(finder, findsOneWidget);
    final tabBar = find.byType(QoutNavBar);
    final limit = tabBar.evaluate().isEmpty
        ? screen.height - navigationBar
        : tester.getRect(tabBar).top;
    expect(tester.getRect(finder).bottom, lessThanOrEqualTo(limit));
  }

  Profile profile() => Profile(
    sex: Sex.female,
    age: 30,
    heightCm: 165,
    weightKg: 60,
    activity: ActivityLevel.moderatelyActive,
  );

  final productOverride = productRepositoryProvider.overrideWithValue(
    FakeProductRepository(
      results: [
        ProductResult.found(
          product: recordedProduct('product-general-graded'),
          fetchedAt: DateTime.utc(2026, 11, 13),
          freshness: ProductFreshness.fresh,
        ),
      ],
    ),
  );

  test('the system bars are transparent, without a contrast scrim', () {
    for (final brightness in Brightness.values) {
      final style = qoutSystemOverlayStyle(brightness);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
      expect(
        style.systemNavigationBarIconBrightness,
        brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      );
    }
  });

  testWidgets('diary: the last scan', (tester) async {
    await configure(tester);
    final history = FakeScanHistoryRepository();
    for (var i = 0; i < 10; i++) {
      history.seed('619123456789$i', at: DateTime.utc(2026, 11, 13, i));
    }
    await tester.pumpQoutApp(history: history);
    await tester.pushRoute(AppRoutes.diary);
    await tester.pumpAndSettle();
    await scrollToEnd(tester);
    expectAboveNavigationBar(tester, find.byType(HistoryTile).last);
  });

  testWidgets('product: the last button', (tester) async {
    await configure(tester);
    await tester.pumpQoutApp(overrides: [productOverride]);
    await tester.pushRoute(AppRoutes.product('123'));
    await tester.pumpAndSettle();
    await scrollToEnd(tester);
    expectAboveNavigationBar(tester, button('Scan another barcode'));
  });

  testWidgets('report an error: the send button', (tester) async {
    await configure(tester);
    await tester.pumpQoutApp(overrides: [productOverride]);
    await tester.pushRoute(AppRoutes.product('123'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Report an error'));
    await tester.pumpAndSettle();
    await scrollToEnd(tester, scrollable: find.byType(Scrollable).last);
    expectAboveNavigationBar(tester, button('Send report'));
  });

  testWidgets('profile: the last button', (tester) async {
    await configure(tester);
    // Not dev: the dev flavor adds developer tools at the end.
    await tester.pumpQoutApp(flavor: AppFlavor.prod, profile: profile());
    await tester.pushRoute(AppRoutes.profile);
    await tester.pumpAndSettle();
    await scrollToEnd(tester);
    expectAboveNavigationBar(tester, button('Delete my profile'));
  });

  testWidgets('profile form: save', (tester) async {
    await configure(tester);
    await tester.pumpQoutApp();
    await tester.pushRoute(AppRoutes.profileEdit);
    await tester.pumpAndSettle();
    await scrollToEnd(tester);
    expectAboveNavigationBar(tester, button('Save'));
  });

  testWidgets('a whole-screen message: its last action', (tester) async {
    await configure(tester);
    await tester.pumpQoutApp(
      overrides: [
        productRepositoryProvider.overrideWithValue(
          FakeProductRepository(
            results: [const ProductResult.notFound(ean: '6191234567897')],
          ),
        ),
      ],
    );
    await tester.pushRoute(AppRoutes.product('6191234567897'));
    await tester.pumpAndSettle();
    await scrollToEnd(tester);
    expectAboveNavigationBar(tester, button('Scan another barcode'));
  });
}
