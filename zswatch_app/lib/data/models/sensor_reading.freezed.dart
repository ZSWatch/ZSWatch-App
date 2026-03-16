// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sensor_reading.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SensorReading {

/// Timestamp when the reading was received
 DateTime get timestamp;/// Type of sensor
 SensorType get type;/// X-axis value (for multi-axis sensors) or primary value
 double get x;/// Y-axis value (for multi-axis sensors)
 double? get y;/// Z-axis value (for multi-axis sensors)
 double? get z;/// Raw integer value (for PPG)
 int? get rawValue;
/// Create a copy of SensorReading
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SensorReadingCopyWith<SensorReading> get copyWith => _$SensorReadingCopyWithImpl<SensorReading>(this as SensorReading, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SensorReading&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.type, type) || other.type == type)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.z, z) || other.z == z)&&(identical(other.rawValue, rawValue) || other.rawValue == rawValue));
}


@override
int get hashCode => Object.hash(runtimeType,timestamp,type,x,y,z,rawValue);

@override
String toString() {
  return 'SensorReading(timestamp: $timestamp, type: $type, x: $x, y: $y, z: $z, rawValue: $rawValue)';
}


}

/// @nodoc
abstract mixin class $SensorReadingCopyWith<$Res>  {
  factory $SensorReadingCopyWith(SensorReading value, $Res Function(SensorReading) _then) = _$SensorReadingCopyWithImpl;
@useResult
$Res call({
 DateTime timestamp, SensorType type, double x, double? y, double? z, int? rawValue
});




}
/// @nodoc
class _$SensorReadingCopyWithImpl<$Res>
    implements $SensorReadingCopyWith<$Res> {
  _$SensorReadingCopyWithImpl(this._self, this._then);

  final SensorReading _self;
  final $Res Function(SensorReading) _then;

/// Create a copy of SensorReading
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = null,Object? type = null,Object? x = null,Object? y = freezed,Object? z = freezed,Object? rawValue = freezed,}) {
  return _then(_self.copyWith(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SensorType,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: freezed == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double?,z: freezed == z ? _self.z : z // ignore: cast_nullable_to_non_nullable
as double?,rawValue: freezed == rawValue ? _self.rawValue : rawValue // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [SensorReading].
extension SensorReadingPatterns on SensorReading {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SensorReading value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SensorReading() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SensorReading value)  $default,){
final _that = this;
switch (_that) {
case _SensorReading():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SensorReading value)?  $default,){
final _that = this;
switch (_that) {
case _SensorReading() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime timestamp,  SensorType type,  double x,  double? y,  double? z,  int? rawValue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SensorReading() when $default != null:
return $default(_that.timestamp,_that.type,_that.x,_that.y,_that.z,_that.rawValue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime timestamp,  SensorType type,  double x,  double? y,  double? z,  int? rawValue)  $default,) {final _that = this;
switch (_that) {
case _SensorReading():
return $default(_that.timestamp,_that.type,_that.x,_that.y,_that.z,_that.rawValue);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime timestamp,  SensorType type,  double x,  double? y,  double? z,  int? rawValue)?  $default,) {final _that = this;
switch (_that) {
case _SensorReading() when $default != null:
return $default(_that.timestamp,_that.type,_that.x,_that.y,_that.z,_that.rawValue);case _:
  return null;

}
}

}

/// @nodoc


class _SensorReading extends SensorReading {
  const _SensorReading({required this.timestamp, required this.type, required this.x, this.y, this.z, this.rawValue}): super._();
  

/// Timestamp when the reading was received
@override final  DateTime timestamp;
/// Type of sensor
@override final  SensorType type;
/// X-axis value (for multi-axis sensors) or primary value
@override final  double x;
/// Y-axis value (for multi-axis sensors)
@override final  double? y;
/// Z-axis value (for multi-axis sensors)
@override final  double? z;
/// Raw integer value (for PPG)
@override final  int? rawValue;

/// Create a copy of SensorReading
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SensorReadingCopyWith<_SensorReading> get copyWith => __$SensorReadingCopyWithImpl<_SensorReading>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SensorReading&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.type, type) || other.type == type)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.z, z) || other.z == z)&&(identical(other.rawValue, rawValue) || other.rawValue == rawValue));
}


@override
int get hashCode => Object.hash(runtimeType,timestamp,type,x,y,z,rawValue);

@override
String toString() {
  return 'SensorReading(timestamp: $timestamp, type: $type, x: $x, y: $y, z: $z, rawValue: $rawValue)';
}


}

/// @nodoc
abstract mixin class _$SensorReadingCopyWith<$Res> implements $SensorReadingCopyWith<$Res> {
  factory _$SensorReadingCopyWith(_SensorReading value, $Res Function(_SensorReading) _then) = __$SensorReadingCopyWithImpl;
@override @useResult
$Res call({
 DateTime timestamp, SensorType type, double x, double? y, double? z, int? rawValue
});




}
/// @nodoc
class __$SensorReadingCopyWithImpl<$Res>
    implements _$SensorReadingCopyWith<$Res> {
  __$SensorReadingCopyWithImpl(this._self, this._then);

  final _SensorReading _self;
  final $Res Function(_SensorReading) _then;

/// Create a copy of SensorReading
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = null,Object? type = null,Object? x = null,Object? y = freezed,Object? z = freezed,Object? rawValue = freezed,}) {
  return _then(_SensorReading(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SensorType,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: freezed == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double?,z: freezed == z ? _self.z : z // ignore: cast_nullable_to_non_nullable
as double?,rawValue: freezed == rawValue ? _self.rawValue : rawValue // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
