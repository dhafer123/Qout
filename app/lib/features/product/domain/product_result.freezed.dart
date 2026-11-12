// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProductResult {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProductResult()';
}


}

/// @nodoc
class $ProductResultCopyWith<$Res>  {
$ProductResultCopyWith(ProductResult _, $Res Function(ProductResult) __);
}


/// Adds pattern-matching-related methods to [ProductResult].
extension ProductResultPatterns on ProductResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ProductFound value)?  found,TResult Function( ProductNotFound value)?  notFound,TResult Function( InvalidBarcode value)?  invalidBarcode,TResult Function( ProductUnavailable value)?  unavailable,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ProductFound() when found != null:
return found(_that);case ProductNotFound() when notFound != null:
return notFound(_that);case InvalidBarcode() when invalidBarcode != null:
return invalidBarcode(_that);case ProductUnavailable() when unavailable != null:
return unavailable(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ProductFound value)  found,required TResult Function( ProductNotFound value)  notFound,required TResult Function( InvalidBarcode value)  invalidBarcode,required TResult Function( ProductUnavailable value)  unavailable,}){
final _that = this;
switch (_that) {
case ProductFound():
return found(_that);case ProductNotFound():
return notFound(_that);case InvalidBarcode():
return invalidBarcode(_that);case ProductUnavailable():
return unavailable(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ProductFound value)?  found,TResult? Function( ProductNotFound value)?  notFound,TResult? Function( InvalidBarcode value)?  invalidBarcode,TResult? Function( ProductUnavailable value)?  unavailable,}){
final _that = this;
switch (_that) {
case ProductFound() when found != null:
return found(_that);case ProductNotFound() when notFound != null:
return notFound(_that);case InvalidBarcode() when invalidBarcode != null:
return invalidBarcode(_that);case ProductUnavailable() when unavailable != null:
return unavailable(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( ProductDetail product,  DateTime fetchedAt,  ProductFreshness freshness,  QoutApiException? refreshError)?  found,TResult Function( String ean)?  notFound,TResult Function( String ean,  String message)?  invalidBarcode,TResult Function( String ean,  QoutApiException error)?  unavailable,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ProductFound() when found != null:
return found(_that.product,_that.fetchedAt,_that.freshness,_that.refreshError);case ProductNotFound() when notFound != null:
return notFound(_that.ean);case InvalidBarcode() when invalidBarcode != null:
return invalidBarcode(_that.ean,_that.message);case ProductUnavailable() when unavailable != null:
return unavailable(_that.ean,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( ProductDetail product,  DateTime fetchedAt,  ProductFreshness freshness,  QoutApiException? refreshError)  found,required TResult Function( String ean)  notFound,required TResult Function( String ean,  String message)  invalidBarcode,required TResult Function( String ean,  QoutApiException error)  unavailable,}) {final _that = this;
switch (_that) {
case ProductFound():
return found(_that.product,_that.fetchedAt,_that.freshness,_that.refreshError);case ProductNotFound():
return notFound(_that.ean);case InvalidBarcode():
return invalidBarcode(_that.ean,_that.message);case ProductUnavailable():
return unavailable(_that.ean,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( ProductDetail product,  DateTime fetchedAt,  ProductFreshness freshness,  QoutApiException? refreshError)?  found,TResult? Function( String ean)?  notFound,TResult? Function( String ean,  String message)?  invalidBarcode,TResult? Function( String ean,  QoutApiException error)?  unavailable,}) {final _that = this;
switch (_that) {
case ProductFound() when found != null:
return found(_that.product,_that.fetchedAt,_that.freshness,_that.refreshError);case ProductNotFound() when notFound != null:
return notFound(_that.ean);case InvalidBarcode() when invalidBarcode != null:
return invalidBarcode(_that.ean,_that.message);case ProductUnavailable() when unavailable != null:
return unavailable(_that.ean,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class ProductFound implements ProductResult {
  const ProductFound({required this.product, required this.fetchedAt, required this.freshness, this.refreshError});
  

 final  ProductDetail product;
 final  DateTime fetchedAt;
 final  ProductFreshness freshness;
/// Why the refresh failed ([ProductFreshness.refreshFailed] only).
 final  QoutApiException? refreshError;

/// Create a copy of ProductResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductFoundCopyWith<ProductFound> get copyWith => _$ProductFoundCopyWithImpl<ProductFound>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductFound&&(identical(other.product, product) || other.product == product)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt)&&(identical(other.freshness, freshness) || other.freshness == freshness)&&(identical(other.refreshError, refreshError) || other.refreshError == refreshError));
}


@override
int get hashCode => Object.hash(runtimeType,product,fetchedAt,freshness,refreshError);

@override
String toString() {
  return 'ProductResult.found(product: $product, fetchedAt: $fetchedAt, freshness: $freshness, refreshError: $refreshError)';
}


}

/// @nodoc
abstract mixin class $ProductFoundCopyWith<$Res> implements $ProductResultCopyWith<$Res> {
  factory $ProductFoundCopyWith(ProductFound value, $Res Function(ProductFound) _then) = _$ProductFoundCopyWithImpl;
@useResult
$Res call({
 ProductDetail product, DateTime fetchedAt, ProductFreshness freshness, QoutApiException? refreshError
});




}
/// @nodoc
class _$ProductFoundCopyWithImpl<$Res>
    implements $ProductFoundCopyWith<$Res> {
  _$ProductFoundCopyWithImpl(this._self, this._then);

  final ProductFound _self;
  final $Res Function(ProductFound) _then;

/// Create a copy of ProductResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? product = null,Object? fetchedAt = null,Object? freshness = null,Object? refreshError = freezed,}) {
  return _then(ProductFound(
product: null == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as ProductDetail,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,freshness: null == freshness ? _self.freshness : freshness // ignore: cast_nullable_to_non_nullable
as ProductFreshness,refreshError: freezed == refreshError ? _self.refreshError : refreshError // ignore: cast_nullable_to_non_nullable
as QoutApiException?,
  ));
}


}

/// @nodoc


class ProductNotFound implements ProductResult {
  const ProductNotFound({required this.ean});
  

 final  String ean;

/// Create a copy of ProductResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductNotFoundCopyWith<ProductNotFound> get copyWith => _$ProductNotFoundCopyWithImpl<ProductNotFound>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductNotFound&&(identical(other.ean, ean) || other.ean == ean));
}


@override
int get hashCode => Object.hash(runtimeType,ean);

@override
String toString() {
  return 'ProductResult.notFound(ean: $ean)';
}


}

/// @nodoc
abstract mixin class $ProductNotFoundCopyWith<$Res> implements $ProductResultCopyWith<$Res> {
  factory $ProductNotFoundCopyWith(ProductNotFound value, $Res Function(ProductNotFound) _then) = _$ProductNotFoundCopyWithImpl;
@useResult
$Res call({
 String ean
});




}
/// @nodoc
class _$ProductNotFoundCopyWithImpl<$Res>
    implements $ProductNotFoundCopyWith<$Res> {
  _$ProductNotFoundCopyWithImpl(this._self, this._then);

  final ProductNotFound _self;
  final $Res Function(ProductNotFound) _then;

/// Create a copy of ProductResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ean = null,}) {
  return _then(ProductNotFound(
ean: null == ean ? _self.ean : ean // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class InvalidBarcode implements ProductResult {
  const InvalidBarcode({required this.ean, required this.message});
  

 final  String ean;
 final  String message;

/// Create a copy of ProductResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvalidBarcodeCopyWith<InvalidBarcode> get copyWith => _$InvalidBarcodeCopyWithImpl<InvalidBarcode>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvalidBarcode&&(identical(other.ean, ean) || other.ean == ean)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,ean,message);

@override
String toString() {
  return 'ProductResult.invalidBarcode(ean: $ean, message: $message)';
}


}

/// @nodoc
abstract mixin class $InvalidBarcodeCopyWith<$Res> implements $ProductResultCopyWith<$Res> {
  factory $InvalidBarcodeCopyWith(InvalidBarcode value, $Res Function(InvalidBarcode) _then) = _$InvalidBarcodeCopyWithImpl;
@useResult
$Res call({
 String ean, String message
});




}
/// @nodoc
class _$InvalidBarcodeCopyWithImpl<$Res>
    implements $InvalidBarcodeCopyWith<$Res> {
  _$InvalidBarcodeCopyWithImpl(this._self, this._then);

  final InvalidBarcode _self;
  final $Res Function(InvalidBarcode) _then;

/// Create a copy of ProductResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ean = null,Object? message = null,}) {
  return _then(InvalidBarcode(
ean: null == ean ? _self.ean : ean // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ProductUnavailable implements ProductResult {
  const ProductUnavailable({required this.ean, required this.error});
  

 final  String ean;
 final  QoutApiException error;

/// Create a copy of ProductResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductUnavailableCopyWith<ProductUnavailable> get copyWith => _$ProductUnavailableCopyWithImpl<ProductUnavailable>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductUnavailable&&(identical(other.ean, ean) || other.ean == ean)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,ean,error);

@override
String toString() {
  return 'ProductResult.unavailable(ean: $ean, error: $error)';
}


}

/// @nodoc
abstract mixin class $ProductUnavailableCopyWith<$Res> implements $ProductResultCopyWith<$Res> {
  factory $ProductUnavailableCopyWith(ProductUnavailable value, $Res Function(ProductUnavailable) _then) = _$ProductUnavailableCopyWithImpl;
@useResult
$Res call({
 String ean, QoutApiException error
});




}
/// @nodoc
class _$ProductUnavailableCopyWithImpl<$Res>
    implements $ProductUnavailableCopyWith<$Res> {
  _$ProductUnavailableCopyWithImpl(this._self, this._then);

  final ProductUnavailable _self;
  final $Res Function(ProductUnavailable) _then;

/// Create a copy of ProductResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ean = null,Object? error = null,}) {
  return _then(ProductUnavailable(
ean: null == ean ? _self.ean : ean // ignore: cast_nullable_to_non_nullable
as String,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as QoutApiException,
  ));
}


}

// dart format on
