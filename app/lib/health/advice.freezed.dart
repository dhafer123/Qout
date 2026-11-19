// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'advice.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Portion {

 double get amount; PortionUnit get unit; bool get isServing;
/// Create a copy of Portion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PortionCopyWith<Portion> get copyWith => _$PortionCopyWithImpl<Portion>(this as Portion, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Portion&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.isServing, isServing) || other.isServing == isServing));
}


@override
int get hashCode => Object.hash(runtimeType,amount,unit,isServing);

@override
String toString() {
  return 'Portion(amount: $amount, unit: $unit, isServing: $isServing)';
}


}

/// @nodoc
abstract mixin class $PortionCopyWith<$Res>  {
  factory $PortionCopyWith(Portion value, $Res Function(Portion) _then) = _$PortionCopyWithImpl;
@useResult
$Res call({
 double amount, PortionUnit unit, bool isServing
});




}
/// @nodoc
class _$PortionCopyWithImpl<$Res>
    implements $PortionCopyWith<$Res> {
  _$PortionCopyWithImpl(this._self, this._then);

  final Portion _self;
  final $Res Function(Portion) _then;

/// Create a copy of Portion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? amount = null,Object? unit = null,Object? isServing = null,}) {
  return _then(_self.copyWith(
amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as PortionUnit,isServing: null == isServing ? _self.isServing : isServing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Portion].
extension PortionPatterns on Portion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Portion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Portion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Portion value)  $default,){
final _that = this;
switch (_that) {
case _Portion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Portion value)?  $default,){
final _that = this;
switch (_that) {
case _Portion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double amount,  PortionUnit unit,  bool isServing)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Portion() when $default != null:
return $default(_that.amount,_that.unit,_that.isServing);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double amount,  PortionUnit unit,  bool isServing)  $default,) {final _that = this;
switch (_that) {
case _Portion():
return $default(_that.amount,_that.unit,_that.isServing);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double amount,  PortionUnit unit,  bool isServing)?  $default,) {final _that = this;
switch (_that) {
case _Portion() when $default != null:
return $default(_that.amount,_that.unit,_that.isServing);case _:
  return null;

}
}

}

/// @nodoc


class _Portion implements Portion {
  const _Portion({required this.amount, required this.unit, required this.isServing});
  

@override final  double amount;
@override final  PortionUnit unit;
@override final  bool isServing;

/// Create a copy of Portion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PortionCopyWith<_Portion> get copyWith => __$PortionCopyWithImpl<_Portion>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Portion&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.isServing, isServing) || other.isServing == isServing));
}


@override
int get hashCode => Object.hash(runtimeType,amount,unit,isServing);

@override
String toString() {
  return 'Portion(amount: $amount, unit: $unit, isServing: $isServing)';
}


}

/// @nodoc
abstract mixin class _$PortionCopyWith<$Res> implements $PortionCopyWith<$Res> {
  factory _$PortionCopyWith(_Portion value, $Res Function(_Portion) _then) = __$PortionCopyWithImpl;
@override @useResult
$Res call({
 double amount, PortionUnit unit, bool isServing
});




}
/// @nodoc
class __$PortionCopyWithImpl<$Res>
    implements _$PortionCopyWith<$Res> {
  __$PortionCopyWithImpl(this._self, this._then);

  final _Portion _self;
  final $Res Function(_Portion) _then;

/// Create a copy of Portion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? amount = null,Object? unit = null,Object? isServing = null,}) {
  return _then(_Portion(
amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as PortionUnit,isServing: null == isServing ? _self.isServing : isServing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$Share {

 Nutrient get nutrient; int get percent; bool get lessThanOne;
/// Create a copy of Share
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShareCopyWith<Share> get copyWith => _$ShareCopyWithImpl<Share>(this as Share, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Share&&(identical(other.nutrient, nutrient) || other.nutrient == nutrient)&&(identical(other.percent, percent) || other.percent == percent)&&(identical(other.lessThanOne, lessThanOne) || other.lessThanOne == lessThanOne));
}


@override
int get hashCode => Object.hash(runtimeType,nutrient,percent,lessThanOne);

@override
String toString() {
  return 'Share(nutrient: $nutrient, percent: $percent, lessThanOne: $lessThanOne)';
}


}

/// @nodoc
abstract mixin class $ShareCopyWith<$Res>  {
  factory $ShareCopyWith(Share value, $Res Function(Share) _then) = _$ShareCopyWithImpl;
@useResult
$Res call({
 Nutrient nutrient, int percent, bool lessThanOne
});




}
/// @nodoc
class _$ShareCopyWithImpl<$Res>
    implements $ShareCopyWith<$Res> {
  _$ShareCopyWithImpl(this._self, this._then);

  final Share _self;
  final $Res Function(Share) _then;

/// Create a copy of Share
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nutrient = null,Object? percent = null,Object? lessThanOne = null,}) {
  return _then(_self.copyWith(
nutrient: null == nutrient ? _self.nutrient : nutrient // ignore: cast_nullable_to_non_nullable
as Nutrient,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as int,lessThanOne: null == lessThanOne ? _self.lessThanOne : lessThanOne // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Share].
extension SharePatterns on Share {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Share value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Share() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Share value)  $default,){
final _that = this;
switch (_that) {
case _Share():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Share value)?  $default,){
final _that = this;
switch (_that) {
case _Share() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Nutrient nutrient,  int percent,  bool lessThanOne)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Share() when $default != null:
return $default(_that.nutrient,_that.percent,_that.lessThanOne);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Nutrient nutrient,  int percent,  bool lessThanOne)  $default,) {final _that = this;
switch (_that) {
case _Share():
return $default(_that.nutrient,_that.percent,_that.lessThanOne);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Nutrient nutrient,  int percent,  bool lessThanOne)?  $default,) {final _that = this;
switch (_that) {
case _Share() when $default != null:
return $default(_that.nutrient,_that.percent,_that.lessThanOne);case _:
  return null;

}
}

}

/// @nodoc


class _Share implements Share {
  const _Share({required this.nutrient, required this.percent, required this.lessThanOne});
  

@override final  Nutrient nutrient;
@override final  int percent;
@override final  bool lessThanOne;

/// Create a copy of Share
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShareCopyWith<_Share> get copyWith => __$ShareCopyWithImpl<_Share>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Share&&(identical(other.nutrient, nutrient) || other.nutrient == nutrient)&&(identical(other.percent, percent) || other.percent == percent)&&(identical(other.lessThanOne, lessThanOne) || other.lessThanOne == lessThanOne));
}


@override
int get hashCode => Object.hash(runtimeType,nutrient,percent,lessThanOne);

@override
String toString() {
  return 'Share(nutrient: $nutrient, percent: $percent, lessThanOne: $lessThanOne)';
}


}

/// @nodoc
abstract mixin class _$ShareCopyWith<$Res> implements $ShareCopyWith<$Res> {
  factory _$ShareCopyWith(_Share value, $Res Function(_Share) _then) = __$ShareCopyWithImpl;
@override @useResult
$Res call({
 Nutrient nutrient, int percent, bool lessThanOne
});




}
/// @nodoc
class __$ShareCopyWithImpl<$Res>
    implements _$ShareCopyWith<$Res> {
  __$ShareCopyWithImpl(this._self, this._then);

  final _Share _self;
  final $Res Function(_Share) _then;

/// Create a copy of Share
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nutrient = null,Object? percent = null,Object? lessThanOne = null,}) {
  return _then(_Share(
nutrient: null == nutrient ? _self.nutrient : nutrient // ignore: cast_nullable_to_non_nullable
as Nutrient,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as int,lessThanOne: null == lessThanOne ? _self.lessThanOne : lessThanOne // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$AdviceNote {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdviceNote);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AdviceNote()';
}


}

/// @nodoc
class $AdviceNoteCopyWith<$Res>  {
$AdviceNoteCopyWith(AdviceNote _, $Res Function(AdviceNote) __);
}


/// Adds pattern-matching-related methods to [AdviceNote].
extension AdviceNotePatterns on AdviceNote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AllergenContains value)?  allergenContains,TResult Function( AllergenMayContain value)?  allergenMayContain,TResult Function( AllergensNoneListed value)?  allergensNoneListed,TResult Function( AdditiveAvoided value)?  additiveAvoided,TResult Function( AdditiveRiskNote value)?  additiveRisk,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AllergenContains() when allergenContains != null:
return allergenContains(_that);case AllergenMayContain() when allergenMayContain != null:
return allergenMayContain(_that);case AllergensNoneListed() when allergensNoneListed != null:
return allergensNoneListed(_that);case AdditiveAvoided() when additiveAvoided != null:
return additiveAvoided(_that);case AdditiveRiskNote() when additiveRisk != null:
return additiveRisk(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AllergenContains value)  allergenContains,required TResult Function( AllergenMayContain value)  allergenMayContain,required TResult Function( AllergensNoneListed value)  allergensNoneListed,required TResult Function( AdditiveAvoided value)  additiveAvoided,required TResult Function( AdditiveRiskNote value)  additiveRisk,}){
final _that = this;
switch (_that) {
case AllergenContains():
return allergenContains(_that);case AllergenMayContain():
return allergenMayContain(_that);case AllergensNoneListed():
return allergensNoneListed(_that);case AdditiveAvoided():
return additiveAvoided(_that);case AdditiveRiskNote():
return additiveRisk(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AllergenContains value)?  allergenContains,TResult? Function( AllergenMayContain value)?  allergenMayContain,TResult? Function( AllergensNoneListed value)?  allergensNoneListed,TResult? Function( AdditiveAvoided value)?  additiveAvoided,TResult? Function( AdditiveRiskNote value)?  additiveRisk,}){
final _that = this;
switch (_that) {
case AllergenContains() when allergenContains != null:
return allergenContains(_that);case AllergenMayContain() when allergenMayContain != null:
return allergenMayContain(_that);case AllergensNoneListed() when allergensNoneListed != null:
return allergensNoneListed(_that);case AdditiveAvoided() when additiveAvoided != null:
return additiveAvoided(_that);case AdditiveRiskNote() when additiveRisk != null:
return additiveRisk(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Allergen allergen)?  allergenContains,TResult Function( Allergen allergen)?  allergenMayContain,TResult Function()?  allergensNoneListed,TResult Function( String code,  String? name)?  additiveAvoided,TResult Function( String code,  String? name,  bool high)?  additiveRisk,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AllergenContains() when allergenContains != null:
return allergenContains(_that.allergen);case AllergenMayContain() when allergenMayContain != null:
return allergenMayContain(_that.allergen);case AllergensNoneListed() when allergensNoneListed != null:
return allergensNoneListed();case AdditiveAvoided() when additiveAvoided != null:
return additiveAvoided(_that.code,_that.name);case AdditiveRiskNote() when additiveRisk != null:
return additiveRisk(_that.code,_that.name,_that.high);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Allergen allergen)  allergenContains,required TResult Function( Allergen allergen)  allergenMayContain,required TResult Function()  allergensNoneListed,required TResult Function( String code,  String? name)  additiveAvoided,required TResult Function( String code,  String? name,  bool high)  additiveRisk,}) {final _that = this;
switch (_that) {
case AllergenContains():
return allergenContains(_that.allergen);case AllergenMayContain():
return allergenMayContain(_that.allergen);case AllergensNoneListed():
return allergensNoneListed();case AdditiveAvoided():
return additiveAvoided(_that.code,_that.name);case AdditiveRiskNote():
return additiveRisk(_that.code,_that.name,_that.high);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Allergen allergen)?  allergenContains,TResult? Function( Allergen allergen)?  allergenMayContain,TResult? Function()?  allergensNoneListed,TResult? Function( String code,  String? name)?  additiveAvoided,TResult? Function( String code,  String? name,  bool high)?  additiveRisk,}) {final _that = this;
switch (_that) {
case AllergenContains() when allergenContains != null:
return allergenContains(_that.allergen);case AllergenMayContain() when allergenMayContain != null:
return allergenMayContain(_that.allergen);case AllergensNoneListed() when allergensNoneListed != null:
return allergensNoneListed();case AdditiveAvoided() when additiveAvoided != null:
return additiveAvoided(_that.code,_that.name);case AdditiveRiskNote() when additiveRisk != null:
return additiveRisk(_that.code,_that.name,_that.high);case _:
  return null;

}
}

}

/// @nodoc


class AllergenContains implements AdviceNote {
  const AllergenContains(this.allergen);
  

 final  Allergen allergen;

/// Create a copy of AdviceNote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AllergenContainsCopyWith<AllergenContains> get copyWith => _$AllergenContainsCopyWithImpl<AllergenContains>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AllergenContains&&(identical(other.allergen, allergen) || other.allergen == allergen));
}


@override
int get hashCode => Object.hash(runtimeType,allergen);

@override
String toString() {
  return 'AdviceNote.allergenContains(allergen: $allergen)';
}


}

/// @nodoc
abstract mixin class $AllergenContainsCopyWith<$Res> implements $AdviceNoteCopyWith<$Res> {
  factory $AllergenContainsCopyWith(AllergenContains value, $Res Function(AllergenContains) _then) = _$AllergenContainsCopyWithImpl;
@useResult
$Res call({
 Allergen allergen
});




}
/// @nodoc
class _$AllergenContainsCopyWithImpl<$Res>
    implements $AllergenContainsCopyWith<$Res> {
  _$AllergenContainsCopyWithImpl(this._self, this._then);

  final AllergenContains _self;
  final $Res Function(AllergenContains) _then;

/// Create a copy of AdviceNote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? allergen = null,}) {
  return _then(AllergenContains(
null == allergen ? _self.allergen : allergen // ignore: cast_nullable_to_non_nullable
as Allergen,
  ));
}


}

/// @nodoc


class AllergenMayContain implements AdviceNote {
  const AllergenMayContain(this.allergen);
  

 final  Allergen allergen;

/// Create a copy of AdviceNote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AllergenMayContainCopyWith<AllergenMayContain> get copyWith => _$AllergenMayContainCopyWithImpl<AllergenMayContain>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AllergenMayContain&&(identical(other.allergen, allergen) || other.allergen == allergen));
}


@override
int get hashCode => Object.hash(runtimeType,allergen);

@override
String toString() {
  return 'AdviceNote.allergenMayContain(allergen: $allergen)';
}


}

/// @nodoc
abstract mixin class $AllergenMayContainCopyWith<$Res> implements $AdviceNoteCopyWith<$Res> {
  factory $AllergenMayContainCopyWith(AllergenMayContain value, $Res Function(AllergenMayContain) _then) = _$AllergenMayContainCopyWithImpl;
@useResult
$Res call({
 Allergen allergen
});




}
/// @nodoc
class _$AllergenMayContainCopyWithImpl<$Res>
    implements $AllergenMayContainCopyWith<$Res> {
  _$AllergenMayContainCopyWithImpl(this._self, this._then);

  final AllergenMayContain _self;
  final $Res Function(AllergenMayContain) _then;

/// Create a copy of AdviceNote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? allergen = null,}) {
  return _then(AllergenMayContain(
null == allergen ? _self.allergen : allergen // ignore: cast_nullable_to_non_nullable
as Allergen,
  ));
}


}

/// @nodoc


class AllergensNoneListed implements AdviceNote {
  const AllergensNoneListed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AllergensNoneListed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AdviceNote.allergensNoneListed()';
}


}




/// @nodoc


class AdditiveAvoided implements AdviceNote {
  const AdditiveAvoided(this.code, this.name);
  

 final  String code;
 final  String? name;

/// Create a copy of AdviceNote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdditiveAvoidedCopyWith<AdditiveAvoided> get copyWith => _$AdditiveAvoidedCopyWithImpl<AdditiveAvoided>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdditiveAvoided&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,code,name);

@override
String toString() {
  return 'AdviceNote.additiveAvoided(code: $code, name: $name)';
}


}

/// @nodoc
abstract mixin class $AdditiveAvoidedCopyWith<$Res> implements $AdviceNoteCopyWith<$Res> {
  factory $AdditiveAvoidedCopyWith(AdditiveAvoided value, $Res Function(AdditiveAvoided) _then) = _$AdditiveAvoidedCopyWithImpl;
@useResult
$Res call({
 String code, String? name
});




}
/// @nodoc
class _$AdditiveAvoidedCopyWithImpl<$Res>
    implements $AdditiveAvoidedCopyWith<$Res> {
  _$AdditiveAvoidedCopyWithImpl(this._self, this._then);

  final AdditiveAvoided _self;
  final $Res Function(AdditiveAvoided) _then;

/// Create a copy of AdviceNote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = freezed,}) {
  return _then(AdditiveAvoided(
null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class AdditiveRiskNote implements AdviceNote {
  const AdditiveRiskNote(this.code, this.name, {required this.high});
  

 final  String code;
 final  String? name;
 final  bool high;

/// Create a copy of AdviceNote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdditiveRiskNoteCopyWith<AdditiveRiskNote> get copyWith => _$AdditiveRiskNoteCopyWithImpl<AdditiveRiskNote>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdditiveRiskNote&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.high, high) || other.high == high));
}


@override
int get hashCode => Object.hash(runtimeType,code,name,high);

@override
String toString() {
  return 'AdviceNote.additiveRisk(code: $code, name: $name, high: $high)';
}


}

/// @nodoc
abstract mixin class $AdditiveRiskNoteCopyWith<$Res> implements $AdviceNoteCopyWith<$Res> {
  factory $AdditiveRiskNoteCopyWith(AdditiveRiskNote value, $Res Function(AdditiveRiskNote) _then) = _$AdditiveRiskNoteCopyWithImpl;
@useResult
$Res call({
 String code, String? name, bool high
});




}
/// @nodoc
class _$AdditiveRiskNoteCopyWithImpl<$Res>
    implements $AdditiveRiskNoteCopyWith<$Res> {
  _$AdditiveRiskNoteCopyWithImpl(this._self, this._then);

  final AdditiveRiskNote _self;
  final $Res Function(AdditiveRiskNote) _then;

/// Create a copy of AdviceNote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = freezed,Object? high = null,}) {
  return _then(AdditiveRiskNote(
null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,high: null == high ? _self.high : high // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ForYou {

/// Allergen notes first, then additive notes.
 List<AdviceNote> get notes;/// Null without nutrition values (`no_nutrition`).
 Portion? get portion; List<Share> get shares;/// `shares_personal` or `shares_reference`.
 NeedsBasis get basis;/// False: `set_up_profile` is shown.
 bool get hasProfile;
/// Create a copy of ForYou
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ForYouCopyWith<ForYou> get copyWith => _$ForYouCopyWithImpl<ForYou>(this as ForYou, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ForYou&&const DeepCollectionEquality().equals(other.notes, notes)&&(identical(other.portion, portion) || other.portion == portion)&&const DeepCollectionEquality().equals(other.shares, shares)&&(identical(other.basis, basis) || other.basis == basis)&&(identical(other.hasProfile, hasProfile) || other.hasProfile == hasProfile));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(notes),portion,const DeepCollectionEquality().hash(shares),basis,hasProfile);

@override
String toString() {
  return 'ForYou(notes: $notes, portion: $portion, shares: $shares, basis: $basis, hasProfile: $hasProfile)';
}


}

/// @nodoc
abstract mixin class $ForYouCopyWith<$Res>  {
  factory $ForYouCopyWith(ForYou value, $Res Function(ForYou) _then) = _$ForYouCopyWithImpl;
@useResult
$Res call({
 List<AdviceNote> notes, Portion? portion, List<Share> shares, NeedsBasis basis, bool hasProfile
});


$PortionCopyWith<$Res>? get portion;

}
/// @nodoc
class _$ForYouCopyWithImpl<$Res>
    implements $ForYouCopyWith<$Res> {
  _$ForYouCopyWithImpl(this._self, this._then);

  final ForYou _self;
  final $Res Function(ForYou) _then;

/// Create a copy of ForYou
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? notes = null,Object? portion = freezed,Object? shares = null,Object? basis = null,Object? hasProfile = null,}) {
  return _then(_self.copyWith(
notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as List<AdviceNote>,portion: freezed == portion ? _self.portion : portion // ignore: cast_nullable_to_non_nullable
as Portion?,shares: null == shares ? _self.shares : shares // ignore: cast_nullable_to_non_nullable
as List<Share>,basis: null == basis ? _self.basis : basis // ignore: cast_nullable_to_non_nullable
as NeedsBasis,hasProfile: null == hasProfile ? _self.hasProfile : hasProfile // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ForYou
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PortionCopyWith<$Res>? get portion {
    if (_self.portion == null) {
    return null;
  }

  return $PortionCopyWith<$Res>(_self.portion!, (value) {
    return _then(_self.copyWith(portion: value));
  });
}
}


/// Adds pattern-matching-related methods to [ForYou].
extension ForYouPatterns on ForYou {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ForYou value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ForYou() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ForYou value)  $default,){
final _that = this;
switch (_that) {
case _ForYou():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ForYou value)?  $default,){
final _that = this;
switch (_that) {
case _ForYou() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AdviceNote> notes,  Portion? portion,  List<Share> shares,  NeedsBasis basis,  bool hasProfile)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ForYou() when $default != null:
return $default(_that.notes,_that.portion,_that.shares,_that.basis,_that.hasProfile);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AdviceNote> notes,  Portion? portion,  List<Share> shares,  NeedsBasis basis,  bool hasProfile)  $default,) {final _that = this;
switch (_that) {
case _ForYou():
return $default(_that.notes,_that.portion,_that.shares,_that.basis,_that.hasProfile);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AdviceNote> notes,  Portion? portion,  List<Share> shares,  NeedsBasis basis,  bool hasProfile)?  $default,) {final _that = this;
switch (_that) {
case _ForYou() when $default != null:
return $default(_that.notes,_that.portion,_that.shares,_that.basis,_that.hasProfile);case _:
  return null;

}
}

}

/// @nodoc


class _ForYou implements ForYou {
  const _ForYou({required final  List<AdviceNote> notes, required this.portion, required final  List<Share> shares, required this.basis, required this.hasProfile}): _notes = notes,_shares = shares;
  

/// Allergen notes first, then additive notes.
 final  List<AdviceNote> _notes;
/// Allergen notes first, then additive notes.
@override List<AdviceNote> get notes {
  if (_notes is EqualUnmodifiableListView) return _notes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notes);
}

/// Null without nutrition values (`no_nutrition`).
@override final  Portion? portion;
 final  List<Share> _shares;
@override List<Share> get shares {
  if (_shares is EqualUnmodifiableListView) return _shares;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_shares);
}

/// `shares_personal` or `shares_reference`.
@override final  NeedsBasis basis;
/// False: `set_up_profile` is shown.
@override final  bool hasProfile;

/// Create a copy of ForYou
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ForYouCopyWith<_ForYou> get copyWith => __$ForYouCopyWithImpl<_ForYou>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ForYou&&const DeepCollectionEquality().equals(other._notes, _notes)&&(identical(other.portion, portion) || other.portion == portion)&&const DeepCollectionEquality().equals(other._shares, _shares)&&(identical(other.basis, basis) || other.basis == basis)&&(identical(other.hasProfile, hasProfile) || other.hasProfile == hasProfile));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_notes),portion,const DeepCollectionEquality().hash(_shares),basis,hasProfile);

@override
String toString() {
  return 'ForYou(notes: $notes, portion: $portion, shares: $shares, basis: $basis, hasProfile: $hasProfile)';
}


}

/// @nodoc
abstract mixin class _$ForYouCopyWith<$Res> implements $ForYouCopyWith<$Res> {
  factory _$ForYouCopyWith(_ForYou value, $Res Function(_ForYou) _then) = __$ForYouCopyWithImpl;
@override @useResult
$Res call({
 List<AdviceNote> notes, Portion? portion, List<Share> shares, NeedsBasis basis, bool hasProfile
});


@override $PortionCopyWith<$Res>? get portion;

}
/// @nodoc
class __$ForYouCopyWithImpl<$Res>
    implements _$ForYouCopyWith<$Res> {
  __$ForYouCopyWithImpl(this._self, this._then);

  final _ForYou _self;
  final $Res Function(_ForYou) _then;

/// Create a copy of ForYou
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? notes = null,Object? portion = freezed,Object? shares = null,Object? basis = null,Object? hasProfile = null,}) {
  return _then(_ForYou(
notes: null == notes ? _self._notes : notes // ignore: cast_nullable_to_non_nullable
as List<AdviceNote>,portion: freezed == portion ? _self.portion : portion // ignore: cast_nullable_to_non_nullable
as Portion?,shares: null == shares ? _self._shares : shares // ignore: cast_nullable_to_non_nullable
as List<Share>,basis: null == basis ? _self.basis : basis // ignore: cast_nullable_to_non_nullable
as NeedsBasis,hasProfile: null == hasProfile ? _self.hasProfile : hasProfile // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ForYou
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PortionCopyWith<$Res>? get portion {
    if (_self.portion == null) {
    return null;
  }

  return $PortionCopyWith<$Res>(_self.portion!, (value) {
    return _then(_self.copyWith(portion: value));
  });
}
}

// dart format on
