import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/product/presentation/product_labels.dart';

void main() {
  test('amounts: at most the given decimals, no trailing zeros', () {
    expect(formatAmount(1.23125), '1.23');
    expect(formatAmount(12.5), '12.5');
    expect(formatAmount(25), '25');
    expect(formatAmount(0), '0');
    expect(formatAmount(2055.5, decimals: 0), '2056');
  });

  test('energy: kJ as declared, kcal at 4.184 kJ each', () {
    expect(kjPerKcalForDisplay, 4.184);
    expect(formatEnergy(2055.5), '2056 kJ / 491 kcal');
    expect(formatEnergy(138), '138 kJ / 33 kcal');
    expect(formatEnergy(4184), '4184 kJ / 1000 kcal');
    expect(formatEnergy(0), '0 kJ / 0 kcal');
  });

  test('unknown names are made readable', () {
    expect(componentLabel('some_new_part'), 'Some new part');
    expect(inputLabel('new_field_g'), 'New field g');
  });
}
