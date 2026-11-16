// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'label_eval_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LabelEvalState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LabelEvalState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LabelEvalState()';
}


}

/// @nodoc
class $LabelEvalStateCopyWith<$Res>  {
$LabelEvalStateCopyWith(LabelEvalState _, $Res Function(LabelEvalState) __);
}


/// Adds pattern-matching-related methods to [LabelEvalState].
extension LabelEvalStatePatterns on LabelEvalState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LabelEvalIdle value)?  idle,TResult Function( LabelEvalWorking value)?  working,TResult Function( LabelEvalSaved value)?  saved,TResult Function( LabelEvalFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LabelEvalIdle() when idle != null:
return idle(_that);case LabelEvalWorking() when working != null:
return working(_that);case LabelEvalSaved() when saved != null:
return saved(_that);case LabelEvalFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LabelEvalIdle value)  idle,required TResult Function( LabelEvalWorking value)  working,required TResult Function( LabelEvalSaved value)  saved,required TResult Function( LabelEvalFailed value)  failed,}){
final _that = this;
switch (_that) {
case LabelEvalIdle():
return idle(_that);case LabelEvalWorking():
return working(_that);case LabelEvalSaved():
return saved(_that);case LabelEvalFailed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LabelEvalIdle value)?  idle,TResult? Function( LabelEvalWorking value)?  working,TResult? Function( LabelEvalSaved value)?  saved,TResult? Function( LabelEvalFailed value)?  failed,}){
final _that = this;
switch (_that) {
case LabelEvalIdle() when idle != null:
return idle(_that);case LabelEvalWorking() when working != null:
return working(_that);case LabelEvalSaved() when saved != null:
return saved(_that);case LabelEvalFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  working,TResult Function( SavedLabel label)?  saved,TResult Function( String message)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LabelEvalIdle() when idle != null:
return idle();case LabelEvalWorking() when working != null:
return working();case LabelEvalSaved() when saved != null:
return saved(_that.label);case LabelEvalFailed() when failed != null:
return failed(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  working,required TResult Function( SavedLabel label)  saved,required TResult Function( String message)  failed,}) {final _that = this;
switch (_that) {
case LabelEvalIdle():
return idle();case LabelEvalWorking():
return working();case LabelEvalSaved():
return saved(_that.label);case LabelEvalFailed():
return failed(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  working,TResult? Function( SavedLabel label)?  saved,TResult? Function( String message)?  failed,}) {final _that = this;
switch (_that) {
case LabelEvalIdle() when idle != null:
return idle();case LabelEvalWorking() when working != null:
return working();case LabelEvalSaved() when saved != null:
return saved(_that.label);case LabelEvalFailed() when failed != null:
return failed(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class LabelEvalIdle implements LabelEvalState {
  const LabelEvalIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LabelEvalIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LabelEvalState.idle()';
}


}




/// @nodoc


class LabelEvalWorking implements LabelEvalState {
  const LabelEvalWorking();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LabelEvalWorking);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LabelEvalState.working()';
}


}




/// @nodoc


class LabelEvalSaved implements LabelEvalState {
  const LabelEvalSaved(this.label);
  

 final  SavedLabel label;

/// Create a copy of LabelEvalState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LabelEvalSavedCopyWith<LabelEvalSaved> get copyWith => _$LabelEvalSavedCopyWithImpl<LabelEvalSaved>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LabelEvalSaved&&(identical(other.label, label) || other.label == label));
}


@override
int get hashCode => Object.hash(runtimeType,label);

@override
String toString() {
  return 'LabelEvalState.saved(label: $label)';
}


}

/// @nodoc
abstract mixin class $LabelEvalSavedCopyWith<$Res> implements $LabelEvalStateCopyWith<$Res> {
  factory $LabelEvalSavedCopyWith(LabelEvalSaved value, $Res Function(LabelEvalSaved) _then) = _$LabelEvalSavedCopyWithImpl;
@useResult
$Res call({
 SavedLabel label
});


$SavedLabelCopyWith<$Res> get label;

}
/// @nodoc
class _$LabelEvalSavedCopyWithImpl<$Res>
    implements $LabelEvalSavedCopyWith<$Res> {
  _$LabelEvalSavedCopyWithImpl(this._self, this._then);

  final LabelEvalSaved _self;
  final $Res Function(LabelEvalSaved) _then;

/// Create a copy of LabelEvalState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? label = null,}) {
  return _then(LabelEvalSaved(
null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as SavedLabel,
  ));
}

/// Create a copy of LabelEvalState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SavedLabelCopyWith<$Res> get label {
  
  return $SavedLabelCopyWith<$Res>(_self.label, (value) {
    return _then(_self.copyWith(label: value));
  });
}
}

/// @nodoc


class LabelEvalFailed implements LabelEvalState {
  const LabelEvalFailed(this.message);
  

 final  String message;

/// Create a copy of LabelEvalState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LabelEvalFailedCopyWith<LabelEvalFailed> get copyWith => _$LabelEvalFailedCopyWithImpl<LabelEvalFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LabelEvalFailed&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'LabelEvalState.failed(message: $message)';
}


}

/// @nodoc
abstract mixin class $LabelEvalFailedCopyWith<$Res> implements $LabelEvalStateCopyWith<$Res> {
  factory $LabelEvalFailedCopyWith(LabelEvalFailed value, $Res Function(LabelEvalFailed) _then) = _$LabelEvalFailedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$LabelEvalFailedCopyWithImpl<$Res>
    implements $LabelEvalFailedCopyWith<$Res> {
  _$LabelEvalFailedCopyWithImpl(this._self, this._then);

  final LabelEvalFailed _self;
  final $Res Function(LabelEvalFailed) _then;

/// Create a copy of LabelEvalState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(LabelEvalFailed(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
