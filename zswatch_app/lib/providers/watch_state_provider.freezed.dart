// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'watch_state_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WatchState implements DiagnosticableTreeMixin {

 Watch? get watch; Connection get connection; bool get isLoading; String? get error;
/// Create a copy of WatchState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WatchStateCopyWith<WatchState> get copyWith => _$WatchStateCopyWithImpl<WatchState>(this as WatchState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'WatchState'))
    ..add(DiagnosticsProperty('watch', watch))..add(DiagnosticsProperty('connection', connection))..add(DiagnosticsProperty('isLoading', isLoading))..add(DiagnosticsProperty('error', error));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WatchState&&(identical(other.watch, watch) || other.watch == watch)&&(identical(other.connection, connection) || other.connection == connection)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,watch,connection,isLoading,error);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'WatchState(watch: $watch, connection: $connection, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class $WatchStateCopyWith<$Res>  {
  factory $WatchStateCopyWith(WatchState value, $Res Function(WatchState) _then) = _$WatchStateCopyWithImpl;
@useResult
$Res call({
 Watch? watch, Connection connection, bool isLoading, String? error
});


$WatchCopyWith<$Res>? get watch;$ConnectionCopyWith<$Res> get connection;

}
/// @nodoc
class _$WatchStateCopyWithImpl<$Res>
    implements $WatchStateCopyWith<$Res> {
  _$WatchStateCopyWithImpl(this._self, this._then);

  final WatchState _self;
  final $Res Function(WatchState) _then;

/// Create a copy of WatchState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? watch = freezed,Object? connection = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
watch: freezed == watch ? _self.watch : watch // ignore: cast_nullable_to_non_nullable
as Watch?,connection: null == connection ? _self.connection : connection // ignore: cast_nullable_to_non_nullable
as Connection,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of WatchState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WatchCopyWith<$Res>? get watch {
    if (_self.watch == null) {
    return null;
  }

  return $WatchCopyWith<$Res>(_self.watch!, (value) {
    return _then(_self.copyWith(watch: value));
  });
}/// Create a copy of WatchState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConnectionCopyWith<$Res> get connection {
  
  return $ConnectionCopyWith<$Res>(_self.connection, (value) {
    return _then(_self.copyWith(connection: value));
  });
}
}


/// Adds pattern-matching-related methods to [WatchState].
extension WatchStatePatterns on WatchState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WatchState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WatchState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WatchState value)  $default,){
final _that = this;
switch (_that) {
case _WatchState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WatchState value)?  $default,){
final _that = this;
switch (_that) {
case _WatchState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Watch? watch,  Connection connection,  bool isLoading,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WatchState() when $default != null:
return $default(_that.watch,_that.connection,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Watch? watch,  Connection connection,  bool isLoading,  String? error)  $default,) {final _that = this;
switch (_that) {
case _WatchState():
return $default(_that.watch,_that.connection,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Watch? watch,  Connection connection,  bool isLoading,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _WatchState() when $default != null:
return $default(_that.watch,_that.connection,_that.isLoading,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _WatchState extends WatchState with DiagnosticableTreeMixin {
  const _WatchState({this.watch, required this.connection, this.isLoading = false, this.error}): super._();
  

@override final  Watch? watch;
@override final  Connection connection;
@override@JsonKey() final  bool isLoading;
@override final  String? error;

/// Create a copy of WatchState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WatchStateCopyWith<_WatchState> get copyWith => __$WatchStateCopyWithImpl<_WatchState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'WatchState'))
    ..add(DiagnosticsProperty('watch', watch))..add(DiagnosticsProperty('connection', connection))..add(DiagnosticsProperty('isLoading', isLoading))..add(DiagnosticsProperty('error', error));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WatchState&&(identical(other.watch, watch) || other.watch == watch)&&(identical(other.connection, connection) || other.connection == connection)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,watch,connection,isLoading,error);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'WatchState(watch: $watch, connection: $connection, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class _$WatchStateCopyWith<$Res> implements $WatchStateCopyWith<$Res> {
  factory _$WatchStateCopyWith(_WatchState value, $Res Function(_WatchState) _then) = __$WatchStateCopyWithImpl;
@override @useResult
$Res call({
 Watch? watch, Connection connection, bool isLoading, String? error
});


@override $WatchCopyWith<$Res>? get watch;@override $ConnectionCopyWith<$Res> get connection;

}
/// @nodoc
class __$WatchStateCopyWithImpl<$Res>
    implements _$WatchStateCopyWith<$Res> {
  __$WatchStateCopyWithImpl(this._self, this._then);

  final _WatchState _self;
  final $Res Function(_WatchState) _then;

/// Create a copy of WatchState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? watch = freezed,Object? connection = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_WatchState(
watch: freezed == watch ? _self.watch : watch // ignore: cast_nullable_to_non_nullable
as Watch?,connection: null == connection ? _self.connection : connection // ignore: cast_nullable_to_non_nullable
as Connection,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of WatchState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WatchCopyWith<$Res>? get watch {
    if (_self.watch == null) {
    return null;
  }

  return $WatchCopyWith<$Res>(_self.watch!, (value) {
    return _then(_self.copyWith(watch: value));
  });
}/// Create a copy of WatchState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConnectionCopyWith<$Res> get connection {
  
  return $ConnectionCopyWith<$Res>(_self.connection, (value) {
    return _then(_self.copyWith(connection: value));
  });
}
}

// dart format on
