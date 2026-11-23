import 'package:flutter/widgets.dart';
import 'package:qout/core/ui/entrance.dart';

/// [builder] with a number running to [value] (T43g): from 0 when its
/// screen opens ([Entrance.isOpening]), from the previous value when it
/// changes (something logged), shown at once otherwise or when the phone
/// asks for reduced motion. Readers of the screen get the final values from
/// the caller's semantics, never a number on its way.
class AnimatedValue extends StatelessWidget {
  const AnimatedValue({
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 700),
    this.delay = Duration.zero,
    super.key,
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;

  /// Waited before running, e.g. until the card has faded in.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return builder(context, value);
    final total = delay + duration;
    return TweenAnimationBuilder<double>(
      // The begin only counts on the first build; later values run from
      // wherever the number is.
      tween: Tween(
        begin: Entrance.isOpening(context) ? 0 : value,
        end: value,
      ),
      duration: total,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, current, _) => builder(context, current),
    );
  }
}
