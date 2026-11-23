import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/features/diary/presentation/day_summary.dart';
import 'package:qout/health/advice.dart' show Nutrient;
import 'package:qout/health/diary.dart';
import 'package:qout/health/needs.dart';

/// 2000 kcal (8368 kJ); fat 70, saturates 20, sugars 90, salt 6 g: test
/// values for the layout, not a nutrition table.
const _needs = DailyNeeds(
  basis: NeedsBasis.reference,
  referenceReason: ReferenceReason.noProfile,
  energyKj: 8368,
  fatG: 70,
  saturatesG: 20,
  sugarsG: 90,
  saltG: 6,
  bmi: null,
);

Totals _totals(Map<Nutrient, double> amounts) =>
    Totals(amounts: amounts, missing: const {});

Future<void> _pump(
  WidgetTester tester,
  Totals totals, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view
    ..physicalSize = const Size(420, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildQoutTheme(brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          child: DaySummaryCard(totals: totals, needs: _needs),
        ),
      ),
    ),
  );
}

void main() {
  test('groupThousands', () {
    expect(groupThousands(0), '0');
    expect(groupThousands(999), '999');
    expect(groupThousands(1799), '1,799');
    expect(groupThousands(1234567), '1,234,567');
    expect(groupThousands(-2885), '-2,885');
  });

  group('energy ring', () {
    testWidgets('what is left, big; eaten and the need under it', (
      tester,
    ) async {
      // 1086 kcal.
      await _pump(tester, _totals({Nutrient.energy: 1086 * 4.184}));
      expect(find.text('914'), findsOneWidget);
      expect(find.text('kcal left'), findsOneWidget);
      expect(find.text('1,086 eaten · 2,000 need'), findsOneWidget);
    });

    testWidgets('eaten and need on one line beside the bars', (tester) async {
      await _pump(tester, _totals({Nutrient.energy: 1086 * 4.184}));
      final detail = tester.widget<Text>(
        find.byKey(const ValueKey('ring-detail')),
      );
      expect(detail.maxLines, 1);
    });

    testWidgets('past the need: how far over, not in red', (tester) async {
      await _pump(tester, _totals({Nutrient.energy: 2214 * 4.184}));
      expect(find.text('214'), findsOneWidget);
      expect(find.text('kcal over'), findsOneWidget);
      final big = tester.widget<Text>(find.byKey(const ValueKey('ring-left')));
      expect(big.style?.color, isNot(StatusColors.light.over));
    });

    testWidgets('read as one sentence by screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _totals({Nutrient.energy: 1086 * 4.184}));
      expect(
        find.bySemanticsLabel(
          'Energy: 914 kilocalories left. 1,086 eaten of a daily need of '
          '2,000.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('nutrient bars', () {
    Color barColor(WidgetTester tester, Nutrient nutrient) => tester
        .widget<LinearProgressIndicator>(
          find.byKey(ValueKey('bar-${nutrient.name}')),
        )
        .color!;

    for (final brightness in Brightness.values) {
      testWidgets('coloured by status, ${brightness.name}', (tester) async {
        final colors = brightness == Brightness.dark
            ? StatusColors.dark
            : StatusColors.light;
        await _pump(
          tester,
          _totals({
            Nutrient.fat: 20, // 29 %: ok
            Nutrient.saturates: 15, // 75 %: warn
            Nutrient.sugars: 120, // above the reference: still warn
            Nutrient.salt: 7, // above: over
          }),
          brightness: brightness,
        );
        expect(barColor(tester, Nutrient.fat), colors.ok);
        expect(barColor(tester, Nutrient.saturates), colors.warn);
        expect(barColor(tester, Nutrient.sugars), colors.warn);
        expect(barColor(tester, Nutrient.salt), colors.over);
      });
    }

    testWidgets('one wording, "eaten / amount g", no qualifiers', (
      tester,
    ) async {
      await _pump(
        tester,
        _totals({Nutrient.fat: 9.1, Nutrient.saturates: 12.4}),
      );
      expect(find.text('9.1 / 70 g'), findsOneWidget);
      expect(find.text('12 / 20 g'), findsOneWidget);
      expect(find.text('0.0 / 90 g'), findsOneWidget);
      for (final word in ['up to', 'under ', 'reference ']) {
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data ?? '').contains(' g') &&
                (w.data ?? '').contains(word),
          ),
          findsNothing,
          reason: word,
        );
      }
    });

    testWidgets('name and value on one line', (tester) async {
      await _pump(tester, _totals({Nutrient.saturates: 9.1}));
      final name = tester.getCenter(find.text('Saturates'));
      final value = tester.getCenter(find.text('9.1 / 20 g'));
      expect(value.dy, name.dy);
      expect(value.dx, greaterThan(name.dx));
    });
  });

  testWidgets('the ⓘ: the card keeps no disclaimer, the sheet explains', (
    tester,
  ) async {
    await _pump(tester, _totals(const {}));
    expect(find.textContaining('not medical advice'), findsNothing);
    expect(
      find.text('Compared with the EU reference intakes.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('About these numbers'));
    await tester.pumpAndSettle();
    expect(find.text('About these numbers'), findsOneWidget);
    expect(find.text('Fat: up to 70 g a day.'), findsOneWidget);
    expect(
      find.textContaining('Sugars: 90 g, a reference intake'),
      findsOneWidget,
    );
    expect(find.text('Salt: 6 g, the EU reference intake.'), findsOneWidget);
    expect(find.textContaining('amber from 70 %'), findsOneWidget);
    expect(
      find.text('General information, not medical advice.'),
      findsOneWidget,
    );
  });
}
