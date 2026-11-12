// The Dart engine reproduces every golden case (scoring-spec/golden/*.json).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qout/scoring/scoring.dart';
import 'package:qout/scoring/spec_json.dart';

/// `flutter test` runs from `app/`.
final goldenDir = Directory('../scoring-spec/golden');

void main() {
  final files =
      goldenDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('golden cases are found', () {
    expect(files.length, greaterThanOrEqualTo(20));
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last.replaceAll('.json', '');
    test(name, () {
      final golden =
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final category = Category.parse(golden['category']! as String);
      final input = nutritionInputFromSpec(
        golden['input']! as Map<String, Object?>,
      );
      final result = score(category, input);
      expect(expectedToSpec(result), golden['expected']);
      expect(result.category, category);
      expect(result.engineVersion, scoringEngineVersion);
    });
  }
}
