import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';

/// The welcome pages' illustrations: theme icons animated in code, and two
/// supplied Lottie animations. Each plays once when its page is built and
/// then holds its last frame; with reduced motion it shows the last frame at
/// once. Decorative only: hidden from screen readers.

/// Runs [builder] with an animation that goes from 0 to 1 once.
class _PlayOnce extends StatefulWidget {
  const _PlayOnce({required this.duration, required this.builder});

  final Duration duration;
  final Widget Function(BuildContext context, Animation<double> t) builder;

  @override
  State<_PlayOnce> createState() => _PlayOnceState();
}

class _PlayOnceState extends State<_PlayOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox.square(
        dimension: WelcomeArt.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => widget.builder(context, _controller),
        ),
      ),
    ),
  );
}

/// [t] mapped onto the part of the timeline from [begin] to [end] (both
/// 0..1), through [curve].
double _phase(
  Animation<double> t,
  double begin,
  double end, [
  Curve curve = Curves.easeOut,
]) => Interval(begin, end, curve: curve).transform(t.value);

/// A soft green disc with a glow, growing in behind the art.
class _Halo extends StatelessWidget {
  const _Halo({required this.t});

  final Animation<double> t;

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    final grow = 0.8 + 0.2 * _phase(t, 0, 0.35, Curves.easeOutCubic);
    return Transform.scale(
      scale: grow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              palette.accent.withValues(alpha: 0.28),
              palette.accent.withValues(alpha: 0.10),
              palette.accent.withValues(alpha: 0),
            ],
            stops: const [0, 0.62, 1],
          ),
        ),
        child: Center(
          child: Container(
            width: WelcomeArt.size * 0.64,
            height: WelcomeArt.size * 0.64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.tag,
            ),
          ),
        ),
      ),
    );
  }
}

/// Namespace for the illustrations.
abstract final class WelcomeArt {
  /// Side of the square each illustration is drawn in (scaled down to fit).
  static const double size = 240;
}

/// Page 1: the grade scale, A to E, each badge popping in after the one
/// before; A then gives a small bounce.
class GradeScaleArt extends StatelessWidget {
  const GradeScaleArt({super.key});

  static const double _badge = 38;

  @override
  Widget build(BuildContext context) => _PlayOnce(
    duration: const Duration(milliseconds: 1700),
    builder: (context, t) {
      final scheme = Theme.of(context).colorScheme;
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _Halo(t: t)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(QoutRadius.lg),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E1E2622),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, grade) in gradeScale.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Transform.scale(
                    scale:
                        _phase(
                          t,
                          0.08 + i * 0.09,
                          0.38 + i * 0.09,
                          Curves.easeOutBack,
                        ) *
                        (i == 0 ? _bounce(t) : 1),
                    child: GradeBadge(grade: grade, size: _badge),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );

  /// 1, up to 1.18 and back, near the end of the timeline.
  static double _bounce(Animation<double> t) {
    final p = _phase(t, 0.78, 1, Curves.easeInOut);
    return 1 + 0.18 * math.sin(p * math.pi);
  }
}

/// Page 2: a barcode with a scan line sweeping over it twice, then a tick.
class ScanArt extends StatelessWidget {
  const ScanArt({super.key});

  static const double _icon = 104;

  @override
  Widget build(BuildContext context) => _PlayOnce(
    duration: const Duration(milliseconds: 2000),
    builder: (context, t) {
      final palette = QoutPalette.of(context);
      final scheme = Theme.of(context).colorScheme;
      // Down, up, down again over the first 70 %, fading at the end.
      final sweep = _phase(t, 0.12, 0.7, Curves.linear);
      final y = (1 - math.cos(sweep * 3 * math.pi)) / 2; // 0..1
      final lineOpacity = sweep == 0
          ? 0.0
          : (1 - _phase(t, 0.66, 0.78)).clamp(0.0, 1.0);
      final tick = _phase(t, 0.72, 1, Curves.easeOutBack);
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _Halo(t: t)),
          Icon(
            PhosphorIconsRegular.barcode,
            size: _icon,
            color: scheme.onSurface,
          ),
          Positioned(
            top: (WelcomeArt.size - _icon) / 2 + 14 + y * (_icon - 28),
            child: Opacity(
              opacity: lineOpacity,
              child: Container(
                width: _icon + 24,
                height: 3,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: WelcomeArt.size * 0.2,
            bottom: WelcomeArt.size * 0.2,
            child: Transform.scale(
              scale: tick,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainer,
                ),
                child: Icon(
                  PhosphorIconsFill.checkCircle,
                  size: 44,
                  color: palette.accent,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// The welcome page: a ball bounces in, grows and writes "hi.".
///
/// "If you are new here!" (Lottie, 1080 × 1920, supplied by the project
/// owner), cropped to the 600 × 600 middle where the ball lands. It loops:
/// the ball comes in and writes "hi." (frames 0 to 80 of 120), holds for
/// [hold], rolls away (to frame 110, where the file is empty) and starts
/// again. With reduced motion it shows "hi." and stays still. Recoloured from
/// its yellow-orange to the brand green (the tile's lip a darker green); "hi."
/// stays white.
class GreetingArt extends StatefulWidget {
  const GreetingArt({super.key});

  static const String asset = 'assets/animations/greeting.json';

  /// The frame it holds on, out of the 120 frames.
  static const double holdAt = 80 / 120;

  /// Where the ball has rolled away and the file shows nothing more.
  static const double exitAt = 110 / 120;

  /// How long "hi." stays before the ball rolls away.
  static const Duration hold = Duration(seconds: 1);

  /// Frames 0 to 80 and 80 to 110, at 30 fps.
  static const Duration comeIn = Duration(milliseconds: 2670);
  static const Duration rollAway = Duration(milliseconds: 1000);

  /// Larger than the other pages' art: the page has little text.
  static const double size = 300;

  /// The tile's lower edge, under its face.
  static const Color lip = Color(0xFF1B5E20);

  /// The brand green over the file's colours. The hidden track mattes keep
  /// theirs: only their shape counts.
  static final List<ValueDelegate<Object>> colours = [
    for (final path in const [
      ['Ball', '**'],
      ['Ball 3', 'Rectangle 1', '**'],
    ])
      ValueDelegate.color(path, value: qoutBrandGreen),
    for (final layer in const ['Tail', 'Tail 2'])
      ValueDelegate.strokeColor([layer, '**'], value: qoutBrandGreen),
    ValueDelegate.color(const ['Ball 3', 'Rectangle 2', '**'], value: lip),
  ];

  @override
  State<GreetingArt> createState() => _GreetingArtState();
}

class _GreetingArtState extends State<GreetingArt>
    with SingleTickerProviderStateMixin {
  // The composition's progress (0..1 over its 120 frames).
  late final AnimationController _progress = AnimationController(vsync: this);
  Timer? _holding;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _progress.value = GreetingArt.holdAt;
    } else {
      unawaited(_round());
    }
  }

  /// One round: in, hold, away; then the next.
  Future<void> _round() async {
    try {
      _progress.value = 0;
      await _progress
          .animateTo(GreetingArt.holdAt, duration: GreetingArt.comeIn)
          .orCancel;
      if (!mounted) return;
      _holding = Timer(GreetingArt.hold, () async {
        try {
          await _progress
              .animateTo(GreetingArt.exitAt, duration: GreetingArt.rollAway)
              .orCancel;
          if (mounted) unawaited(_round());
        } on TickerCanceled {
          // Disposed while rolling away.
        }
      });
    } on TickerCanceled {
      // Disposed while coming in.
    }
  }

  @override
  void dispose() {
    _holding?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = GreetingArt.size;
    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox.square(
          dimension: size,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: size * 1080 / 600,
              maxHeight: size * 1920 / 600,
              child: Lottie.asset(
                GreetingArt.asset,
                controller: _progress,
                width: size * 1080 / 600,
                height: size * 1920 / 600,
                fit: BoxFit.fill,
                delegates: LottieDelegates(values: GreetingArt.colours),
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The advice page: a shield pops in and a tick draws across it.
///
/// "Security status - Safe" (Lottie, supplied by the project owner), its
/// shield recoloured from a bright mint to the brand green.
class ShieldArt extends StatelessWidget {
  const ShieldArt({super.key});

  static const String asset = 'assets/animations/privacy_shield.json';

  @override
  Widget build(BuildContext context) => _PlayOnce(
    duration: const Duration(milliseconds: 1280),
    builder: (context, t) => Lottie.asset(
      asset,
      controller: t,
      fit: BoxFit.contain,
      delegates: LottieDelegates(
        values: [
          ValueDelegate.color(const ['shield', '**'], value: qoutBrandGreen),
        ],
      ),
      errorBuilder: (context, error, stackTrace) => const SizedBox(),
    ),
  );
}
