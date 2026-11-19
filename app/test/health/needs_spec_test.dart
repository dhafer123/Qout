// The needs calculation reproduces every case in scoring-spec/needs/ (T38):
// the exact cases, and EFSA's published energy requirements within the
// file's tolerance.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qout/health/needs.dart';
import 'package:qout/health/profile.dart';

/// `flutter test` runs from `app/`.
final needsDir = Directory('../scoring-spec/needs');

Map<String, Object?> _json(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

Profile? _profile(Object? input) {
  if (input == null) return null;
  final json = input as Map<String, Object?>;
  return Profile(
    sex: Sex.parse(json['sex'] as String?),
    age: json['age']! as int,
    heightCm: (json['height_cm']! as num).toDouble(),
    weightKg: (json['weight_kg']! as num).toDouble(),
    activity: ActivityLevel.parse((json['pal']! as num).toString()),
  );
}

/// [needs] in the format of the cases' `expected` block.
Map<String, Object?> _spec(DailyNeeds needs) => {
  'basis': needs.basis.value,
  'energy_kj': needs.energyKj,
  'fat_g': needs.fatG,
  'saturates_g': needs.saturatesG,
  'sugars_g': needs.sugarsG,
  'salt_g': needs.saltG,
  'bmi': needs.bmi == null ? null : double.parse(needs.bmi!.display),
  'bmi_category': needs.bmi?.category.value,
};

void main() {
  final cases =
      Directory('${needsDir.path}/cases')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('needs cases are found', () {
    expect(cases.length, greaterThanOrEqualTo(20));
  });

  for (final file in cases) {
    final name = file.uri.pathSegments.last.replaceAll('.json', '');
    test(name, () {
      final json = _json(file);
      expect(json['id'], name);
      expect(_spec(computeNeeds(_profile(json['input']))), json['expected']);
    });
  }

  group('EFSA Table 12', () {
    final table = _json(File('${needsDir.path}/efsa-table-12.json'));
    final tolerance = table['tolerance_kj']! as int;
    final rows = (table['cases']! as List<Object?>)
        .cast<Map<String, Object?>>();

    test('has every sex, age band and activity level', () {
      expect(rows, hasLength(48));
    });

    for (final row in rows) {
      final input = row['input']! as Map<String, Object?>;
      final published = ((row['energy_mj']! as num) * 1000).round();
      test('${input['sex']} ${row['age_band']} PAL ${input['pal']}: '
          '$published kJ ± $tolerance', () {
        final needs = computeNeeds(_profile(input));
        expect(needs.basis, NeedsBasis.personal);
        expect(
          (needs.energyKj - published).abs(),
          lessThanOrEqualTo(tolerance),
        );
      });
    }
  });
}
