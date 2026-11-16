// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saved_label.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SavedLabel {

 String get id; String get ocrText; String get directory;
/// Create a copy of SavedLabel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedLabelCopyWith<SavedLabel> get copyWith => _$SavedLabelCopyWithImpl<SavedLabel>(this as SavedLabel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedLabel&&(identical(other.id, id) || other.id == id)&&(identical(other.ocrText, ocrText) || other.ocrText == ocrText)&&(identical(other.directory, directory) || other.directory == directory));
}


@override
int get hashCode => Object.hash(runtimeType,id,ocrText,directory);

@override
String toString() {
  return 'SavedLabel(id: $id, ocrText: $ocrText, directory: $directory)';
}


}

/// @nodoc
abstract mixin class $SavedLabelCopyWith<$Res>  {
  factory $SavedLabelCopyWith(SavedLabel value, $Res Function(SavedLabel) _then) = _$SavedLabelCopyWithImpl;
@useResult
$Res call({
 String id, String ocrText, String directory
});




}
/// @nodoc
class _$SavedLabelCopyWithImpl<$Res>
    implements $SavedLabelCopyWith<$Res> {
  _$SavedLabelCopyWithImpl(this._self, this._then);

  final SavedLabel _self;
  final $Res Function(SavedLabel) _then;

/// Create a copy of SavedLabel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ocrText = null,Object? directory = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ocrText: null == ocrText ? _self.ocrText : ocrText // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SavedLabel].
extension SavedLabelPatterns on SavedLabel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedLabel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedLabel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedLabel value)  $default,){
final _that = this;
switch (_that) {
case _SavedLabel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedLabel value)?  $default,){
final _that = this;
switch (_that) {
case _SavedLabel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ocrText,  String directory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedLabel() when $default != null:
return $default(_that.id,_that.ocrText,_that.directory);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ocrText,  String directory)  $default,) {final _that = this;
switch (_that) {
case _SavedLabel():
return $default(_that.id,_that.ocrText,_that.directory);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ocrText,  String directory)?  $default,) {final _that = this;
switch (_that) {
case _SavedLabel() when $default != null:
return $default(_that.id,_that.ocrText,_that.directory);case _:
  return null;

}
}

}

/// @nodoc


class _SavedLabel implements SavedLabel {
  const _SavedLabel({required this.id, required this.ocrText, required this.directory});
  

@override final  String id;
@override final  String ocrText;
@override final  String directory;

/// Create a copy of SavedLabel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedLabelCopyWith<_SavedLabel> get copyWith => __$SavedLabelCopyWithImpl<_SavedLabel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedLabel&&(identical(other.id, id) || other.id == id)&&(identical(other.ocrText, ocrText) || other.ocrText == ocrText)&&(identical(other.directory, directory) || other.directory == directory));
}


@override
int get hashCode => Object.hash(runtimeType,id,ocrText,directory);

@override
String toString() {
  return 'SavedLabel(id: $id, ocrText: $ocrText, directory: $directory)';
}


}

/// @nodoc
abstract mixin class _$SavedLabelCopyWith<$Res> implements $SavedLabelCopyWith<$Res> {
  factory _$SavedLabelCopyWith(_SavedLabel value, $Res Function(_SavedLabel) _then) = __$SavedLabelCopyWithImpl;
@override @useResult
$Res call({
 String id, String ocrText, String directory
});




}
/// @nodoc
class __$SavedLabelCopyWithImpl<$Res>
    implements _$SavedLabelCopyWith<$Res> {
  __$SavedLabelCopyWithImpl(this._self, this._then);

  final _SavedLabel _self;
  final $Res Function(_SavedLabel) _then;

/// Create a copy of SavedLabel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ocrText = null,Object? directory = null,}) {
  return _then(_SavedLabel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ocrText: null == ocrText ? _self.ocrText : ocrText // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
