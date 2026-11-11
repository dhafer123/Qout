// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_env.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppEnv {

 AppFlavor get flavor; Uri get apiBaseUrl;
/// Create a copy of AppEnv
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppEnvCopyWith<AppEnv> get copyWith => _$AppEnvCopyWithImpl<AppEnv>(this as AppEnv, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppEnv&&(identical(other.flavor, flavor) || other.flavor == flavor)&&(identical(other.apiBaseUrl, apiBaseUrl) || other.apiBaseUrl == apiBaseUrl));
}


@override
int get hashCode => Object.hash(runtimeType,flavor,apiBaseUrl);

@override
String toString() {
  return 'AppEnv(flavor: $flavor, apiBaseUrl: $apiBaseUrl)';
}


}

/// @nodoc
abstract mixin class $AppEnvCopyWith<$Res>  {
  factory $AppEnvCopyWith(AppEnv value, $Res Function(AppEnv) _then) = _$AppEnvCopyWithImpl;
@useResult
$Res call({
 AppFlavor flavor, Uri apiBaseUrl
});




}
/// @nodoc
class _$AppEnvCopyWithImpl<$Res>
    implements $AppEnvCopyWith<$Res> {
  _$AppEnvCopyWithImpl(this._self, this._then);

  final AppEnv _self;
  final $Res Function(AppEnv) _then;

/// Create a copy of AppEnv
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? flavor = null,Object? apiBaseUrl = null,}) {
  return _then(_self.copyWith(
flavor: null == flavor ? _self.flavor : flavor // ignore: cast_nullable_to_non_nullable
as AppFlavor,apiBaseUrl: null == apiBaseUrl ? _self.apiBaseUrl : apiBaseUrl // ignore: cast_nullable_to_non_nullable
as Uri,
  ));
}

}


/// Adds pattern-matching-related methods to [AppEnv].
extension AppEnvPatterns on AppEnv {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppEnv value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppEnv() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppEnv value)  $default,){
final _that = this;
switch (_that) {
case _AppEnv():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppEnv value)?  $default,){
final _that = this;
switch (_that) {
case _AppEnv() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AppFlavor flavor,  Uri apiBaseUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppEnv() when $default != null:
return $default(_that.flavor,_that.apiBaseUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AppFlavor flavor,  Uri apiBaseUrl)  $default,) {final _that = this;
switch (_that) {
case _AppEnv():
return $default(_that.flavor,_that.apiBaseUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AppFlavor flavor,  Uri apiBaseUrl)?  $default,) {final _that = this;
switch (_that) {
case _AppEnv() when $default != null:
return $default(_that.flavor,_that.apiBaseUrl);case _:
  return null;

}
}

}

/// @nodoc


class _AppEnv implements AppEnv {
  const _AppEnv({required this.flavor, required this.apiBaseUrl});
  

@override final  AppFlavor flavor;
@override final  Uri apiBaseUrl;

/// Create a copy of AppEnv
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppEnvCopyWith<_AppEnv> get copyWith => __$AppEnvCopyWithImpl<_AppEnv>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppEnv&&(identical(other.flavor, flavor) || other.flavor == flavor)&&(identical(other.apiBaseUrl, apiBaseUrl) || other.apiBaseUrl == apiBaseUrl));
}


@override
int get hashCode => Object.hash(runtimeType,flavor,apiBaseUrl);

@override
String toString() {
  return 'AppEnv(flavor: $flavor, apiBaseUrl: $apiBaseUrl)';
}


}

/// @nodoc
abstract mixin class _$AppEnvCopyWith<$Res> implements $AppEnvCopyWith<$Res> {
  factory _$AppEnvCopyWith(_AppEnv value, $Res Function(_AppEnv) _then) = __$AppEnvCopyWithImpl;
@override @useResult
$Res call({
 AppFlavor flavor, Uri apiBaseUrl
});




}
/// @nodoc
class __$AppEnvCopyWithImpl<$Res>
    implements _$AppEnvCopyWith<$Res> {
  __$AppEnvCopyWithImpl(this._self, this._then);

  final _AppEnv _self;
  final $Res Function(_AppEnv) _then;

/// Create a copy of AppEnv
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? flavor = null,Object? apiBaseUrl = null,}) {
  return _then(_AppEnv(
flavor: null == flavor ? _self.flavor : flavor // ignore: cast_nullable_to_non_nullable
as AppFlavor,apiBaseUrl: null == apiBaseUrl ? _self.apiBaseUrl : apiBaseUrl // ignore: cast_nullable_to_non_nullable
as Uri,
  ));
}


}

// dart format on
