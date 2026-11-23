import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/app_shell.dart';
import 'package:qout/app/router.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/health/advice.dart' show Nutrient;
import 'package:qout/health/diary.dart';
import 'package:qout/health/profile.dart';

import '../../../helpers/fake_diary_repository.dart';
import '../../../helpers/fake_product_repository.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

/// T43h: Today's numbers run again each time it comes back into view.
void main() {
  String detail(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('ring-detail'))).data!;

  Future<void> pumpToday(WidgetTester tester) async {
    final diary = FakeDiaryRepository()
      ..seed(
        DiaryEntry(
          id: 0,
          eatenAt: DateTime.now(),
          meal: Meal.lunch,
          name: 'Couscous',
          ean: '1',
          amount: 100,
          values: const {Nutrient.energy: 2092}, // 500 kcal
        ),
      );
    await tester.pumpQoutApp(
      diary: diary,
      profile: Profile(
        sex: Sex.male,
        age: 23,
        heightCm: 178,
        weightKg: 65,
        activity: ActivityLevel.active,
      ),
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
    expect(detail(tester), startsWith('500 eaten'));
  }

  /// The frames right after coming back: the replay starts from 0.
  Future<void> expectReplay(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    expect(detail(tester), startsWith('0 eaten'));
    await tester.pumpAndSettle();
    expect(detail(tester), startsWith('500 eaten'));
  }

  testWidgets('back from another tab', (tester) async {
    await pumpToday(tester);
    await tester.tap(find.byKey(ValueKey('tab-${AppTab.diary.name}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('tab-${AppTab.today.name}')));
    await expectReplay(tester);
  });

  testWidgets('back from a screen on top', (tester) async {
    await pumpToday(tester);
    await tester.pushRoute(AppRoutes.product('3017620422003'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await expectReplay(tester);
  });

  testWidgets('staying on Today: no replay', (tester) async {
    await pumpToday(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(detail(tester), startsWith('500 eaten'));
  });
}
