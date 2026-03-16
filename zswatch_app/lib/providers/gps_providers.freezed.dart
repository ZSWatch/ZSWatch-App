// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gps_providers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GpsState implements DiagnosticableTreeMixin {

 bool get isActive; bool get isRequesting; Position? get lastPosition; GpsError? get lastError; DateTime? get lastUpdateTime;
/// Create a copy of GpsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GpsStateCopyWith<GpsState> get copyWith => _$GpsStateCopyWithImpl<GpsState>(this as GpsState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'GpsState'))
    ..add(DiagnosticsProperty('isActive', isActive))..add(DiagnosticsProperty('isRequesting', isRequesting))..add(DiagnosticsProperty('lastPosition', lastPosition))..add(DiagnosticsProperty('lastError', lastError))..add(DiagnosticsProperty('lastUpdateTime', lastUpdateTime));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GpsState&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isRequesting, isRequesting) || other.isRequesting == isRequesting)&&(identical(other.lastPosition, lastPosition) || other.lastPosition == lastPosition)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.lastUpdateTime, lastUpdateTime) || other.lastUpdateTime == lastUpdateTime));
}


@override
int get hashCode => Object.hash(runtimeType,isActive,isRequesting,lastPosition,lastError,lastUpdateTime);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'GpsState(isActive: $isActive, isRequesting: $isRequesting, lastPosition: $lastPosition, lastError: $lastError, lastUpdateTime: $lastUpdateTime)';
}


}

/// @nodoc
abstract mixin class $GpsStateCopyWith<$Res>  {
  factory $GpsStateCopyWith(GpsState value, $Res Function(GpsState) _then) = _$GpsStateCopyWithImpl;
@useResult
$Res call({
 bool isActive, bool isRequesting, Position? lastPosition, GpsError? lastError, DateTime? lastUpdateTime
});




}
/// @nodoc
class _$GpsStateCopyWithImpl<$Res>
    implements $GpsStateCopyWith<$Res> {
  _$GpsStateCopyWithImpl(this._self, this._then);

  final GpsState _self;
  final $Res Function(GpsState) _then;

/// Create a copy of GpsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isActive = null,Object? isRequesting = null,Object? lastPosition = freezed,Object? lastError = freezed,Object? lastUpdateTime = freezed,}) {
  return _then(_self.copyWith(
isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,isRequesting: null == isRequesting ? _self.isRequesting : isRequesting // ignore: cast_nullable_to_non_nullable
as bool,lastPosition: freezed == lastPosition ? _self.lastPosition : lastPosition // ignore: cast_nullable_to_non_nullable
as Position?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as GpsError?,lastUpdateTime: freezed == lastUpdateTime ? _self.lastUpdateTime : lastUpdateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [GpsState].
extension GpsStatePatterns on GpsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GpsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GpsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GpsState value)  $default,){
final _that = this;
switch (_that) {
case _GpsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GpsState value)?  $default,){
final _that = this;
switch (_that) {
case _GpsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isActive,  bool isRequesting,  Position? lastPosition,  GpsError? lastError,  DateTime? lastUpdateTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GpsState() when $default != null:
return $default(_that.isActive,_that.isRequesting,_that.lastPosition,_that.lastError,_that.lastUpdateTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isActive,  bool isRequesting,  Position? lastPosition,  GpsError? lastError,  DateTime? lastUpdateTime)  $default,) {final _that = this;
switch (_that) {
case _GpsState():
return $default(_that.isActive,_that.isRequesting,_that.lastPosition,_that.lastError,_that.lastUpdateTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isActive,  bool isRequesting,  Position? lastPosition,  GpsError? lastError,  DateTime? lastUpdateTime)?  $default,) {final _that = this;
switch (_that) {
case _GpsState() when $default != null:
return $default(_that.isActive,_that.isRequesting,_that.lastPosition,_that.lastError,_that.lastUpdateTime);case _:
  return null;

}
}

}

/// @nodoc


class _GpsState with DiagnosticableTreeMixin implements GpsState {
  const _GpsState({this.isActive = false, this.isRequesting = false, this.lastPosition, this.lastError, this.lastUpdateTime});
  

@override@JsonKey() final  bool isActive;
@override@JsonKey() final  bool isRequesting;
@override final  Position? lastPosition;
@override final  GpsError? lastError;
@override final  DateTime? lastUpdateTime;

/// Create a copy of GpsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GpsStateCopyWith<_GpsState> get copyWith => __$GpsStateCopyWithImpl<_GpsState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'GpsState'))
    ..add(DiagnosticsProperty('isActive', isActive))..add(DiagnosticsProperty('isRequesting', isRequesting))..add(DiagnosticsProperty('lastPosition', lastPosition))..add(DiagnosticsProperty('lastError', lastError))..add(DiagnosticsProperty('lastUpdateTime', lastUpdateTime));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GpsState&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isRequesting, isRequesting) || other.isRequesting == isRequesting)&&(identical(other.lastPosition, lastPosition) || other.lastPosition == lastPosition)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.lastUpdateTime, lastUpdateTime) || other.lastUpdateTime == lastUpdateTime));
}


@override
int get hashCode => Object.hash(runtimeType,isActive,isRequesting,lastPosition,lastError,lastUpdateTime);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'GpsState(isActive: $isActive, isRequesting: $isRequesting, lastPosition: $lastPosition, lastError: $lastError, lastUpdateTime: $lastUpdateTime)';
}


}

/// @nodoc
abstract mixin class _$GpsStateCopyWith<$Res> implements $GpsStateCopyWith<$Res> {
  factory _$GpsStateCopyWith(_GpsState value, $Res Function(_GpsState) _then) = __$GpsStateCopyWithImpl;
@override @useResult
$Res call({
 bool isActive, bool isRequesting, Position? lastPosition, GpsError? lastError, DateTime? lastUpdateTime
});




}
/// @nodoc
class __$GpsStateCopyWithImpl<$Res>
    implements _$GpsStateCopyWith<$Res> {
  __$GpsStateCopyWithImpl(this._self, this._then);

  final _GpsState _self;
  final $Res Function(_GpsState) _then;

/// Create a copy of GpsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isActive = null,Object? isRequesting = null,Object? lastPosition = freezed,Object? lastError = freezed,Object? lastUpdateTime = freezed,}) {
  return _then(_GpsState(
isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,isRequesting: null == isRequesting ? _self.isRequesting : isRequesting // ignore: cast_nullable_to_non_nullable
as bool,lastPosition: freezed == lastPosition ? _self.lastPosition : lastPosition // ignore: cast_nullable_to_non_nullable
as Position?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as GpsError?,lastUpdateTime: freezed == lastUpdateTime ? _self.lastUpdateTime : lastUpdateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
