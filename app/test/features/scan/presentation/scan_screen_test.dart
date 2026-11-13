import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qout/features/scan/presentation/scan_screen.dart';

import '../../../helpers/fake_scanner_platform.dart';

const _ean = '6191234567897';

void main() {
  late FakeScannerPlatform scanner;
  late List<String> scanned;
  late List<String> haptics;

  setUp(() {
    scanner = installFakeScanner();
    scanned = [];
    haptics = [];
  });

  Future<void> pumpScanScreen(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(onScanned: (_, ean) => scanned.add(ean)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> emit(WidgetTester tester, String raw, [BarcodeFormat? format]) {
    scanner.emitCode(raw, format ?? BarcodeFormat.ean13);
    return tester.pump();
  }

  group('camera running', () {
    testWidgets('shows the camera and an aiming hint', (tester) async {
      await pumpScanScreen(tester);

      expect(find.byKey(FakeScannerPlatform.cameraKey), findsOneWidget);
      expect(find.text('Point the camera at the barcode'), findsOneWidget);
      expect(find.text('Scan a barcode'), findsOneWidget);
    });

    testWidgets('asks only for retail barcode formats', (tester) async {
      await pumpScanScreen(tester);

      expect(
        scanner.lastStartOptions!.formats,
        unorderedEquals([
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ]),
      );
    });

    testWidgets('accepts a code after three identical reads', (tester) async {
      await pumpScanScreen(tester);

      await emit(tester, _ean);
      await emit(tester, _ean);
      expect(scanned, isEmpty);
      expect(haptics, isEmpty);

      await emit(tester, _ean);
      expect(scanned, [_ean]);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      expect(scanner.stopCalls, 1);
    });

    testWidgets('reports a code once, however many reads follow', (
      tester,
    ) async {
      await pumpScanScreen(tester);

      for (var i = 0; i < 6; i++) {
        await emit(tester, _ean);
      }
      expect(scanned, [_ean]);
    });

    testWidgets('ignores misreads (wrong check digit)', (tester) async {
      await pumpScanScreen(tester);

      for (var i = 0; i < 5; i++) {
        await emit(tester, '6191234567890');
      }
      expect(scanned, isEmpty);
      expect(haptics, isEmpty);
    });

    testWidgets('reports UPC-E as EAN-13', (tester) async {
      await pumpScanScreen(tester);

      for (var i = 0; i < 3; i++) {
        await emit(tester, '04252614', BarcodeFormat.upcE);
      }
      expect(scanned, ['0042100005264']);
    });

    testWidgets('ignores formats it did not ask for', (tester) async {
      await pumpScanScreen(tester);

      for (var i = 0; i < 3; i++) {
        await emit(tester, _ean, BarcodeFormat.qrCode);
      }
      scanner.emit([const Barcode(format: BarcodeFormat.ean13)]); // no value
      await tester.pump();
      expect(scanned, isEmpty);
    });

    testWidgets('releases the camera in the background and restarts it', (
      tester,
    ) async {
      await pumpScanScreen(tester);
      expect(scanner.startCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(scanner.stopCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(scanner.startCalls, 2);
      expect(find.byKey(FakeScannerPlatform.cameraKey), findsOneWidget);
    });
  });

  group('torch', () {
    testWidgets('toggles the flashlight', (tester) async {
      await pumpScanScreen(tester);

      await tester.tap(find.byTooltip('Turn on the flashlight'));
      await tester.pump();
      expect(scanner.toggleTorchCalls, 1);
      expect(find.byTooltip('Turn off the flashlight'), findsOneWidget);
      expect(find.byIcon(Icons.flashlight_on), findsOneWidget);

      await tester.tap(find.byTooltip('Turn off the flashlight'));
      await tester.pump();
      expect(scanner.toggleTorchCalls, 2);
      expect(find.byTooltip('Turn on the flashlight'), findsOneWidget);
    });

    testWidgets('is hidden when the camera has no torch', (tester) async {
      scanner.initialTorch = TorchState.unavailable;
      await pumpScanScreen(tester);

      expect(find.byIcon(Icons.flashlight_off), findsNothing);
      expect(find.byIcon(Icons.flashlight_on), findsNothing);
    });

    testWidgets('is hidden when the camera could not start', (tester) async {
      scanner.startError = scannerError(MobileScannerErrorCode.genericError);
      await pumpScanScreen(tester);

      expect(find.byIcon(Icons.flashlight_off), findsNothing);
    });
  });

  group('permission denied', () {
    setUp(() {
      scanner.startError = scannerError(
        MobileScannerErrorCode.permissionDenied,
      );
    });

    testWidgets('explains why the camera is needed', (tester) async {
      await pumpScanScreen(tester);

      expect(find.text('Camera access needed'), findsOneWidget);
      expect(
        find.textContaining('uses the camera only to read barcodes'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byKey(FakeScannerPlatform.cameraKey), findsNothing);
    });

    testWidgets('Try again restarts the camera once allowed', (tester) async {
      await pumpScanScreen(tester);

      scanner.startError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(scanner.startCalls, 2);
      expect(find.text('Camera access needed'), findsNothing);
      expect(find.byKey(FakeScannerPlatform.cameraKey), findsOneWidget);
    });

    testWidgets('Try again while still denied keeps the explanation', (
      tester,
    ) async {
      await pumpScanScreen(tester);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(scanner.startCalls, 2);
      expect(find.text('Camera access needed'), findsOneWidget);
    });

    testWidgets('does not ask again on its own when the app resumes', (
      tester,
    ) async {
      await pumpScanScreen(tester);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(scanner.startCalls, 1);
      expect(find.text('Camera access needed'), findsOneWidget);
    });
  });

  group('other camera errors', () {
    testWidgets('no camera: explains, no retry', (tester) async {
      scanner.startError = scannerError(MobileScannerErrorCode.unsupported);
      await pumpScanScreen(tester);

      expect(find.text('No camera available'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('generic failure: explains, can retry', (tester) async {
      scanner.startError = scannerError(MobileScannerErrorCode.genericError);
      await pumpScanScreen(tester);

      expect(find.text('Camera unavailable'), findsOneWidget);
      scanner.startError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(FakeScannerPlatform.cameraKey), findsOneWidget);
    });
  });
}
