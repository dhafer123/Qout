/// Generates the app's API client (models + a dio client) from the backend's
/// OpenAPI document (`api/openapi.json`).
///
/// Supports what FastAPI emits for the app's endpoints: objects with
/// properties, nullable values (`anyOf: [X, {type: null}]`), `$ref`, string
/// enums, string/integer/number/boolean, `date-time`, arrays and free-form
/// objects; GET and POST operations with path and query parameters, a JSON
/// request body (POST, a `$ref` schema) and a JSON (200, 201) or empty (204)
/// response. Operations with `security` are marked so the app's auth
/// interceptor adds the access token to them, and only to them. Anything else
/// throws [UnsupportedError] naming where it was found, so a new endpoint
/// never silently produces a wrong client.
library;

/// Operations whose path starts with this are generated (not `/health`).
const apiPathPrefix = '/v1/';

const _methods = {'get', 'post'};

const _header = '''
// GENERATED CODE - DO NOT MODIFY BY HAND.
//
// Generated from api/openapi.json by tool/gen_api.dart.
// Regenerate with scripts/gen_client.sh after changing the backend API.
''';

const _reserved = {
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch', //
  'class', 'const', 'continue', 'default', 'do', 'else', 'enum', 'extends',
  'false', 'final', 'finally', 'for', 'if', 'in', 'is', 'new', 'null',
  'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'var', 'void',
  'while', 'with', 'values', 'index', 'unrecognized', 'value',
};

/// Generates the Dart library for [spec] (a decoded OpenAPI 3.1 document).
String generateClient(Map<String, Object?> spec) => _Generator(spec).generate();

class _Type {
  const _Type(this.dart, this._decode, this._encode, {this.nullable = false});

  /// Dart type without the `?`.
  final String dart;
  final bool nullable;
  final String Function(String json) _decode;
  final String Function(String value, {required bool nullable}) _encode;

  String get declaration => nullable ? '$dart?' : dart;

  _Type asNullable() => _Type(dart, _decode, _encode, nullable: true);

  /// Expression turning [json] (an `Object?` expression) into this type.
  String decode(String json) =>
      nullable ? '$json == null ? null : ${_decode(json)}' : _decode(json);

  /// Expression turning [value] (of this type) into JSON.
  String encode(String value) => _encode(value, nullable: nullable);
}

String _same(String value, {required bool nullable}) => value;

class _Generator {
  _Generator(this.spec)
    : schemas = _map(
        _map(spec['components'], 'components')['schemas'],
        'components.schemas',
      );

  final Map<String, Object?> spec;
  final Map<String, Object?> schemas;
  final _used = <String>{};

  String generate() {
    final operations = _operations();
    final out = StringBuffer(_header)
      ..writeln()
      ..writeln("import 'package:dio/dio.dart';")
      ..writeln("import 'package:flutter/foundation.dart' show immutable;")
      ..writeln();
    final pending = [..._used];
    final written = <String>{};
    while (pending.isNotEmpty) {
      pending.sort();
      final name = pending.removeAt(0);
      if (!written.add(name)) continue;
      out.write(_schema(name));
      pending.addAll(_used.difference(written));
    }
    out
      ..write(_client(operations))
      ..write(_helpers);
    return out.toString();
  }

  // -------------------------------------------------------------- operations

  List<String> _operations() {
    final paths = _map(spec['paths'], 'paths');
    final methods = <String>[];
    for (final path in paths.keys.toList()..sort()) {
      if (!path.startsWith(apiPathPrefix)) continue;
      final operations = _map(paths[path], 'paths.$path');
      for (final method in operations.keys.toList()..sort()) {
        if (!_methods.contains(method)) {
          throw UnsupportedError('$method $path: only GET and POST');
        }
        methods.add(
          _operation(
            method,
            path,
            _map(operations[method], 'paths.$path.$method'),
          ),
        );
      }
    }
    return methods;
  }

  /// Required named parameters first (lint `always_put_required_named_
  /// parameters_first`), otherwise in spec order.
  static List<String> _requiredFirst(List<String> params) => [
    ...params.where((p) => p.startsWith('required ')),
    ...params.where((p) => !p.startsWith('required ')),
  ];

  String _operation(
    String method,
    String path,
    Map<String, Object?> operation,
  ) {
    final where = '${method.toUpperCase()} $path';
    final name = _string(operation['operationId'], '$where operationId');
    final params = <String>[];
    String? bodyArgument;
    if (operation['requestBody'] case final Object raw) {
      if (method != 'post') {
        throw UnsupportedError('$where: a request body needs POST');
      }
      final body = _map(raw, '$where requestBody');
      if (body['required'] != true) {
        throw UnsupportedError('$where: optional request bodies');
      }
      final content = _map(body['content'], '$where requestBody content');
      final schema = _map(
        _map(content['application/json'], '$where requestBody JSON')['schema'],
        '$where requestBody schema',
      );
      if (!schema.containsKey(r'$ref')) {
        throw UnsupportedError('$where: the request body must be a \$ref');
      }
      final type = _type(schema, '$where requestBody');
      params.add('required ${type.declaration} body');
      bodyArgument = 'body: body.toJson()';
    }
    final query = <String>[];
    var url = path;
    for (final raw in _list(operation['parameters'] ?? <Object?>[], where)) {
      final param = _map(raw, '$where parameter');
      final paramName = _string(param['name'], '$where parameter name');
      final dartName = _camel(paramName);
      final type = _type(param['schema'], '$where parameter $paramName');
      final required = param['required'] == true;
      final declared = required ? type : type.asNullable();
      params.add(
        '${required ? 'required ' : ''}${declared.declaration} $dartName',
      );
      switch (param['in']) {
        case 'path':
          final text = type.dart == 'String' ? dartName : "'\$$dartName'";
          url = url.replaceAll(
            '{$paramName}',
            '\${Uri.encodeComponent($text)}',
          );
        case 'query':
          // Optional parameters are left out when null (null-aware entry).
          query.add("'$paramName': ${required ? '' : '?'}$dartName,");
        default:
          throw UnsupportedError(
            '$where parameter $paramName: only path and query parameters',
          );
      }
    }
    final responses = _map(operation['responses'], '$where responses');
    final status = ['200', '201', '204'].firstWhere(
      responses.containsKey,
      orElse: () => throw UnsupportedError('$where: no 200, 201 or 204'),
    );
    _Type? result;
    if (status != '204') {
      final success = _map(responses[status], '$where $status response');
      final content = _map(success['content'], '$where $status content');
      final schema = _map(
        _map(content['application/json'], '$where $status JSON')['schema'],
        '$where $status schema',
      );
      result = _type(schema, '$where $status schema');
    }
    final authenticated = operation['security'] != null;
    final docs = [
      if (operation['summary'] case final String summary) summary,
      if (operation['description'] case final String description) description,
      if (authenticated)
        'Needs a signed-in user: the auth interceptor adds the access token.',
    ];
    final arguments = [
      "'$method'",
      "'$url'",
      if (query.isNotEmpty)
        'queryParameters: <String, Object?>{${query.join(' ')}}',
      ?bodyArgument,
      if (authenticated) 'authenticated: true',
    ].join(', ');
    final signature = params.isEmpty
        ? ''
        : '{${_requiredFirst(params).join(', ')}}';
    final docComment = _doc(docs.join('\n\n'), indent: 2);
    if (result == null) {
      return '''
$docComment  Future<void> $name($signature) async {
    await _send($arguments);
  }
''';
    }
    return '''
$docComment  Future<${result.declaration}> $name($signature) async {
    final json = await _send($arguments);
    return _parse(() => ${result.decode('json')});
  }
''';
  }

  // -------------------------------------------------------------- schemas

  _Type _type(Object? raw, String where) {
    final schema = _map(raw, where);
    if (schema['anyOf'] case final List<Object?> options) {
      final others = options
          .where((o) => !(o is Map && o['type'] == 'null'))
          .toList();
      if (others.length != 1 || options.length != 2) {
        throw UnsupportedError('$where: only anyOf [X, null] is supported');
      }
      return _type(others.single, where).asNullable();
    }
    if (schema[r'$ref'] case final String ref) {
      const prefix = '#/components/schemas/';
      if (!ref.startsWith(prefix)) {
        throw UnsupportedError('$where: unsupported \$ref $ref');
      }
      final name = ref.substring(prefix.length);
      final target = _map(schemas[name], 'components.schemas.$name');
      _used.add(name);
      if (target.containsKey('enum')) {
        return _Type(
          name,
          (json) => '$name.fromJson($json)',
          (value, {required nullable}) =>
              nullable ? '$value?.toJson()' : '$value.toJson()',
        );
      }
      return _Type(
        name,
        (json) => '$name.fromJson($json! as Map<String, Object?>)',
        (value, {required nullable}) =>
            nullable ? '$value?.toJson()' : '$value.toJson()',
      );
    }
    switch (schema['type']) {
      case 'string' when schema['format'] == 'date-time':
        return _Type(
          'DateTime',
          (json) => 'DateTime.parse($json! as String)',
          (value, {required nullable}) => nullable
              ? '$value?.toIso8601String()'
              : '$value.toIso8601String()',
        );
      case 'string' when !schema.containsKey('enum'):
        return _Type('String', (json) => '$json! as String', _same);
      case 'integer':
        return _Type('int', (json) => '$json! as int', _same);
      case 'number':
        return _Type('double', (json) => '($json! as num).toDouble()', _same);
      case 'boolean':
        return _Type('bool', (json) => '$json! as bool', _same);
      case 'array':
        final item = _type(schema['items'], '$where items');
        final itemJson = item.encode('item');
        return _Type(
          'List<${item.declaration}>',
          (json) =>
              'List<${item.declaration}>.unmodifiable(($json! as List<Object?>)'
              ' .map((item) => ${item.decode('item')}))',
          (value, {required nullable}) => itemJson == 'item'
              ? value
              : '$value${nullable ? '?' : ''}'
                    '.map((item) => $itemJson).toList()',
        );
      case 'object'
          when !schema.containsKey('properties') &&
              schema['additionalProperties'] == true:
        return _Type(
          'Map<String, Object?>',
          (json) => 'Map<String, Object?>.unmodifiable($json! as Map)',
          _same,
        );
    }
    throw UnsupportedError('$where: unsupported schema $schema');
  }

  String _schema(String name) {
    final schema = _map(schemas[name], 'components.schemas.$name');
    if (schema['enum'] case final List<Object?> values) {
      return _enum(name, schema, values);
    }
    if (schema['type'] != 'object' || !schema.containsKey('properties')) {
      throw UnsupportedError('components.schemas.$name: not an object or enum');
    }
    return _class(name, schema);
  }

  String _enum(String name, Map<String, Object?> schema, List<Object?> raw) {
    if (schema['type'] != 'string') {
      throw UnsupportedError('components.schemas.$name: only string enums');
    }
    final values = [for (final v in raw) _string(v, '$name enum value')];
    final members = [
      for (final value in values) "  ${_member(value)}('$value'),",
      '  /// A value this app version does not know (from a newer backend).',
      "  unrecognized('');",
    ];
    return '''
${_doc(_description(schema))}enum $name {
${members.join('\n')}

  const $name(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory $name.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('$name: expected a string, got \$json');
    }
    for (final member in values) {
      if (member != unrecognized && member.value == json) return member;
    }
    return unrecognized;
  }

  /// The value sent by the API.
  final String value;

  String toJson() => value;
}

''';
  }

  String _class(String name, Map<String, Object?> schema) {
    final properties = _map(schema['properties'], '$name properties');
    final required = {
      for (final r in _list(schema['required'] ?? <Object?>[], name))
        _string(r, '$name required'),
    };
    final fields = <({String json, String dart, _Type type, String doc})>[];
    for (final entry in properties.entries) {
      final where = 'components.schemas.$name.${entry.key}';
      var type = _type(entry.value, where);
      if (!required.contains(entry.key)) type = type.asNullable();
      final property = _map(entry.value, where);
      fields.add((
        json: entry.key,
        dart: _camel(entry.key),
        type: type,
        doc: _description(property),
      ));
    }
    // Required parameters first; nullable ones are optional (default null).
    final constructor =
        [
              ...fields.where((f) => !f.type.nullable),
              ...fields.where((f) => f.type.nullable),
            ]
            .map((f) => '${f.type.nullable ? '' : 'required '}this.${f.dart},')
            .join(' ');
    final fromJson = fields
        .map((f) => "${f.dart}: ${f.type.decode("json['${f.json}']")},")
        .join('\n');
    final declarations = fields
        .map(
          (f) =>
              '${_doc(f.doc, indent: 2)}  final ${f.type.declaration} '
              '${f.dart};',
        )
        .join('\n\n');
    final toJson = fields
        .map((f) => "'${f.json}': ${f.type.encode(f.dart)},")
        .join('\n');
    final equals = fields
        .map((f) => '_deepEquals(${f.dart}, other.${f.dart})')
        .join(' && ');
    final hash = fields.map((f) => '_deepHash(${f.dart})').join(', ');
    return '''
${_doc(_description(schema))}@immutable
class $name {
  const $name({$constructor});

  factory $name.fromJson(Map<String, Object?> json) => $name(
    $fromJson
  );

$declarations

  Map<String, Object?> toJson() => <String, Object?>{
    $toJson
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is $name && $equals;

  @override
  int get hashCode => Object.hashAll([$hash]);

  @override
  String toString() => '$name(\${toJson()})';
}

''';
  }

  // -------------------------------------------------------------- client

  String _client(List<String> operations) =>
      '''
/// `RequestOptions.extra` key: true on calls that need the signed-in user's
/// access token (the app's auth interceptor adds it).
const authenticatedRequestKey = 'qout.authenticated';

/// Calls the Qout API through [Dio] (base URL, timeouts, logging and the
/// auth interceptor are the caller's configuration). Failures are
/// [QoutApiException]s.
class QoutApi {
  QoutApi(this._dio);

  final Dio _dio;

${operations.join('\n')}
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, Object?>? queryParameters,
    Object? body,
    bool authenticated = false,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: Options(
          method: method.toUpperCase(),
          extra: {authenticatedRequestKey: authenticated},
        ),
      );
      return response.data;
    } on DioException catch (error) {
      throw QoutApiException.fromDio(error);
    }
  }

  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on Object catch (error) {
      throw ApiBadResponse(null, 'unexpected response body: \$error');
    }
  }
}

''';
}

// ---------------------------------------------------------------- helpers

/// Exceptions and equality helpers, the same for every generated client.
const _helpers = r'''
/// Why an API call failed.
sealed class QoutApiException implements Exception {
  const QoutApiException(this.message);

  /// Maps dio's error to the matching exception.
  factory QoutApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return ApiConnectionError(error.message ?? error.type.name);
    }
    final message = _detail(response.data) ?? 'HTTP ${response.statusCode}';
    final retryAfter = _seconds(response.headers.value('retry-after'));
    return switch (response.statusCode) {
      401 => ApiUnauthorized(message),
      404 => ApiNotFound(message),
      409 => ApiConflict(message),
      422 => ApiInvalidRequest(message),
      429 => ApiTooManyRequests(message, retryAfter: retryAfter),
      503 => ApiUnavailable(message, retryAfter: retryAfter),
      final status => ApiBadResponse(status, message),
    };
  }

  final String message;

  @override
  String toString() {
    final kind = switch (this) {
      ApiUnauthorized() => 'ApiUnauthorized',
      ApiNotFound() => 'ApiNotFound',
      ApiConflict() => 'ApiConflict',
      ApiTooManyRequests() => 'ApiTooManyRequests',
      ApiInvalidRequest() => 'ApiInvalidRequest',
      ApiUnavailable() => 'ApiUnavailable',
      ApiConnectionError() => 'ApiConnectionError',
      ApiBadResponse() => 'ApiBadResponse',
    };
    return '$kind: $message';
  }
}

/// 401: not signed in, wrong credentials, or an expired or used token.
final class ApiUnauthorized extends QoutApiException {
  const ApiUnauthorized(super.message);
}

/// 409: conflicts with what exists, e.g. an email already registered.
final class ApiConflict extends QoutApiException {
  const ApiConflict(super.message);
}

/// 429: too many attempts; try again after [retryAfter] if given.
final class ApiTooManyRequests extends QoutApiException {
  const ApiTooManyRequests(super.message, {this.retryAfter});

  final Duration? retryAfter;
}

/// 404: e.g. a barcode nobody knows.
final class ApiNotFound extends QoutApiException {
  const ApiNotFound(super.message);
}

/// 422: the request was rejected, e.g. not a valid barcode.
final class ApiInvalidRequest extends QoutApiException {
  const ApiInvalidRequest(super.message);
}

/// 503: temporarily unavailable; try again after [retryAfter] if given.
final class ApiUnavailable extends QoutApiException {
  const ApiUnavailable(super.message, {this.retryAfter});

  final Duration? retryAfter;
}

/// No response: offline, DNS, timeout, connection refused.
final class ApiConnectionError extends QoutApiException {
  const ApiConnectionError(super.message);
}

/// Any other status, or a body that doesn't match the API spec.
final class ApiBadResponse extends QoutApiException {
  const ApiBadResponse(this.statusCode, String message) : super(message);

  final int? statusCode;
}

String? _detail(Object? body) => switch (body) {
  {'detail': final String detail} => detail,
  _ => null,
};

Duration? _seconds(String? header) {
  final seconds = int.tryParse(header ?? '');
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

bool _deepEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

int _deepHash(Object? value) => switch (value) {
  final List<Object?> list => Object.hashAll(list.map(_deepHash)),
  final Map<Object?, Object?> map => Object.hashAllUnordered(
    map.entries.map((e) => Object.hash(e.key, _deepHash(e.value))),
  ),
  _ => value.hashCode,
};
''';

// ---------------------------------------------------------------- utilities

Map<String, Object?> _map(Object? value, String where) {
  if (value is Map<String, Object?>) return value;
  throw UnsupportedError('$where: expected an object, got $value');
}

List<Object?> _list(Object? value, String where) {
  if (value is List<Object?>) return value;
  throw UnsupportedError('$where: expected a list, got $value');
}

String _string(Object? value, String where) {
  if (value is String && value.isNotEmpty) return value;
  throw UnsupportedError('$where: expected a string, got $value');
}

String _description(Map<String, Object?> schema) =>
    schema['description'] is String ? schema['description']! as String : '';

/// `snake_case` (or `kebab-case`) to `lowerCamelCase`, safe as an identifier.
String _camel(String name) {
  final parts = name.split(RegExp('[^A-Za-z0-9]+')).where((p) => p.isNotEmpty);
  final words = [
    for (final (i, part) in parts.indexed)
      i == 0
          ? part.toLowerCase()
          : part[0].toUpperCase() + part.substring(1).toLowerCase(),
  ];
  var identifier = words.join();
  if (identifier.isEmpty || RegExp('^[0-9]').hasMatch(identifier)) {
    identifier = 'v$identifier';
  }
  return _reserved.contains(identifier) ? '${identifier}Value' : identifier;
}

String _member(String value) => _camel(value);

/// A `///` doc comment wrapped to fit 80 columns at [indent], or nothing.
String _doc(String text, {int indent = 0}) {
  if (text.trim().isEmpty) return '';
  final prefix = '${' ' * indent}/// ';
  final width = 80 - prefix.length;
  final lines = <String>[];
  for (final paragraph in text.trim().split(RegExp(r'\n\s*\n'))) {
    if (lines.isNotEmpty) lines.add('');
    var line = '';
    for (final word in paragraph.split(RegExp(r'\s+'))) {
      if (line.isNotEmpty && line.length + 1 + word.length > width) {
        lines.add(line);
        line = word;
      } else {
        line = line.isEmpty ? word : '$line $word';
      }
    }
    if (line.isNotEmpty) lines.add(line);
  }
  return lines
      .map((l) => l.isEmpty ? '${' ' * indent}///' : '$prefix$l')
      .map((l) => '$l\n')
      .join();
}
