// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'log_filter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LogStreamingState {

/// Whether app has requested log streaming from watch
 bool get requestedByApp;/// Whether log streaming is currently enabled on watch
/// Note: May be true even if not requested by app (watch setting)
 bool get enabledOnWatch;/// Whether we're waiting for confirmation from watch
 bool get pending;/// Error message if log enable/disable failed
 String? get error;
/// Create a copy of LogStreamingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LogStreamingStateCopyWith<LogStreamingState> get copyWith => _$LogStreamingStateCopyWithImpl<LogStreamingState>(this as LogStreamingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LogStreamingState&&(identical(other.requestedByApp, requestedByApp) || other.requestedByApp == requestedByApp)&&(identical(other.enabledOnWatch, enabledOnWatch) || other.enabledOnWatch == enabledOnWatch)&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,requestedByApp,enabledOnWatch,pending,error);

@override
String toString() {
  return 'LogStreamingState(requestedByApp: $requestedByApp, enabledOnWatch: $enabledOnWatch, pending: $pending, error: $error)';
}


}

/// @nodoc
abstract mixin class $LogStreamingStateCopyWith<$Res>  {
  factory $LogStreamingStateCopyWith(LogStreamingState value, $Res Function(LogStreamingState) _then) = _$LogStreamingStateCopyWithImpl;
@useResult
$Res call({
 bool requestedByApp, bool enabledOnWatch, bool pending, String? error
});




}
/// @nodoc
class _$LogStreamingStateCopyWithImpl<$Res>
    implements $LogStreamingStateCopyWith<$Res> {
  _$LogStreamingStateCopyWithImpl(this._self, this._then);

  final LogStreamingState _self;
  final $Res Function(LogStreamingState) _then;

/// Create a copy of LogStreamingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestedByApp = null,Object? enabledOnWatch = null,Object? pending = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
requestedByApp: null == requestedByApp ? _self.requestedByApp : requestedByApp // ignore: cast_nullable_to_non_nullable
as bool,enabledOnWatch: null == enabledOnWatch ? _self.enabledOnWatch : enabledOnWatch // ignore: cast_nullable_to_non_nullable
as bool,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LogStreamingState].
extension LogStreamingStatePatterns on LogStreamingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LogStreamingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LogStreamingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LogStreamingState value)  $default,){
final _that = this;
switch (_that) {
case _LogStreamingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LogStreamingState value)?  $default,){
final _that = this;
switch (_that) {
case _LogStreamingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool requestedByApp,  bool enabledOnWatch,  bool pending,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LogStreamingState() when $default != null:
return $default(_that.requestedByApp,_that.enabledOnWatch,_that.pending,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool requestedByApp,  bool enabledOnWatch,  bool pending,  String? error)  $default,) {final _that = this;
switch (_that) {
case _LogStreamingState():
return $default(_that.requestedByApp,_that.enabledOnWatch,_that.pending,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool requestedByApp,  bool enabledOnWatch,  bool pending,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _LogStreamingState() when $default != null:
return $default(_that.requestedByApp,_that.enabledOnWatch,_that.pending,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _LogStreamingState extends LogStreamingState {
  const _LogStreamingState({this.requestedByApp = false, this.enabledOnWatch = false, this.pending = false, this.error}): super._();
  

/// Whether app has requested log streaming from watch
@override@JsonKey() final  bool requestedByApp;
/// Whether log streaming is currently enabled on watch
/// Note: May be true even if not requested by app (watch setting)
@override@JsonKey() final  bool enabledOnWatch;
/// Whether we're waiting for confirmation from watch
@override@JsonKey() final  bool pending;
/// Error message if log enable/disable failed
@override final  String? error;

/// Create a copy of LogStreamingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LogStreamingStateCopyWith<_LogStreamingState> get copyWith => __$LogStreamingStateCopyWithImpl<_LogStreamingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LogStreamingState&&(identical(other.requestedByApp, requestedByApp) || other.requestedByApp == requestedByApp)&&(identical(other.enabledOnWatch, enabledOnWatch) || other.enabledOnWatch == enabledOnWatch)&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,requestedByApp,enabledOnWatch,pending,error);

@override
String toString() {
  return 'LogStreamingState(requestedByApp: $requestedByApp, enabledOnWatch: $enabledOnWatch, pending: $pending, error: $error)';
}


}

/// @nodoc
abstract mixin class _$LogStreamingStateCopyWith<$Res> implements $LogStreamingStateCopyWith<$Res> {
  factory _$LogStreamingStateCopyWith(_LogStreamingState value, $Res Function(_LogStreamingState) _then) = __$LogStreamingStateCopyWithImpl;
@override @useResult
$Res call({
 bool requestedByApp, bool enabledOnWatch, bool pending, String? error
});




}
/// @nodoc
class __$LogStreamingStateCopyWithImpl<$Res>
    implements _$LogStreamingStateCopyWith<$Res> {
  __$LogStreamingStateCopyWithImpl(this._self, this._then);

  final _LogStreamingState _self;
  final $Res Function(_LogStreamingState) _then;

/// Create a copy of LogStreamingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestedByApp = null,Object? enabledOnWatch = null,Object? pending = null,Object? error = freezed,}) {
  return _then(_LogStreamingState(
requestedByApp: null == requestedByApp ? _self.requestedByApp : requestedByApp // ignore: cast_nullable_to_non_nullable
as bool,enabledOnWatch: null == enabledOnWatch ? _self.enabledOnWatch : enabledOnWatch // ignore: cast_nullable_to_non_nullable
as bool,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
