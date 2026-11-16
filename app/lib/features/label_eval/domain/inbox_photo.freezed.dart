// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'inbox_photo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InboxPhoto {

 String get path;/// From `<name>.json` next to the photo: ground truth template values
/// (product, brand, ean, source, photo_url). Empty when there is none.
 Map<String, Object?> get template;
/// Create a copy of InboxPhoto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InboxPhotoCopyWith<InboxPhoto> get copyWith => _$InboxPhotoCopyWithImpl<InboxPhoto>(this as InboxPhoto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InboxPhoto&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other.template, template));
}


@override
int get hashCode => Object.hash(runtimeType,path,const DeepCollectionEquality().hash(template));

@override
String toString() {
  return 'InboxPhoto(path: $path, template: $template)';
}


}

/// @nodoc
abstract mixin class $InboxPhotoCopyWith<$Res>  {
  factory $InboxPhotoCopyWith(InboxPhoto value, $Res Function(InboxPhoto) _then) = _$InboxPhotoCopyWithImpl;
@useResult
$Res call({
 String path, Map<String, Object?> template
});




}
/// @nodoc
class _$InboxPhotoCopyWithImpl<$Res>
    implements $InboxPhotoCopyWith<$Res> {
  _$InboxPhotoCopyWithImpl(this._self, this._then);

  final InboxPhoto _self;
  final $Res Function(InboxPhoto) _then;

/// Create a copy of InboxPhoto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? template = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [InboxPhoto].
extension InboxPhotoPatterns on InboxPhoto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InboxPhoto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InboxPhoto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InboxPhoto value)  $default,){
final _that = this;
switch (_that) {
case _InboxPhoto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InboxPhoto value)?  $default,){
final _that = this;
switch (_that) {
case _InboxPhoto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  Map<String, Object?> template)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InboxPhoto() when $default != null:
return $default(_that.path,_that.template);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  Map<String, Object?> template)  $default,) {final _that = this;
switch (_that) {
case _InboxPhoto():
return $default(_that.path,_that.template);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  Map<String, Object?> template)?  $default,) {final _that = this;
switch (_that) {
case _InboxPhoto() when $default != null:
return $default(_that.path,_that.template);case _:
  return null;

}
}

}

/// @nodoc


class _InboxPhoto implements InboxPhoto {
  const _InboxPhoto({required this.path, final  Map<String, Object?> template = const <String, Object?>{}}): _template = template;
  

@override final  String path;
/// From `<name>.json` next to the photo: ground truth template values
/// (product, brand, ean, source, photo_url). Empty when there is none.
 final  Map<String, Object?> _template;
/// From `<name>.json` next to the photo: ground truth template values
/// (product, brand, ean, source, photo_url). Empty when there is none.
@override@JsonKey() Map<String, Object?> get template {
  if (_template is EqualUnmodifiableMapView) return _template;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_template);
}


/// Create a copy of InboxPhoto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InboxPhotoCopyWith<_InboxPhoto> get copyWith => __$InboxPhotoCopyWithImpl<_InboxPhoto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InboxPhoto&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other._template, _template));
}


@override
int get hashCode => Object.hash(runtimeType,path,const DeepCollectionEquality().hash(_template));

@override
String toString() {
  return 'InboxPhoto(path: $path, template: $template)';
}


}

/// @nodoc
abstract mixin class _$InboxPhotoCopyWith<$Res> implements $InboxPhotoCopyWith<$Res> {
  factory _$InboxPhotoCopyWith(_InboxPhoto value, $Res Function(_InboxPhoto) _then) = __$InboxPhotoCopyWithImpl;
@override @useResult
$Res call({
 String path, Map<String, Object?> template
});




}
/// @nodoc
class __$InboxPhotoCopyWithImpl<$Res>
    implements _$InboxPhotoCopyWith<$Res> {
  __$InboxPhotoCopyWithImpl(this._self, this._then);

  final _InboxPhoto _self;
  final $Res Function(_InboxPhoto) _then;

/// Create a copy of InboxPhoto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? template = null,}) {
  return _then(_InboxPhoto(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,template: null == template ? _self._template : template // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

// dart format on
