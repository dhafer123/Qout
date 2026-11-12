// Generates lib/core/api/qout_api.dart from the backend's OpenAPI document.
//
//   dart run tool/gen_api.dart ../api/openapi.json lib/core/api/qout_api.dart
//
// Normally run through scripts/gen_client.sh, which also formats the output.
import 'dart:convert';
import 'dart:io';

import 'api_generator.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: dart run tool/gen_api.dart <openapi.json> <out>');
    exitCode = 64;
    return;
  }
  final spec = jsonDecode(File(args[0]).readAsStringSync());
  if (spec is! Map<String, Object?>) {
    stderr.writeln('${args[0]}: not an OpenAPI document');
    exitCode = 65;
    return;
  }
  File(args[1])
    ..createSync(recursive: true)
    ..writeAsStringSync(generateClient(spec));
  stdout.writeln('wrote ${args[1]}');
}
