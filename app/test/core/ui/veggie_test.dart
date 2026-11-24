import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/ui/state_message.dart';
import 'package:qout/core/ui/veggie.dart';

import '../../helpers/veggie_finder.dart';

/// Width and height from a PNG's header.
(int, int) pngSize(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

Future<void> pumpIn(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildQoutTheme(Brightness.light),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('stickers', () {
    const folder = 'assets/illustrations/veg';

    test('every vegetable has its PNG, small enough for 72 dp at most', () {
      for (final veggie in Veggie.values) {
        final file = File(veggie.asset);
        expect(file.existsSync(), isTrue, reason: veggie.asset);
        final bytes = file.readAsBytesSync();
        expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: veggie.asset);
        final (width, height) = pngSize(bytes);
        expect(width, inInclusiveRange(100, 240), reason: veggie.asset);
        expect(height, inInclusiveRange(100, 240), reason: veggie.asset);
      }
    });

    test('no sticker without a vegetable', () {
      final names = Directory(folder)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(names, {for (final v in Veggie.values) '${v.name}.png'});
    });

    test('bundled with the app', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final veggie in Veggie.values) {
        final data = await rootBundle.load(veggie.asset);
        expect(data.lengthInBytes, greaterThan(1000), reason: veggie.asset);
      }
    });
  });

  test('every nothing-logged state shows the tearful onion', () {
    expect(VeggieFor.emptyDay, Veggie.onionTear);
    expect(VeggieFor.emptyWeek, Veggie.onionTear);
    expect(VeggieFor.allSent, Veggie.peas);
  });

  group('VeggieArt', () {
    testWidgets('shows the sticker at its size, hidden from screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpIn(tester, const VeggieArt(Veggie.carrot, size: 48));
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, Veggie.carrot.asset);
      expect(tester.getSize(find.byType(Image)), const Size(48, 48));
      expect(
        find.descendant(
          of: find.byType(VeggieArt),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('pops in once, then holds still', (tester) async {
      await pumpIn(tester, const VeggieArt(Veggie.tomato));
      final scale = find.descendant(
        of: find.byType(VeggieArt),
        matching: find.byType(Transform),
      );
      // x scale (the z axis always stays 1).
      double scaleOf() => tester.widget<Transform>(scale).transform.entry(0, 0);
      expect(scaleOf(), 0.5);
      await tester.pumpAndSettle();
      expect(scaleOf(), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion or pop: false: no animation', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpIn(tester, const VeggieArt(Veggie.peas));
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();

      await pumpIn(tester, const VeggieArt(Veggie.corn, pop: false));
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });
  });

  group('StateMessage', () {
    testWidgets('a vegetable replaces the icon', (tester) async {
      await pumpIn(
        tester,
        const StateMessage(
          icon: PhosphorIconsRegular.warningCircle,
          veggie: VeggieFor.error,
          title: 'Something went wrong',
        ),
      );
      expect(findVeggie(Veggie.onion), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.warningCircle), findsNothing);
    });

    testWidgets('without one, the icon', (tester) async {
      await pumpIn(
        tester,
        const StateMessage(
          icon: PhosphorIconsRegular.warningCircle,
          title: 'Something went wrong',
        ),
      );
      expect(find.byType(VeggieArt), findsNothing);
      expect(find.byIcon(PhosphorIconsRegular.warningCircle), findsOneWidget);
    });
  });
}
