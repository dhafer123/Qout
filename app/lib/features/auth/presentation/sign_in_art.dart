import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// The sign-in illustration: two people signing in on a laptop and a tablet
/// in front of a big phone.
///
/// "Sign In Green" (Lottie, supplied by the project owner), its phone
/// recoloured from hot pink and purple to the brand greens (T46); the rest
/// keeps its colours. It plays a round, rests for [rest] and plays again;
/// with reduced motion it stands still. Decorative: hidden from screen
/// readers.
class SignInArt extends StatefulWidget {
  const SignInArt({this.size = 200, super.key});

  final double size;

  static const String asset = 'assets/animations/sign_in.json';

  /// One round: 120 frames at 24 fps.
  static const Duration round = Duration(seconds: 5);

  /// The pause between rounds (also what lets the screen settle).
  static const Duration rest = Duration(milliseconds: 1500);

  @override
  State<SignInArt> createState() => _SignInArtState();
}

class _SignInArtState extends State<SignInArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: SignInArt.round,
  );
  Timer? _resting;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context)) unawaited(_play());
  }

  Future<void> _play() async {
    try {
      await _progress.forward(from: 0).orCancel;
      if (!mounted) return;
      _resting = Timer(SignInArt.rest, () {
        if (mounted) unawaited(_play());
      });
    } on TickerCanceled {
      // Disposed mid-round.
    }
  }

  @override
  void dispose() {
    _resting?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: widget.size,
      child: Lottie.asset(
        SignInArt.asset,
        controller: _progress,
        errorBuilder: (context, error, stackTrace) => const SizedBox(),
      ),
    ),
  );
}
