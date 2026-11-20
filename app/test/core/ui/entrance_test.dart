import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/ui/entrance.dart';

void main() {
  const box = SizedBox(key: Key('content'), width: 10, height: 10);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool reducedMotion = false,
  }) => tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    ),
  );

  double? opacity(WidgetTester tester) {
    final found = find.ancestor(
      of: find.byKey(const Key('content')),
      matching: find.byType(Opacity),
    );
    return found.evaluate().isEmpty
        ? null
        : tester.widget<Opacity>(found).opacity;
  }

  testWidgets('fades in when its screen opens, then stays', (tester) async {
    await pump(tester, const EntranceScope(child: Entrance(child: box)));
    expect(opacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 140));
    expect(opacity(tester), allOf(greaterThan(0), lessThan(1)));

    await tester.pumpAndSettle();
    expect(opacity(tester), 1);
  });

  testWidgets('later items start later', (tester) async {
    await pump(
      tester,
      const EntranceScope(
        child: Column(
          children: [
            Entrance(child: SizedBox(key: Key('first'), height: 10)),
            Entrance(index: 4, child: SizedBox(key: Key('fifth'), height: 10)),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    double of(String key) => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.byKey(Key(key)),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(of('first'), greaterThan(of('fifth')));
    await tester.pumpAndSettle();
  });

  testWidgets('static with reduced motion', (tester) async {
    await pump(
      tester,
      const EntranceScope(child: Entrance(child: box)),
      reducedMotion: true,
    );
    expect(opacity(tester), isNull);
  });

  testWidgets('static outside a scope', (tester) async {
    await pump(tester, const Entrance(child: box));
    expect(opacity(tester), isNull);
  });
}
