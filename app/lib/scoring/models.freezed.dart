// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Breakdown {

 Map<String, int> get negative; Map<String, int> get positive; int get negativeTotal; int get positiveTotal; bool get proteinCounted; int get score;/// Undeclared inputs scored as 0 points (decision 8: fibre only).
 List<String> get assumedZero;
/// Create a copy of Breakdown
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BreakdownCopyWith<Breakdown> get copyWith => _$BreakdownCopyWithImpl<Breakdown>(this as Breakdown, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Breakdown&&const DeepCollectionEquality().equals(other.negative, negative)&&const DeepCollectionEquality().equals(other.positive, positive)&&(identical(other.negativeTotal, negativeTotal) || other.negativeTotal == negativeTotal)&&(identical(other.positiveTotal, positiveTotal) || other.positiveTotal == positiveTotal)&&(identical(other.proteinCounted, proteinCounted) || other.proteinCounted == proteinCounted)&&(identical(other.score, score) || other.score == score)&&const DeepCollectionEquality().equals(other.assumedZero, assumedZero));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(negative),const DeepCollectionEquality().hash(positive),negativeTotal,positiveTotal,proteinCounted,score,const DeepCollectionEquality().hash(assumedZero));

@override
String toString() {
  return 'Breakdown(negative: $negative, positive: $positive, negativeTotal: $negativeTotal, positiveTotal: $positiveTotal, proteinCounted: $proteinCounted, score: $score, assumedZero: $assumedZero)';
}


}

/// @nodoc
abstract mixin class $BreakdownCopyWith<$Res>  {
  factory $BreakdownCopyWith(Breakdown value, $Res Function(Breakdown) _then) = _$BreakdownCopyWithImpl;
@useResult
$Res call({
 Map<String, int> negative, Map<String, int> positive, int negativeTotal, int positiveTotal, bool proteinCounted, int score, List<String> assumedZero
});




}
/// @nodoc
class _$BreakdownCopyWithImpl<$Res>
    implements $BreakdownCopyWith<$Res> {
  _$BreakdownCopyWithImpl(this._self, this._then);

  final Breakdown _self;
  final $Res Function(Breakdown) _then;

/// Create a copy of Breakdown
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? negative = null,Object? positive = null,Object? negativeTotal = null,Object? positiveTotal = null,Object? proteinCounted = null,Object? score = null,Object? assumedZero = null,}) {
  return _then(_self.copyWith(
negative: null == negative ? _self.negative : negative // ignore: cast_nullable_to_non_nullable
as Map<String, int>,positive: null == positive ? _self.positive : positive // ignore: cast_nullable_to_non_nullable
as Map<String, int>,negativeTotal: null == negativeTotal ? _self.negativeTotal : negativeTotal // ignore: cast_nullable_to_non_nullable
as int,positiveTotal: null == positiveTotal ? _self.positiveTotal : positiveTotal // ignore: cast_nullable_to_non_nullable
as int,proteinCounted: null == proteinCounted ? _self.proteinCounted : proteinCounted // ignore: cast_nullable_to_non_nullable
as bool,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,assumedZero: null == assumedZero ? _self.assumedZero : assumedZero // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Breakdown].
extension BreakdownPatterns on Breakdown {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Breakdown value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Breakdown() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Breakdown value)  $default,){
final _that = this;
switch (_that) {
case _Breakdown():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Breakdown value)?  $default,){
final _that = this;
switch (_that) {
case _Breakdown() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, int> negative,  Map<String, int> positive,  int negativeTotal,  int positiveTotal,  bool proteinCounted,  int score,  List<String> assumedZero)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Breakdown() when $default != null:
return $default(_that.negative,_that.positive,_that.negativeTotal,_that.positiveTotal,_that.proteinCounted,_that.score,_that.assumedZero);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, int> negative,  Map<String, int> positive,  int negativeTotal,  int positiveTotal,  bool proteinCounted,  int score,  List<String> assumedZero)  $default,) {final _that = this;
switch (_that) {
case _Breakdown():
return $default(_that.negative,_that.positive,_that.negativeTotal,_that.positiveTotal,_that.proteinCounted,_that.score,_that.assumedZero);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, int> negative,  Map<String, int> positive,  int negativeTotal,  int positiveTotal,  bool proteinCounted,  int score,  List<String> assumedZero)?  $default,) {final _that = this;
switch (_that) {
case _Breakdown() when $default != null:
return $default(_that.negative,_that.positive,_that.negativeTotal,_that.positiveTotal,_that.proteinCounted,_that.score,_that.assumedZero);case _:
  return null;

}
}

}

/// @nodoc


class _Breakdown implements Breakdown {
  const _Breakdown({required final  Map<String, int> negative, required final  Map<String, int> positive, required this.negativeTotal, required this.positiveTotal, required this.proteinCounted, required this.score, final  List<String> assumedZero = const <String>[]}): _negative = negative,_positive = positive,_assumedZero = assumedZero;
  

 final  Map<String, int> _negative;
@override Map<String, int> get negative {
  if (_negative is EqualUnmodifiableMapView) return _negative;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_negative);
}

 final  Map<String, int> _positive;
@override Map<String, int> get positive {
  if (_positive is EqualUnmodifiableMapView) return _positive;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_positive);
}

@override final  int negativeTotal;
@override final  int positiveTotal;
@override final  bool proteinCounted;
@override final  int score;
/// Undeclared inputs scored as 0 points (decision 8: fibre only).
 final  List<String> _assumedZero;
/// Undeclared inputs scored as 0 points (decision 8: fibre only).
@override@JsonKey() List<String> get assumedZero {
  if (_assumedZero is EqualUnmodifiableListView) return _assumedZero;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_assumedZero);
}


/// Create a copy of Breakdown
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BreakdownCopyWith<_Breakdown> get copyWith => __$BreakdownCopyWithImpl<_Breakdown>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Breakdown&&const DeepCollectionEquality().equals(other._negative, _negative)&&const DeepCollectionEquality().equals(other._positive, _positive)&&(identical(other.negativeTotal, negativeTotal) || other.negativeTotal == negativeTotal)&&(identical(other.positiveTotal, positiveTotal) || other.positiveTotal == positiveTotal)&&(identical(other.proteinCounted, proteinCounted) || other.proteinCounted == proteinCounted)&&(identical(other.score, score) || other.score == score)&&const DeepCollectionEquality().equals(other._assumedZero, _assumedZero));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_negative),const DeepCollectionEquality().hash(_positive),negativeTotal,positiveTotal,proteinCounted,score,const DeepCollectionEquality().hash(_assumedZero));

@override
String toString() {
  return 'Breakdown(negative: $negative, positive: $positive, negativeTotal: $negativeTotal, positiveTotal: $positiveTotal, proteinCounted: $proteinCounted, score: $score, assumedZero: $assumedZero)';
}


}

/// @nodoc
abstract mixin class _$BreakdownCopyWith<$Res> implements $BreakdownCopyWith<$Res> {
  factory _$BreakdownCopyWith(_Breakdown value, $Res Function(_Breakdown) _then) = __$BreakdownCopyWithImpl;
@override @useResult
$Res call({
 Map<String, int> negative, Map<String, int> positive, int negativeTotal, int positiveTotal, bool proteinCounted, int score, List<String> assumedZero
});




}
/// @nodoc
class __$BreakdownCopyWithImpl<$Res>
    implements _$BreakdownCopyWith<$Res> {
  __$BreakdownCopyWithImpl(this._self, this._then);

  final _Breakdown _self;
  final $Res Function(_Breakdown) _then;

/// Create a copy of Breakdown
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? negative = null,Object? positive = null,Object? negativeTotal = null,Object? positiveTotal = null,Object? proteinCounted = null,Object? score = null,Object? assumedZero = null,}) {
  return _then(_Breakdown(
negative: null == negative ? _self._negative : negative // ignore: cast_nullable_to_non_nullable
as Map<String, int>,positive: null == positive ? _self._positive : positive // ignore: cast_nullable_to_non_nullable
as Map<String, int>,negativeTotal: null == negativeTotal ? _self.negativeTotal : negativeTotal // ignore: cast_nullable_to_non_nullable
as int,positiveTotal: null == positiveTotal ? _self.positiveTotal : positiveTotal // ignore: cast_nullable_to_non_nullable
as int,proteinCounted: null == proteinCounted ? _self.proteinCounted : proteinCounted // ignore: cast_nullable_to_non_nullable
as bool,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,assumedZero: null == assumedZero ? _self._assumedZero : assumedZero // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$ScoreResult {

 Category get category; String get engineVersion;
/// Create a copy of ScoreResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScoreResultCopyWith<ScoreResult> get copyWith => _$ScoreResultCopyWithImpl<ScoreResult>(this as ScoreResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScoreResult&&(identical(other.category, category) || other.category == category)&&(identical(other.engineVersion, engineVersion) || other.engineVersion == engineVersion));
}


@override
int get hashCode => Object.hash(runtimeType,category,engineVersion);

@override
String toString() {
  return 'ScoreResult(category: $category, engineVersion: $engineVersion)';
}


}

/// @nodoc
abstract mixin class $ScoreResultCopyWith<$Res>  {
  factory $ScoreResultCopyWith(ScoreResult value, $Res Function(ScoreResult) _then) = _$ScoreResultCopyWithImpl;
@useResult
$Res call({
 Category category, String engineVersion
});




}
/// @nodoc
class _$ScoreResultCopyWithImpl<$Res>
    implements $ScoreResultCopyWith<$Res> {
  _$ScoreResultCopyWithImpl(this._self, this._then);

  final ScoreResult _self;
  final $Res Function(ScoreResult) _then;

/// Create a copy of ScoreResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? category = null,Object? engineVersion = null,}) {
  return _then(_self.copyWith(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category,engineVersion: null == engineVersion ? _self.engineVersion : engineVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ScoreResult].
extension ScoreResultPatterns on ScoreResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( NutriScore value)?  graded,TResult Function( InsufficientData value)?  insufficientData,required TResult orElse(),}){
final _that = this;
switch (_that) {
case NutriScore() when graded != null:
return graded(_that);case InsufficientData() when insufficientData != null:
return insufficientData(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( NutriScore value)  graded,required TResult Function( InsufficientData value)  insufficientData,}){
final _that = this;
switch (_that) {
case NutriScore():
return graded(_that);case InsufficientData():
return insufficientData(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( NutriScore value)?  graded,TResult? Function( InsufficientData value)?  insufficientData,}){
final _that = this;
switch (_that) {
case NutriScore() when graded != null:
return graded(_that);case InsufficientData() when insufficientData != null:
return insufficientData(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Category category,  Grade grade,  Breakdown? breakdown,  String engineVersion)?  graded,TResult Function( Category category,  List<String> missing,  String engineVersion)?  insufficientData,required TResult orElse(),}) {final _that = this;
switch (_that) {
case NutriScore() when graded != null:
return graded(_that.category,_that.grade,_that.breakdown,_that.engineVersion);case InsufficientData() when insufficientData != null:
return insufficientData(_that.category,_that.missing,_that.engineVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Category category,  Grade grade,  Breakdown? breakdown,  String engineVersion)  graded,required TResult Function( Category category,  List<String> missing,  String engineVersion)  insufficientData,}) {final _that = this;
switch (_that) {
case NutriScore():
return graded(_that.category,_that.grade,_that.breakdown,_that.engineVersion);case InsufficientData():
return insufficientData(_that.category,_that.missing,_that.engineVersion);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Category category,  Grade grade,  Breakdown? breakdown,  String engineVersion)?  graded,TResult? Function( Category category,  List<String> missing,  String engineVersion)?  insufficientData,}) {final _that = this;
switch (_that) {
case NutriScore() when graded != null:
return graded(_that.category,_that.grade,_that.breakdown,_that.engineVersion);case InsufficientData() when insufficientData != null:
return insufficientData(_that.category,_that.missing,_that.engineVersion);case _:
  return null;

}
}

}

/// @nodoc


class NutriScore implements ScoreResult {
  const NutriScore({required this.category, required this.grade, required this.breakdown, this.engineVersion = scoringEngineVersion});
  

@override final  Category category;
 final  Grade grade;
 final  Breakdown? breakdown;
@override@JsonKey() final  String engineVersion;

/// Create a copy of ScoreResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NutriScoreCopyWith<NutriScore> get copyWith => _$NutriScoreCopyWithImpl<NutriScore>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NutriScore&&(identical(other.category, category) || other.category == category)&&(identical(other.grade, grade) || other.grade == grade)&&(identical(other.breakdown, breakdown) || other.breakdown == breakdown)&&(identical(other.engineVersion, engineVersion) || other.engineVersion == engineVersion));
}


@override
int get hashCode => Object.hash(runtimeType,category,grade,breakdown,engineVersion);

@override
String toString() {
  return 'ScoreResult.graded(category: $category, grade: $grade, breakdown: $breakdown, engineVersion: $engineVersion)';
}


}

/// @nodoc
abstract mixin class $NutriScoreCopyWith<$Res> implements $ScoreResultCopyWith<$Res> {
  factory $NutriScoreCopyWith(NutriScore value, $Res Function(NutriScore) _then) = _$NutriScoreCopyWithImpl;
@override @useResult
$Res call({
 Category category, Grade grade, Breakdown? breakdown, String engineVersion
});


$BreakdownCopyWith<$Res>? get breakdown;

}
/// @nodoc
class _$NutriScoreCopyWithImpl<$Res>
    implements $NutriScoreCopyWith<$Res> {
  _$NutriScoreCopyWithImpl(this._self, this._then);

  final NutriScore _self;
  final $Res Function(NutriScore) _then;

/// Create a copy of ScoreResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? category = null,Object? grade = null,Object? breakdown = freezed,Object? engineVersion = null,}) {
  return _then(NutriScore(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category,grade: null == grade ? _self.grade : grade // ignore: cast_nullable_to_non_nullable
as Grade,breakdown: freezed == breakdown ? _self.breakdown : breakdown // ignore: cast_nullable_to_non_nullable
as Breakdown?,engineVersion: null == engineVersion ? _self.engineVersion : engineVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of ScoreResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BreakdownCopyWith<$Res>? get breakdown {
    if (_self.breakdown == null) {
    return null;
  }

  return $BreakdownCopyWith<$Res>(_self.breakdown!, (value) {
    return _then(_self.copyWith(breakdown: value));
  });
}
}

/// @nodoc


class InsufficientData implements ScoreResult {
  const InsufficientData({required this.category, required final  List<String> missing, this.engineVersion = scoringEngineVersion}): _missing = missing;
  

@override final  Category category;
 final  List<String> _missing;
 List<String> get missing {
  if (_missing is EqualUnmodifiableListView) return _missing;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_missing);
}

@override@JsonKey() final  String engineVersion;

/// Create a copy of ScoreResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InsufficientDataCopyWith<InsufficientData> get copyWith => _$InsufficientDataCopyWithImpl<InsufficientData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InsufficientData&&(identical(other.category, category) || other.category == category)&&const DeepCollectionEquality().equals(other._missing, _missing)&&(identical(other.engineVersion, engineVersion) || other.engineVersion == engineVersion));
}


@override
int get hashCode => Object.hash(runtimeType,category,const DeepCollectionEquality().hash(_missing),engineVersion);

@override
String toString() {
  return 'ScoreResult.insufficientData(category: $category, missing: $missing, engineVersion: $engineVersion)';
}


}

/// @nodoc
abstract mixin class $InsufficientDataCopyWith<$Res> implements $ScoreResultCopyWith<$Res> {
  factory $InsufficientDataCopyWith(InsufficientData value, $Res Function(InsufficientData) _then) = _$InsufficientDataCopyWithImpl;
@override @useResult
$Res call({
 Category category, List<String> missing, String engineVersion
});




}
/// @nodoc
class _$InsufficientDataCopyWithImpl<$Res>
    implements $InsufficientDataCopyWith<$Res> {
  _$InsufficientDataCopyWithImpl(this._self, this._then);

  final InsufficientData _self;
  final $Res Function(InsufficientData) _then;

/// Create a copy of ScoreResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? category = null,Object? missing = null,Object? engineVersion = null,}) {
  return _then(InsufficientData(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category,missing: null == missing ? _self._missing : missing // ignore: cast_nullable_to_non_nullable
as List<String>,engineVersion: null == engineVersion ? _self.engineVersion : engineVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
