import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/ui/animated_value.dart';
import 'package:qout/core/ui/entrance.dart';

/// The number shown, as text.
double _shown(WidgetTester tester) => double.parse(
  tester.widget<Text>(find.byKey(const ValueKey('n'))).data!,
);

Widget _number(double value, {bool opening = true}) {
  final number = AnimatedValue(
    value: value,
    duration: const Duration(milliseconds: 400),
    delay: const Duration(milliseconds: 100),
    builder: (context, v) =>
        Text(v.toStringAsFixed(1), key: const ValueKey('n')),
  );
  return MaterialApp(
    home: opening ? EntranceScope(child: number) : number,
  );
}

void main() {
  testWidgets('counts up from 0 when its screen opens', (tester) async {
    await tester.pumpWidget(_number(100));
    expect(_shown(tester), 0);

    // Still waiting out the delay.
    await tester.pump(const Duration(milliseconds: 90));
    expect(_shown(tester), 0);

    await tester.pump(const Duration(milliseconds: 210));
    expect(_shown(tester), allOf(greaterThan(0), lessThan(100)));

    await tester.pumpAndSettle();
    expect(_shown(tester), 100);
  });

  testWidgets('a new value runs from the old one, not from 0', (
    tester,
  ) async {
    await tester.pumpWidget(_number(100));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_number(200));
    await tester.pump(const Duration(milliseconds: 1));
    expect(_shown(tester), 100);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_shown(tester), allOf(greaterThan(100), lessThan(200)));
    await tester.pumpAndSettle();
    expect(_shown(tester), 200);
  });

  testWidgets('shown at once outside an opening screen', (tester) async {
    await tester.pumpWidget(_number(100, opening: false));
    expect(_shown(tester), 100);
  });

  testWidgets('shown at once with reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(_number(100));
    expect(_shown(tester), 100);
    expect(Entrance.isOpening(tester.element(find.text('100.0'))), isFalse);
  });
}
