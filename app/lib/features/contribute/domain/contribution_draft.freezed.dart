// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contribution_draft.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ContributionDraft {

 String get ean;/// The contribution's id, also in its photo keys: a resend is the same
/// contribution.
 String get clientId;/// Photo kind -> file path on the phone.
 Map<PhotoKind, String> get photos;/// Photo kind -> text ML Kit read from it.
 Map<PhotoKind, String> get ocrText; Category get category; NutritionBasis get basis; String get name; String get brand;/// Field -> amount as typed (decimal comma or point); missing or blank:
/// not declared.
 Map<NutrientField, String> get values; EnergyUnit get energyUnit;/// Beverages only: contains a non-nutritive sweetener.
 bool get sweeteners;/// What filled in the values before the contributor reviewed them.
 ParserUsed get parserUsed;/// Values the label parser flagged (missing, impossible, inconsistent):
/// worth checking against the photo.
 Set<NutrientField> get flagged;/// The contributor changed a value by hand.
 bool get edited;/// Bumped when values are filled in by the app (a parser), so the form
/// shows them instead of what it holds.
 int get revision;
/// Create a copy of ContributionDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContributionDraftCopyWith<ContributionDraft> get copyWith => _$ContributionDraftCopyWithImpl<ContributionDraft>(this as ContributionDraft, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContributionDraft&&(identical(other.ean, ean) || other.ean == ean)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&const DeepCollectionEquality().equals(other.photos, photos)&&const DeepCollectionEquality().equals(other.ocrText, ocrText)&&(identical(other.category, category) || other.category == category)&&(identical(other.basis, basis) || other.basis == basis)&&(identical(other.name, name) || other.name == name)&&(identical(other.brand, brand) || other.brand == brand)&&const DeepCollectionEquality().equals(other.values, values)&&(identical(other.energyUnit, energyUnit) || other.energyUnit == energyUnit)&&(identical(other.sweeteners, sweeteners) || other.sweeteners == sweeteners)&&(identical(other.parserUsed, parserUsed) || other.parserUsed == parserUsed)&&const DeepCollectionEquality().equals(other.flagged, flagged)&&(identical(other.edited, edited) || other.edited == edited)&&(identical(other.revision, revision) || other.revision == revision));
}


@override
int get hashCode => Object.hash(runtimeType,ean,clientId,const DeepCollectionEquality().hash(photos),const DeepCollectionEquality().hash(ocrText),category,basis,name,brand,const DeepCollectionEquality().hash(values),energyUnit,sweeteners,parserUsed,const DeepCollectionEquality().hash(flagged),edited,revision);

@override
String toString() {
  return 'ContributionDraft(ean: $ean, clientId: $clientId, photos: $photos, ocrText: $ocrText, category: $category, basis: $basis, name: $name, brand: $brand, values: $values, energyUnit: $energyUnit, sweeteners: $sweeteners, parserUsed: $parserUsed, flagged: $flagged, edited: $edited, revision: $revision)';
}


}

/// @nodoc
abstract mixin class $ContributionDraftCopyWith<$Res>  {
  factory $ContributionDraftCopyWith(ContributionDraft value, $Res Function(ContributionDraft) _then) = _$ContributionDraftCopyWithImpl;
@useResult
$Res call({
 String ean, String clientId, Map<PhotoKind, String> photos, Map<PhotoKind, String> ocrText, Category category, NutritionBasis basis, String name, String brand, Map<NutrientField, String> values, EnergyUnit energyUnit, bool sweeteners, ParserUsed parserUsed, Set<NutrientField> flagged, bool edited, int revision
});




}
/// @nodoc
class _$ContributionDraftCopyWithImpl<$Res>
    implements $ContributionDraftCopyWith<$Res> {
  _$ContributionDraftCopyWithImpl(this._self, this._then);

  final ContributionDraft _self;
  final $Res Function(ContributionDraft) _then;

/// Create a copy of ContributionDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ean = null,Object? clientId = null,Object? photos = null,Object? ocrText = null,Object? category = null,Object? basis = null,Object? name = null,Object? brand = null,Object? values = null,Object? energyUnit = null,Object? sweeteners = null,Object? parserUsed = null,Object? flagged = null,Object? edited = null,Object? revision = null,}) {
  return _then(_self.copyWith(
ean: null == ean ? _self.ean : ean // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as Map<PhotoKind, String>,ocrText: null == ocrText ? _self.ocrText : ocrText // ignore: cast_nullable_to_non_nullable
as Map<PhotoKind, String>,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category,basis: null == basis ? _self.basis : basis // ignore: cast_nullable_to_non_nullable
as NutritionBasis,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,brand: null == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as Map<NutrientField, String>,energyUnit: null == energyUnit ? _self.energyUnit : energyUnit // ignore: cast_nullable_to_non_nullable
as EnergyUnit,sweeteners: null == sweeteners ? _self.sweeteners : sweeteners // ignore: cast_nullable_to_non_nullable
as bool,parserUsed: null == parserUsed ? _self.parserUsed : parserUsed // ignore: cast_nullable_to_non_nullable
as ParserUsed,flagged: null == flagged ? _self.flagged : flagged // ignore: cast_nullable_to_non_nullable
as Set<NutrientField>,edited: null == edited ? _self.edited : edited // ignore: cast_nullable_to_non_nullable
as bool,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ContributionDraft].
extension ContributionDraftPatterns on ContributionDraft {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContributionDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContributionDraft() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContributionDraft value)  $default,){
final _that = this;
switch (_that) {
case _ContributionDraft():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContributionDraft value)?  $default,){
final _that = this;
switch (_that) {
case _ContributionDraft() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ean,  String clientId,  Map<PhotoKind, String> photos,  Map<PhotoKind, String> ocrText,  Category category,  NutritionBasis basis,  String name,  String brand,  Map<NutrientField, String> values,  EnergyUnit energyUnit,  bool sweeteners,  ParserUsed parserUsed,  Set<NutrientField> flagged,  bool edited,  int revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContributionDraft() when $default != null:
return $default(_that.ean,_that.clientId,_that.photos,_that.ocrText,_that.category,_that.basis,_that.name,_that.brand,_that.values,_that.energyUnit,_that.sweeteners,_that.parserUsed,_that.flagged,_that.edited,_that.revision);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ean,  String clientId,  Map<PhotoKind, String> photos,  Map<PhotoKind, String> ocrText,  Category category,  NutritionBasis basis,  String name,  String brand,  Map<NutrientField, String> values,  EnergyUnit energyUnit,  bool sweeteners,  ParserUsed parserUsed,  Set<NutrientField> flagged,  bool edited,  int revision)  $default,) {final _that = this;
switch (_that) {
case _ContributionDraft():
return $default(_that.ean,_that.clientId,_that.photos,_that.ocrText,_that.category,_that.basis,_that.name,_that.brand,_that.values,_that.energyUnit,_that.sweeteners,_that.parserUsed,_that.flagged,_that.edited,_that.revision);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ean,  String clientId,  Map<PhotoKind, String> photos,  Map<PhotoKind, String> ocrText,  Category category,  NutritionBasis basis,  String name,  String brand,  Map<NutrientField, String> values,  EnergyUnit energyUnit,  bool sweeteners,  ParserUsed parserUsed,  Set<NutrientField> flagged,  bool edited,  int revision)?  $default,) {final _that = this;
switch (_that) {
case _ContributionDraft() when $default != null:
return $default(_that.ean,_that.clientId,_that.photos,_that.ocrText,_that.category,_that.basis,_that.name,_that.brand,_that.values,_that.energyUnit,_that.sweeteners,_that.parserUsed,_that.flagged,_that.edited,_that.revision);case _:
  return null;

}
}

}

/// @nodoc


class _ContributionDraft implements ContributionDraft {
  const _ContributionDraft({required this.ean, required this.clientId, final  Map<PhotoKind, String> photos = const <PhotoKind, String>{}, final  Map<PhotoKind, String> ocrText = const <PhotoKind, String>{}, this.category = Category.general, this.basis = NutritionBasis.per100g, this.name = '', this.brand = '', final  Map<NutrientField, String> values = const <NutrientField, String>{}, this.energyUnit = EnergyUnit.kj, this.sweeteners = false, this.parserUsed = ParserUsed.manual, final  Set<NutrientField> flagged = const <NutrientField>{}, this.edited = false, this.revision = 0}): _photos = photos,_ocrText = ocrText,_values = values,_flagged = flagged;
  

@override final  String ean;
/// The contribution's id, also in its photo keys: a resend is the same
/// contribution.
@override final  String clientId;
/// Photo kind -> file path on the phone.
 final  Map<PhotoKind, String> _photos;
/// Photo kind -> file path on the phone.
@override@JsonKey() Map<PhotoKind, String> get photos {
  if (_photos is EqualUnmodifiableMapView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_photos);
}

/// Photo kind -> text ML Kit read from it.
 final  Map<PhotoKind, String> _ocrText;
/// Photo kind -> text ML Kit read from it.
@override@JsonKey() Map<PhotoKind, String> get ocrText {
  if (_ocrText is EqualUnmodifiableMapView) return _ocrText;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_ocrText);
}

@override@JsonKey() final  Category category;
@override@JsonKey() final  NutritionBasis basis;
@override@JsonKey() final  String name;
@override@JsonKey() final  String brand;
/// Field -> amount as typed (decimal comma or point); missing or blank:
/// not declared.
 final  Map<NutrientField, String> _values;
/// Field -> amount as typed (decimal comma or point); missing or blank:
/// not declared.
@override@JsonKey() Map<NutrientField, String> get values {
  if (_values is EqualUnmodifiableMapView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_values);
}

@override@JsonKey() final  EnergyUnit energyUnit;
/// Beverages only: contains a non-nutritive sweetener.
@override@JsonKey() final  bool sweeteners;
/// What filled in the values before the contributor reviewed them.
@override@JsonKey() final  ParserUsed parserUsed;
/// Values the label parser flagged (missing, impossible, inconsistent):
/// worth checking against the photo.
 final  Set<NutrientField> _flagged;
/// Values the label parser flagged (missing, impossible, inconsistent):
/// worth checking against the photo.
@override@JsonKey() Set<NutrientField> get flagged {
  if (_flagged is EqualUnmodifiableSetView) return _flagged;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_flagged);
}

/// The contributor changed a value by hand.
@override@JsonKey() final  bool edited;
/// Bumped when values are filled in by the app (a parser), so the form
/// shows them instead of what it holds.
@override@JsonKey() final  int revision;

/// Create a copy of ContributionDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContributionDraftCopyWith<_ContributionDraft> get copyWith => __$ContributionDraftCopyWithImpl<_ContributionDraft>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContributionDraft&&(identical(other.ean, ean) || other.ean == ean)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&const DeepCollectionEquality().equals(other._photos, _photos)&&const DeepCollectionEquality().equals(other._ocrText, _ocrText)&&(identical(other.category, category) || other.category == category)&&(identical(other.basis, basis) || other.basis == basis)&&(identical(other.name, name) || other.name == name)&&(identical(other.brand, brand) || other.brand == brand)&&const DeepCollectionEquality().equals(other._values, _values)&&(identical(other.energyUnit, energyUnit) || other.energyUnit == energyUnit)&&(identical(other.sweeteners, sweeteners) || other.sweeteners == sweeteners)&&(identical(other.parserUsed, parserUsed) || other.parserUsed == parserUsed)&&const DeepCollectionEquality().equals(other._flagged, _flagged)&&(identical(other.edited, edited) || other.edited == edited)&&(identical(other.revision, revision) || other.revision == revision));
}


@override
int get hashCode => Object.hash(runtimeType,ean,clientId,const DeepCollectionEquality().hash(_photos),const DeepCollectionEquality().hash(_ocrText),category,basis,name,brand,const DeepCollectionEquality().hash(_values),energyUnit,sweeteners,parserUsed,const DeepCollectionEquality().hash(_flagged),edited,revision);

@override
String toString() {
  return 'ContributionDraft(ean: $ean, clientId: $clientId, photos: $photos, ocrText: $ocrText, category: $category, basis: $basis, name: $name, brand: $brand, values: $values, energyUnit: $energyUnit, sweeteners: $sweeteners, parserUsed: $parserUsed, flagged: $flagged, edited: $edited, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$ContributionDraftCopyWith<$Res> implements $ContributionDraftCopyWith<$Res> {
  factory _$ContributionDraftCopyWith(_ContributionDraft value, $Res Function(_ContributionDraft) _then) = __$ContributionDraftCopyWithImpl;
@override @useResult
$Res call({
 String ean, String clientId, Map<PhotoKind, String> photos, Map<PhotoKind, String> ocrText, Category category, NutritionBasis basis, String name, String brand, Map<NutrientField, String> values, EnergyUnit energyUnit, bool sweeteners, ParserUsed parserUsed, Set<NutrientField> flagged, bool edited, int revision
});




}
/// @nodoc
class __$ContributionDraftCopyWithImpl<$Res>
    implements _$ContributionDraftCopyWith<$Res> {
  __$ContributionDraftCopyWithImpl(this._self, this._then);

  final _ContributionDraft _self;
  final $Res Function(_ContributionDraft) _then;

/// Create a copy of ContributionDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ean = null,Object? clientId = null,Object? photos = null,Object? ocrText = null,Object? category = null,Object? basis = null,Object? name = null,Object? brand = null,Object? values = null,Object? energyUnit = null,Object? sweeteners = null,Object? parserUsed = null,Object? flagged = null,Object? edited = null,Object? revision = null,}) {
  return _then(_ContributionDraft(
ean: null == ean ? _self.ean : ean // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as Map<PhotoKind, String>,ocrText: null == ocrText ? _self._ocrText : ocrText // ignore: cast_nullable_to_non_nullable
as Map<PhotoKind, String>,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category,basis: null == basis ? _self.basis : basis // ignore: cast_nullable_to_non_nullable
as NutritionBasis,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,brand: null == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as Map<NutrientField, String>,energyUnit: null == energyUnit ? _self.energyUnit : energyUnit // ignore: cast_nullable_to_non_nullable
as EnergyUnit,sweeteners: null == sweeteners ? _self.sweeteners : sweeteners // ignore: cast_nullable_to_non_nullable
as bool,parserUsed: null == parserUsed ? _self.parserUsed : parserUsed // ignore: cast_nullable_to_non_nullable
as ParserUsed,flagged: null == flagged ? _self._flagged : flagged // ignore: cast_nullable_to_non_nullable
as Set<NutrientField>,edited: null == edited ? _self.edited : edited // ignore: cast_nullable_to_non_nullable
as bool,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
