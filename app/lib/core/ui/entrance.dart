import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Starts the entrance clock for the content below: [Entrance] widgets
/// built within [Entrance.window] of it appearing fade and rise into place.
/// Later builds (a row scrolled back into view, a refresh) show at once, so
/// nothing plays twice.
class EntranceScope extends StatefulWidget {
  const EntranceScope({required this.child, super.key});

  final Widget child;

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope> {
  final Stopwatch _clock = Stopwatch()..start();

  @override
  Widget build(BuildContext context) =>
      _EntranceClock(clock: _clock, child: widget.child);
}

class _EntranceClock extends InheritedWidget {
  const _EntranceClock({required this.clock, required super.child});

  final Stopwatch clock;

  @override
  bool updateShouldNotify(_EntranceClock oldWidget) => clock != oldWidget.clock;
}

/// [child] fading in and rising 14 px when its screen opens, after the
/// items before it ([index] staggers it). Static when the phone asks for
/// reduced motion, outside an [EntranceScope], or once the screen has been
/// open longer than [window].
class Entrance extends StatelessWidget {
  const Entrance({required this.child, this.index = 0, super.key});

  final Widget child;
  final int index;

  /// How long after a screen opens its content still animates in.
  static const Duration window = Duration(milliseconds: 700);

  static const Duration _duration = Duration(milliseconds: 280);
  static const Duration _stagger = Duration(milliseconds: 45);
  static const int _maxStaggered = 6;
  static const double _rise = 14;

  @override
  Widget build(BuildContext context) {
    final clock = context
        .dependOnInheritedWidgetOfExactType<_EntranceClock>()
        ?.clock;
    if (clock == null ||
        clock.elapsed > window ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final delay = _stagger * math.min(index, _maxStaggered);
    final total = delay + _duration;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, _rise * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
