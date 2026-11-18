import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';

/// Played over the camera once a barcode is accepted: the scan frame pops
/// and a check appears, then [onDone]. The product starts loading at the
/// same moment, so the animation hides part of the wait rather than adding
/// one.
///
/// The animation is the success part of "QR Scan Successful" (Lottie,
/// supplied by the project owner), trimmed to its last 1.1 s and recoloured
/// to the theme's accent.
class ScanSuccess extends StatefulWidget {
  const ScanSuccess({required this.onDone, super.key});

  final VoidCallback onDone;

  static const String asset = 'assets/animations/scan_success.json';

  /// Length of the trimmed animation (frames 36 to 69 at 30 fps).
  static const Duration duration = Duration(milliseconds: 1100);

  @override
  State<ScanSuccess> createState() => _ScanSuccessState();
}

class _ScanSuccessState extends State<ScanSuccess>
    with SingleTickerProviderStateMixin {
  // Timed here, not by the composition, so the result opens on time even if
  // the animation file can't be read.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ScanSuccess.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenCompleteOrCancel(() {
      if (mounted && _controller.isCompleted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = QoutPalette.dark.accent;
    final fallback = FadeTransition(
      opacity: _controller,
      child: Icon(PhosphorIconsFill.checkCircle, size: 96, color: accent),
    );
    return Semantics(
      liveRegion: true,
      label: 'Barcode read',
      child: ColoredBox(
        color: const Color(0x8C000000),
        child: Center(
          child: SizedBox.square(
            dimension: 220,
            child: Lottie.asset(
              ScanSuccess.asset,
              controller: _controller,
              delegates: LottieDelegates(
                values: [
                  for (final layer in const [
                    'Circle 1',
                    'Circle 2',
                    'QR Scanner frame',
                  ])
                    ValueDelegate.color([layer, '**'], value: accent),
                ],
              ),
              frameBuilder: (context, child, composition) =>
                  composition == null ? fallback : child,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
          ),
        ),
      ),
    );
  }
}
