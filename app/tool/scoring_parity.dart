// Scores the parity inputs with the Dart engine (see
// backend/app/modules/scoring/parity.py for the whole check).
//
//   cd app && dart run tool/scoring_parity.dart OUT.json [INPUTS.json]
//
// INPUTS defaults to ../scoring-spec/parity/inputs.json.

import 'dart:convert';
import 'dart:io';

import 'package:qout/scoring/scoring.dart';
import 'package:qout/scoring/spec_json.dart';

void main(List<String> args) {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln(
      'usage: dart run tool/scoring_parity.dart OUT.json [INPUTS.json]',
    );
    exitCode = 64;
    return;
  }
  final inputs = File(
    args.length == 2 ? args[1] : '../scoring-spec/parity/inputs.json',
  );
  final document =
      jsonDecode(inputs.readAsStringSync()) as Map<String, Object?>;
  final cases = (document['cases']! as List<Object?>)
      .cast<Map<String, Object?>>();

  final results = {
    for (final c in cases)
      c['id']! as String: expectedToSpec(
        score(
          Category.parse(c['category']! as String),
          nutritionInputFromSpec(c['input']! as Map<String, Object?>),
        ),
      ),
  };
  File(args[0]).writeAsStringSync(
    '${jsonEncode({'engine': 'dart', 'results': results})}\n',
  );
  stdout.writeln('scored ${cases.length} cases into ${args[0]}');
}
