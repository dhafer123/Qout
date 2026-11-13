import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/api_generator.dart';

/// A minimal OpenAPI document with [paths] and [schemas].
Map<String, Object?> spec({
  Map<String, Object?> paths = const {},
  Map<String, Object?> schemas = const {},
}) => {
  'openapi': '3.1.0',
  'paths': paths,
  'components': {'schemas': schemas},
};

Map<String, Object?> getOperation({
  String id = 'getThing',
  List<Object?> parameters = const [],
  Map<String, Object?> schema = const {r'$ref': '#/components/schemas/Thing'},
  Map<String, Object?> extra = const {},
}) => {
  'get': {
    'operationId': id,
    'summary': 'Get a thing',
    'parameters': parameters,
    'responses': {
      '200': {
        'content': {
          'application/json': {'schema': schema},
        },
      },
    },
    ...extra,
  },
};

const Map<String, Object?> thing = {
  'type': 'object',
  'description': 'A thing.',
  'required': ['id', 'kind', 'tags', 'seen_at', 'extra', 'parts'],
  'properties': {
    'id': {'type': 'integer'},
    'kind': {r'$ref': '#/components/schemas/Kind'},
    'tags': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'seen_at': {'type': 'string', 'format': 'date-time'},
    'extra': {'type': 'object', 'additionalProperties': true},
    'parts': {
      'type': 'array',
      'items': {r'$ref': '#/components/schemas/Part'},
    },
    'weight': {
      'anyOf': [
        {'type': 'number'},
        {'type': 'null'},
      ],
      'description': 'Grams.',
    },
    'is_new': {'type': 'boolean'},
  },
};

const Map<String, Object?> kind = {
  'type': 'string',
  'enum': ['big_one', 'default', '2x', 'unknown'],
};

const Map<String, Object?> part = {
  'type': 'object',
  'required': ['name'],
  'properties': {
    'name': {'type': 'string'},
  },
};

String generated({
  Map<String, Object?>? paths,
  Map<String, Object?> schemas = const {
    'Thing': thing,
    'Kind': kind,
    'Part': part,
  },
}) => generateClient(
  spec(paths: paths ?? {'/v1/things/{id}': getOperation()}, schemas: schemas),
);

void main() {
  test('the committed spec generates a client', () {
    final committed =
        jsonDecode(File('../api/openapi.json').readAsStringSync())
            as Map<String, Object?>;
    final code = generateClient(committed);
    expect(code, contains('Future<ProductDetail> getProduct('));
    expect(code, isNot(contains('health'))); // only /v1/ operations
    expect(code, startsWith('// GENERATED CODE - DO NOT MODIFY BY HAND.'));
  });

  group('models', () {
    test('fields are typed, required ones first', () {
      final code = generated();
      expect(code, contains('class Thing {'));
      expect(code, contains('final int id;'));
      expect(code, contains('final Kind kind;'));
      expect(code, contains('final List<String> tags;'));
      expect(code, contains('final DateTime seenAt;'));
      expect(code, contains('final Map<String, Object?> extra;'));
      expect(code, contains('final List<Part> parts;'));
      expect(code, contains('final double? weight;'));
      expect(code, contains('final bool? isNew;')); // not required
      final constructor = RegExp(
        r'const Thing\(\{([^}]*)\}\)',
      ).firstMatch(code)!.group(1)!;
      expect(
        constructor.indexOf('required this.parts'),
        lessThan(constructor.indexOf('this.weight')),
      );
    });

    test('JSON keys stay snake_case', () {
      final code = generated();
      expect(
        code,
        contains("seenAt: DateTime.parse(json['seen_at']! as String)"),
      );
      expect(code, contains("'seen_at': seenAt.toIso8601String(),"));
      expect(code, contains("'is_new': isNew,"));
      expect(code, contains('parts.map((item) => item.toJson()).toList()'));
    });

    test('descriptions become doc comments', () {
      final code = generated();
      expect(code, contains('/// A thing.\n@immutable\nclass Thing'));
      expect(code, contains('  /// Grams.\n  final double? weight;'));
    });

    test('long descriptions are wrapped to 80 columns', () {
      final long = {...thing, 'description': List.filled(40, 'word').join(' ')};
      final code = generated(
        schemas: {'Thing': long, 'Kind': kind, 'Part': part},
      );
      final docs = code.split('\n').where((l) => l.startsWith('///'));
      expect(docs.length, greaterThan(1));
      expect(docs.every((l) => l.length <= 80), isTrue);
    });

    test('only schemas the operations use are generated', () {
      final code = generated(
        schemas: {'Thing': thing, 'Kind': kind, 'Part': part, 'Unused': part},
      );
      expect(code, isNot(contains('Unused')));
    });
  });

  group('enums', () {
    test('members are identifiers, with a fallback for new values', () {
      final code = generated();
      expect(code, contains("bigOne('big_one'),"));
      expect(code, contains("defaultValue('default'),"));
      expect(code, contains("v2x('2x'),"));
      expect(code, contains("unknown('unknown'),"));
      expect(code, contains("unrecognized('');"));
    });

    test('only string enums are supported', () {
      expect(
        () => generated(
          schemas: {
            'Thing': thing,
            'Kind': {
              'type': 'integer',
              'enum': [1, 2],
            },
            'Part': part,
          },
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('operations', () {
    test('path and query parameters', () {
      final code = generated(
        paths: {
          '/v1/things/{id}': getOperation(
            parameters: [
              {
                'name': 'id',
                'in': 'path',
                'required': true,
                'schema': {'type': 'integer'},
              },
              {
                'name': 'page_size',
                'in': 'query',
                'schema': {'type': 'integer'},
              },
              {
                'name': 'lang',
                'in': 'query',
                'required': true,
                'schema': {'type': 'string'},
              },
            ],
          ),
        },
      );
      expect(
        code,
        contains(
          'Future<Thing> getThing({required int id, required String lang, '
          'int? pageSize})',
        ),
      );
      expect(code, contains(r"'/v1/things/${Uri.encodeComponent('$id')}'"));
      expect(code, contains("'page_size': ?pageSize,"));
      expect(code, contains("'lang': lang,"));
      expect(code, contains('/// Get a thing'));
    });

    test('operations outside /v1/ are left out', () {
      final code = generated(
        paths: {
          '/health': getOperation(id: 'health'),
          '/v1/things/{id}': getOperation(),
        },
      );
      expect(code, isNot(contains('health')));
    });

    for (final (description, paths) in [
      (
        'POST',
        {
          '/v1/things': {'post': <String, Object?>{}},
        },
      ),
      (
        'a request body',
        {
          '/v1/things': getOperation(
            extra: {'requestBody': <String, Object?>{}},
          ),
        },
      ),
      (
        'a header parameter',
        {
          '/v1/things': getOperation(
            parameters: [
              {
                'name': 'x',
                'in': 'header',
                'schema': {'type': 'string'},
              },
            ],
          ),
        },
      ),
      (
        'anyOf with two types',
        {
          '/v1/things': getOperation(
            schema: {
              'anyOf': [
                {'type': 'string'},
                {'type': 'integer'},
              ],
            },
          ),
        },
      ),
      (
        'oneOf',
        {
          '/v1/things': getOperation(schema: {'oneOf': <Object?>[]}),
        },
      ),
      (
        'a remote reference',
        {
          '/v1/things': getOperation(schema: {r'$ref': 'other.json#/X'}),
        },
      ),
      (
        'a response without JSON',
        {
          '/v1/things': {
            'get': {
              'operationId': 'x',
              'responses': {'200': <String, Object?>{}},
            },
          },
        },
      ),
    ]) {
      test('$description is not supported', () {
        expect(
          () => generated(paths: paths),
          throwsA(isA<UnsupportedError>()),
        );
      });
    }

    test('a referenced schema that is not an object fails', () {
      expect(
        () => generated(
          schemas: {
            'Thing': {'type': 'string'},
          },
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('a missing operation id fails', () {
      expect(
        () => generated(paths: {'/v1/things': getOperation(id: '')}),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('operationId'),
          ),
        ),
      );
    });
  });
}
