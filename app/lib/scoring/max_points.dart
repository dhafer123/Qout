/// The most points each score component can give, per category: the scale a
/// breakdown is shown against ("energy 6 / 10"). Read from the point tables,
/// so it always matches what the engine can award.
library;

import 'package:qout/scoring/models.dart';
import 'package:qout/scoring/tables.dart' as t;

final Map<String, int> _foods = {
  'energy': t.energyKj.maxPoints,
  'sugars': t.sugarsG.maxPoints,
  'saturated_fat': t.saturatedFatG.maxPoints,
  'salt': t.saltG.maxPoints,
  'protein': t.proteinG.maxPoints,
  'fibre': t.fibreG.maxPoints,
  'fvl': t.fvlPercent.maxPoints,
};

final Map<Category, Map<String, int>> _maxPoints = {
  Category.general: _foods,
  Category.cheese: _foods,
  Category.redMeat: {..._foods, 'protein': t.redMeatMaxProteinPoints},
  Category.fatsOilsNutsSeeds: {
    'energy_from_saturates': t.energyFromSaturatesKj.maxPoints,
    'sugars': t.sugarsG.maxPoints,
    'saturated_fat_ratio': t.saturatedFatRatioPercent.maxPoints,
    'salt': t.saltG.maxPoints,
    'protein': t.proteinG.maxPoints,
    'fibre': t.fibreG.maxPoints,
    'fvl': t.fvlPercent.maxPoints,
  },
  Category.beverage: {
    'energy': t.beverageEnergyKj.maxPoints,
    'sugars': t.beverageSugarsG.maxPoints,
    'saturated_fat': t.beverageSaturatedFatG.maxPoints,
    'salt': t.saltG.maxPoints,
    'non_nutritive_sweeteners': t.nonNutritiveSweetenersPoints,
    'protein': t.beverageProteinG.maxPoints,
    'fibre': t.fibreG.maxPoints,
    'fvl': t.beverageFvlPercent.maxPoints,
  },
};

/// The most points [component] (a breakdown key such as `energy` or
/// `saturated_fat_ratio`) can give in [category]. Null for water (no points)
/// and for components the category doesn't have.
int? maxComponentPoints(Category category, String component) =>
    _maxPoints[category]?[component];
