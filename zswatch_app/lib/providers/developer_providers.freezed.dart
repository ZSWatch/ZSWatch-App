// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'developer_providers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SensorStreamingState {

 bool get accelerometer; bool get gyroscope; bool get ppg; bool get temperature;
/// Create a copy of SensorStreamingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SensorStreamingStateCopyWith<SensorStreamingState> get copyWith => _$SensorStreamingStateCopyWithImpl<SensorStreamingState>(this as SensorStreamingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SensorStreamingState&&(identical(other.accelerometer, accelerometer) || other.accelerometer == accelerometer)&&(identical(other.gyroscope, gyroscope) || other.gyroscope == gyroscope)&&(identical(other.ppg, ppg) || other.ppg == ppg)&&(identical(other.temperature, temperature) || other.temperature == temperature));
}


@override
int get hashCode => Object.hash(runtimeType,accelerometer,gyroscope,ppg,temperature);

@override
String toString() {
  return 'SensorStreamingState(accelerometer: $accelerometer, gyroscope: $gyroscope, ppg: $ppg, temperature: $temperature)';
}


}

/// @nodoc
abstract mixin class $SensorStreamingStateCopyWith<$Res>  {
  factory $SensorStreamingStateCopyWith(SensorStreamingState value, $Res Function(SensorStreamingState) _then) = _$SensorStreamingStateCopyWithImpl;
@useResult
$Res call({
 bool accelerometer, bool gyroscope, bool ppg, bool temperature
});




}
/// @nodoc
class _$SensorStreamingStateCopyWithImpl<$Res>
    implements $SensorStreamingStateCopyWith<$Res> {
  _$SensorStreamingStateCopyWithImpl(this._self, this._then);

  final SensorStreamingState _self;
  final $Res Function(SensorStreamingState) _then;

/// Create a copy of SensorStreamingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accelerometer = null,Object? gyroscope = null,Object? ppg = null,Object? temperature = null,}) {
  return _then(_self.copyWith(
accelerometer: null == accelerometer ? _self.accelerometer : accelerometer // ignore: cast_nullable_to_non_nullable
as bool,gyroscope: null == gyroscope ? _self.gyroscope : gyroscope // ignore: cast_nullable_to_non_nullable
as bool,ppg: null == ppg ? _self.ppg : ppg // ignore: cast_nullable_to_non_nullable
as bool,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SensorStreamingState].
extension SensorStreamingStatePatterns on SensorStreamingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SensorStreamingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SensorStreamingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SensorStreamingState value)  $default,){
final _that = this;
switch (_that) {
case _SensorStreamingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SensorStreamingState value)?  $default,){
final _that = this;
switch (_that) {
case _SensorStreamingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool accelerometer,  bool gyroscope,  bool ppg,  bool temperature)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SensorStreamingState() when $default != null:
return $default(_that.accelerometer,_that.gyroscope,_that.ppg,_that.temperature);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool accelerometer,  bool gyroscope,  bool ppg,  bool temperature)  $default,) {final _that = this;
switch (_that) {
case _SensorStreamingState():
return $default(_that.accelerometer,_that.gyroscope,_that.ppg,_that.temperature);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool accelerometer,  bool gyroscope,  bool ppg,  bool temperature)?  $default,) {final _that = this;
switch (_that) {
case _SensorStreamingState() when $default != null:
return $default(_that.accelerometer,_that.gyroscope,_that.ppg,_that.temperature);case _:
  return null;

}
}

}

/// @nodoc


class _SensorStreamingState extends SensorStreamingState {
  const _SensorStreamingState({this.accelerometer = false, this.gyroscope = false, this.ppg = false, this.temperature = false}): super._();
  

@override@JsonKey() final  bool accelerometer;
@override@JsonKey() final  bool gyroscope;
@override@JsonKey() final  bool ppg;
@override@JsonKey() final  bool temperature;

/// Create a copy of SensorStreamingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SensorStreamingStateCopyWith<_SensorStreamingState> get copyWith => __$SensorStreamingStateCopyWithImpl<_SensorStreamingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SensorStreamingState&&(identical(other.accelerometer, accelerometer) || other.accelerometer == accelerometer)&&(identical(other.gyroscope, gyroscope) || other.gyroscope == gyroscope)&&(identical(other.ppg, ppg) || other.ppg == ppg)&&(identical(other.temperature, temperature) || other.temperature == temperature));
}


@override
int get hashCode => Object.hash(runtimeType,accelerometer,gyroscope,ppg,temperature);

@override
String toString() {
  return 'SensorStreamingState(accelerometer: $accelerometer, gyroscope: $gyroscope, ppg: $ppg, temperature: $temperature)';
}


}

/// @nodoc
abstract mixin class _$SensorStreamingStateCopyWith<$Res> implements $SensorStreamingStateCopyWith<$Res> {
  factory _$SensorStreamingStateCopyWith(_SensorStreamingState value, $Res Function(_SensorStreamingState) _then) = __$SensorStreamingStateCopyWithImpl;
@override @useResult
$Res call({
 bool accelerometer, bool gyroscope, bool ppg, bool temperature
});




}
/// @nodoc
class __$SensorStreamingStateCopyWithImpl<$Res>
    implements _$SensorStreamingStateCopyWith<$Res> {
  __$SensorStreamingStateCopyWithImpl(this._self, this._then);

  final _SensorStreamingState _self;
  final $Res Function(_SensorStreamingState) _then;

/// Create a copy of SensorStreamingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accelerometer = null,Object? gyroscope = null,Object? ppg = null,Object? temperature = null,}) {
  return _then(_SensorStreamingState(
accelerometer: null == accelerometer ? _self.accelerometer : accelerometer // ignore: cast_nullable_to_non_nullable
as bool,gyroscope: null == gyroscope ? _self.gyroscope : gyroscope // ignore: cast_nullable_to_non_nullable
as bool,ppg: null == ppg ? _self.ppg : ppg // ignore: cast_nullable_to_non_nullable
as bool,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
