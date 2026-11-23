import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/ui/state_message.dart';
import 'package:qout/core/ui/veggie.dart';
import 'package:qout/features/scan/domain/barcode.dart';
import 'package:qout/features/scan/domain/scan_acceptor.dart';
import 'package:qout/features/scan/presentation/scan_success.dart';

/// Camera barcode scanner. Reads EAN-13, EAN-8, UPC-A and UPC-E, accepts a
/// code once [ScanAcceptor] trusts it, calls [onAccepted] at once (to start
/// loading the product), plays [ScanSuccess], then calls [onScanned] with the
/// normalised code (EAN-13 or EAN-8). With reduced motion there is no
/// animation.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    required this.onScanned,
    this.onAccepted,
    this.requiredReads = ScanAcceptor.defaultRequiredReads,
    super.key,
  });

  final void Function(BuildContext context, String ean) onScanned;
  final void Function(String ean)? onAccepted;
  final int requiredReads;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final ScanAcceptor _acceptor = ScanAcceptor(
    requiredReads: widget.requiredReads,
  );

  /// The accepted code while the success animation plays.
  String? _celebrating;

  final _controller = MobileScannerController(
    formats: _formats.keys.toList(),
    // Frequent frames: N identical reads take a fraction of a second.
    detectionTimeoutMs: 100,
  );

  static const Map<BarcodeFormat, RetailBarcodeFormat> _formats = {
    BarcodeFormat.ean13: RetailBarcodeFormat.ean13,
    BarcodeFormat.ean8: RetailBarcodeFormat.ean8,
    BarcodeFormat.upcA: RetailBarcodeFormat.upcA,
    BarcodeFormat.upcE: RetailBarcodeFormat.upcE,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    unawaited(_controller.dispose());
  }

  /// The camera is released while the app is in the background. Without
  /// permission nothing is restarted: the permission dialog itself makes the
  /// app inactive, so restarting here would ask again in a loop.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission || _acceptor.accepted != null) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final ean = _acceptor.addFrame([
      for (final barcode in capture.barcodes)
        if ((barcode.rawValue, _formats[barcode.format]) case (
          final raw?,
          final format?,
        ))
          (raw: raw, format: format),
    ]);
    if (ean == null || !mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    unawaited(_controller.stop());
    widget.onAccepted?.call(ean);
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onScanned(context, ean);
    } else {
      setState(() => _celebrating = ean);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan a barcode'),
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _TorchButton(controller: _controller),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => ScannerErrorView(
              error: error,
              onRetry: () => unawaited(_controller.start()),
            ),
            overlayBuilder: (context, constraints) =>
                _celebrating == null ? const _ScanFrame() : const SizedBox(),
          ),
          if (_celebrating case final ean?)
            ScanSuccess(onDone: () => widget.onScanned(context, ean)),
        ],
      ),
    );
  }
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, state, _) {
        final on = switch (state.torchState) {
          TorchState.unavailable => null,
          TorchState.on => true,
          TorchState.off || TorchState.auto => false,
        };
        if (on == null || !state.isRunning) return const SizedBox.shrink();
        return IconButton(
          tooltip: on ? 'Turn off the flashlight' : 'Turn on the flashlight',
          isSelected: on,
          color: Colors.white,
          icon: const Icon(PhosphorIconsRegular.flashlight),
          selectedIcon: const Icon(PhosphorIconsFill.flashlight),
          onPressed: () => unawaited(controller.toggleTorch()),
        );
      },
    );
  }
}

/// Where to aim: accent corner brackets shaped like a barcode, with a hint
/// below. Still on purpose: the camera image already moves.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  static const Size size = Size(260, 150);

  @override
  Widget build(BuildContext context) {
    const palette = QoutPalette.dark;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox.fromSize(
          size: size,
          child: CustomPaint(painter: _BracketsPainter(palette.accent)),
        ),
        const SizedBox(height: 24),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xB3161826),
            borderRadius: BorderRadius.circular(QoutRadius.lg),
            border: Border.all(color: palette.edge),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              'Point the camera at the barcode',
              style: TextStyle(color: Color(0xFFE9E9ED), fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Four rounded corners with a soft glow.
class _BracketsPainter extends CustomPainter {
  const _BracketsPainter(this.color);

  final Color color;

  static const double _arm = 28;
  static const double _radius = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    // Top left, top right, bottom right, bottom left.
    path
      ..moveTo(0, _arm)
      ..lineTo(0, _radius)
      ..arcToPoint(
        const Offset(_radius, 0),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(_arm, 0)
      ..moveTo(w - _arm, 0)
      ..lineTo(w - _radius, 0)
      ..arcToPoint(Offset(w, _radius), radius: const Radius.circular(_radius))
      ..lineTo(w, _arm)
      ..moveTo(w, h - _arm)
      ..lineTo(w, h - _radius)
      ..arcToPoint(
        Offset(w - _radius, h),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(w - _arm, h)
      ..moveTo(_arm, h)
      ..lineTo(_radius, h)
      ..arcToPoint(
        Offset(0, h - _radius),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(0, h - _arm);
    final glow = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(path, glow)
      ..drawPath(path, line);
  }

  @override
  bool shouldRepaint(_BracketsPainter old) => old.color != color;
}

/// Shown instead of the camera when it can't start.
class ScannerErrorView extends StatelessWidget {
  const ScannerErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message, canRetry) = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
        PhosphorIconsRegular.cameraSlash,
        'Camera access needed',
        'Qout uses the camera only to read barcodes. Allow camera access, '
            "or turn it on in your phone's settings (Apps > Qout > "
            'Permissions), then try again.',
        true,
      ),
      MobileScannerErrorCode.unsupported => (
        PhosphorIconsRegular.cameraSlash,
        'No camera available',
        'This device has no camera Qout can use to read barcodes.',
        false,
      ),
      _ => (
        PhosphorIconsRegular.warningCircle,
        'Camera unavailable',
        'The camera could not be started. Close other apps using it and '
            'try again.',
        true,
      ),
    };
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: StateMessage(
          veggie: VeggieFor.noCamera,
          icon: icon,
          title: title,
          message: message,
          actions: [
            if (canRetry)
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
