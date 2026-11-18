import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';

/// WCAG 2 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      final theme = buildQoutTheme(brightness);
      final scheme = theme.colorScheme;
      final palette = theme.extension<QoutPalette>()!;
      final grounds = {
        'ground': scheme.surface,
        'surface': scheme.surfaceContainer,
      };

      test('carries the matching palette', () {
        expect(
          palette,
          brightness == Brightness.dark ? QoutPalette.dark : QoutPalette.light,
        );
        expect(theme.textTheme.bodyMedium?.fontFamily, qoutFontFamily);
      });

      for (final MapEntry(key: name, value: ground) in grounds.entries) {
        test('body text, secondary text and accent text are readable on '
            'the $name (WCAG AA, 4.5:1)', () {
          expect(contrast(scheme.onSurface, ground), greaterThan(4.5));
          expect(contrast(palette.muted, ground), greaterThan(4.5));
          expect(contrast(palette.accentText, ground), greaterThan(4.5));
          expect(contrast(scheme.error, ground), greaterThan(4.5));
        });

        test('outlines and bars stand out from the $name (3:1)', () {
          expect(contrast(palette.accent, ground), greaterThan(3));
          expect(contrast(palette.against, ground), greaterThan(3));
          expect(contrast(palette.inFavour, ground), greaterThan(3));
        });
      }

      test('tags are readable', () {
        expect(contrast(palette.onTag, palette.tag), greaterThan(4.5));
      });

      test('every tap target is at least 48 dp high', () {
        for (final style in [
          theme.filledButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.textButtonTheme.style,
          theme.iconButtonTheme.style,
        ]) {
          final size = style!.minimumSize!.resolve({})!;
          expect(size.height, greaterThanOrEqualTo(48));
        }
      });
    });
  }

  test('the grade letter is readable on every grade colour', () {
    for (final color in gradeColors.values) {
      expect(contrast(gradeInk, color), greaterThan(4.5));
    }
  });

  test('the palette interpolates between themes', () {
    final mid = QoutPalette.dark.lerp(QoutPalette.light, 0.5);
    expect(
      mid.muted,
      Color.lerp(QoutPalette.dark.muted, QoutPalette.light.muted, 0.5),
    );
    expect(QoutPalette.dark.lerp(null, 0.5), QoutPalette.dark);
    expect(QoutPalette.dark.copyWith(), QoutPalette.dark);
    expect(QoutPalette.dark.copyWith(muted: Colors.red).muted, Colors.red);
  });
}
