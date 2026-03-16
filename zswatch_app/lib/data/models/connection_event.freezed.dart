// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConnectionEvent implements DiagnosticableTreeMixin {

/// Unique identifier
 int? get id;/// Watch device ID
 String get watchId;/// Type of event
 ConnectionEventType get eventType;/// When the event occurred
 DateTime get timestamp;/// Reason for disconnection (only for disconnect events)
 DisconnectReason? get reason;/// Additional details (e.g., error message)
 String? get details;/// Session ID to group connect/disconnect pairs
 String? get sessionId;
/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionEventCopyWith<ConnectionEvent> get copyWith => _$ConnectionEventCopyWithImpl<ConnectionEvent>(this as ConnectionEvent, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ConnectionEvent'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('watchId', watchId))..add(DiagnosticsProperty('eventType', eventType))..add(DiagnosticsProperty('timestamp', timestamp))..add(DiagnosticsProperty('reason', reason))..add(DiagnosticsProperty('details', details))..add(DiagnosticsProperty('sessionId', sessionId));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.watchId, watchId) || other.watchId == watchId)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.details, details) || other.details == details)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}


@override
int get hashCode => Object.hash(runtimeType,id,watchId,eventType,timestamp,reason,details,sessionId);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ConnectionEvent(id: $id, watchId: $watchId, eventType: $eventType, timestamp: $timestamp, reason: $reason, details: $details, sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $ConnectionEventCopyWith<$Res>  {
  factory $ConnectionEventCopyWith(ConnectionEvent value, $Res Function(ConnectionEvent) _then) = _$ConnectionEventCopyWithImpl;
@useResult
$Res call({
 int? id, String watchId, ConnectionEventType eventType, DateTime timestamp, DisconnectReason? reason, String? details, String? sessionId
});




}
/// @nodoc
class _$ConnectionEventCopyWithImpl<$Res>
    implements $ConnectionEventCopyWith<$Res> {
  _$ConnectionEventCopyWithImpl(this._self, this._then);

  final ConnectionEvent _self;
  final $Res Function(ConnectionEvent) _then;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? watchId = null,Object? eventType = null,Object? timestamp = null,Object? reason = freezed,Object? details = freezed,Object? sessionId = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,watchId: null == watchId ? _self.watchId : watchId // ignore: cast_nullable_to_non_nullable
as String,eventType: null == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as ConnectionEventType,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as DisconnectReason?,details: freezed == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as String?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ConnectionEvent].
extension ConnectionEventPatterns on ConnectionEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConnectionEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConnectionEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConnectionEvent value)  $default,){
final _that = this;
switch (_that) {
case _ConnectionEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConnectionEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ConnectionEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String watchId,  ConnectionEventType eventType,  DateTime timestamp,  DisconnectReason? reason,  String? details,  String? sessionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConnectionEvent() when $default != null:
return $default(_that.id,_that.watchId,_that.eventType,_that.timestamp,_that.reason,_that.details,_that.sessionId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String watchId,  ConnectionEventType eventType,  DateTime timestamp,  DisconnectReason? reason,  String? details,  String? sessionId)  $default,) {final _that = this;
switch (_that) {
case _ConnectionEvent():
return $default(_that.id,_that.watchId,_that.eventType,_that.timestamp,_that.reason,_that.details,_that.sessionId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String watchId,  ConnectionEventType eventType,  DateTime timestamp,  DisconnectReason? reason,  String? details,  String? sessionId)?  $default,) {final _that = this;
switch (_that) {
case _ConnectionEvent() when $default != null:
return $default(_that.id,_that.watchId,_that.eventType,_that.timestamp,_that.reason,_that.details,_that.sessionId);case _:
  return null;

}
}

}

/// @nodoc


class _ConnectionEvent extends ConnectionEvent with DiagnosticableTreeMixin {
  const _ConnectionEvent({this.id, required this.watchId, required this.eventType, required this.timestamp, this.reason, this.details, this.sessionId}): super._();
  

/// Unique identifier
@override final  int? id;
/// Watch device ID
@override final  String watchId;
/// Type of event
@override final  ConnectionEventType eventType;
/// When the event occurred
@override final  DateTime timestamp;
/// Reason for disconnection (only for disconnect events)
@override final  DisconnectReason? reason;
/// Additional details (e.g., error message)
@override final  String? details;
/// Session ID to group connect/disconnect pairs
@override final  String? sessionId;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectionEventCopyWith<_ConnectionEvent> get copyWith => __$ConnectionEventCopyWithImpl<_ConnectionEvent>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ConnectionEvent'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('watchId', watchId))..add(DiagnosticsProperty('eventType', eventType))..add(DiagnosticsProperty('timestamp', timestamp))..add(DiagnosticsProperty('reason', reason))..add(DiagnosticsProperty('details', details))..add(DiagnosticsProperty('sessionId', sessionId));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConnectionEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.watchId, watchId) || other.watchId == watchId)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.details, details) || other.details == details)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}


@override
int get hashCode => Object.hash(runtimeType,id,watchId,eventType,timestamp,reason,details,sessionId);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ConnectionEvent(id: $id, watchId: $watchId, eventType: $eventType, timestamp: $timestamp, reason: $reason, details: $details, sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class _$ConnectionEventCopyWith<$Res> implements $ConnectionEventCopyWith<$Res> {
  factory _$ConnectionEventCopyWith(_ConnectionEvent value, $Res Function(_ConnectionEvent) _then) = __$ConnectionEventCopyWithImpl;
@override @useResult
$Res call({
 int? id, String watchId, ConnectionEventType eventType, DateTime timestamp, DisconnectReason? reason, String? details, String? sessionId
});




}
/// @nodoc
class __$ConnectionEventCopyWithImpl<$Res>
    implements _$ConnectionEventCopyWith<$Res> {
  __$ConnectionEventCopyWithImpl(this._self, this._then);

  final _ConnectionEvent _self;
  final $Res Function(_ConnectionEvent) _then;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? watchId = null,Object? eventType = null,Object? timestamp = null,Object? reason = freezed,Object? details = freezed,Object? sessionId = freezed,}) {
  return _then(_ConnectionEvent(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,watchId: null == watchId ? _self.watchId : watchId // ignore: cast_nullable_to_non_nullable
as String,eventType: null == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as ConnectionEventType,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as DisconnectReason?,details: freezed == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as String?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
