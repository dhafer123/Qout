import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:qout/app/theme.dart';

/// The splash Flutter shows after Android's own: the same icon at the same
/// place (the leaf mark on a brand-green circle, centred), with the loading
/// dots under it for one loop (T45b), then [child] fades in.
///
/// [child] is not built until then, so the first screen's animations (the
/// welcome greeting, Today's count-up) start when it is seen.
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({required this.child, super.key});

  final Widget child;

  /// The mark on a transparent square, its box 44 % of the side (as the
  /// launcher icon's foreground).
  static const String markAsset = 'assets/brand/qout_mark.png';

  /// "loading" (Lottie, supplied by the project owner), recoloured to the
  /// brand green with a light-green flash.
  static const String dotsAsset = 'assets/animations/loading_dots.json';

  /// One loop of the dots: 33 frames at 25 fps.
  static const Duration duration = Duration(milliseconds: 1320);

  /// As Android's splash draws `splash_icon`: the circle 160 dp, the mark
  /// image 240 dp (its box 106 dp).
  static const double iconBox = 240;
  static const double circle = 160;

  /// The dots' canvas (800 × 600) drawn 200 dp wide.
  static const Size dotsBox = Size(200, 150);

  /// The highest point the dots jump to over the loop: 108 of the canvas's
  /// 600 (measured frame by frame).
  static const double dotsJumpTop = 108 / 600;

  /// Space between the circle and the dots at the top of their jump.
  static const double dotsGap = 32;

  /// How far below the icon's centre the dots' box is centred, so their
  /// highest jump stays [dotsGap] under the circle.
  static double get dotsOffset =>
      circle / 2 + dotsGap - dotsBox.height * dotsJumpTop + dotsBox.height / 2;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  // Timed here, not by the composition, so the app opens on time even if
  // the animation can't be read.
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: LaunchSplash.duration,
  );
  bool _started = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // With reduced motion the dots stand still; the icon shows just as long.
    final play = MediaQuery.disableAnimationsOf(context)
        ? Future<void>.delayed(LaunchSplash.duration)
        : _dots.forward().orCancel;
    unawaited(
      play.then((_) {
        if (mounted) setState(() => _done = true);
      }, onError: (Object _) {}),
    );
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    child: _done
        ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
        : _SplashView(key: const ValueKey('splash'), dots: _dots),
  );
}

class _SplashView extends StatelessWidget {
  const _SplashView({required this.dots, super.key});

  final Animation<double> dots;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Qout, loading',
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      // The whole screen, not only the icon's square; its children keep
      // their own sizes (regression: stretched, the dots grew into the icon).
      child: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: SizedBox.square(
                dimension: LaunchSplash.iconBox,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: qoutBrandGreen,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: LaunchSplash.circle),
                    ),
                    Image.asset(
                      LaunchSplash.markAsset,
                      width: LaunchSplash.iconBox,
                      height: LaunchSplash.iconBox,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(),
                    ),
                  ],
                ),
              ),
            ),
            // Regression: placed by their resting row, the dots jumped into
            // the circle.
            Transform.translate(
              offset: Offset(0, LaunchSplash.dotsOffset),
              child: ExcludeSemantics(
                child: SizedBox.fromSize(
                  size: LaunchSplash.dotsBox,
                  child: Lottie.asset(
                    LaunchSplash.dotsAsset,
                    controller: dots,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
