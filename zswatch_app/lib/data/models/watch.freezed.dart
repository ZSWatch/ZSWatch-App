// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'watch.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Watch {

/// BLE device identifier (MAC address on Android, UUID on iOS)
 String get id;/// Advertised device name
 String get name;/// User-defined custom name for the watch (FR-099 to FR-102)
 String? get customName;/// Last known firmware version
 String? get firmwareVersion;/// Hardware revision
 String? get hardwareVersion;/// Last known battery level (0-100)
 int? get batteryLevel;/// Whether this is the currently selected watch
 bool get isPrimary;/// Whether firmware supports Extended ZSWatch API
 bool get supportsExtendedApi;/// Last successful connection timestamp
 DateTime? get lastConnectedAt;/// When the device was first paired
 DateTime get createdAt;
/// Create a copy of Watch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WatchCopyWith<Watch> get copyWith => _$WatchCopyWithImpl<Watch>(this as Watch, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Watch&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.customName, customName) || other.customName == customName)&&(identical(other.firmwareVersion, firmwareVersion) || other.firmwareVersion == firmwareVersion)&&(identical(other.hardwareVersion, hardwareVersion) || other.hardwareVersion == hardwareVersion)&&(identical(other.batteryLevel, batteryLevel) || other.batteryLevel == batteryLevel)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.supportsExtendedApi, supportsExtendedApi) || other.supportsExtendedApi == supportsExtendedApi)&&(identical(other.lastConnectedAt, lastConnectedAt) || other.lastConnectedAt == lastConnectedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,customName,firmwareVersion,hardwareVersion,batteryLevel,isPrimary,supportsExtendedApi,lastConnectedAt,createdAt);

@override
String toString() {
  return 'Watch(id: $id, name: $name, customName: $customName, firmwareVersion: $firmwareVersion, hardwareVersion: $hardwareVersion, batteryLevel: $batteryLevel, isPrimary: $isPrimary, supportsExtendedApi: $supportsExtendedApi, lastConnectedAt: $lastConnectedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $WatchCopyWith<$Res>  {
  factory $WatchCopyWith(Watch value, $Res Function(Watch) _then) = _$WatchCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? customName, String? firmwareVersion, String? hardwareVersion, int? batteryLevel, bool isPrimary, bool supportsExtendedApi, DateTime? lastConnectedAt, DateTime createdAt
});




}
/// @nodoc
class _$WatchCopyWithImpl<$Res>
    implements $WatchCopyWith<$Res> {
  _$WatchCopyWithImpl(this._self, this._then);

  final Watch _self;
  final $Res Function(Watch) _then;

/// Create a copy of Watch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? customName = freezed,Object? firmwareVersion = freezed,Object? hardwareVersion = freezed,Object? batteryLevel = freezed,Object? isPrimary = null,Object? supportsExtendedApi = null,Object? lastConnectedAt = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,customName: freezed == customName ? _self.customName : customName // ignore: cast_nullable_to_non_nullable
as String?,firmwareVersion: freezed == firmwareVersion ? _self.firmwareVersion : firmwareVersion // ignore: cast_nullable_to_non_nullable
as String?,hardwareVersion: freezed == hardwareVersion ? _self.hardwareVersion : hardwareVersion // ignore: cast_nullable_to_non_nullable
as String?,batteryLevel: freezed == batteryLevel ? _self.batteryLevel : batteryLevel // ignore: cast_nullable_to_non_nullable
as int?,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,supportsExtendedApi: null == supportsExtendedApi ? _self.supportsExtendedApi : supportsExtendedApi // ignore: cast_nullable_to_non_nullable
as bool,lastConnectedAt: freezed == lastConnectedAt ? _self.lastConnectedAt : lastConnectedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Watch].
extension WatchPatterns on Watch {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Watch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Watch() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Watch value)  $default,){
final _that = this;
switch (_that) {
case _Watch():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Watch value)?  $default,){
final _that = this;
switch (_that) {
case _Watch() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? customName,  String? firmwareVersion,  String? hardwareVersion,  int? batteryLevel,  bool isPrimary,  bool supportsExtendedApi,  DateTime? lastConnectedAt,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Watch() when $default != null:
return $default(_that.id,_that.name,_that.customName,_that.firmwareVersion,_that.hardwareVersion,_that.batteryLevel,_that.isPrimary,_that.supportsExtendedApi,_that.lastConnectedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? customName,  String? firmwareVersion,  String? hardwareVersion,  int? batteryLevel,  bool isPrimary,  bool supportsExtendedApi,  DateTime? lastConnectedAt,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Watch():
return $default(_that.id,_that.name,_that.customName,_that.firmwareVersion,_that.hardwareVersion,_that.batteryLevel,_that.isPrimary,_that.supportsExtendedApi,_that.lastConnectedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? customName,  String? firmwareVersion,  String? hardwareVersion,  int? batteryLevel,  bool isPrimary,  bool supportsExtendedApi,  DateTime? lastConnectedAt,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Watch() when $default != null:
return $default(_that.id,_that.name,_that.customName,_that.firmwareVersion,_that.hardwareVersion,_that.batteryLevel,_that.isPrimary,_that.supportsExtendedApi,_that.lastConnectedAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _Watch extends Watch {
  const _Watch({required this.id, required this.name, this.customName, this.firmwareVersion, this.hardwareVersion, this.batteryLevel, this.isPrimary = false, this.supportsExtendedApi = false, this.lastConnectedAt, required this.createdAt}): super._();
  

/// BLE device identifier (MAC address on Android, UUID on iOS)
@override final  String id;
/// Advertised device name
@override final  String name;
/// User-defined custom name for the watch (FR-099 to FR-102)
@override final  String? customName;
/// Last known firmware version
@override final  String? firmwareVersion;
/// Hardware revision
@override final  String? hardwareVersion;
/// Last known battery level (0-100)
@override final  int? batteryLevel;
/// Whether this is the currently selected watch
@override@JsonKey() final  bool isPrimary;
/// Whether firmware supports Extended ZSWatch API
@override@JsonKey() final  bool supportsExtendedApi;
/// Last successful connection timestamp
@override final  DateTime? lastConnectedAt;
/// When the device was first paired
@override final  DateTime createdAt;

/// Create a copy of Watch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WatchCopyWith<_Watch> get copyWith => __$WatchCopyWithImpl<_Watch>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Watch&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.customName, customName) || other.customName == customName)&&(identical(other.firmwareVersion, firmwareVersion) || other.firmwareVersion == firmwareVersion)&&(identical(other.hardwareVersion, hardwareVersion) || other.hardwareVersion == hardwareVersion)&&(identical(other.batteryLevel, batteryLevel) || other.batteryLevel == batteryLevel)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.supportsExtendedApi, supportsExtendedApi) || other.supportsExtendedApi == supportsExtendedApi)&&(identical(other.lastConnectedAt, lastConnectedAt) || other.lastConnectedAt == lastConnectedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,customName,firmwareVersion,hardwareVersion,batteryLevel,isPrimary,supportsExtendedApi,lastConnectedAt,createdAt);

@override
String toString() {
  return 'Watch(id: $id, name: $name, customName: $customName, firmwareVersion: $firmwareVersion, hardwareVersion: $hardwareVersion, batteryLevel: $batteryLevel, isPrimary: $isPrimary, supportsExtendedApi: $supportsExtendedApi, lastConnectedAt: $lastConnectedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$WatchCopyWith<$Res> implements $WatchCopyWith<$Res> {
  factory _$WatchCopyWith(_Watch value, $Res Function(_Watch) _then) = __$WatchCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? customName, String? firmwareVersion, String? hardwareVersion, int? batteryLevel, bool isPrimary, bool supportsExtendedApi, DateTime? lastConnectedAt, DateTime createdAt
});




}
/// @nodoc
class __$WatchCopyWithImpl<$Res>
    implements _$WatchCopyWith<$Res> {
  __$WatchCopyWithImpl(this._self, this._then);

  final _Watch _self;
  final $Res Function(_Watch) _then;

/// Create a copy of Watch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? customName = freezed,Object? firmwareVersion = freezed,Object? hardwareVersion = freezed,Object? batteryLevel = freezed,Object? isPrimary = null,Object? supportsExtendedApi = null,Object? lastConnectedAt = freezed,Object? createdAt = null,}) {
  return _then(_Watch(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,customName: freezed == customName ? _self.customName : customName // ignore: cast_nullable_to_non_nullable
as String?,firmwareVersion: freezed == firmwareVersion ? _self.firmwareVersion : firmwareVersion // ignore: cast_nullable_to_non_nullable
as String?,hardwareVersion: freezed == hardwareVersion ? _self.hardwareVersion : hardwareVersion // ignore: cast_nullable_to_non_nullable
as String?,batteryLevel: freezed == batteryLevel ? _self.batteryLevel : batteryLevel // ignore: cast_nullable_to_non_nullable
as int?,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,supportsExtendedApi: null == supportsExtendedApi ? _self.supportsExtendedApi : supportsExtendedApi // ignore: cast_nullable_to_non_nullable
as bool,lastConnectedAt: freezed == lastConnectedAt ? _self.lastConnectedAt : lastConnectedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
