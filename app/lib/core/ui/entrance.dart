import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Starts the entrance clock for the content below: [Entrance] widgets
/// built within [Entrance.window] of it appearing fade and rise into place.
/// Later builds (a row scrolled back into view, a refresh) show at once, so
/// nothing plays twice. Also remembers which numbers have run
/// ([Entrance.firstShow]) for as long as the screen lives.
class EntranceScope extends StatefulWidget {
  const EntranceScope({required this.child, this.replay, super.key});

  final Widget child;

  /// When this changes, the numbers below run again from 0
  /// ([Entrance.firstShow] forgets what has run), e.g. each time Today
  /// comes back into view (T43h). Fades in only once.
  final Object? replay;

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope> {
  final Stopwatch _clock = Stopwatch()..start();
  final Set<Object> _shown = {};
  int _round = 0;

  @override
  void didUpdateWidget(EntranceScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replay != oldWidget.replay) {
      _shown.clear();
      _round++;
    }
  }

  @override
  Widget build(BuildContext context) => _EntranceClock(
    clock: _clock,
    shown: _shown,
    round: _round,
    child: widget.child,
  );
}

class _EntranceClock extends InheritedWidget {
  const _EntranceClock({
    required this.clock,
    required this.shown,
    required this.round,
    required super.child,
  });

  final Stopwatch clock;
  final Set<Object> shown;

  /// Counts the replays.
  final int round;

  @override
  bool updateShouldNotify(_EntranceClock oldWidget) =>
      clock != oldWidget.clock || round != oldWidget.round;
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

  /// Whether [id] is shown for the first time on [context]'s screen (inside
  /// an [EntranceScope], the phone allowing motion), and notes that it now
  /// has been: true once per screen, whenever its data arrives; false when
  /// it is built again (scrolled back into view).
  static bool firstShow(BuildContext context, Object id) {
    final shown = context
        .dependOnInheritedWidgetOfExactType<_EntranceClock>()
        ?.shown;
    if (shown == null || MediaQuery.disableAnimationsOf(context)) {
      return false;
    }
    return shown.add(id);
  }

  /// The scope's replay round (see [EntranceScope.replay]); 0 outside one.
  static int round(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EntranceClock>()?.round ?? 0;

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
