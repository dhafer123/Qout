import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qout/features/scan/domain/barcode.dart';
import 'package:qout/features/scan/domain/scan_acceptor.dart';

/// Camera barcode scanner. Reads EAN-13, EAN-8, UPC-A and UPC-E, accepts a
/// code once [ScanAcceptor] trusts it, then calls [onScanned] with the
/// normalised code (EAN-13 or EAN-8).
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    required this.onScanned,
    this.requiredReads = ScanAcceptor.defaultRequiredReads,
    super.key,
  });

  final void Function(BuildContext context, String ean) onScanned;
  final int requiredReads;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final ScanAcceptor _acceptor = ScanAcceptor(
    requiredReads: widget.requiredReads,
  );

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
    widget.onScanned(context, ean);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan a barcode'),
        actions: [_TorchButton(controller: _controller)],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error) => ScannerErrorView(
          error: error,
          onRetry: () => unawaited(_controller.start()),
        ),
        overlayBuilder: (context, constraints) => const _ScanFrame(),
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
          icon: const Icon(Icons.flashlight_off),
          selectedIcon: const Icon(Icons.flashlight_on),
          onPressed: () => unawaited(controller.toggleTorch()),
        );
      },
    );
  }
}

/// Where to aim: a frame shaped like a barcode, with a hint below.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 280,
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: colors.primaryContainer, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Point the camera at the barcode',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }
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
        Icons.no_photography_outlined,
        'Camera access needed',
        'Qout uses the camera only to read barcodes. Allow camera access, '
            "or turn it on in your phone's settings (Apps > Qout > "
            'Permissions), then try again.',
        true,
      ),
      MobileScannerErrorCode.unsupported => (
        Icons.videocam_off_outlined,
        'No camera available',
        'This device has no camera Qout can use to read barcodes.',
        false,
      ),
      _ => (
        Icons.error_outline,
        'Camera unavailable',
        'The camera could not be started. Close other apps using it and '
            'try again.',
        true,
      ),
    };
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (canRetry) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
