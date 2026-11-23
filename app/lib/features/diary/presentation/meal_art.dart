import 'package:flutter/material.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/health/diary.dart';

/// Each meal's picture (T43e): toast and coffee for breakfast, a bento box
/// for lunch, a bag of chips for a snack, a full plate for dinner.
String mealPicture(Meal meal) => 'assets/illustrations/meals/${meal.name}.png';

/// The tint behind a meal's row or heading, from its picture.
Color mealTint(QoutPalette palette, Meal meal) => switch (meal) {
  Meal.breakfast => palette.breakfastTint,
  Meal.lunch => palette.lunchTint,
  Meal.snack => palette.snackTint,
  Meal.dinner => palette.dinnerTint,
};

/// A meal's picture, [size] dp square (the pictures are about 240 px, so
/// 80 dp at most). Decorative: the meal's name is always written next to it.
class MealArt extends StatelessWidget {
  const MealArt(this.meal, {this.size = 40, super.key});

  final Meal meal;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      mealPicture(meal),
      key: ValueKey('meal-art-${meal.name}'),
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) =>
          SizedBox.square(dimension: size),
    ),
  );
}
