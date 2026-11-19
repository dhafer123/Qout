// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'needs.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Bmi {

/// BMI × 10, rounded down (decision H6): 184 is shown 18.4.
 int get tenths; BmiCategory get category;
/// Create a copy of Bmi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BmiCopyWith<Bmi> get copyWith => _$BmiCopyWithImpl<Bmi>(this as Bmi, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Bmi&&(identical(other.tenths, tenths) || other.tenths == tenths)&&(identical(other.category, category) || other.category == category));
}


@override
int get hashCode => Object.hash(runtimeType,tenths,category);

@override
String toString() {
  return 'Bmi(tenths: $tenths, category: $category)';
}


}

/// @nodoc
abstract mixin class $BmiCopyWith<$Res>  {
  factory $BmiCopyWith(Bmi value, $Res Function(Bmi) _then) = _$BmiCopyWithImpl;
@useResult
$Res call({
 int tenths, BmiCategory category
});




}
/// @nodoc
class _$BmiCopyWithImpl<$Res>
    implements $BmiCopyWith<$Res> {
  _$BmiCopyWithImpl(this._self, this._then);

  final Bmi _self;
  final $Res Function(Bmi) _then;

/// Create a copy of Bmi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tenths = null,Object? category = null,}) {
  return _then(_self.copyWith(
tenths: null == tenths ? _self.tenths : tenths // ignore: cast_nullable_to_non_nullable
as int,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as BmiCategory,
  ));
}

}


/// Adds pattern-matching-related methods to [Bmi].
extension BmiPatterns on Bmi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Bmi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Bmi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Bmi value)  $default,){
final _that = this;
switch (_that) {
case _Bmi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Bmi value)?  $default,){
final _that = this;
switch (_that) {
case _Bmi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int tenths,  BmiCategory category)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Bmi() when $default != null:
return $default(_that.tenths,_that.category);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int tenths,  BmiCategory category)  $default,) {final _that = this;
switch (_that) {
case _Bmi():
return $default(_that.tenths,_that.category);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int tenths,  BmiCategory category)?  $default,) {final _that = this;
switch (_that) {
case _Bmi() when $default != null:
return $default(_that.tenths,_that.category);case _:
  return null;

}
}

}

/// @nodoc


class _Bmi extends Bmi {
  const _Bmi({required this.tenths, required this.category}): super._();
  

/// BMI × 10, rounded down (decision H6): 184 is shown 18.4.
@override final  int tenths;
@override final  BmiCategory category;

/// Create a copy of Bmi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BmiCopyWith<_Bmi> get copyWith => __$BmiCopyWithImpl<_Bmi>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Bmi&&(identical(other.tenths, tenths) || other.tenths == tenths)&&(identical(other.category, category) || other.category == category));
}


@override
int get hashCode => Object.hash(runtimeType,tenths,category);

@override
String toString() {
  return 'Bmi(tenths: $tenths, category: $category)';
}


}

/// @nodoc
abstract mixin class _$BmiCopyWith<$Res> implements $BmiCopyWith<$Res> {
  factory _$BmiCopyWith(_Bmi value, $Res Function(_Bmi) _then) = __$BmiCopyWithImpl;
@override @useResult
$Res call({
 int tenths, BmiCategory category
});




}
/// @nodoc
class __$BmiCopyWithImpl<$Res>
    implements _$BmiCopyWith<$Res> {
  __$BmiCopyWithImpl(this._self, this._then);

  final _Bmi _self;
  final $Res Function(_Bmi) _then;

/// Create a copy of Bmi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tenths = null,Object? category = null,}) {
  return _then(_Bmi(
tenths: null == tenths ? _self.tenths : tenths // ignore: cast_nullable_to_non_nullable
as int,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as BmiCategory,
  ));
}


}

/// @nodoc
mixin _$DailyNeeds {

 NeedsBasis get basis;/// Set when [basis] is [NeedsBasis.reference].
 ReferenceReason? get referenceReason; int get energyKj; int get fatG; int get saturatesG; int get sugarsG; int get saltG;/// Null without a profile.
 Bmi? get bmi;
/// Create a copy of DailyNeeds
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyNeedsCopyWith<DailyNeeds> get copyWith => _$DailyNeedsCopyWithImpl<DailyNeeds>(this as DailyNeeds, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyNeeds&&(identical(other.basis, basis) || other.basis == basis)&&(identical(other.referenceReason, referenceReason) || other.referenceReason == referenceReason)&&(identical(other.energyKj, energyKj) || other.energyKj == energyKj)&&(identical(other.fatG, fatG) || other.fatG == fatG)&&(identical(other.saturatesG, saturatesG) || other.saturatesG == saturatesG)&&(identical(other.sugarsG, sugarsG) || other.sugarsG == sugarsG)&&(identical(other.saltG, saltG) || other.saltG == saltG)&&(identical(other.bmi, bmi) || other.bmi == bmi));
}


@override
int get hashCode => Object.hash(runtimeType,basis,referenceReason,energyKj,fatG,saturatesG,sugarsG,saltG,bmi);

@override
String toString() {
  return 'DailyNeeds(basis: $basis, referenceReason: $referenceReason, energyKj: $energyKj, fatG: $fatG, saturatesG: $saturatesG, sugarsG: $sugarsG, saltG: $saltG, bmi: $bmi)';
}


}

/// @nodoc
abstract mixin class $DailyNeedsCopyWith<$Res>  {
  factory $DailyNeedsCopyWith(DailyNeeds value, $Res Function(DailyNeeds) _then) = _$DailyNeedsCopyWithImpl;
@useResult
$Res call({
 NeedsBasis basis, ReferenceReason? referenceReason, int energyKj, int fatG, int saturatesG, int sugarsG, int saltG, Bmi? bmi
});


$BmiCopyWith<$Res>? get bmi;

}
/// @nodoc
class _$DailyNeedsCopyWithImpl<$Res>
    implements $DailyNeedsCopyWith<$Res> {
  _$DailyNeedsCopyWithImpl(this._self, this._then);

  final DailyNeeds _self;
  final $Res Function(DailyNeeds) _then;

/// Create a copy of DailyNeeds
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? basis = null,Object? referenceReason = freezed,Object? energyKj = null,Object? fatG = null,Object? saturatesG = null,Object? sugarsG = null,Object? saltG = null,Object? bmi = freezed,}) {
  return _then(_self.copyWith(
basis: null == basis ? _self.basis : basis // ignore: cast_nullable_to_non_nullable
as NeedsBasis,referenceReason: freezed == referenceReason ? _self.referenceReason : referenceReason // ignore: cast_nullable_to_non_nullable
as ReferenceReason?,energyKj: null == energyKj ? _self.energyKj : energyKj // ignore: cast_nullable_to_non_nullable
as int,fatG: null == fatG ? _self.fatG : fatG // ignore: cast_nullable_to_non_nullable
as int,saturatesG: null == saturatesG ? _self.saturatesG : saturatesG // ignore: cast_nullable_to_non_nullable
as int,sugarsG: null == sugarsG ? _self.sugarsG : sugarsG // ignore: cast_nullable_to_non_nullable
as int,saltG: null == saltG ? _self.saltG : saltG // ignore: cast_nullable_to_non_nullable
as int,bmi: freezed == bmi ? _self.bmi : bmi // ignore: cast_nullable_to_non_nullable
as Bmi?,
  ));
}
/// Create a copy of DailyNeeds
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BmiCopyWith<$Res>? get bmi {
    if (_self.bmi == null) {
    return null;
  }

  return $BmiCopyWith<$Res>(_self.bmi!, (value) {
    return _then(_self.copyWith(bmi: value));
  });
}
}


/// Adds pattern-matching-related methods to [DailyNeeds].
extension DailyNeedsPatterns on DailyNeeds {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyNeeds value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyNeeds() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyNeeds value)  $default,){
final _that = this;
switch (_that) {
case _DailyNeeds():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyNeeds value)?  $default,){
final _that = this;
switch (_that) {
case _DailyNeeds() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( NeedsBasis basis,  ReferenceReason? referenceReason,  int energyKj,  int fatG,  int saturatesG,  int sugarsG,  int saltG,  Bmi? bmi)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyNeeds() when $default != null:
return $default(_that.basis,_that.referenceReason,_that.energyKj,_that.fatG,_that.saturatesG,_that.sugarsG,_that.saltG,_that.bmi);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( NeedsBasis basis,  ReferenceReason? referenceReason,  int energyKj,  int fatG,  int saturatesG,  int sugarsG,  int saltG,  Bmi? bmi)  $default,) {final _that = this;
switch (_that) {
case _DailyNeeds():
return $default(_that.basis,_that.referenceReason,_that.energyKj,_that.fatG,_that.saturatesG,_that.sugarsG,_that.saltG,_that.bmi);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( NeedsBasis basis,  ReferenceReason? referenceReason,  int energyKj,  int fatG,  int saturatesG,  int sugarsG,  int saltG,  Bmi? bmi)?  $default,) {final _that = this;
switch (_that) {
case _DailyNeeds() when $default != null:
return $default(_that.basis,_that.referenceReason,_that.energyKj,_that.fatG,_that.saturatesG,_that.sugarsG,_that.saltG,_that.bmi);case _:
  return null;

}
}

}

/// @nodoc


class _DailyNeeds implements DailyNeeds {
  const _DailyNeeds({required this.basis, required this.referenceReason, required this.energyKj, required this.fatG, required this.saturatesG, required this.sugarsG, required this.saltG, required this.bmi});
  

@override final  NeedsBasis basis;
/// Set when [basis] is [NeedsBasis.reference].
@override final  ReferenceReason? referenceReason;
@override final  int energyKj;
@override final  int fatG;
@override final  int saturatesG;
@override final  int sugarsG;
@override final  int saltG;
/// Null without a profile.
@override final  Bmi? bmi;

/// Create a copy of DailyNeeds
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyNeedsCopyWith<_DailyNeeds> get copyWith => __$DailyNeedsCopyWithImpl<_DailyNeeds>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyNeeds&&(identical(other.basis, basis) || other.basis == basis)&&(identical(other.referenceReason, referenceReason) || other.referenceReason == referenceReason)&&(identical(other.energyKj, energyKj) || other.energyKj == energyKj)&&(identical(other.fatG, fatG) || other.fatG == fatG)&&(identical(other.saturatesG, saturatesG) || other.saturatesG == saturatesG)&&(identical(other.sugarsG, sugarsG) || other.sugarsG == sugarsG)&&(identical(other.saltG, saltG) || other.saltG == saltG)&&(identical(other.bmi, bmi) || other.bmi == bmi));
}


@override
int get hashCode => Object.hash(runtimeType,basis,referenceReason,energyKj,fatG,saturatesG,sugarsG,saltG,bmi);

@override
String toString() {
  return 'DailyNeeds(basis: $basis, referenceReason: $referenceReason, energyKj: $energyKj, fatG: $fatG, saturatesG: $saturatesG, sugarsG: $sugarsG, saltG: $saltG, bmi: $bmi)';
}


}

/// @nodoc
abstract mixin class _$DailyNeedsCopyWith<$Res> implements $DailyNeedsCopyWith<$Res> {
  factory _$DailyNeedsCopyWith(_DailyNeeds value, $Res Function(_DailyNeeds) _then) = __$DailyNeedsCopyWithImpl;
@override @useResult
$Res call({
 NeedsBasis basis, ReferenceReason? referenceReason, int energyKj, int fatG, int saturatesG, int sugarsG, int saltG, Bmi? bmi
});


@override $BmiCopyWith<$Res>? get bmi;

}
/// @nodoc
class __$DailyNeedsCopyWithImpl<$Res>
    implements _$DailyNeedsCopyWith<$Res> {
  __$DailyNeedsCopyWithImpl(this._self, this._then);

  final _DailyNeeds _self;
  final $Res Function(_DailyNeeds) _then;

/// Create a copy of DailyNeeds
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? basis = null,Object? referenceReason = freezed,Object? energyKj = null,Object? fatG = null,Object? saturatesG = null,Object? sugarsG = null,Object? saltG = null,Object? bmi = freezed,}) {
  return _then(_DailyNeeds(
basis: null == basis ? _self.basis : basis // ignore: cast_nullable_to_non_nullable
as NeedsBasis,referenceReason: freezed == referenceReason ? _self.referenceReason : referenceReason // ignore: cast_nullable_to_non_nullable
as ReferenceReason?,energyKj: null == energyKj ? _self.energyKj : energyKj // ignore: cast_nullable_to_non_nullable
as int,fatG: null == fatG ? _self.fatG : fatG // ignore: cast_nullable_to_non_nullable
as int,saturatesG: null == saturatesG ? _self.saturatesG : saturatesG // ignore: cast_nullable_to_non_nullable
as int,sugarsG: null == sugarsG ? _self.sugarsG : sugarsG // ignore: cast_nullable_to_non_nullable
as int,saltG: null == saltG ? _self.saltG : saltG // ignore: cast_nullable_to_non_nullable
as int,bmi: freezed == bmi ? _self.bmi : bmi // ignore: cast_nullable_to_non_nullable
as Bmi?,
  ));
}

/// Create a copy of DailyNeeds
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BmiCopyWith<$Res>? get bmi {
    if (_self.bmi == null) {
    return null;
  }

  return $BmiCopyWith<$Res>(_self.bmi!, (value) {
    return _then(_self.copyWith(bmi: value));
  });
}
}

// dart format on
