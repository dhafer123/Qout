// GENERATED CODE - DO NOT MODIFY BY HAND.
//
// Generated from api/openapi.json by tool/gen_api.dart.
// Regenerate with scripts/gen_client.sh after changing the backend API.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;

@immutable
class ContributionCreate {
  const ContributionCreate({
    required this.clientId,
    required this.ean,
    required this.category,
    required this.basis,
    required this.nutrition,
    required this.photos,
    required this.parserUsed,
    this.name,
    this.brand,
    this.ocrText,
  });

  factory ContributionCreate.fromJson(Map<String, Object?> json) =>
      ContributionCreate(
        clientId: json['client_id']! as String,
        ean: json['ean']! as String,
        name: json['name'] == null ? null : json['name']! as String,
        brand: json['brand'] == null ? null : json['brand']! as String,
        category: Category.fromJson(json['category']),
        basis: NutritionBasis.fromJson(json['basis']),
        nutrition: NutritionValues.fromJson(
          json['nutrition']! as Map<String, Object?>,
        ),
        photos: ContributionPhotos.fromJson(
          json['photos']! as Map<String, Object?>,
        ),
        ocrText: json['ocr_text'] == null
            ? null
            : ContributionOcr.fromJson(
                json['ocr_text']! as Map<String, Object?>,
              ),
        parserUsed: ParserUsed.fromJson(json['parser_used']),
      );

  final String clientId;

  final String ean;

  final String? name;

  final String? brand;

  final Category category;

  final NutritionBasis basis;

  final NutritionValues nutrition;

  final ContributionPhotos photos;

  final ContributionOcr? ocrText;

  final ParserUsed parserUsed;

  Map<String, Object?> toJson() => <String, Object?>{
    'client_id': clientId,
    'ean': ean,
    'name': name,
    'brand': brand,
    'category': category.toJson(),
    'basis': basis.toJson(),
    'nutrition': nutrition.toJson(),
    'photos': photos.toJson(),
    'ocr_text': ocrText?.toJson(),
    'parser_used': parserUsed.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributionCreate &&
          _deepEquals(clientId, other.clientId) &&
          _deepEquals(ean, other.ean) &&
          _deepEquals(name, other.name) &&
          _deepEquals(brand, other.brand) &&
          _deepEquals(category, other.category) &&
          _deepEquals(basis, other.basis) &&
          _deepEquals(nutrition, other.nutrition) &&
          _deepEquals(photos, other.photos) &&
          _deepEquals(ocrText, other.ocrText) &&
          _deepEquals(parserUsed, other.parserUsed);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(clientId),
    _deepHash(ean),
    _deepHash(name),
    _deepHash(brand),
    _deepHash(category),
    _deepHash(basis),
    _deepHash(nutrition),
    _deepHash(photos),
    _deepHash(ocrText),
    _deepHash(parserUsed),
  ]);

  @override
  String toString() => 'ContributionCreate(${toJson()})';
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

@immutable
class ContributionList {
  const ContributionList({
    required this.items,
  });

  factory ContributionList.fromJson(Map<String, Object?> json) =>
      ContributionList(
        items: List<ContributionRead>.unmodifiable(
          (json['items']! as List<Object?>).map(
            (item) => ContributionRead.fromJson(item! as Map<String, Object?>),
          ),
        ),
      );

  final List<ContributionRead> items;

  Map<String, Object?> toJson() => <String, Object?>{
    'items': items.map((item) => item.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributionList && _deepEquals(items, other.items);

  @override
  int get hashCode => Object.hashAll([_deepHash(items)]);

  @override
  String toString() => 'ContributionList(${toJson()})';
}

/// Text read from each photo on the phone.
@immutable
class ContributionOcr {
  const ContributionOcr({
    this.front,
    this.nutrition,
    this.ingredients,
  });

  factory ContributionOcr.fromJson(Map<String, Object?> json) =>
      ContributionOcr(
        front: json['front'] == null ? null : json['front']! as String,
        nutrition: json['nutrition'] == null
            ? null
            : json['nutrition']! as String,
        ingredients: json['ingredients'] == null
            ? null
            : json['ingredients']! as String,
      );

  final String? front;

  final String? nutrition;

  final String? ingredients;

  Map<String, Object?> toJson() => <String, Object?>{
    'front': front,
    'nutrition': nutrition,
    'ingredients': ingredients,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributionOcr &&
          _deepEquals(front, other.front) &&
          _deepEquals(nutrition, other.nutrition) &&
          _deepEquals(ingredients, other.ingredients);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(front),
    _deepHash(nutrition),
    _deepHash(ingredients),
  ]);

  @override
  String toString() => 'ContributionOcr(${toJson()})';
}

/// Keys returned by `POST /v1/uploads` for this contribution, once uploaded.
@immutable
class ContributionPhotos {
  const ContributionPhotos({
    required this.front,
    required this.nutrition,
    this.ingredients,
  });

  factory ContributionPhotos.fromJson(Map<String, Object?> json) =>
      ContributionPhotos(
        front: json['front']! as String,
        nutrition: json['nutrition']! as String,
        ingredients: json['ingredients'] == null
            ? null
            : json['ingredients']! as String,
      );

  final String front;

  final String nutrition;

  final String? ingredients;

  Map<String, Object?> toJson() => <String, Object?>{
    'front': front,
    'nutrition': nutrition,
    'ingredients': ingredients,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributionPhotos &&
          _deepEquals(front, other.front) &&
          _deepEquals(nutrition, other.nutrition) &&
          _deepEquals(ingredients, other.ingredients);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(front),
    _deepHash(nutrition),
    _deepHash(ingredients),
  ]);

  @override
  String toString() => 'ContributionPhotos(${toJson()})';
}

/// A contribution as its contributor sees it.
@immutable
class ContributionRead {
  const ContributionRead({
    required this.id,
    required this.clientId,
    required this.ean,
    required this.category,
    required this.status,
    required this.createdAt,
    this.name,
    this.brand,
    this.reviewNote,
    this.reviewedAt,
  });

  factory ContributionRead.fromJson(Map<String, Object?> json) =>
      ContributionRead(
        id: json['id']! as String,
        clientId: json['client_id']! as String,
        ean: json['ean']! as String,
        name: json['name'] == null ? null : json['name']! as String,
        brand: json['brand'] == null ? null : json['brand']! as String,
        category: Category.fromJson(json['category']),
        status: ContributionStatus.fromJson(json['status']),
        reviewNote: json['review_note'] == null
            ? null
            : json['review_note']! as String,
        createdAt: DateTime.parse(json['created_at']! as String),
        reviewedAt: json['reviewed_at'] == null
            ? null
            : DateTime.parse(json['reviewed_at']! as String),
      );

  final String id;

  final String clientId;

  final String ean;

  final String? name;

  final String? brand;

  final Category category;

  final ContributionStatus status;

  final String? reviewNote;

  final DateTime createdAt;

  final DateTime? reviewedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'client_id': clientId,
    'ean': ean,
    'name': name,
    'brand': brand,
    'category': category.toJson(),
    'status': status.toJson(),
    'review_note': reviewNote,
    'created_at': createdAt.toIso8601String(),
    'reviewed_at': reviewedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributionRead &&
          _deepEquals(id, other.id) &&
          _deepEquals(clientId, other.clientId) &&
          _deepEquals(ean, other.ean) &&
          _deepEquals(name, other.name) &&
          _deepEquals(brand, other.brand) &&
          _deepEquals(category, other.category) &&
          _deepEquals(status, other.status) &&
          _deepEquals(reviewNote, other.reviewNote) &&
          _deepEquals(createdAt, other.createdAt) &&
          _deepEquals(reviewedAt, other.reviewedAt);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(id),
    _deepHash(clientId),
    _deepHash(ean),
    _deepHash(name),
    _deepHash(brand),
    _deepHash(category),
    _deepHash(status),
    _deepHash(reviewNote),
    _deepHash(createdAt),
    _deepHash(reviewedAt),
  ]);

  @override
  String toString() => 'ContributionRead(${toJson()})';
}

enum ContributionStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const ContributionStatus(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory ContributionStatus.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('ContributionStatus: expected a string, got $json');
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

/// Registration and login. Emails are compared lower-cased.
@immutable
class Credentials {
  const Credentials({
    required this.email,
    required this.password,
  });

  factory Credentials.fromJson(Map<String, Object?> json) => Credentials(
    email: json['email']! as String,
    password: json['password']! as String,
  );

  final String email;

  final String password;

  Map<String, Object?> toJson() => <String, Object?>{
    'email': email,
    'password': password,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Credentials &&
          _deepEquals(email, other.email) &&
          _deepEquals(password, other.password);

  @override
  int get hashCode => Object.hashAll([_deepHash(email), _deepHash(password)]);

  @override
  String toString() => 'Credentials(${toJson()})';
}

/// The LLM fallback parser's reading of a label, read in the background.
@immutable
class LabelFallbackRead {
  const LabelFallbackRead({
    required this.id,
    required this.status,
    required this.createdAt,
    this.reason,
    this.result,
    this.completedAt,
  });

  factory LabelFallbackRead.fromJson(Map<String, Object?> json) =>
      LabelFallbackRead(
        id: json['id']! as String,
        status: FallbackStatus.fromJson(json['status']),
        reason: json['reason'] == null
            ? null
            : FallbackReason.fromJson(json['reason']),
        result: json['result'] == null
            ? null
            : LabelReading.fromJson(json['result']! as Map<String, Object?>),
        createdAt: DateTime.parse(json['created_at']! as String),
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at']! as String),
      );

  final String id;

  final FallbackStatus status;

  final FallbackReason? reason;

  final LabelReading? result;

  final DateTime createdAt;

  final DateTime? completedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'status': status.toJson(),
    'reason': reason?.toJson(),
    'result': result?.toJson(),
    'created_at': createdAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelFallbackRead &&
          _deepEquals(id, other.id) &&
          _deepEquals(status, other.status) &&
          _deepEquals(reason, other.reason) &&
          _deepEquals(result, other.result) &&
          _deepEquals(createdAt, other.createdAt) &&
          _deepEquals(completedAt, other.completedAt);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(id),
    _deepHash(status),
    _deepHash(reason),
    _deepHash(result),
    _deepHash(createdAt),
    _deepHash(completedAt),
  ]);

  @override
  String toString() => 'LabelFallbackRead(${toJson()})';
}

/// Why the LLM fallback gave no values (the contributor types them).
enum FallbackReason {
  disabled('disabled'),
  rateLimited('rate_limited'),
  timeout('timeout'),
  unavailable('unavailable'),
  refused('refused'),
  invalidOutput('invalid_output'),
  ungroundedValue('ungrounded_value'),
  failedChecks('failed_checks'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const FallbackReason(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory FallbackReason.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('FallbackReason: expected a string, got $json');
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

/// A request to the LLM fallback parser (T28).
enum FallbackStatus {
  pending('pending'),
  done('done'),
  needsManualEntry('needs_manual_entry'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const FallbackStatus(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory FallbackStatus.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('FallbackStatus: expected a string, got $json');
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
class LabelParseRequest {
  const LabelParseRequest({
    required this.ocrText,
  });

  factory LabelParseRequest.fromJson(Map<String, Object?> json) =>
      LabelParseRequest(
        ocrText: json['ocr_text']! as String,
      );

  final String ocrText;

  Map<String, Object?> toJson() => <String, Object?>{
    'ocr_text': ocrText,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelParseRequest && _deepEquals(ocrText, other.ocrText);

  @override
  int get hashCode => Object.hashAll([_deepHash(ocrText)]);

  @override
  String toString() => 'LabelParseRequest(${toJson()})';
}

/// The rule-based parser's reading, and the LLM fallback when that one is not
/// ok.
@immutable
class LabelParseResult {
  const LabelParseResult({
    required this.parserUsed,
    required this.ok,
    required this.valuesValue,
    required this.derived,
    required this.approximate,
    required this.issues,
    this.basis,
    this.fallback,
  });

  factory LabelParseResult.fromJson(
    Map<String, Object?> json,
  ) => LabelParseResult(
    parserUsed: ParserUsed.fromJson(json['parser_used']),
    ok: json['ok']! as bool,
    basis: json['basis'] == null
        ? null
        : NutritionBasis.fromJson(json['basis']),
    valuesValue: LabelValues.fromJson(json['values']! as Map<String, Object?>),
    derived: List<String>.unmodifiable(
      (json['derived']! as List<Object?>).map((item) => item! as String),
    ),
    approximate: List<String>.unmodifiable(
      (json['approximate']! as List<Object?>).map((item) => item! as String),
    ),
    issues: List<LabelIssueRead>.unmodifiable(
      (json['issues']! as List<Object?>).map(
        (item) => LabelIssueRead.fromJson(item! as Map<String, Object?>),
      ),
    ),
    fallback: json['fallback'] == null
        ? null
        : LabelFallbackRead.fromJson(json['fallback']! as Map<String, Object?>),
  );

  final ParserUsed parserUsed;

  final bool ok;

  final NutritionBasis? basis;

  final LabelValues valuesValue;

  final List<String> derived;

  final List<String> approximate;

  final List<LabelIssueRead> issues;

  final LabelFallbackRead? fallback;

  Map<String, Object?> toJson() => <String, Object?>{
    'parser_used': parserUsed.toJson(),
    'ok': ok,
    'basis': basis?.toJson(),
    'values': valuesValue.toJson(),
    'derived': derived,
    'approximate': approximate,
    'issues': issues.map((item) => item.toJson()).toList(),
    'fallback': fallback?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelParseResult &&
          _deepEquals(parserUsed, other.parserUsed) &&
          _deepEquals(ok, other.ok) &&
          _deepEquals(basis, other.basis) &&
          _deepEquals(valuesValue, other.valuesValue) &&
          _deepEquals(derived, other.derived) &&
          _deepEquals(approximate, other.approximate) &&
          _deepEquals(issues, other.issues) &&
          _deepEquals(fallback, other.fallback);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(parserUsed),
    _deepHash(ok),
    _deepHash(basis),
    _deepHash(valuesValue),
    _deepHash(derived),
    _deepHash(approximate),
    _deepHash(issues),
    _deepHash(fallback),
  ]);

  @override
  String toString() => 'LabelParseResult(${toJson()})';
}

@immutable
class LabelIssueRead {
  const LabelIssueRead({
    required this.code,
    required this.blocking,
    this.field,
  });

  factory LabelIssueRead.fromJson(Map<String, Object?> json) => LabelIssueRead(
    code: json['code']! as String,
    field: json['field'] == null ? null : json['field']! as String,
    blocking: json['blocking']! as bool,
  );

  final String code;

  final String? field;

  final bool blocking;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'field': field,
    'blocking': blocking,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelIssueRead &&
          _deepEquals(code, other.code) &&
          _deepEquals(field, other.field) &&
          _deepEquals(blocking, other.blocking);

  @override
  int get hashCode =>
      Object.hashAll([_deepHash(code), _deepHash(field), _deepHash(blocking)]);

  @override
  String toString() => 'LabelIssueRead(${toJson()})';
}

/// Values read from a label by one parser.
@immutable
class LabelReading {
  const LabelReading({
    required this.parserUsed,
    required this.ok,
    required this.valuesValue,
    required this.derived,
    required this.approximate,
    required this.issues,
    this.basis,
  });

  factory LabelReading.fromJson(Map<String, Object?> json) => LabelReading(
    parserUsed: ParserUsed.fromJson(json['parser_used']),
    ok: json['ok']! as bool,
    basis: json['basis'] == null
        ? null
        : NutritionBasis.fromJson(json['basis']),
    valuesValue: LabelValues.fromJson(json['values']! as Map<String, Object?>),
    derived: List<String>.unmodifiable(
      (json['derived']! as List<Object?>).map((item) => item! as String),
    ),
    approximate: List<String>.unmodifiable(
      (json['approximate']! as List<Object?>).map((item) => item! as String),
    ),
    issues: List<LabelIssueRead>.unmodifiable(
      (json['issues']! as List<Object?>).map(
        (item) => LabelIssueRead.fromJson(item! as Map<String, Object?>),
      ),
    ),
  );

  final ParserUsed parserUsed;

  final bool ok;

  final NutritionBasis? basis;

  final LabelValues valuesValue;

  final List<String> derived;

  final List<String> approximate;

  final List<LabelIssueRead> issues;

  Map<String, Object?> toJson() => <String, Object?>{
    'parser_used': parserUsed.toJson(),
    'ok': ok,
    'basis': basis?.toJson(),
    'values': valuesValue.toJson(),
    'derived': derived,
    'approximate': approximate,
    'issues': issues.map((item) => item.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelReading &&
          _deepEquals(parserUsed, other.parserUsed) &&
          _deepEquals(ok, other.ok) &&
          _deepEquals(basis, other.basis) &&
          _deepEquals(valuesValue, other.valuesValue) &&
          _deepEquals(derived, other.derived) &&
          _deepEquals(approximate, other.approximate) &&
          _deepEquals(issues, other.issues);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(parserUsed),
    _deepHash(ok),
    _deepHash(basis),
    _deepHash(valuesValue),
    _deepHash(derived),
    _deepHash(approximate),
    _deepHash(issues),
  ]);

  @override
  String toString() => 'LabelReading(${toJson()})';
}

/// Values read from the label, per 100 g or 100 mL; null: not found. Not
/// checked against the request limits: a value can be impossible (see
/// `issues`).
@immutable
class LabelValues {
  const LabelValues({
    this.energyKj,
    this.energyKcal,
    this.totalFatG,
    this.saturatedFatG,
    this.carbohydratesG,
    this.sugarsG,
    this.fibreG,
    this.proteinG,
    this.saltG,
    this.sodiumG,
  });

  factory LabelValues.fromJson(Map<String, Object?> json) => LabelValues(
    energyKj: json['energy_kj'] == null
        ? null
        : (json['energy_kj']! as num).toDouble(),
    energyKcal: json['energy_kcal'] == null
        ? null
        : (json['energy_kcal']! as num).toDouble(),
    totalFatG: json['total_fat_g'] == null
        ? null
        : (json['total_fat_g']! as num).toDouble(),
    saturatedFatG: json['saturated_fat_g'] == null
        ? null
        : (json['saturated_fat_g']! as num).toDouble(),
    carbohydratesG: json['carbohydrates_g'] == null
        ? null
        : (json['carbohydrates_g']! as num).toDouble(),
    sugarsG: json['sugars_g'] == null
        ? null
        : (json['sugars_g']! as num).toDouble(),
    fibreG: json['fibre_g'] == null
        ? null
        : (json['fibre_g']! as num).toDouble(),
    proteinG: json['protein_g'] == null
        ? null
        : (json['protein_g']! as num).toDouble(),
    saltG: json['salt_g'] == null ? null : (json['salt_g']! as num).toDouble(),
    sodiumG: json['sodium_g'] == null
        ? null
        : (json['sodium_g']! as num).toDouble(),
  );

  final double? energyKj;

  final double? energyKcal;

  final double? totalFatG;

  final double? saturatedFatG;

  final double? carbohydratesG;

  final double? sugarsG;

  final double? fibreG;

  final double? proteinG;

  final double? saltG;

  final double? sodiumG;

  Map<String, Object?> toJson() => <String, Object?>{
    'energy_kj': energyKj,
    'energy_kcal': energyKcal,
    'total_fat_g': totalFatG,
    'saturated_fat_g': saturatedFatG,
    'carbohydrates_g': carbohydratesG,
    'sugars_g': sugarsG,
    'fibre_g': fibreG,
    'protein_g': proteinG,
    'salt_g': saltG,
    'sodium_g': sodiumG,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelValues &&
          _deepEquals(energyKj, other.energyKj) &&
          _deepEquals(energyKcal, other.energyKcal) &&
          _deepEquals(totalFatG, other.totalFatG) &&
          _deepEquals(saturatedFatG, other.saturatedFatG) &&
          _deepEquals(carbohydratesG, other.carbohydratesG) &&
          _deepEquals(sugarsG, other.sugarsG) &&
          _deepEquals(fibreG, other.fibreG) &&
          _deepEquals(proteinG, other.proteinG) &&
          _deepEquals(saltG, other.saltG) &&
          _deepEquals(sodiumG, other.sodiumG);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(energyKj),
    _deepHash(energyKcal),
    _deepHash(totalFatG),
    _deepHash(saturatedFatG),
    _deepHash(carbohydratesG),
    _deepHash(sugarsG),
    _deepHash(fibreG),
    _deepHash(proteinG),
    _deepHash(saltG),
    _deepHash(sodiumG),
  ]);

  @override
  String toString() => 'LabelValues(${toJson()})';
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

/// Per 100 g or 100 mL, as declared on the label; null or missing: not
/// declared.
@immutable
class NutritionValues {
  const NutritionValues({
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

  factory NutritionValues.fromJson(Map<String, Object?> json) =>
      NutritionValues(
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
      other is NutritionValues &&
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
  String toString() => 'NutritionValues(${toJson()})';
}

/// What filled in the fields before the contributor reviewed them.
enum ParserUsed {
  rules('rules'),
  llm('llm'),
  manual('manual'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const ParserUsed(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory ParserUsed.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('ParserUsed: expected a string, got $json');
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
class RefreshRequest {
  const RefreshRequest({
    required this.refreshToken,
  });

  factory RefreshRequest.fromJson(Map<String, Object?> json) => RefreshRequest(
    refreshToken: json['refresh_token']! as String,
  );

  final String refreshToken;

  Map<String, Object?> toJson() => <String, Object?>{
    'refresh_token': refreshToken,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RefreshRequest && _deepEquals(refreshToken, other.refreshToken);

  @override
  int get hashCode => Object.hashAll([_deepHash(refreshToken)]);

  @override
  String toString() => 'RefreshRequest(${toJson()})';
}

/// As queued by the app (T20).
@immutable
class ReportCreate {
  const ReportCreate({
    required this.clientId,
    required this.ean,
    required this.reasons,
    required this.productUpdatedAt,
    required this.createdAt,
    this.comment,
  });

  factory ReportCreate.fromJson(Map<String, Object?> json) => ReportCreate(
    clientId: json['client_id']! as String,
    ean: json['ean']! as String,
    reasons: List<ReportReason>.unmodifiable(
      (json['reasons']! as List<Object?>).map(ReportReason.fromJson),
    ),
    comment: json['comment'] == null ? null : json['comment']! as String,
    productUpdatedAt: DateTime.parse(json['product_updated_at']! as String),
    createdAt: DateTime.parse(json['created_at']! as String),
  );

  final String clientId;

  final String ean;

  final List<ReportReason> reasons;

  final String? comment;

  final DateTime productUpdatedAt;

  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'client_id': clientId,
    'ean': ean,
    'reasons': reasons.map((item) => item.toJson()).toList(),
    'comment': comment,
    'product_updated_at': productUpdatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportCreate &&
          _deepEquals(clientId, other.clientId) &&
          _deepEquals(ean, other.ean) &&
          _deepEquals(reasons, other.reasons) &&
          _deepEquals(comment, other.comment) &&
          _deepEquals(productUpdatedAt, other.productUpdatedAt) &&
          _deepEquals(createdAt, other.createdAt);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(clientId),
    _deepHash(ean),
    _deepHash(reasons),
    _deepHash(comment),
    _deepHash(productUpdatedAt),
    _deepHash(createdAt),
  ]);

  @override
  String toString() => 'ReportCreate(${toJson()})';
}

enum ReportReason {
  name('name'),
  nutrition('nutrition'),
  grade('grade'),
  additives('additives'),
  other('other'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const ReportReason(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory ReportReason.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('ReportReason: expected a string, got $json');
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
class ReportReceipt {
  const ReportReceipt({
    required this.clientId,
    required this.receivedAt,
  });

  factory ReportReceipt.fromJson(Map<String, Object?> json) => ReportReceipt(
    clientId: json['client_id']! as String,
    receivedAt: DateTime.parse(json['received_at']! as String),
  );

  final String clientId;

  final DateTime receivedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'client_id': clientId,
    'received_at': receivedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportReceipt &&
          _deepEquals(clientId, other.clientId) &&
          _deepEquals(receivedAt, other.receivedAt);

  @override
  int get hashCode =>
      Object.hashAll([_deepHash(clientId), _deepHash(receivedAt)]);

  @override
  String toString() => 'ReportReceipt(${toJson()})';
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

/// The score the product would get, computed by the server's engine; nothing is
/// saved. Same fields as a product's score.
@immutable
class ScorePreview {
  const ScorePreview({
    required this.engineVersion,
    required this.breakdown,
    this.grade,
    this.total,
  });

  factory ScorePreview.fromJson(Map<String, Object?> json) => ScorePreview(
    engineVersion: json['engine_version']! as String,
    grade: json['grade'] == null ? null : Grade.fromJson(json['grade']),
    total: json['total'] == null ? null : json['total']! as int,
    breakdown: Map<String, Object?>.unmodifiable(json['breakdown']! as Map),
  );

  final String engineVersion;

  final Grade? grade;

  final int? total;

  final Map<String, Object?> breakdown;

  Map<String, Object?> toJson() => <String, Object?>{
    'engine_version': engineVersion,
    'grade': grade?.toJson(),
    'total': total,
    'breakdown': breakdown,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScorePreview &&
          _deepEquals(engineVersion, other.engineVersion) &&
          _deepEquals(grade, other.grade) &&
          _deepEquals(total, other.total) &&
          _deepEquals(breakdown, other.breakdown);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(engineVersion),
    _deepHash(grade),
    _deepHash(total),
    _deepHash(breakdown),
  ]);

  @override
  String toString() => 'ScorePreview(${toJson()})';
}

@immutable
class ScorePreviewRequest {
  const ScorePreviewRequest({
    required this.category,
    required this.nutrition,
  });

  factory ScorePreviewRequest.fromJson(Map<String, Object?> json) =>
      ScorePreviewRequest(
        category: Category.fromJson(json['category']),
        nutrition: NutritionValues.fromJson(
          json['nutrition']! as Map<String, Object?>,
        ),
      );

  final Category category;

  final NutritionValues nutrition;

  Map<String, Object?> toJson() => <String, Object?>{
    'category': category.toJson(),
    'nutrition': nutrition.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScorePreviewRequest &&
          _deepEquals(category, other.category) &&
          _deepEquals(nutrition, other.nutrition);

  @override
  int get hashCode =>
      Object.hashAll([_deepHash(category), _deepHash(nutrition)]);

  @override
  String toString() => 'ScorePreviewRequest(${toJson()})';
}

/// Send `access_token` as `Authorization: Bearer ...`; when it expires,
/// exchange `refresh_token` (single use) at `/v1/auth/refresh` for a new pair.
@immutable
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.expiresIn,
    required this.refreshToken,
    required this.refreshExpiresIn,
    this.tokenType,
  });

  factory TokenPair.fromJson(Map<String, Object?> json) => TokenPair(
    accessToken: json['access_token']! as String,
    tokenType: json['token_type'] == null
        ? null
        : json['token_type']! as String,
    expiresIn: json['expires_in']! as int,
    refreshToken: json['refresh_token']! as String,
    refreshExpiresIn: json['refresh_expires_in']! as int,
  );

  final String accessToken;

  final String? tokenType;

  final int expiresIn;

  final String refreshToken;

  final int refreshExpiresIn;

  Map<String, Object?> toJson() => <String, Object?>{
    'access_token': accessToken,
    'token_type': tokenType,
    'expires_in': expiresIn,
    'refresh_token': refreshToken,
    'refresh_expires_in': refreshExpiresIn,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenPair &&
          _deepEquals(accessToken, other.accessToken) &&
          _deepEquals(tokenType, other.tokenType) &&
          _deepEquals(expiresIn, other.expiresIn) &&
          _deepEquals(refreshToken, other.refreshToken) &&
          _deepEquals(refreshExpiresIn, other.refreshExpiresIn);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(accessToken),
    _deepHash(tokenType),
    _deepHash(expiresIn),
    _deepHash(refreshToken),
    _deepHash(refreshExpiresIn),
  ]);

  @override
  String toString() => 'TokenPair(${toJson()})';
}

@immutable
class UploadRequest {
  const UploadRequest({
    required this.contributionId,
    required this.kind,
    required this.contentType,
    required this.sizeBytes,
  });

  factory UploadRequest.fromJson(Map<String, Object?> json) => UploadRequest(
    contributionId: json['contribution_id']! as String,
    kind: PhotoKind.fromJson(json['kind']),
    contentType: PhotoContentType.fromJson(json['content_type']),
    sizeBytes: json['size_bytes']! as int,
  );

  final String contributionId;

  final PhotoKind kind;

  final PhotoContentType contentType;

  final int sizeBytes;

  Map<String, Object?> toJson() => <String, Object?>{
    'contribution_id': contributionId,
    'kind': kind.toJson(),
    'content_type': contentType.toJson(),
    'size_bytes': sizeBytes,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadRequest &&
          _deepEquals(contributionId, other.contributionId) &&
          _deepEquals(kind, other.kind) &&
          _deepEquals(contentType, other.contentType) &&
          _deepEquals(sizeBytes, other.sizeBytes);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(contributionId),
    _deepHash(kind),
    _deepHash(contentType),
    _deepHash(sizeBytes),
  ]);

  @override
  String toString() => 'UploadRequest(${toJson()})';
}

enum PhotoContentType {
  imageJpeg('image/jpeg'),
  imagePng('image/png'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const PhotoContentType(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory PhotoContentType.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('PhotoContentType: expected a string, got $json');
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

/// Which side of the package a contribution photo shows.
enum PhotoKind {
  front('front'),
  nutrition('nutrition'),
  ingredients('ingredients'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const PhotoKind(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory PhotoKind.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('PhotoKind: expected a string, got $json');
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

/// Upload the file with `PUT url`, sending exactly the requested `Content-Type`
/// and `Content-Length` (both are signed: storage rejects anything else). Then
/// refer to the photo by `key` when submitting the contribution.
@immutable
class UploadTicket {
  const UploadTicket({
    required this.key,
    required this.url,
    required this.expiresAt,
  });

  factory UploadTicket.fromJson(Map<String, Object?> json) => UploadTicket(
    key: json['key']! as String,
    url: json['url']! as String,
    expiresAt: DateTime.parse(json['expires_at']! as String),
  );

  final String key;

  final String url;

  final DateTime expiresAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'url': url,
    'expires_at': expiresAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadTicket &&
          _deepEquals(key, other.key) &&
          _deepEquals(url, other.url) &&
          _deepEquals(expiresAt, other.expiresAt);

  @override
  int get hashCode =>
      Object.hashAll([_deepHash(key), _deepHash(url), _deepHash(expiresAt)]);

  @override
  String toString() => 'UploadTicket(${toJson()})';
}

@immutable
class UserRead {
  const UserRead({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory UserRead.fromJson(Map<String, Object?> json) => UserRead(
    id: json['id']! as String,
    email: json['email']! as String,
    role: UserRole.fromJson(json['role']),
    createdAt: DateTime.parse(json['created_at']! as String),
  );

  final String id;

  final String email;

  final UserRole role;

  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'email': email,
    'role': role.toJson(),
    'created_at': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRead &&
          _deepEquals(id, other.id) &&
          _deepEquals(email, other.email) &&
          _deepEquals(role, other.role) &&
          _deepEquals(createdAt, other.createdAt);

  @override
  int get hashCode => Object.hashAll([
    _deepHash(id),
    _deepHash(email),
    _deepHash(role),
    _deepHash(createdAt),
  ]);

  @override
  String toString() => 'UserRead(${toJson()})';
}

enum UserRole {
  contributor('contributor'),
  admin('admin'),

  /// A value this app version does not know (from a newer backend).
  unrecognized('')
  ;

  const UserRole(this.value);

  /// Values this app does not know become [unrecognized] instead of failing.
  factory UserRole.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('UserRole: expected a string, got $json');
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

/// `RequestOptions.extra` key: true on calls that need the signed-in user's
/// access token (the app's auth interceptor adds it).
const authenticatedRequestKey = 'qout.authenticated';

/// Calls the Qout API through [Dio] (base URL, timeouts, logging and the
/// auth interceptor are the caller's configuration). Failures are
/// [QoutApiException]s.
class QoutApi {
  QoutApi(this._dio);

  final Dio _dio;

  /// Sign in
  Future<TokenPair> login({required Credentials body}) async {
    final json = await _send('post', '/v1/auth/login', body: body.toJson());
    return _parse(() => TokenPair.fromJson(json! as Map<String, Object?>));
  }

  /// Sign out (this device)
  ///
  /// Revokes the refresh token's session. Always succeeds.
  Future<void> logout({required RefreshRequest body}) async {
    await _send('post', '/v1/auth/logout', body: body.toJson());
  }

  /// The signed-in user
  ///
  /// Needs a signed-in user: the auth interceptor adds the access token.
  Future<UserRead> getMe() async {
    final json = await _send('get', '/v1/auth/me', authenticated: true);
    return _parse(() => UserRead.fromJson(json! as Map<String, Object?>));
  }

  /// Exchange a refresh token for new tokens
  ///
  /// Each refresh token works once. Presenting one again signs out every device
  /// that shares its session (the token was probably copied).
  Future<TokenPair> refreshTokens({required RefreshRequest body}) async {
    final json = await _send('post', '/v1/auth/refresh', body: body.toJson());
    return _parse(() => TokenPair.fromJson(json! as Map<String, Object?>));
  }

  /// Create a contributor account
  ///
  /// Scanning needs no account; contributing does. Signs the new user in.
  Future<TokenPair> register({required Credentials body}) async {
    final json = await _send('post', '/v1/auth/register', body: body.toJson());
    return _parse(() => TokenPair.fromJson(json! as Map<String, Object?>));
  }

  /// My contributions
  ///
  /// The signed-in user's contributions with their moderation status.
  ///
  /// Needs a signed-in user: the auth interceptor adds the access token.
  Future<ContributionList> listMyContributions({int? limit}) async {
    final json = await _send(
      'get',
      '/v1/contributions',
      queryParameters: <String, Object?>{
        'limit': ?limit,
      },
      authenticated: true,
    );
    return _parse(
      () => ContributionList.fromJson(json! as Map<String, Object?>),
    );
  }

  /// Submit a product
  ///
  /// A product from label photos, as reviewed by the contributor. Upload the
  /// photos first (`POST /v1/uploads`, same `client_id`). Stored as `pending`
  /// until a moderator decides. Sending the same `client_id` again returns the
  /// stored contribution (200).
  ///
  /// Needs a signed-in user: the auth interceptor adds the access token.
  Future<ContributionRead> submitContribution({
    required ContributionCreate body,
  }) async {
    final json = await _send(
      'post',
      '/v1/contributions',
      body: body.toJson(),
      authenticated: true,
    );
    return _parse(
      () => ContributionRead.fromJson(json! as Map<String, Object?>),
    );
  }

  /// One of my contributions
  ///
  /// Needs a signed-in user: the auth interceptor adds the access token.
  Future<ContributionRead> getMyContribution({
    required String contributionId,
  }) async {
    final json = await _send(
      'get',
      '/v1/contributions/${Uri.encodeComponent(contributionId)}',
      authenticated: true,
    );
    return _parse(
      () => ContributionRead.fromJson(json! as Map<String, Object?>),
    );
  }

  /// Read nutrition values from a label's OCR text
  ///
  /// Rule-based parser (French, English, Arabic): values per 100 g or 100 mL,
  /// the basis, and issues (missing values, a table declared per portion only,
  /// values failing the sanity checks). When that reading is not ok and the LLM
  /// fallback is enabled, `fallback` holds a request for it: poll `GET
  /// /v1/labels/parse/{id}`. Only the OCR text is sent to the LLM. The
  /// contributor reviews the values either way; nothing else is stored.
  ///
  /// Needs a signed-in user: the auth interceptor adds the access token.
  Future<LabelParseResult> parseLabelText({
    required LabelParseRequest body,
  }) async {
    final json = await _send(
      'post',
      '/v1/labels/parse',
      body: body.toJson(),
      authenticated: true,
    );
    return _parse(
      () => LabelParseResult.fromJson(json! as Map<String, Object?>),
    );
  }

  /// The LLM fallback's reading of a label
  ///
  /// `pending` until the worker has read it (ask again every second or two),
  /// then `done` with values that passed the same checks as the rule-based
  /// parser's, or `needs_manual_entry` with the reason. Given up as `timeout`
  /// when not done in time.
  ///
  /// Needs a signed-in user: the auth interceptor adds the access token.
  Future<LabelFallbackRead> getLabelFallback({
    required String fallbackId,
  }) async {
    final json = await _send(
      'get',
      '/v1/labels/parse/${Uri.encodeComponent(fallbackId)}',
      authenticated: true,
    );
    return _parse(
      () => LabelFallbackRead.fromJson(json! as Map<String, Object?>),
    );
  }

  /// Look up a product by barcode
  ///
  /// Barcode: EAN-8, UPC-A (returned as EAN-13), EAN-13 or GTIN-14, with a
  /// valid check digit. Served from the cache or our database; unknown barcodes
  /// are looked up on Open Food Facts, stored and scored.
  Future<ProductDetail> getProduct({required String ean}) async {
    final json = await _send('get', '/v1/products/${Uri.encodeComponent(ean)}');
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
    final json = await _send(
      'get',
      '/v1/products/${Uri.encodeComponent(ean)}/alternatives',
      queryParameters: <String, Object?>{
        'limit': ?limit,
      },
    );
    return _parse(
      () => ProductAlternatives.fromJson(json! as Map<String, Object?>),
    );
  }

  /// Report an error on a product
  ///
  /// No account needed; the user is recorded when a valid token is sent.
  /// Sending the same `client_id` again is acknowledged (200) without storing
  /// it twice.
  ///
  /// Needs a signed-in user: the auth interceptor adds the access token.
  Future<ReportReceipt> reportError({required ReportCreate body}) async {
    final json = await _send(
      'post',
      '/v1/reports',
      body: body.toJson(),
      authenticated: true,
    );
    return _parse(() => ReportReceipt.fromJson(json! as Map<String, Object?>));
  }

  /// Score nutrition values without saving
  ///
  /// The grade and breakdown the server's engine gives these values, e.g. while
  /// a contributor reviews a label. Nothing is stored.
  ///
  /// Needs a signed-in user: the auth interceptor adds the access token.
  Future<ScorePreview> previewScore({required ScorePreviewRequest body}) async {
    final json = await _send(
      'post',
      '/v1/score/preview',
      body: body.toJson(),
      authenticated: true,
    );
    return _parse(() => ScorePreview.fromJson(json! as Map<String, Object?>));
  }

  /// Get a URL to upload a contribution photo
  ///
  /// Returns a presigned URL for one `PUT` of the photo, valid for a few
  /// minutes. The upload must send exactly the declared `Content-Type` and
  /// `Content-Length`; storage rejects anything else. JPEG or PNG, up to the
  /// server's size limit.
  ///
  /// Needs a signed-in user: the auth interceptor adds the access token.
  Future<UploadTicket> createUpload({required UploadRequest body}) async {
    final json = await _send(
      'post',
      '/v1/uploads',
      body: body.toJson(),
      authenticated: true,
    );
    return _parse(() => UploadTicket.fromJson(json! as Map<String, Object?>));
  }

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
      // Without a message (type `unknown`), the underlying error says what
      // went wrong (e.g. an exception thrown while building the request).
      return ApiConnectionError(
        error.message ?? error.error?.toString() ?? error.type.name,
      );
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
