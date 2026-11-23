import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/ui/animated_value.dart';
import 'package:qout/core/ui/entrance.dart';

/// The number shown, as text.
double _shown(WidgetTester tester) => double.parse(
  tester.widget<Text>(find.byKey(const ValueKey('n'))).data!,
);

Widget _number(double value) => AnimatedValue(
  id: 'n',
  value: value,
  duration: const Duration(milliseconds: 400),
  delay: const Duration(milliseconds: 100),
  builder: (context, v) => Text(v.toStringAsFixed(1), key: const ValueKey('n')),
);

/// [child] on a screen: inside an [EntranceScope] (with a key, so the scope
/// lives on while its content changes).
Widget _screen(Widget child, {bool scope = true}) => MaterialApp(
  home: scope
      ? EntranceScope(key: const ValueKey('scope'), child: child)
      : child,
);

void main() {
  testWidgets('counts up from 0 the first time it shows', (tester) async {
    await tester.pumpWidget(_screen(_number(100)));
    expect(_shown(tester), 0);

    // Still waiting out the delay.
    await tester.pump(const Duration(milliseconds: 90));
    expect(_shown(tester), 0);

    await tester.pump(const Duration(milliseconds: 210));
    expect(_shown(tester), allOf(greaterThan(0), lessThan(100)));

    await tester.pumpAndSettle();
    expect(_shown(tester), 100);
  });

  testWidgets('regression: data arriving late still counts up', (
    tester,
  ) async {
    // On the phone the numbers only appear once the database has answered,
    // well after the screen opened (found on Dhafer's phone, T43g).
    await tester.pumpWidget(_screen(const Text('loading')));
    await tester.pump(const Duration(seconds: 3));

    await tester.pumpWidget(_screen(_number(100)));
    expect(_shown(tester), 0);
    await tester.pumpAndSettle();
    expect(_shown(tester), 100);
  });

  testWidgets('built again on the same screen: shown at once', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_number(100)));
    await tester.pumpAndSettle();

    // Scrolled away and back: the widget is built anew.
    await tester.pumpWidget(_screen(const SizedBox()));
    await tester.pumpWidget(_screen(_number(100)));
    expect(_shown(tester), 100);
  });

  testWidgets('a new value runs from the old one, not from 0', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_number(100)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_screen(_number(200)));
    await tester.pump(const Duration(milliseconds: 1));
    expect(_shown(tester), 100);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_shown(tester), allOf(greaterThan(100), lessThan(200)));
    await tester.pumpAndSettle();
    expect(_shown(tester), 200);
  });

  testWidgets('shown at once outside a screen scope', (tester) async {
    await tester.pumpWidget(_screen(_number(100), scope: false));
    expect(_shown(tester), 100);
  });

  testWidgets('shown at once with reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(_screen(_number(100)));
    expect(_shown(tester), 100);
  });
}
