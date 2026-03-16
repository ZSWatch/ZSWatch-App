// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Connection {

/// ID of the connected watch
 String get watchId;/// Name of the connected watch
 String? get watchName;/// Current connection state
 WatchConnectionState get state;/// Signal strength in dBm (negative value, closer to 0 is stronger)
 int? get rssi;/// Negotiated MTU size
 int? get mtu;/// Current PHY mode
 PhyMode? get phyMode;/// Whether Data Length Extension is enabled
 bool get dleEnabled;/// Whether watch is currently charging
 bool get isCharging;/// Number of reconnection attempts in current session
 int get reconnectionCount;/// When the current connection was established
 DateTime? get connectedAt;/// Last data exchange timestamp
 DateTime? get lastActivityAt;/// Error information if state is error
 ConnectionErrorType? get errorType;/// Additional error details
 String? get errorDetails;
/// Create a copy of Connection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionCopyWith<Connection> get copyWith => _$ConnectionCopyWithImpl<Connection>(this as Connection, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Connection&&(identical(other.watchId, watchId) || other.watchId == watchId)&&(identical(other.watchName, watchName) || other.watchName == watchName)&&(identical(other.state, state) || other.state == state)&&(identical(other.rssi, rssi) || other.rssi == rssi)&&(identical(other.mtu, mtu) || other.mtu == mtu)&&(identical(other.phyMode, phyMode) || other.phyMode == phyMode)&&(identical(other.dleEnabled, dleEnabled) || other.dleEnabled == dleEnabled)&&(identical(other.isCharging, isCharging) || other.isCharging == isCharging)&&(identical(other.reconnectionCount, reconnectionCount) || other.reconnectionCount == reconnectionCount)&&(identical(other.connectedAt, connectedAt) || other.connectedAt == connectedAt)&&(identical(other.lastActivityAt, lastActivityAt) || other.lastActivityAt == lastActivityAt)&&(identical(other.errorType, errorType) || other.errorType == errorType)&&(identical(other.errorDetails, errorDetails) || other.errorDetails == errorDetails));
}


@override
int get hashCode => Object.hash(runtimeType,watchId,watchName,state,rssi,mtu,phyMode,dleEnabled,isCharging,reconnectionCount,connectedAt,lastActivityAt,errorType,errorDetails);

@override
String toString() {
  return 'Connection(watchId: $watchId, watchName: $watchName, state: $state, rssi: $rssi, mtu: $mtu, phyMode: $phyMode, dleEnabled: $dleEnabled, isCharging: $isCharging, reconnectionCount: $reconnectionCount, connectedAt: $connectedAt, lastActivityAt: $lastActivityAt, errorType: $errorType, errorDetails: $errorDetails)';
}


}

/// @nodoc
abstract mixin class $ConnectionCopyWith<$Res>  {
  factory $ConnectionCopyWith(Connection value, $Res Function(Connection) _then) = _$ConnectionCopyWithImpl;
@useResult
$Res call({
 String watchId, String? watchName, WatchConnectionState state, int? rssi, int? mtu, PhyMode? phyMode, bool dleEnabled, bool isCharging, int reconnectionCount, DateTime? connectedAt, DateTime? lastActivityAt, ConnectionErrorType? errorType, String? errorDetails
});




}
/// @nodoc
class _$ConnectionCopyWithImpl<$Res>
    implements $ConnectionCopyWith<$Res> {
  _$ConnectionCopyWithImpl(this._self, this._then);

  final Connection _self;
  final $Res Function(Connection) _then;

/// Create a copy of Connection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? watchId = null,Object? watchName = freezed,Object? state = null,Object? rssi = freezed,Object? mtu = freezed,Object? phyMode = freezed,Object? dleEnabled = null,Object? isCharging = null,Object? reconnectionCount = null,Object? connectedAt = freezed,Object? lastActivityAt = freezed,Object? errorType = freezed,Object? errorDetails = freezed,}) {
  return _then(_self.copyWith(
watchId: null == watchId ? _self.watchId : watchId // ignore: cast_nullable_to_non_nullable
as String,watchName: freezed == watchName ? _self.watchName : watchName // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as WatchConnectionState,rssi: freezed == rssi ? _self.rssi : rssi // ignore: cast_nullable_to_non_nullable
as int?,mtu: freezed == mtu ? _self.mtu : mtu // ignore: cast_nullable_to_non_nullable
as int?,phyMode: freezed == phyMode ? _self.phyMode : phyMode // ignore: cast_nullable_to_non_nullable
as PhyMode?,dleEnabled: null == dleEnabled ? _self.dleEnabled : dleEnabled // ignore: cast_nullable_to_non_nullable
as bool,isCharging: null == isCharging ? _self.isCharging : isCharging // ignore: cast_nullable_to_non_nullable
as bool,reconnectionCount: null == reconnectionCount ? _self.reconnectionCount : reconnectionCount // ignore: cast_nullable_to_non_nullable
as int,connectedAt: freezed == connectedAt ? _self.connectedAt : connectedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastActivityAt: freezed == lastActivityAt ? _self.lastActivityAt : lastActivityAt // ignore: cast_nullable_to_non_nullable
as DateTime?,errorType: freezed == errorType ? _self.errorType : errorType // ignore: cast_nullable_to_non_nullable
as ConnectionErrorType?,errorDetails: freezed == errorDetails ? _self.errorDetails : errorDetails // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Connection].
extension ConnectionPatterns on Connection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Connection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Connection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Connection value)  $default,){
final _that = this;
switch (_that) {
case _Connection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Connection value)?  $default,){
final _that = this;
switch (_that) {
case _Connection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String watchId,  String? watchName,  WatchConnectionState state,  int? rssi,  int? mtu,  PhyMode? phyMode,  bool dleEnabled,  bool isCharging,  int reconnectionCount,  DateTime? connectedAt,  DateTime? lastActivityAt,  ConnectionErrorType? errorType,  String? errorDetails)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Connection() when $default != null:
return $default(_that.watchId,_that.watchName,_that.state,_that.rssi,_that.mtu,_that.phyMode,_that.dleEnabled,_that.isCharging,_that.reconnectionCount,_that.connectedAt,_that.lastActivityAt,_that.errorType,_that.errorDetails);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String watchId,  String? watchName,  WatchConnectionState state,  int? rssi,  int? mtu,  PhyMode? phyMode,  bool dleEnabled,  bool isCharging,  int reconnectionCount,  DateTime? connectedAt,  DateTime? lastActivityAt,  ConnectionErrorType? errorType,  String? errorDetails)  $default,) {final _that = this;
switch (_that) {
case _Connection():
return $default(_that.watchId,_that.watchName,_that.state,_that.rssi,_that.mtu,_that.phyMode,_that.dleEnabled,_that.isCharging,_that.reconnectionCount,_that.connectedAt,_that.lastActivityAt,_that.errorType,_that.errorDetails);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String watchId,  String? watchName,  WatchConnectionState state,  int? rssi,  int? mtu,  PhyMode? phyMode,  bool dleEnabled,  bool isCharging,  int reconnectionCount,  DateTime? connectedAt,  DateTime? lastActivityAt,  ConnectionErrorType? errorType,  String? errorDetails)?  $default,) {final _that = this;
switch (_that) {
case _Connection() when $default != null:
return $default(_that.watchId,_that.watchName,_that.state,_that.rssi,_that.mtu,_that.phyMode,_that.dleEnabled,_that.isCharging,_that.reconnectionCount,_that.connectedAt,_that.lastActivityAt,_that.errorType,_that.errorDetails);case _:
  return null;

}
}

}

/// @nodoc


class _Connection extends Connection {
  const _Connection({required this.watchId, this.watchName, required this.state, this.rssi, this.mtu, this.phyMode, this.dleEnabled = false, this.isCharging = false, this.reconnectionCount = 0, this.connectedAt, this.lastActivityAt, this.errorType, this.errorDetails}): super._();
  

/// ID of the connected watch
@override final  String watchId;
/// Name of the connected watch
@override final  String? watchName;
/// Current connection state
@override final  WatchConnectionState state;
/// Signal strength in dBm (negative value, closer to 0 is stronger)
@override final  int? rssi;
/// Negotiated MTU size
@override final  int? mtu;
/// Current PHY mode
@override final  PhyMode? phyMode;
/// Whether Data Length Extension is enabled
@override@JsonKey() final  bool dleEnabled;
/// Whether watch is currently charging
@override@JsonKey() final  bool isCharging;
/// Number of reconnection attempts in current session
@override@JsonKey() final  int reconnectionCount;
/// When the current connection was established
@override final  DateTime? connectedAt;
/// Last data exchange timestamp
@override final  DateTime? lastActivityAt;
/// Error information if state is error
@override final  ConnectionErrorType? errorType;
/// Additional error details
@override final  String? errorDetails;

/// Create a copy of Connection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectionCopyWith<_Connection> get copyWith => __$ConnectionCopyWithImpl<_Connection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Connection&&(identical(other.watchId, watchId) || other.watchId == watchId)&&(identical(other.watchName, watchName) || other.watchName == watchName)&&(identical(other.state, state) || other.state == state)&&(identical(other.rssi, rssi) || other.rssi == rssi)&&(identical(other.mtu, mtu) || other.mtu == mtu)&&(identical(other.phyMode, phyMode) || other.phyMode == phyMode)&&(identical(other.dleEnabled, dleEnabled) || other.dleEnabled == dleEnabled)&&(identical(other.isCharging, isCharging) || other.isCharging == isCharging)&&(identical(other.reconnectionCount, reconnectionCount) || other.reconnectionCount == reconnectionCount)&&(identical(other.connectedAt, connectedAt) || other.connectedAt == connectedAt)&&(identical(other.lastActivityAt, lastActivityAt) || other.lastActivityAt == lastActivityAt)&&(identical(other.errorType, errorType) || other.errorType == errorType)&&(identical(other.errorDetails, errorDetails) || other.errorDetails == errorDetails));
}


@override
int get hashCode => Object.hash(runtimeType,watchId,watchName,state,rssi,mtu,phyMode,dleEnabled,isCharging,reconnectionCount,connectedAt,lastActivityAt,errorType,errorDetails);

@override
String toString() {
  return 'Connection(watchId: $watchId, watchName: $watchName, state: $state, rssi: $rssi, mtu: $mtu, phyMode: $phyMode, dleEnabled: $dleEnabled, isCharging: $isCharging, reconnectionCount: $reconnectionCount, connectedAt: $connectedAt, lastActivityAt: $lastActivityAt, errorType: $errorType, errorDetails: $errorDetails)';
}


}

/// @nodoc
abstract mixin class _$ConnectionCopyWith<$Res> implements $ConnectionCopyWith<$Res> {
  factory _$ConnectionCopyWith(_Connection value, $Res Function(_Connection) _then) = __$ConnectionCopyWithImpl;
@override @useResult
$Res call({
 String watchId, String? watchName, WatchConnectionState state, int? rssi, int? mtu, PhyMode? phyMode, bool dleEnabled, bool isCharging, int reconnectionCount, DateTime? connectedAt, DateTime? lastActivityAt, ConnectionErrorType? errorType, String? errorDetails
});




}
/// @nodoc
class __$ConnectionCopyWithImpl<$Res>
    implements _$ConnectionCopyWith<$Res> {
  __$ConnectionCopyWithImpl(this._self, this._then);

  final _Connection _self;
  final $Res Function(_Connection) _then;

/// Create a copy of Connection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? watchId = null,Object? watchName = freezed,Object? state = null,Object? rssi = freezed,Object? mtu = freezed,Object? phyMode = freezed,Object? dleEnabled = null,Object? isCharging = null,Object? reconnectionCount = null,Object? connectedAt = freezed,Object? lastActivityAt = freezed,Object? errorType = freezed,Object? errorDetails = freezed,}) {
  return _then(_Connection(
watchId: null == watchId ? _self.watchId : watchId // ignore: cast_nullable_to_non_nullable
as String,watchName: freezed == watchName ? _self.watchName : watchName // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as WatchConnectionState,rssi: freezed == rssi ? _self.rssi : rssi // ignore: cast_nullable_to_non_nullable
as int?,mtu: freezed == mtu ? _self.mtu : mtu // ignore: cast_nullable_to_non_nullable
as int?,phyMode: freezed == phyMode ? _self.phyMode : phyMode // ignore: cast_nullable_to_non_nullable
as PhyMode?,dleEnabled: null == dleEnabled ? _self.dleEnabled : dleEnabled // ignore: cast_nullable_to_non_nullable
as bool,isCharging: null == isCharging ? _self.isCharging : isCharging // ignore: cast_nullable_to_non_nullable
as bool,reconnectionCount: null == reconnectionCount ? _self.reconnectionCount : reconnectionCount // ignore: cast_nullable_to_non_nullable
as int,connectedAt: freezed == connectedAt ? _self.connectedAt : connectedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastActivityAt: freezed == lastActivityAt ? _self.lastActivityAt : lastActivityAt // ignore: cast_nullable_to_non_nullable
as DateTime?,errorType: freezed == errorType ? _self.errorType : errorType // ignore: cast_nullable_to_non_nullable
as ConnectionErrorType?,errorDetails: freezed == errorDetails ? _self.errorDetails : errorDetails // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
