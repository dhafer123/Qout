import 'package:flutter/widgets.dart';
import 'package:qout/core/ui/entrance.dart';

/// [builder] with a number running to [value] (T43g): from 0 the first time
/// [id] shows on its screen ([Entrance.firstShow]: when its data arrives,
/// however long that takes) and again on each replay of the screen
/// ([EntranceScope.replay]), from the previous value when it changes
/// (something logged), and shown at once when built again (scrolled back
/// into view), outside an [EntranceScope] or when the phone asks for reduced
/// motion. Readers of the screen get the final values from the caller's
/// semantics, never a number on its way.
class AnimatedValue extends StatefulWidget {
  const AnimatedValue({
    required this.id,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 700),
    this.delay = Duration.zero,
    super.key,
  });

  /// What this number is on its screen ("ring", "bar-salt"...).
  final Object id;
  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;

  /// Waited before running, e.g. until the card has faded in.
  final Duration delay;

  @override
  State<AnimatedValue> createState() => _AnimatedValueState();
}

class _AnimatedValueState extends State<AnimatedValue> {
  /// Where the number starts, decided once per round of its screen.
  double? _begin;
  int? _round;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final round = Entrance.round(context);
    if (round == _round) return;
    // First build, or the screen asked for a replay (T43h).
    _round = round;
    _begin = Entrance.firstShow(context, widget.id) ? 0 : widget.value;
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.builder(context, widget.value);
    }
    final total = widget.delay + widget.duration;
    return TweenAnimationBuilder<double>(
      // A new round starts a new animation from its begin; otherwise the
      // begin only counts on the first build and later values run from
      // wherever the number is.
      key: ValueKey(_round),
      tween: Tween(begin: _begin, end: widget.value),
      duration: total,
      curve: Interval(
        widget.delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, current, _) => widget.builder(context, current),
    );
  }
}
