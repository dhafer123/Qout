// GENERATED CODE - DO NOT MODIFY BY HAND.
//
// Generated from api/openapi.json by tool/gen_api.dart.
// Regenerate with scripts/gen_client.sh after changing the backend API.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;

/// `GET /v1/products/{ean}/alternatives`: best first.
@immutable
class ProductAlternatives {
  const ProductAlternatives({
    required this.ean,
    required this.items,
  });

  factory ProductAlternatives.fromJson(Map<String, Object?> json) =>
      ProductAlternatives(
        ean: json['ean']! as String,
        items: List<AlternativeProduct>.unmodifiable(
          (json['items']! as List<Object?>).map(
            (item) =>
                AlternativeProduct.fromJson(item! as Map<String, Object?>),
          ),
        ),
      );

  final String ean;

  final List<AlternativeProduct> items;

  Map<String, Object?> toJson() => <String, Object?>{
    'ean': ean,
    'items': items.map((item) => item.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAlternatives &&
          _deepEquals(ean, other.ean) &&
          _deepEquals(items, other.items);

  @override
  int get hashCode => Object.hashAll([_deepHash(ean), _deepHash(items)]);

  @override
  String toString() => 'ProductAlternatives(${toJson()})';
}

/// A product with a better grade, of the same kind (`GET .../alternatives`).
@immutable
class AlternativeProduct {
  const AlternativeProduct({
    required this.ean,
    required this.grade,
    this.name,
    this.brand,
    this.total,
    this.novaGroup,
  });

  factory AlternativeProduct.fromJson(Map<String, Object?> json) =>
      AlternativeProduct(
        ean: json['ean']! as String,
        name: json['name'] == null ? null : json['name']! as String,
        brand: json['brand'] == null ? null : json['brand']! as String,
        grade: Grade.fromJson(json['grade']),
        total: json['total'] == null ? null : json['total']! as int,
        novaGroup: json['nova_group'] == null
            ? null
            : json['nova_group']! as int,
      );

  final String ean;

  final String? name;

  final String? brand;

  final Grade grade;

  final int? total;

  final int? novaGroup;

  Map<String, Object?> toJson() => <String, Object?>{
    'ean': ean,
    'name': name,
    'brand': brand,
    'grade': grade.toJson(),
    'total': total,
    'nova_group': novaGroup,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlternativeProduct &&
          _deepEquals(ean, other.ean) &&
          _deepEquals(name, other.name) &&
          _deepEquals(brand, other.brand) &&
          _deepEquals(grade, other.grade) &&
          _deepEquals(total, other.total) &&
          _deepEquals(novaGroup, other.novaGroup);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(ean),
    _deepHash(name),
    _deepHash(brand),
    _deepHash(grade),
    _deepHash(total),
    _deepHash(novaGroup),
  ]);

  @override
  String toString() => 'AlternativeProduct(${toJson()})';
}

enum Grade {
  a('A'),
  b('B'),
  c('C'),
  d('D'),
  e('E'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const Grade(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory Grade.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('Grade: expected a string, got $json');
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

/// `GET /v1/products/{ean}`: everything the app shows for a scanned product.
@immutable
class ProductDetail {
  const ProductDetail({
    required this.ean,
    required this.source,
    required this.status,
    required this.additives,
    required this.updatedAt,
    this.name,
    this.brand,
    this.imageUrl,
    this.category,
    this.qualityFlag,
    this.novaGroup,
    this.nutrition,
    this.score,
  });

  factory ProductDetail.fromJson(Map<String, Object?> json) => ProductDetail(
    ean: json['ean']! as String,
    name: json['name'] == null ? null : json['name']! as String,
    brand: json['brand'] == null ? null : json['brand']! as String,
    imageUrl: json['image_url'] == null ? null : json['image_url']! as String,
    category: json['category'] == null
        ? null
        : Category.fromJson(json['category']),
    source: DataSource.fromJson(json['source']),
    status: ProductStatus.fromJson(json['status']),
    qualityFlag: json['quality_flag'] == null
        ? null
        : QualityFlag.fromJson(json['quality_flag']),
    novaGroup: json['nova_group'] == null ? null : json['nova_group']! as int,
    additives: List<AdditiveDetail>.unmodifiable(
      (json['additives']! as List<Object?>).map(
        (item) => AdditiveDetail.fromJson(item! as Map<String, Object?>),
      ),
    ),
    nutrition: json['nutrition'] == null
        ? null
        : NutritionDetail.fromJson(json['nutrition']! as Map<String, Object?>),
    score: json['score'] == null
        ? null
        : ScoreDetail.fromJson(json['score']! as Map<String, Object?>),
    updatedAt: DateTime.parse(json['updated_at']! as String),
  );

  final String ean;

  final String? name;

  final String? brand;

  final String? imageUrl;

  final Category? category;

  final DataSource source;

  final ProductStatus status;

  final QualityFlag? qualityFlag;

  final int? novaGroup;

  final List<AdditiveDetail> additives;

  final NutritionDetail? nutrition;

  final ScoreDetail? score;

  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'ean': ean,
    'name': name,
    'brand': brand,
    'image_url': imageUrl,
    'category': category?.toJson(),
    'source': source.toJson(),
    'status': status.toJson(),
    'quality_flag': qualityFlag?.toJson(),
    'nova_group': novaGroup,
    'additives': additives.map((item) => item.toJson()).toList(),
    'nutrition': nutrition?.toJson(),
    'score': score?.toJson(),
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductDetail &&
          _deepEquals(ean, other.ean) &&
          _deepEquals(name, other.name) &&
          _deepEquals(brand, other.brand) &&
          _deepEquals(imageUrl, other.imageUrl) &&
          _deepEquals(category, other.category) &&
          _deepEquals(source, other.source) &&
          _deepEquals(status, other.status) &&
          _deepEquals(qualityFlag, other.qualityFlag) &&
          _deepEquals(novaGroup, other.novaGroup) &&
          _deepEquals(additives, other.additives) &&
          _deepEquals(nutrition, other.nutrition) &&
          _deepEquals(score, other.score) &&
          _deepEquals(updatedAt, other.updatedAt);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(ean),
    _deepHash(name),
    _deepHash(brand),
    _deepHash(imageUrl),
    _deepHash(category),
    _deepHash(source),
    _deepHash(status),
    _deepHash(qualityFlag),
    _deepHash(novaGroup),
    _deepHash(additives),
    _deepHash(nutrition),
    _deepHash(score),
    _deepHash(updatedAt),
  ]);

  @override
  String toString() => 'ProductDetail(${toJson()})';
}

@immutable
class AdditiveDetail {
  const AdditiveDetail({
    required this.code,
    required this.overexposureRisk,
    this.name,
  });

  factory AdditiveDetail.fromJson(Map<String, Object?> json) => AdditiveDetail(
    code: json['code']! as String,
    name: json['name'] == null ? null : json['name']! as String,
    overexposureRisk: OverexposureRisk.fromJson(json['overexposure_risk']),
  );

  final String code;

  final String? name;

  final OverexposureRisk overexposureRisk;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'name': name,
    'overexposure_risk': overexposureRisk.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdditiveDetail &&
          _deepEquals(code, other.code) &&
          _deepEquals(name, other.name) &&
          _deepEquals(overexposureRisk, other.overexposureRisk);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(code),
    _deepHash(name),
    _deepHash(overexposureRisk),
  ]);

  @override
  String toString() => 'AdditiveDetail(${toJson()})';
}

/// Scoring category. Choosing it is the caller's job (see
/// docs/specs/README.md).
enum Category {
  general('general'),
  redMeat('red_meat'),
  cheese('cheese'),
  fatsOilsNutsSeeds('fats_oils_nuts_seeds'),
  beverage('beverage'),
  water('water'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const Category(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory Category.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('Category: expected a string, got $json');
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

enum DataSource {
  openFoodFacts('open_food_facts'),
  contribution('contribution'),
  manual('manual'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const DataSource(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory DataSource.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('DataSource: expected a string, got $json');
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

/// The latest declared nutrition, per 100 g or 100 mL (`basis`). None: not
/// declared.
@immutable
class NutritionDetail {
  const NutritionDetail({
    required this.version,
    required this.basis,
    required this.source,
    this.energyKj,
    this.sugarsG,
    this.saturatedFatG,
    this.totalFatG,
    this.saltG,
    this.fibreG,
    this.proteinG,
    this.fvlPercent,
    this.nonNutritiveSweeteners,
  });

  factory NutritionDetail.fromJson(Map<String, Object?> json) =>
      NutritionDetail(
        version: json['version']! as int,
        basis: NutritionBasis.fromJson(json['basis']),
        source: DataSource.fromJson(json['source']),
        energyKj: json['energy_kj'] == null
            ? null
            : (json['energy_kj']! as num).toDouble(),
        sugarsG: json['sugars_g'] == null
            ? null
            : (json['sugars_g']! as num).toDouble(),
        saturatedFatG: json['saturated_fat_g'] == null
            ? null
            : (json['saturated_fat_g']! as num).toDouble(),
        totalFatG: json['total_fat_g'] == null
            ? null
            : (json['total_fat_g']! as num).toDouble(),
        saltG: json['salt_g'] == null
            ? null
            : (json['salt_g']! as num).toDouble(),
        fibreG: json['fibre_g'] == null
            ? null
            : (json['fibre_g']! as num).toDouble(),
        proteinG: json['protein_g'] == null
            ? null
            : (json['protein_g']! as num).toDouble(),
        fvlPercent: json['fvl_percent'] == null
            ? null
            : (json['fvl_percent']! as num).toDouble(),
        nonNutritiveSweeteners: json['non_nutritive_sweeteners'] == null
            ? null
            : json['non_nutritive_sweeteners']! as bool,
      );

  final int version;

  final NutritionBasis basis;

  final DataSource source;

  final double? energyKj;

  final double? sugarsG;

  final double? saturatedFatG;

  final double? totalFatG;

  final double? saltG;

  final double? fibreG;

  final double? proteinG;

  final double? fvlPercent;

  final bool? nonNutritiveSweeteners;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'basis': basis.toJson(),
    'source': source.toJson(),
    'energy_kj': energyKj,
    'sugars_g': sugarsG,
    'saturated_fat_g': saturatedFatG,
    'total_fat_g': totalFatG,
    'salt_g': saltG,
    'fibre_g': fibreG,
    'protein_g': proteinG,
    'fvl_percent': fvlPercent,
    'non_nutritive_sweeteners': nonNutritiveSweeteners,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionDetail &&
          _deepEquals(version, other.version) &&
          _deepEquals(basis, other.basis) &&
          _deepEquals(source, other.source) &&
          _deepEquals(energyKj, other.energyKj) &&
          _deepEquals(sugarsG, other.sugarsG) &&
          _deepEquals(saturatedFatG, other.saturatedFatG) &&
          _deepEquals(totalFatG, other.totalFatG) &&
          _deepEquals(saltG, other.saltG) &&
          _deepEquals(fibreG, other.fibreG) &&
          _deepEquals(proteinG, other.proteinG) &&
          _deepEquals(fvlPercent, other.fvlPercent) &&
          _deepEquals(nonNutritiveSweeteners, other.nonNutritiveSweeteners);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(version),
    _deepHash(basis),
    _deepHash(source),
    _deepHash(energyKj),
    _deepHash(sugarsG),
    _deepHash(saturatedFatG),
    _deepHash(totalFatG),
    _deepHash(saltG),
    _deepHash(fibreG),
    _deepHash(proteinG),
    _deepHash(fvlPercent),
    _deepHash(nonNutritiveSweeteners),
  ]);

  @override
  String toString() => 'NutritionDetail(${toJson()})';
}

enum NutritionBasis {
  per100g('per_100g'),
  per100ml('per_100ml'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const NutritionBasis(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory NutritionBasis.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('NutritionBasis: expected a string, got $json');
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

/// EFSA's risk that part of the population exceeds the acceptable daily intake.
enum OverexposureRisk {
  high('high'),
  moderate('moderate'),
  none('none'),
  unknown('unknown'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const OverexposureRisk(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory OverexposureRisk.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('OverexposureRisk: expected a string, got $json');
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

enum ProductStatus {
  unverified('unverified'),
  verified('verified'),
  hidden('hidden'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const ProductStatus(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory ProductStatus.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('ProductStatus: expected a string, got $json');
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

/// Data quality, set by the Open Food Facts normaliser (T13).
enum QualityFlag {
  complete('complete'),
  incomplete('incomplete'),
  suspect('suspect'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const QualityFlag(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory QualityFlag.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('QualityFlag: expected a string, got $json');
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

@immutable
class ScoreDetail {
  const ScoreDetail({
    required this.engineVersion,
    required this.breakdown,
    required this.computedAt,
    this.grade,
    this.total,
  });

  factory ScoreDetail.fromJson(Map<String, Object?> json) => ScoreDetail(
    engineVersion: json['engine_version']! as String,
    grade: json['grade'] == null ? null : Grade.fromJson(json['grade']),
    total: json['total'] == null ? null : json['total']! as int,
    breakdown: Map<String, Object?>.unmodifiable(json['breakdown']! as Map),
    computedAt: DateTime.parse(json['computed_at']! as String),
  );

  final String engineVersion;

  final Grade? grade;

  final int? total;

  final Map<String, Object?> breakdown;

  final DateTime computedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'engine_version': engineVersion,
    'grade': grade?.toJson(),
    'total': total,
    'breakdown': breakdown,
    'computed_at': computedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreDetail &&
          _deepEquals(engineVersion, other.engineVersion) &&
          _deepEquals(grade, other.grade) &&
          _deepEquals(total, other.total) &&
          _deepEquals(breakdown, other.breakdown) &&
          _deepEquals(computedAt, other.computedAt);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(engineVersion),
    _deepHash(grade),
    _deepHash(total),
    _deepHash(breakdown),
    _deepHash(computedAt),
  ]);

  @override
  String toString() => 'ScoreDetail(${toJson()})';
}

/// Calls the Qout API through [Dio] (base URL, timeouts and logging are the
/// caller's configuration). Failures are [QoutApiException]s.
class QoutApi {
  QoutApi(this._dio);

  final Dio _dio;

  /// Look up a product by barcode
  ///
  /// Barcode: EAN-8, UPC-A (returned as EAN-13), EAN-13 or GTIN-14, with a
  /// valid check digit. Served from the cache or our database; unknown barcodes
  /// are looked up on Open Food Facts, stored and scored.
  Future<ProductDetail> getProduct({required String ean}) async {
    final json = await _get('/v1/products/${Uri.encodeComponent(ean)}');
    return _parse(() => ProductDetail.fromJson(json! as Map<String, Object?>));
  }

  /// Better alternatives to a product
  ///
  /// Products of the same kind (Nutri-Score category and shared Open Food Facts
  /// food categories) with a strictly better grade, closest nutrient profile
  /// first. Reads our database only; the product must have been looked up
  /// before. A product without a grade has no alternatives (empty list).
  Future<ProductAlternatives> getProductAlternatives({
    required String ean,
    int? limit,
  }) async {
    final json = await _get(
      '/v1/products/${Uri.encodeComponent(ean)}/alternatives',
      queryParameters: <String, Object?>{
        if (limit != null) 'limit': limit,
      },
    );
    return _parse(
      () => ProductAlternatives.fromJson(json! as Map<String, Object?>),
    );
  }

  Future<Object?> _get(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
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
      throw ApiBadResponse(null, 'unexpected response body: $error');
    }
  }
}

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
    return switch (response.statusCode) {
      404 => ApiNotFound(message),
      422 => ApiInvalidRequest(message),
      503 => ApiUnavailable(
        message,
        retryAfter: _seconds(response.headers.value('retry-after')),
      ),
      final status => ApiBadResponse(status, message),
    };
  }

  final String message;

  @override
  String toString() {
    final kind = switch (this) {
      ApiNotFound() => 'ApiNotFound',
      ApiInvalidRequest() => 'ApiInvalidRequest',
      ApiUnavailable() => 'ApiUnavailable',
      ApiConnectionError() => 'ApiConnectionError',
      ApiBadResponse() => 'ApiBadResponse',
    };
    return '$kind: $message';
  }
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
