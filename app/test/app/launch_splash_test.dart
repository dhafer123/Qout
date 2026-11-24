import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:qout/app/launch_splash.dart';
import 'package:qout/app/theme.dart';

import '../helpers/pump_app.dart';

/// Counts its builds, to see whether the app under the splash was built.
class _App extends StatelessWidget {
  const _App(this.builds);

  final List<int> builds;

  @override
  Widget build(BuildContext context) {
    builds.add(1);
    return const Text('the app');
  }
}

Future<void> pumpSplash(WidgetTester tester, List<int> builds) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildQoutTheme(Brightness.dark),
        home: LaunchSplash(child: _App(builds)),
      ),
    );

/// Every fill and stroke colour in a Lottie file, as 0xRRGGBB.
Set<int> lottieColours(Object? node) {
  final found = <int>{};
  void add(List<dynamic> c) => found.add(
    ((c[0] as num) * 255).round() << 16 |
        ((c[1] as num) * 255).round() << 8 |
        ((c[2] as num) * 255).round(),
  );
  void walk(Object? o) {
    if (o is Map<String, dynamic>) {
      if ((o['ty'] == 'fl' || o['ty'] == 'st') && o['c'] is Map) {
        final k = (o['c'] as Map)['k'] as List<dynamic>;
        if (k.first is Map) {
          for (final frame in k.cast<Map<String, dynamic>>()) {
            for (final key in ['s', 'e']) {
              if (frame[key] case final List<dynamic> c) add(c);
            }
          }
        } else {
          add(k);
        }
      }
      o.values.forEach(walk);
    } else if (o is List) {
      o.forEach(walk);
    }
  }

  walk(node);
  return found;
}

void main() {
  testWidgets('the icon and the dots for one loop, then the app', (
    tester,
  ) async {
    final builds = <int>[];
    await pumpSplash(tester, builds);

    final mark = tester.widget<Image>(find.byType(Image));
    expect((mark.image as AssetImage).assetName, LaunchSplash.markAsset);
    expect(find.byType(Lottie), findsOneWidget);
    expect(find.bySemanticsLabel('Qout, loading'), findsOneWidget);
    // Not built yet: its animations wait until it is seen.
    expect(builds, isEmpty);
    expect(find.text('the app'), findsNothing);

    await tester.pump(LaunchSplash.duration - const Duration(milliseconds: 50));
    expect(find.text('the app'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);
    expect(find.byType(Lottie), findsNothing);
  });

  testWidgets('the icon sits in the middle, as on the system splash', (
    tester,
  ) async {
    await pumpSplash(tester, []);
    final screen = tester.getCenter(find.byType(LaunchSplash));
    expect(tester.getCenter(find.byType(Image)), screen);
    // Regression: the ground only filled the icon's square, black around.
    expect(
      tester.getSize(
        find.descendant(
          of: find.byType(LaunchSplash),
          matching: find.byType(ColoredBox),
        ),
      ),
      tester.getSize(find.byType(LaunchSplash)),
    );
    expect(
      tester.getSize(find.byType(Image)),
      const Size.square(LaunchSplash.iconBox),
    );
    // The dots under it: even at the top of their jump (108 of the 600
    // canvas), a clear gap under the circle (regression: they overlapped).
    final dots = tester.getRect(find.byType(Lottie));
    expect(dots.size, LaunchSplash.dotsBox);
    final jumpTop = dots.top + dots.height * LaunchSplash.dotsJumpTop;
    expect(
      jumpTop - (screen.dy + LaunchSplash.circle / 2),
      closeTo(LaunchSplash.dotsGap, 0.01),
    );
    await tester.pumpAndSettle(); // let the splash finish
  });

  testWidgets('reduced motion: the dots stand still, the app still opens', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpSplash(tester, []);

    await tester.pump(const Duration(milliseconds: 600));
    final dots = tester.widget<Lottie>(find.byType(Lottie));
    expect(dots.controller!.value, 0);

    await tester.pump(LaunchSplash.duration);
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('no splash unless asked for (tests, hot restarts)', (
    tester,
  ) async {
    await tester.pumpQoutApp();
    expect(find.byType(LaunchSplash), findsNothing);
  });

  group('assets', () {
    test('the dots are in the brand green with a light-green flash', () {
      final json = jsonDecode(
        File(LaunchSplash.dotsAsset).readAsStringSync(),
      );
      // Regression: the supplied file was teal, pink, mint and orange.
      expect(lottieColours(json), {0x2E7D32, 0x7DB069});
    });

    test('the launcher icon and the splash circle are brand green', () {
      final colours = File(
        'android/app/src/main/res/values/colors.xml',
      ).readAsStringSync();
      expect(
        colours,
        contains('<color name="ic_launcher_background">#2E7D32</color>'),
      );
      expect(qoutBrandGreen, const Color(0xFF2E7D32));
    });
  });
}
