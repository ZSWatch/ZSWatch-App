// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sensor_fusion_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SensorFusionData {

/// Quaternion w component (scalar part)
 double get w;/// Quaternion x component (vector i)
 double get x;/// Quaternion y component (vector j)
 double get y;/// Quaternion z component (vector k)
 double get z;/// Timestamp when the data was received
 DateTime get timestamp;
/// Create a copy of SensorFusionData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SensorFusionDataCopyWith<SensorFusionData> get copyWith => _$SensorFusionDataCopyWithImpl<SensorFusionData>(this as SensorFusionData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SensorFusionData&&(identical(other.w, w) || other.w == w)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.z, z) || other.z == z)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}


@override
int get hashCode => Object.hash(runtimeType,w,x,y,z,timestamp);

@override
String toString() {
  return 'SensorFusionData(w: $w, x: $x, y: $y, z: $z, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $SensorFusionDataCopyWith<$Res>  {
  factory $SensorFusionDataCopyWith(SensorFusionData value, $Res Function(SensorFusionData) _then) = _$SensorFusionDataCopyWithImpl;
@useResult
$Res call({
 double w, double x, double y, double z, DateTime timestamp
});




}
/// @nodoc
class _$SensorFusionDataCopyWithImpl<$Res>
    implements $SensorFusionDataCopyWith<$Res> {
  _$SensorFusionDataCopyWithImpl(this._self, this._then);

  final SensorFusionData _self;
  final $Res Function(SensorFusionData) _then;

/// Create a copy of SensorFusionData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? w = null,Object? x = null,Object? y = null,Object? z = null,Object? timestamp = null,}) {
  return _then(_self.copyWith(
w: null == w ? _self.w : w // ignore: cast_nullable_to_non_nullable
as double,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,z: null == z ? _self.z : z // ignore: cast_nullable_to_non_nullable
as double,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SensorFusionData].
extension SensorFusionDataPatterns on SensorFusionData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SensorFusionData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SensorFusionData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SensorFusionData value)  $default,){
final _that = this;
switch (_that) {
case _SensorFusionData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SensorFusionData value)?  $default,){
final _that = this;
switch (_that) {
case _SensorFusionData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double w,  double x,  double y,  double z,  DateTime timestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SensorFusionData() when $default != null:
return $default(_that.w,_that.x,_that.y,_that.z,_that.timestamp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double w,  double x,  double y,  double z,  DateTime timestamp)  $default,) {final _that = this;
switch (_that) {
case _SensorFusionData():
return $default(_that.w,_that.x,_that.y,_that.z,_that.timestamp);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double w,  double x,  double y,  double z,  DateTime timestamp)?  $default,) {final _that = this;
switch (_that) {
case _SensorFusionData() when $default != null:
return $default(_that.w,_that.x,_that.y,_that.z,_that.timestamp);case _:
  return null;

}
}

}

/// @nodoc


class _SensorFusionData extends SensorFusionData {
  const _SensorFusionData({required this.w, required this.x, required this.y, required this.z, required this.timestamp}): super._();
  

/// Quaternion w component (scalar part)
@override final  double w;
/// Quaternion x component (vector i)
@override final  double x;
/// Quaternion y component (vector j)
@override final  double y;
/// Quaternion z component (vector k)
@override final  double z;
/// Timestamp when the data was received
@override final  DateTime timestamp;

/// Create a copy of SensorFusionData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SensorFusionDataCopyWith<_SensorFusionData> get copyWith => __$SensorFusionDataCopyWithImpl<_SensorFusionData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SensorFusionData&&(identical(other.w, w) || other.w == w)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.z, z) || other.z == z)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}


@override
int get hashCode => Object.hash(runtimeType,w,x,y,z,timestamp);

@override
String toString() {
  return 'SensorFusionData(w: $w, x: $x, y: $y, z: $z, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class _$SensorFusionDataCopyWith<$Res> implements $SensorFusionDataCopyWith<$Res> {
  factory _$SensorFusionDataCopyWith(_SensorFusionData value, $Res Function(_SensorFusionData) _then) = __$SensorFusionDataCopyWithImpl;
@override @useResult
$Res call({
 double w, double x, double y, double z, DateTime timestamp
});




}
/// @nodoc
class __$SensorFusionDataCopyWithImpl<$Res>
    implements _$SensorFusionDataCopyWith<$Res> {
  __$SensorFusionDataCopyWithImpl(this._self, this._then);

  final _SensorFusionData _self;
  final $Res Function(_SensorFusionData) _then;

/// Create a copy of SensorFusionData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? w = null,Object? x = null,Object? y = null,Object? z = null,Object? timestamp = null,}) {
  return _then(_SensorFusionData(
w: null == w ? _self.w : w // ignore: cast_nullable_to_non_nullable
as double,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,z: null == z ? _self.z : z // ignore: cast_nullable_to_non_nullable
as double,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$EulerAngles {

/// Roll (rotation around X-axis) in radians
 double get roll;/// Pitch (rotation around Y-axis) in radians
 double get pitch;/// Yaw (rotation around Z-axis) in radians
 double get yaw;
/// Create a copy of EulerAngles
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EulerAnglesCopyWith<EulerAngles> get copyWith => _$EulerAnglesCopyWithImpl<EulerAngles>(this as EulerAngles, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EulerAngles&&(identical(other.roll, roll) || other.roll == roll)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.yaw, yaw) || other.yaw == yaw));
}


@override
int get hashCode => Object.hash(runtimeType,roll,pitch,yaw);

@override
String toString() {
  return 'EulerAngles(roll: $roll, pitch: $pitch, yaw: $yaw)';
}


}

/// @nodoc
abstract mixin class $EulerAnglesCopyWith<$Res>  {
  factory $EulerAnglesCopyWith(EulerAngles value, $Res Function(EulerAngles) _then) = _$EulerAnglesCopyWithImpl;
@useResult
$Res call({
 double roll, double pitch, double yaw
});




}
/// @nodoc
class _$EulerAnglesCopyWithImpl<$Res>
    implements $EulerAnglesCopyWith<$Res> {
  _$EulerAnglesCopyWithImpl(this._self, this._then);

  final EulerAngles _self;
  final $Res Function(EulerAngles) _then;

/// Create a copy of EulerAngles
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roll = null,Object? pitch = null,Object? yaw = null,}) {
  return _then(_self.copyWith(
roll: null == roll ? _self.roll : roll // ignore: cast_nullable_to_non_nullable
as double,pitch: null == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double,yaw: null == yaw ? _self.yaw : yaw // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [EulerAngles].
extension EulerAnglesPatterns on EulerAngles {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EulerAngles value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EulerAngles() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EulerAngles value)  $default,){
final _that = this;
switch (_that) {
case _EulerAngles():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EulerAngles value)?  $default,){
final _that = this;
switch (_that) {
case _EulerAngles() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double roll,  double pitch,  double yaw)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EulerAngles() when $default != null:
return $default(_that.roll,_that.pitch,_that.yaw);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double roll,  double pitch,  double yaw)  $default,) {final _that = this;
switch (_that) {
case _EulerAngles():
return $default(_that.roll,_that.pitch,_that.yaw);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double roll,  double pitch,  double yaw)?  $default,) {final _that = this;
switch (_that) {
case _EulerAngles() when $default != null:
return $default(_that.roll,_that.pitch,_that.yaw);case _:
  return null;

}
}

}

/// @nodoc


class _EulerAngles extends EulerAngles {
  const _EulerAngles({required this.roll, required this.pitch, required this.yaw}): super._();
  

/// Roll (rotation around X-axis) in radians
@override final  double roll;
/// Pitch (rotation around Y-axis) in radians
@override final  double pitch;
/// Yaw (rotation around Z-axis) in radians
@override final  double yaw;

/// Create a copy of EulerAngles
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EulerAnglesCopyWith<_EulerAngles> get copyWith => __$EulerAnglesCopyWithImpl<_EulerAngles>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EulerAngles&&(identical(other.roll, roll) || other.roll == roll)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.yaw, yaw) || other.yaw == yaw));
}


@override
int get hashCode => Object.hash(runtimeType,roll,pitch,yaw);

@override
String toString() {
  return 'EulerAngles(roll: $roll, pitch: $pitch, yaw: $yaw)';
}


}

/// @nodoc
abstract mixin class _$EulerAnglesCopyWith<$Res> implements $EulerAnglesCopyWith<$Res> {
  factory _$EulerAnglesCopyWith(_EulerAngles value, $Res Function(_EulerAngles) _then) = __$EulerAnglesCopyWithImpl;
@override @useResult
$Res call({
 double roll, double pitch, double yaw
});




}
/// @nodoc
class __$EulerAnglesCopyWithImpl<$Res>
    implements _$EulerAnglesCopyWith<$Res> {
  __$EulerAnglesCopyWithImpl(this._self, this._then);

  final _EulerAngles _self;
  final $Res Function(_EulerAngles) _then;

/// Create a copy of EulerAngles
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roll = null,Object? pitch = null,Object? yaw = null,}) {
  return _then(_EulerAngles(
roll: null == roll ? _self.roll : roll // ignore: cast_nullable_to_non_nullable
as double,pitch: null == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double,yaw: null == yaw ? _self.yaw : yaw // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
