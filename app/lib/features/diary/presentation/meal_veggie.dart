import 'package:qout/core/ui/veggie.dart';
import 'package:qout/health/diary.dart';

/// The vegetable shown with each meal: corn for breakfast (cereal), tomato
/// for lunch, carrot for a snack, broccoli for dinner.
Veggie mealVeggie(Meal meal) => switch (meal) {
  Meal.breakfast => Veggie.corn,
  Meal.lunch => Veggie.tomato,
  Meal.snack => Veggie.carrot,
  Meal.dinner => Veggie.broccoli,
};
