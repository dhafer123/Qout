import 'package:qout/features/product/presentation/product_labels.dart'
    show formatAmount;
import 'package:qout/health/advice.dart' show Nutrient, PortionUnit;
import 'package:qout/health/diary.dart';
import 'package:qout/health/energy.dart';

/// kJ as whole kcal, for the diary (energy is stored in kJ).
int kcalOf(double kj) => (kj / kjPerKcalForDisplay).round();

String unitLabel(PortionUnit? unit) =>
    unit == PortionUnit.millilitre ? 'mL' : 'g';

/// "1 serving (30 g)", "150 g", "250 mL", or "Quick add".
String portionText(DiaryEntry entry) {
  final amount = entry.amount;
  if (amount == null) return 'Quick add';
  final unit = unitLabel(entry.unit);
  if (entry.servingQuantity == amount) {
    return '1 serving (${formatAmount(amount)} $unit)';
  }
  return '${formatAmount(amount)} $unit';
}

String nutrientName(Nutrient nutrient) => switch (nutrient) {
  Nutrient.energy => 'Energy',
  Nutrient.fat => 'Fat',
  Nutrient.saturates => 'Saturates',
  Nutrient.sugars => 'Sugars',
  Nutrient.salt => 'Salt',
};
