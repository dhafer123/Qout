import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/product/domain/score_explanation.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_sections.dart';

import '../../../helpers/fixtures.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.dark,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildQoutTheme(brightness),
      home: Scaffold(body: ListView(children: [child])),
    ),
  );

  group('componentAmount', () {
    final n = recordedProduct('product-general-graded').nutrition;

    test('energy in kJ, nutrients in grams', () {
      expect(componentAmount('energy', n), '2056 kJ');
      expect(componentAmount('saturated_fat', n), '12.5 g');
      expect(componentAmount('salt', n), '1.23 g');
    });

    test('nothing when not declared, not a single amount, or no data', () {
      expect(componentAmount('fibre', n), isNull);
      expect(componentAmount('saturated_fat_ratio', n), isNull);
      expect(componentAmount('energy', null), isNull);
    });

    test('sweeteners in words, fruit share in percent', () {
      final drink = recordedProduct('product-beverage-graded').nutrition;
      expect(
        componentAmount('non_nutritive_sweeteners', drink),
        'Contains sweeteners',
      );
      expect(componentAmount('fvl', drink), endsWith(' %'));
    });
  });

  group('ComponentRow.fill', () {
    test('points out of the maximum, clamped', () {
      expect(
        ComponentRow.fill(
          const ScoreComponent(name: 'salt', points: 6, maxPoints: 20),
        ),
        0.3,
      );
      expect(
        ComponentRow.fill(
          const ScoreComponent(name: 'salt', points: 25, maxPoints: 20),
        ),
        1,
      );
    });

    test('empty without a maximum', () {
      expect(
        ComponentRow.fill(const ScoreComponent(name: 'x', points: 3)),
        0,
      );
      expect(
        ComponentRow.fill(
          const ScoreComponent(name: 'x', points: 0, maxPoints: 0),
        ),
        0,
      );
    });
  });

  group('GradeCard', () {
    testWidgets('graded: grade, scale and track', (tester) async {
      await pump(
        tester,
        GradeCard(
          explanation: explainScore(recordedProduct('product-general-graded')),
        ),
      );
      expect(find.text('Grade E'), findsOneWidget);
      expect(find.byType(GradeTrack), findsOneWidget);
    });

    testWidgets('insufficient data: no grade and why', (tester) async {
      await pump(
        tester,
        GradeCard(
          explanation: explainScore(
            recordedProduct('product-insufficient-data'),
          ),
        ),
      );
      expect(find.text('No grade'), findsOneWidget);
      expect(find.text('Not enough data to grade it.'), findsOneWidget);
      expect(find.byType(GradeTrack), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is GradeBadge && w.grade == null),
        findsOneWidget,
      );
    });

    testWidgets('unknown category', (tester) async {
      await pump(
        tester,
        GradeCard(
          explanation: explainScore(
            recordedProduct('product-unknown-category'),
          ),
        ),
      );
      expect(find.text('Its food category is not known yet.'), findsOneWidget);
    });
  });

  group('ProductHeader', () {
    testWidgets('a verified product says so', (tester) async {
      final json = recordedProductJson('product-general-graded')
        ..['status'] = 'verified';
      await pump(tester, ProductHeader(product: ProductDetail.fromJson(json)));
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Not verified yet'), findsNothing);
    });

    testWidgets('an unverified one too', (tester) async {
      await pump(
        tester,
        ProductHeader(product: recordedProduct('product-general-graded')),
        brightness: Brightness.light,
      );
      expect(find.text('Not verified yet'), findsOneWidget);
    });
  });

  testWidgets('GradeBadge labels the grade for screen readers', (
    tester,
  ) async {
    await pump(tester, const GradeBadge(grade: Grade.c, size: 44));
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Grade C',
      ),
      findsOneWidget,
    );
  });
}
