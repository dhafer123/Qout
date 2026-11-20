import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/app_shell.dart';
import 'package:qout/app/router.dart';
import 'package:qout/features/diary/presentation/diary_screen.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/insights/presentation/progress_screen.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/presentation/product_screen.dart';
import 'package:qout/features/profile/presentation/profile_screen.dart';

import '../helpers/fake_product_repository.dart';
import '../helpers/fake_scan_history_repository.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

/// The tabs and the bottom bar (T41).
void main() {
  Finder tab(AppTab tab) => find.byKey(ValueKey('tab-${tab.name}'));

  Future<void> openTab(WidgetTester tester, AppTab which) async {
    await tester.tap(tab(which));
    await tester.pumpAndSettle();
  }

  testWidgets('each tab opens its screen', (tester) async {
    await tester.pumpQoutApp();
    expect(find.byType(HomeScreen), findsOneWidget);

    await openTab(tester, AppTab.diary);
    expect(find.byType(DiaryScreen), findsOneWidget);
    await openTab(tester, AppTab.progress);
    expect(find.byType(ProgressScreen), findsOneWidget);
    expect(find.text('Your week will show here'), findsOneWidget);
    await openTab(tester, AppTab.profile);
    expect(find.byType(ProfileScreen), findsOneWidget);
    await openTab(tester, AppTab.today);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a tab keeps its scroll position', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final history = FakeScanHistoryRepository();
    for (var i = 0; i < 12; i++) {
      history.seed('619123456789$i', at: DateTime.utc(2026, 11, 13, i));
    }
    await tester.pumpQoutApp(history: history);
    await openTab(tester, AppTab.diary);

    final diaryList = find.descendant(
      of: find.byType(DiaryScreen),
      matching: find.byType(Scrollable),
    );
    await tester.drag(diaryList.first, const Offset(0, -400));
    await tester.pumpAndSettle();
    double offset() =>
        tester.state<ScrollableState>(diaryList.first).position.pixels;
    final scrolled = offset();
    expect(scrolled, greaterThan(0));

    await openTab(tester, AppTab.profile);
    await openTab(tester, AppTab.diary);
    expect(offset(), scrolled);
  });

  testWidgets('back on another tab goes to Today first', (tester) async {
    await tester.pumpQoutApp();
    await openTab(tester, AppTab.progress);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('details open full screen, without the bar', (tester) async {
    final history = FakeScanHistoryRepository()
      ..seed('9557062321136', product: recordedProduct('product-water'));
    await tester.pumpQoutApp(
      history: history,
      overrides: [
        productRepositoryProvider.overrideWithValue(
          FakeProductRepository(
            results: [
              ProductResult.found(
                product: recordedProduct('product-water'),
                fetchedAt: DateTime.utc(2026, 11, 13),
                freshness: ProductFreshness.fresh,
              ),
            ],
          ),
        ),
      ],
    );
    await tester.pushRoute(AppRoutes.product('9557062321136'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductScreen), findsOneWidget);
    expect(find.byType(QoutNavBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(QoutNavBar), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the bar fits ${width.round()} dp at text ×$scale on every '
          'tab', (tester) async {
        tester.view
          ..physicalSize = Size(width, 700)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpQoutApp();
        for (final which in [...AppTab.values, AppTab.today]) {
          await openTab(tester, which);
          expect(tester.takeException(), isNull, reason: which.name);
        }
      });
    }
  }
}
