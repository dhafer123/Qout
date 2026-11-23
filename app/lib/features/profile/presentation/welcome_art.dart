import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';

/// The welcome pages' illustrations: theme icons drawn and animated in code
/// (no image or animation files). Each plays once when its page is built
/// and then holds its last frame; with reduced motion it shows the last
/// frame at once. Decorative only: hidden from screen readers.

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

/// Namespace for the three illustrations.
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
                  color: Color(0x2E17401C),
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

/// Page 3: a phone whose padlock snaps shut, with a ring rippling out.
class LockArt extends StatelessWidget {
  const LockArt({super.key});

  @override
  Widget build(BuildContext context) => _PlayOnce(
    duration: const Duration(milliseconds: 1600),
    builder: (context, t) {
      final palette = QoutPalette.of(context);
      final scheme = Theme.of(context).colorScheme;
      final closed = t.value >= 0.5;
      final snap = _phase(t, 0.5, 0.75, Curves.easeInOut);
      final lockScale = 1 + 0.22 * math.sin(snap * math.pi);
      final ripple = _phase(t, 0.5, 1, Curves.easeOutCubic);
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _Halo(t: t)),
          if (ripple > 0 && ripple < 1)
            Container(
              width: 90 + 90 * ripple,
              height: 90 + 90 * ripple,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.7 * (1 - ripple)),
                  width: 2,
                ),
              ),
            ),
          Icon(
            PhosphorIconsRegular.deviceMobile,
            size: 128,
            color: scheme.onSurface,
          ),
          Transform.scale(
            scale: lockScale,
            child: Icon(
              closed
                  ? PhosphorIconsFill.lockSimple
                  : PhosphorIconsFill.lockSimpleOpen,
              size: 40,
              color: palette.accent,
            ),
          ),
        ],
      );
    },
  );
}
