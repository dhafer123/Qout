import 'package:flutter/material.dart';

/// The vegetable stickers (`assets/illustrations/veg/`, see
/// `assets/illustrations/SOURCE.md`). Each stands for something: every
/// state and welcome page has its own ([VeggieFor]), except the empty
/// day and week, which share the tearful onion.
enum Veggie {
  asparagus,
  broccoli,
  cabbage,
  carrot,
  cauliflower,
  corn,
  cucumber,
  eggplant,
  garlic,
  mushroom,
  onion,

  /// The smiling onion with a tear (a separate picture, not from the sheet).
  onionTear,
  peas,
  pepper,
  potato,
  pumpkin,
  radish,
  spinach,
  tomato
  ;

  /// The sticker's asset path.
  String get asset => 'assets/illustrations/veg/$name.png';
}

/// Which vegetable goes with which state, everywhere in the app.
abstract final class VeggieFor {
  /// Something went wrong (the onion: it makes you cry).
  static const Veggie error = Veggie.onion;

  /// No connection (the couch potato, resting).
  static const Veggie offline = Veggie.potato;

  /// A product Qout does not know (the mushroom, popping up).
  static const Veggie unknown = Veggie.mushroom;

  /// Nothing logged on a day (the tearful onion: nothing to eat yet).
  static const Veggie emptyDay = Veggie.onionTear;

  /// Nothing logged in a week.
  static const Veggie emptyWeek = Veggie.onionTear;

  /// Everything sent.
  static const Veggie allSent = Veggie.peas;

  /// A contribution sent or saved (the radish with its heart).
  static const Veggie thanks = Veggie.radish;

  /// The camera can't be used.
  static const Veggie noCamera = Veggie.eggplant;

  /// Welcome, the grade page (spinach: an A food).
  static const Veggie welcomeGrades = Veggie.spinach;

  /// Welcome, scanning without an account.
  static const Veggie welcomeScan = Veggie.pepper;

  /// Welcome, data kept on the phone (garlic keeps the vampires away).
  static const Veggie welcomePrivate = Veggie.garlic;
}

/// A vegetable sticker, [size] dp square (kept at 72 or less: the
/// stickers are about 200 px). It pops in when first built, unless the
/// phone asks for reduced motion. Decorative: hidden from screen readers.
class VeggieArt extends StatelessWidget {
  const VeggieArt(this.veggie, {this.size = 64, this.pop = true, super.key});

  final Veggie veggie;
  final double size;

  /// Whether it pops in when first built.
  final bool pop;

  static const Duration _popDuration = Duration(milliseconds: 420);

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      veggie.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) =>
          SizedBox.square(dimension: size),
    );
    if (!pop || MediaQuery.disableAnimationsOf(context)) {
      return ExcludeSemantics(child: image);
    }
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.5, end: 1),
        duration: _popDuration,
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: image,
      ),
    );
  }
}
