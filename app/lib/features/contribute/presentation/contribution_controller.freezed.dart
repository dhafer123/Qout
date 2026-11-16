// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contribution_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ContributionState {

 ContributionDraft get draft; ContributionStep get step; LabelReadingStatus get reading;/// Photos being read by ML Kit right now.
 Set<PhotoKind> get readingPhotos;/// The LLM's reading, when offered (not applied).
 LabelReading? get aiOffer;/// Sending: uploading the photos, then submitting.
 bool get sending;/// Why the last send failed (shown with "Try again").
 String? get sendError;/// The contributor tried to send: missing values are shown as errors.
 bool get showRequired;
/// Create a copy of ContributionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContributionStateCopyWith<ContributionState> get copyWith => _$ContributionStateCopyWithImpl<ContributionState>(this as ContributionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContributionState&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.step, step) || other.step == step)&&(identical(other.reading, reading) || other.reading == reading)&&const DeepCollectionEquality().equals(other.readingPhotos, readingPhotos)&&(identical(other.aiOffer, aiOffer) || other.aiOffer == aiOffer)&&(identical(other.sending, sending) || other.sending == sending)&&(identical(other.sendError, sendError) || other.sendError == sendError)&&(identical(other.showRequired, showRequired) || other.showRequired == showRequired));
}


@override
int get hashCode => Object.hash(runtimeType,draft,step,reading,const DeepCollectionEquality().hash(readingPhotos),aiOffer,sending,sendError,showRequired);

@override
String toString() {
  return 'ContributionState(draft: $draft, step: $step, reading: $reading, readingPhotos: $readingPhotos, aiOffer: $aiOffer, sending: $sending, sendError: $sendError, showRequired: $showRequired)';
}


}

/// @nodoc
abstract mixin class $ContributionStateCopyWith<$Res>  {
  factory $ContributionStateCopyWith(ContributionState value, $Res Function(ContributionState) _then) = _$ContributionStateCopyWithImpl;
@useResult
$Res call({
 ContributionDraft draft, ContributionStep step, LabelReadingStatus reading, Set<PhotoKind> readingPhotos, LabelReading? aiOffer, bool sending, String? sendError, bool showRequired
});


$ContributionDraftCopyWith<$Res> get draft;

}
/// @nodoc
class _$ContributionStateCopyWithImpl<$Res>
    implements $ContributionStateCopyWith<$Res> {
  _$ContributionStateCopyWithImpl(this._self, this._then);

  final ContributionState _self;
  final $Res Function(ContributionState) _then;

/// Create a copy of ContributionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? draft = null,Object? step = null,Object? reading = null,Object? readingPhotos = null,Object? aiOffer = freezed,Object? sending = null,Object? sendError = freezed,Object? showRequired = null,}) {
  return _then(_self.copyWith(
draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as ContributionDraft,step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as ContributionStep,reading: null == reading ? _self.reading : reading // ignore: cast_nullable_to_non_nullable
as LabelReadingStatus,readingPhotos: null == readingPhotos ? _self.readingPhotos : readingPhotos // ignore: cast_nullable_to_non_nullable
as Set<PhotoKind>,aiOffer: freezed == aiOffer ? _self.aiOffer : aiOffer // ignore: cast_nullable_to_non_nullable
as LabelReading?,sending: null == sending ? _self.sending : sending // ignore: cast_nullable_to_non_nullable
as bool,sendError: freezed == sendError ? _self.sendError : sendError // ignore: cast_nullable_to_non_nullable
as String?,showRequired: null == showRequired ? _self.showRequired : showRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ContributionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContributionDraftCopyWith<$Res> get draft {
  
  return $ContributionDraftCopyWith<$Res>(_self.draft, (value) {
    return _then(_self.copyWith(draft: value));
  });
}
}


/// Adds pattern-matching-related methods to [ContributionState].
extension ContributionStatePatterns on ContributionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContributionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContributionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContributionState value)  $default,){
final _that = this;
switch (_that) {
case _ContributionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContributionState value)?  $default,){
final _that = this;
switch (_that) {
case _ContributionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ContributionDraft draft,  ContributionStep step,  LabelReadingStatus reading,  Set<PhotoKind> readingPhotos,  LabelReading? aiOffer,  bool sending,  String? sendError,  bool showRequired)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContributionState() when $default != null:
return $default(_that.draft,_that.step,_that.reading,_that.readingPhotos,_that.aiOffer,_that.sending,_that.sendError,_that.showRequired);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ContributionDraft draft,  ContributionStep step,  LabelReadingStatus reading,  Set<PhotoKind> readingPhotos,  LabelReading? aiOffer,  bool sending,  String? sendError,  bool showRequired)  $default,) {final _that = this;
switch (_that) {
case _ContributionState():
return $default(_that.draft,_that.step,_that.reading,_that.readingPhotos,_that.aiOffer,_that.sending,_that.sendError,_that.showRequired);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ContributionDraft draft,  ContributionStep step,  LabelReadingStatus reading,  Set<PhotoKind> readingPhotos,  LabelReading? aiOffer,  bool sending,  String? sendError,  bool showRequired)?  $default,) {final _that = this;
switch (_that) {
case _ContributionState() when $default != null:
return $default(_that.draft,_that.step,_that.reading,_that.readingPhotos,_that.aiOffer,_that.sending,_that.sendError,_that.showRequired);case _:
  return null;

}
}

}

/// @nodoc


class _ContributionState implements ContributionState {
  const _ContributionState({required this.draft, this.step = ContributionStep.photos, this.reading = LabelReadingStatus.none, final  Set<PhotoKind> readingPhotos = const <PhotoKind>{}, this.aiOffer, this.sending = false, this.sendError, this.showRequired = false}): _readingPhotos = readingPhotos;
  

@override final  ContributionDraft draft;
@override@JsonKey() final  ContributionStep step;
@override@JsonKey() final  LabelReadingStatus reading;
/// Photos being read by ML Kit right now.
 final  Set<PhotoKind> _readingPhotos;
/// Photos being read by ML Kit right now.
@override@JsonKey() Set<PhotoKind> get readingPhotos {
  if (_readingPhotos is EqualUnmodifiableSetView) return _readingPhotos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_readingPhotos);
}

/// The LLM's reading, when offered (not applied).
@override final  LabelReading? aiOffer;
/// Sending: uploading the photos, then submitting.
@override@JsonKey() final  bool sending;
/// Why the last send failed (shown with "Try again").
@override final  String? sendError;
/// The contributor tried to send: missing values are shown as errors.
@override@JsonKey() final  bool showRequired;

/// Create a copy of ContributionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContributionStateCopyWith<_ContributionState> get copyWith => __$ContributionStateCopyWithImpl<_ContributionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContributionState&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.step, step) || other.step == step)&&(identical(other.reading, reading) || other.reading == reading)&&const DeepCollectionEquality().equals(other._readingPhotos, _readingPhotos)&&(identical(other.aiOffer, aiOffer) || other.aiOffer == aiOffer)&&(identical(other.sending, sending) || other.sending == sending)&&(identical(other.sendError, sendError) || other.sendError == sendError)&&(identical(other.showRequired, showRequired) || other.showRequired == showRequired));
}


@override
int get hashCode => Object.hash(runtimeType,draft,step,reading,const DeepCollectionEquality().hash(_readingPhotos),aiOffer,sending,sendError,showRequired);

@override
String toString() {
  return 'ContributionState(draft: $draft, step: $step, reading: $reading, readingPhotos: $readingPhotos, aiOffer: $aiOffer, sending: $sending, sendError: $sendError, showRequired: $showRequired)';
}


}

/// @nodoc
abstract mixin class _$ContributionStateCopyWith<$Res> implements $ContributionStateCopyWith<$Res> {
  factory _$ContributionStateCopyWith(_ContributionState value, $Res Function(_ContributionState) _then) = __$ContributionStateCopyWithImpl;
@override @useResult
$Res call({
 ContributionDraft draft, ContributionStep step, LabelReadingStatus reading, Set<PhotoKind> readingPhotos, LabelReading? aiOffer, bool sending, String? sendError, bool showRequired
});


@override $ContributionDraftCopyWith<$Res> get draft;

}
/// @nodoc
class __$ContributionStateCopyWithImpl<$Res>
    implements _$ContributionStateCopyWith<$Res> {
  __$ContributionStateCopyWithImpl(this._self, this._then);

  final _ContributionState _self;
  final $Res Function(_ContributionState) _then;

/// Create a copy of ContributionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? draft = null,Object? step = null,Object? reading = null,Object? readingPhotos = null,Object? aiOffer = freezed,Object? sending = null,Object? sendError = freezed,Object? showRequired = null,}) {
  return _then(_ContributionState(
draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as ContributionDraft,step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as ContributionStep,reading: null == reading ? _self.reading : reading // ignore: cast_nullable_to_non_nullable
as LabelReadingStatus,readingPhotos: null == readingPhotos ? _self._readingPhotos : readingPhotos // ignore: cast_nullable_to_non_nullable
as Set<PhotoKind>,aiOffer: freezed == aiOffer ? _self.aiOffer : aiOffer // ignore: cast_nullable_to_non_nullable
as LabelReading?,sending: null == sending ? _self.sending : sending // ignore: cast_nullable_to_non_nullable
as bool,sendError: freezed == sendError ? _self.sendError : sendError // ignore: cast_nullable_to_non_nullable
as String?,showRequired: null == showRequired ? _self.showRequired : showRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ContributionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContributionDraftCopyWith<$Res> get draft {
  
  return $ContributionDraftCopyWith<$Res>(_self.draft, (value) {
    return _then(_self.copyWith(draft: value));
  });
}
}

// dart format on
