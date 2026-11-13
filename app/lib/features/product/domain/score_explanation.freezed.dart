// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'score_explanation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScoreComponent {

/// Breakdown key: `energy`, `saturated_fat_ratio`, `fvl`, ...
 String get name; int get points; int? get maxPoints;
/// Create a copy of ScoreComponent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScoreComponentCopyWith<ScoreComponent> get copyWith => _$ScoreComponentCopyWithImpl<ScoreComponent>(this as ScoreComponent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScoreComponent&&(identical(other.name, name) || other.name == name)&&(identical(other.points, points) || other.points == points)&&(identical(other.maxPoints, maxPoints) || other.maxPoints == maxPoints));
}


@override
int get hashCode => Object.hash(runtimeType,name,points,maxPoints);

@override
String toString() {
  return 'ScoreComponent(name: $name, points: $points, maxPoints: $maxPoints)';
}


}

/// @nodoc
abstract mixin class $ScoreComponentCopyWith<$Res>  {
  factory $ScoreComponentCopyWith(ScoreComponent value, $Res Function(ScoreComponent) _then) = _$ScoreComponentCopyWithImpl;
@useResult
$Res call({
 String name, int points, int? maxPoints
});




}
/// @nodoc
class _$ScoreComponentCopyWithImpl<$Res>
    implements $ScoreComponentCopyWith<$Res> {
  _$ScoreComponentCopyWithImpl(this._self, this._then);

  final ScoreComponent _self;
  final $Res Function(ScoreComponent) _then;

/// Create a copy of ScoreComponent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? points = null,Object? maxPoints = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,maxPoints: freezed == maxPoints ? _self.maxPoints : maxPoints // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ScoreComponent].
extension ScoreComponentPatterns on ScoreComponent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScoreComponent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScoreComponent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScoreComponent value)  $default,){
final _that = this;
switch (_that) {
case _ScoreComponent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScoreComponent value)?  $default,){
final _that = this;
switch (_that) {
case _ScoreComponent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int points,  int? maxPoints)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScoreComponent() when $default != null:
return $default(_that.name,_that.points,_that.maxPoints);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int points,  int? maxPoints)  $default,) {final _that = this;
switch (_that) {
case _ScoreComponent():
return $default(_that.name,_that.points,_that.maxPoints);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int points,  int? maxPoints)?  $default,) {final _that = this;
switch (_that) {
case _ScoreComponent() when $default != null:
return $default(_that.name,_that.points,_that.maxPoints);case _:
  return null;

}
}

}

/// @nodoc


class _ScoreComponent implements ScoreComponent {
  const _ScoreComponent({required this.name, required this.points, this.maxPoints});
  

/// Breakdown key: `energy`, `saturated_fat_ratio`, `fvl`, ...
@override final  String name;
@override final  int points;
@override final  int? maxPoints;

/// Create a copy of ScoreComponent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScoreComponentCopyWith<_ScoreComponent> get copyWith => __$ScoreComponentCopyWithImpl<_ScoreComponent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScoreComponent&&(identical(other.name, name) || other.name == name)&&(identical(other.points, points) || other.points == points)&&(identical(other.maxPoints, maxPoints) || other.maxPoints == maxPoints));
}


@override
int get hashCode => Object.hash(runtimeType,name,points,maxPoints);

@override
String toString() {
  return 'ScoreComponent(name: $name, points: $points, maxPoints: $maxPoints)';
}


}

/// @nodoc
abstract mixin class _$ScoreComponentCopyWith<$Res> implements $ScoreComponentCopyWith<$Res> {
  factory _$ScoreComponentCopyWith(_ScoreComponent value, $Res Function(_ScoreComponent) _then) = __$ScoreComponentCopyWithImpl;
@override @useResult
$Res call({
 String name, int points, int? maxPoints
});




}
/// @nodoc
class __$ScoreComponentCopyWithImpl<$Res>
    implements _$ScoreComponentCopyWith<$Res> {
  __$ScoreComponentCopyWithImpl(this._self, this._then);

  final _ScoreComponent _self;
  final $Res Function(_ScoreComponent) _then;

/// Create a copy of ScoreComponent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? points = null,Object? maxPoints = freezed,}) {
  return _then(_ScoreComponent(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,maxPoints: freezed == maxPoints ? _self.maxPoints : maxPoints // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$ScoreExplanation {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScoreExplanation);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ScoreExplanation()';
}


}

/// @nodoc
class $ScoreExplanationCopyWith<$Res>  {
$ScoreExplanationCopyWith(ScoreExplanation _, $Res Function(ScoreExplanation) __);
}


/// Adds pattern-matching-related methods to [ScoreExplanation].
extension ScoreExplanationPatterns on ScoreExplanation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( GradedExplanation value)?  graded,TResult Function( WaterExplanation value)?  water,TResult Function( GradeOnlyExplanation value)?  gradeOnly,TResult Function( InsufficientDataExplanation value)?  insufficientData,TResult Function( NotScoredExplanation value)?  notScored,required TResult orElse(),}){
final _that = this;
switch (_that) {
case GradedExplanation() when graded != null:
return graded(_that);case WaterExplanation() when water != null:
return water(_that);case GradeOnlyExplanation() when gradeOnly != null:
return gradeOnly(_that);case InsufficientDataExplanation() when insufficientData != null:
return insufficientData(_that);case NotScoredExplanation() when notScored != null:
return notScored(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( GradedExplanation value)  graded,required TResult Function( WaterExplanation value)  water,required TResult Function( GradeOnlyExplanation value)  gradeOnly,required TResult Function( InsufficientDataExplanation value)  insufficientData,required TResult Function( NotScoredExplanation value)  notScored,}){
final _that = this;
switch (_that) {
case GradedExplanation():
return graded(_that);case WaterExplanation():
return water(_that);case GradeOnlyExplanation():
return gradeOnly(_that);case InsufficientDataExplanation():
return insufficientData(_that);case NotScoredExplanation():
return notScored(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( GradedExplanation value)?  graded,TResult? Function( WaterExplanation value)?  water,TResult? Function( GradeOnlyExplanation value)?  gradeOnly,TResult? Function( InsufficientDataExplanation value)?  insufficientData,TResult? Function( NotScoredExplanation value)?  notScored,}){
final _that = this;
switch (_that) {
case GradedExplanation() when graded != null:
return graded(_that);case WaterExplanation() when water != null:
return water(_that);case GradeOnlyExplanation() when gradeOnly != null:
return gradeOnly(_that);case InsufficientDataExplanation() when insufficientData != null:
return insufficientData(_that);case NotScoredExplanation() when notScored != null:
return notScored(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Grade grade,  List<ScoreComponent> negative,  List<ScoreComponent> positive,  int negativeTotal,  int positiveTotal,  bool proteinCounted,  int score,  int? proteinNLimit,  List<String> assumedZero)?  graded,TResult Function()?  water,TResult Function( Grade grade)?  gradeOnly,TResult Function( List<String> missing)?  insufficientData,TResult Function()?  notScored,required TResult orElse(),}) {final _that = this;
switch (_that) {
case GradedExplanation() when graded != null:
return graded(_that.grade,_that.negative,_that.positive,_that.negativeTotal,_that.positiveTotal,_that.proteinCounted,_that.score,_that.proteinNLimit,_that.assumedZero);case WaterExplanation() when water != null:
return water();case GradeOnlyExplanation() when gradeOnly != null:
return gradeOnly(_that.grade);case InsufficientDataExplanation() when insufficientData != null:
return insufficientData(_that.missing);case NotScoredExplanation() when notScored != null:
return notScored();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Grade grade,  List<ScoreComponent> negative,  List<ScoreComponent> positive,  int negativeTotal,  int positiveTotal,  bool proteinCounted,  int score,  int? proteinNLimit,  List<String> assumedZero)  graded,required TResult Function()  water,required TResult Function( Grade grade)  gradeOnly,required TResult Function( List<String> missing)  insufficientData,required TResult Function()  notScored,}) {final _that = this;
switch (_that) {
case GradedExplanation():
return graded(_that.grade,_that.negative,_that.positive,_that.negativeTotal,_that.positiveTotal,_that.proteinCounted,_that.score,_that.proteinNLimit,_that.assumedZero);case WaterExplanation():
return water();case GradeOnlyExplanation():
return gradeOnly(_that.grade);case InsufficientDataExplanation():
return insufficientData(_that.missing);case NotScoredExplanation():
return notScored();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Grade grade,  List<ScoreComponent> negative,  List<ScoreComponent> positive,  int negativeTotal,  int positiveTotal,  bool proteinCounted,  int score,  int? proteinNLimit,  List<String> assumedZero)?  graded,TResult? Function()?  water,TResult? Function( Grade grade)?  gradeOnly,TResult? Function( List<String> missing)?  insufficientData,TResult? Function()?  notScored,}) {final _that = this;
switch (_that) {
case GradedExplanation() when graded != null:
return graded(_that.grade,_that.negative,_that.positive,_that.negativeTotal,_that.positiveTotal,_that.proteinCounted,_that.score,_that.proteinNLimit,_that.assumedZero);case WaterExplanation() when water != null:
return water();case GradeOnlyExplanation() when gradeOnly != null:
return gradeOnly(_that.grade);case InsufficientDataExplanation() when insufficientData != null:
return insufficientData(_that.missing);case NotScoredExplanation() when notScored != null:
return notScored();case _:
  return null;

}
}

}

/// @nodoc


class GradedExplanation implements ScoreExplanation {
  const GradedExplanation({required this.grade, required final  List<ScoreComponent> negative, required final  List<ScoreComponent> positive, required this.negativeTotal, required this.positiveTotal, required this.proteinCounted, required this.score, this.proteinNLimit, final  List<String> assumedZero = const <String>[]}): _negative = negative,_positive = positive,_assumedZero = assumedZero;
  

 final  Grade grade;
 final  List<ScoreComponent> _negative;
 List<ScoreComponent> get negative {
  if (_negative is EqualUnmodifiableListView) return _negative;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_negative);
}

 final  List<ScoreComponent> _positive;
 List<ScoreComponent> get positive {
  if (_positive is EqualUnmodifiableListView) return _positive;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_positive);
}

 final  int negativeTotal;
 final  int positiveTotal;
 final  bool proteinCounted;
 final  int score;
/// The negative-points limit from which protein stops counting, for the
/// categories that have one (general foods, red meat, fats).
 final  int? proteinNLimit;
/// Undeclared inputs counted as 0 points (decision 8: `fibre_g`).
 final  List<String> _assumedZero;
/// Undeclared inputs counted as 0 points (decision 8: `fibre_g`).
@JsonKey() List<String> get assumedZero {
  if (_assumedZero is EqualUnmodifiableListView) return _assumedZero;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_assumedZero);
}


/// Create a copy of ScoreExplanation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GradedExplanationCopyWith<GradedExplanation> get copyWith => _$GradedExplanationCopyWithImpl<GradedExplanation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GradedExplanation&&(identical(other.grade, grade) || other.grade == grade)&&const DeepCollectionEquality().equals(other._negative, _negative)&&const DeepCollectionEquality().equals(other._positive, _positive)&&(identical(other.negativeTotal, negativeTotal) || other.negativeTotal == negativeTotal)&&(identical(other.positiveTotal, positiveTotal) || other.positiveTotal == positiveTotal)&&(identical(other.proteinCounted, proteinCounted) || other.proteinCounted == proteinCounted)&&(identical(other.score, score) || other.score == score)&&(identical(other.proteinNLimit, proteinNLimit) || other.proteinNLimit == proteinNLimit)&&const DeepCollectionEquality().equals(other._assumedZero, _assumedZero));
}


@override
int get hashCode => Object.hash(runtimeType,grade,const DeepCollectionEquality().hash(_negative),const DeepCollectionEquality().hash(_positive),negativeTotal,positiveTotal,proteinCounted,score,proteinNLimit,const DeepCollectionEquality().hash(_assumedZero));

@override
String toString() {
  return 'ScoreExplanation.graded(grade: $grade, negative: $negative, positive: $positive, negativeTotal: $negativeTotal, positiveTotal: $positiveTotal, proteinCounted: $proteinCounted, score: $score, proteinNLimit: $proteinNLimit, assumedZero: $assumedZero)';
}


}

/// @nodoc
abstract mixin class $GradedExplanationCopyWith<$Res> implements $ScoreExplanationCopyWith<$Res> {
  factory $GradedExplanationCopyWith(GradedExplanation value, $Res Function(GradedExplanation) _then) = _$GradedExplanationCopyWithImpl;
@useResult
$Res call({
 Grade grade, List<ScoreComponent> negative, List<ScoreComponent> positive, int negativeTotal, int positiveTotal, bool proteinCounted, int score, int? proteinNLimit, List<String> assumedZero
});




}
/// @nodoc
class _$GradedExplanationCopyWithImpl<$Res>
    implements $GradedExplanationCopyWith<$Res> {
  _$GradedExplanationCopyWithImpl(this._self, this._then);

  final GradedExplanation _self;
  final $Res Function(GradedExplanation) _then;

/// Create a copy of ScoreExplanation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? grade = null,Object? negative = null,Object? positive = null,Object? negativeTotal = null,Object? positiveTotal = null,Object? proteinCounted = null,Object? score = null,Object? proteinNLimit = freezed,Object? assumedZero = null,}) {
  return _then(GradedExplanation(
grade: null == grade ? _self.grade : grade // ignore: cast_nullable_to_non_nullable
as Grade,negative: null == negative ? _self._negative : negative // ignore: cast_nullable_to_non_nullable
as List<ScoreComponent>,positive: null == positive ? _self._positive : positive // ignore: cast_nullable_to_non_nullable
as List<ScoreComponent>,negativeTotal: null == negativeTotal ? _self.negativeTotal : negativeTotal // ignore: cast_nullable_to_non_nullable
as int,positiveTotal: null == positiveTotal ? _self.positiveTotal : positiveTotal // ignore: cast_nullable_to_non_nullable
as int,proteinCounted: null == proteinCounted ? _self.proteinCounted : proteinCounted // ignore: cast_nullable_to_non_nullable
as bool,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,proteinNLimit: freezed == proteinNLimit ? _self.proteinNLimit : proteinNLimit // ignore: cast_nullable_to_non_nullable
as int?,assumedZero: null == assumedZero ? _self._assumedZero : assumedZero // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class WaterExplanation implements ScoreExplanation {
  const WaterExplanation();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WaterExplanation);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ScoreExplanation.water()';
}


}




/// @nodoc


class GradeOnlyExplanation implements ScoreExplanation {
  const GradeOnlyExplanation({required this.grade});
  

 final  Grade grade;

/// Create a copy of ScoreExplanation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GradeOnlyExplanationCopyWith<GradeOnlyExplanation> get copyWith => _$GradeOnlyExplanationCopyWithImpl<GradeOnlyExplanation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GradeOnlyExplanation&&(identical(other.grade, grade) || other.grade == grade));
}


@override
int get hashCode => Object.hash(runtimeType,grade);

@override
String toString() {
  return 'ScoreExplanation.gradeOnly(grade: $grade)';
}


}

/// @nodoc
abstract mixin class $GradeOnlyExplanationCopyWith<$Res> implements $ScoreExplanationCopyWith<$Res> {
  factory $GradeOnlyExplanationCopyWith(GradeOnlyExplanation value, $Res Function(GradeOnlyExplanation) _then) = _$GradeOnlyExplanationCopyWithImpl;
@useResult
$Res call({
 Grade grade
});




}
/// @nodoc
class _$GradeOnlyExplanationCopyWithImpl<$Res>
    implements $GradeOnlyExplanationCopyWith<$Res> {
  _$GradeOnlyExplanationCopyWithImpl(this._self, this._then);

  final GradeOnlyExplanation _self;
  final $Res Function(GradeOnlyExplanation) _then;

/// Create a copy of ScoreExplanation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? grade = null,}) {
  return _then(GradeOnlyExplanation(
grade: null == grade ? _self.grade : grade // ignore: cast_nullable_to_non_nullable
as Grade,
  ));
}


}

/// @nodoc


class InsufficientDataExplanation implements ScoreExplanation {
  const InsufficientDataExplanation({required final  List<String> missing}): _missing = missing;
  

 final  List<String> _missing;
 List<String> get missing {
  if (_missing is EqualUnmodifiableListView) return _missing;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_missing);
}


/// Create a copy of ScoreExplanation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InsufficientDataExplanationCopyWith<InsufficientDataExplanation> get copyWith => _$InsufficientDataExplanationCopyWithImpl<InsufficientDataExplanation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InsufficientDataExplanation&&const DeepCollectionEquality().equals(other._missing, _missing));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_missing));

@override
String toString() {
  return 'ScoreExplanation.insufficientData(missing: $missing)';
}


}

/// @nodoc
abstract mixin class $InsufficientDataExplanationCopyWith<$Res> implements $ScoreExplanationCopyWith<$Res> {
  factory $InsufficientDataExplanationCopyWith(InsufficientDataExplanation value, $Res Function(InsufficientDataExplanation) _then) = _$InsufficientDataExplanationCopyWithImpl;
@useResult
$Res call({
 List<String> missing
});




}
/// @nodoc
class _$InsufficientDataExplanationCopyWithImpl<$Res>
    implements $InsufficientDataExplanationCopyWith<$Res> {
  _$InsufficientDataExplanationCopyWithImpl(this._self, this._then);

  final InsufficientDataExplanation _self;
  final $Res Function(InsufficientDataExplanation) _then;

/// Create a copy of ScoreExplanation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? missing = null,}) {
  return _then(InsufficientDataExplanation(
missing: null == missing ? _self._missing : missing // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class NotScoredExplanation implements ScoreExplanation {
  const NotScoredExplanation();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotScoredExplanation);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ScoreExplanation.notScored()';
}


}




// dart format on
