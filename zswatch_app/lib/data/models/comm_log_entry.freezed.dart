// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comm_log_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CommLogEntry {

/// Unique identifier for this entry
 int get id;/// Timestamp when the entry was recorded
 DateTime get timestamp;/// The raw data content
 String get data;/// Direction of communication
 CommDirection get direction;/// Size in bytes
 int get sizeBytes;/// Optional parsed message type (from 't' field in JSON)
 String? get messageType;/// Whether the data was chunked across multiple BLE packets
 bool get wasChunked;/// Number of chunks if chunked
 int? get chunkCount;
/// Create a copy of CommLogEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommLogEntryCopyWith<CommLogEntry> get copyWith => _$CommLogEntryCopyWithImpl<CommLogEntry>(this as CommLogEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommLogEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.data, data) || other.data == data)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.wasChunked, wasChunked) || other.wasChunked == wasChunked)&&(identical(other.chunkCount, chunkCount) || other.chunkCount == chunkCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,timestamp,data,direction,sizeBytes,messageType,wasChunked,chunkCount);

@override
String toString() {
  return 'CommLogEntry(id: $id, timestamp: $timestamp, data: $data, direction: $direction, sizeBytes: $sizeBytes, messageType: $messageType, wasChunked: $wasChunked, chunkCount: $chunkCount)';
}


}

/// @nodoc
abstract mixin class $CommLogEntryCopyWith<$Res>  {
  factory $CommLogEntryCopyWith(CommLogEntry value, $Res Function(CommLogEntry) _then) = _$CommLogEntryCopyWithImpl;
@useResult
$Res call({
 int id, DateTime timestamp, String data, CommDirection direction, int sizeBytes, String? messageType, bool wasChunked, int? chunkCount
});




}
/// @nodoc
class _$CommLogEntryCopyWithImpl<$Res>
    implements $CommLogEntryCopyWith<$Res> {
  _$CommLogEntryCopyWithImpl(this._self, this._then);

  final CommLogEntry _self;
  final $Res Function(CommLogEntry) _then;

/// Create a copy of CommLogEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? timestamp = null,Object? data = null,Object? direction = null,Object? sizeBytes = null,Object? messageType = freezed,Object? wasChunked = null,Object? chunkCount = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as CommDirection,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,messageType: freezed == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String?,wasChunked: null == wasChunked ? _self.wasChunked : wasChunked // ignore: cast_nullable_to_non_nullable
as bool,chunkCount: freezed == chunkCount ? _self.chunkCount : chunkCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [CommLogEntry].
extension CommLogEntryPatterns on CommLogEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommLogEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommLogEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommLogEntry value)  $default,){
final _that = this;
switch (_that) {
case _CommLogEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommLogEntry value)?  $default,){
final _that = this;
switch (_that) {
case _CommLogEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  DateTime timestamp,  String data,  CommDirection direction,  int sizeBytes,  String? messageType,  bool wasChunked,  int? chunkCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommLogEntry() when $default != null:
return $default(_that.id,_that.timestamp,_that.data,_that.direction,_that.sizeBytes,_that.messageType,_that.wasChunked,_that.chunkCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  DateTime timestamp,  String data,  CommDirection direction,  int sizeBytes,  String? messageType,  bool wasChunked,  int? chunkCount)  $default,) {final _that = this;
switch (_that) {
case _CommLogEntry():
return $default(_that.id,_that.timestamp,_that.data,_that.direction,_that.sizeBytes,_that.messageType,_that.wasChunked,_that.chunkCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  DateTime timestamp,  String data,  CommDirection direction,  int sizeBytes,  String? messageType,  bool wasChunked,  int? chunkCount)?  $default,) {final _that = this;
switch (_that) {
case _CommLogEntry() when $default != null:
return $default(_that.id,_that.timestamp,_that.data,_that.direction,_that.sizeBytes,_that.messageType,_that.wasChunked,_that.chunkCount);case _:
  return null;

}
}

}

/// @nodoc


class _CommLogEntry extends CommLogEntry {
  const _CommLogEntry({required this.id, required this.timestamp, required this.data, required this.direction, required this.sizeBytes, this.messageType, this.wasChunked = false, this.chunkCount}): super._();
  

/// Unique identifier for this entry
@override final  int id;
/// Timestamp when the entry was recorded
@override final  DateTime timestamp;
/// The raw data content
@override final  String data;
/// Direction of communication
@override final  CommDirection direction;
/// Size in bytes
@override final  int sizeBytes;
/// Optional parsed message type (from 't' field in JSON)
@override final  String? messageType;
/// Whether the data was chunked across multiple BLE packets
@override@JsonKey() final  bool wasChunked;
/// Number of chunks if chunked
@override final  int? chunkCount;

/// Create a copy of CommLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommLogEntryCopyWith<_CommLogEntry> get copyWith => __$CommLogEntryCopyWithImpl<_CommLogEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommLogEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.data, data) || other.data == data)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.wasChunked, wasChunked) || other.wasChunked == wasChunked)&&(identical(other.chunkCount, chunkCount) || other.chunkCount == chunkCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,timestamp,data,direction,sizeBytes,messageType,wasChunked,chunkCount);

@override
String toString() {
  return 'CommLogEntry(id: $id, timestamp: $timestamp, data: $data, direction: $direction, sizeBytes: $sizeBytes, messageType: $messageType, wasChunked: $wasChunked, chunkCount: $chunkCount)';
}


}

/// @nodoc
abstract mixin class _$CommLogEntryCopyWith<$Res> implements $CommLogEntryCopyWith<$Res> {
  factory _$CommLogEntryCopyWith(_CommLogEntry value, $Res Function(_CommLogEntry) _then) = __$CommLogEntryCopyWithImpl;
@override @useResult
$Res call({
 int id, DateTime timestamp, String data, CommDirection direction, int sizeBytes, String? messageType, bool wasChunked, int? chunkCount
});




}
/// @nodoc
class __$CommLogEntryCopyWithImpl<$Res>
    implements _$CommLogEntryCopyWith<$Res> {
  __$CommLogEntryCopyWithImpl(this._self, this._then);

  final _CommLogEntry _self;
  final $Res Function(_CommLogEntry) _then;

/// Create a copy of CommLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? timestamp = null,Object? data = null,Object? direction = null,Object? sizeBytes = null,Object? messageType = freezed,Object? wasChunked = null,Object? chunkCount = freezed,}) {
  return _then(_CommLogEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as CommDirection,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,messageType: freezed == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String?,wasChunked: null == wasChunked ? _self.wasChunked : wasChunked // ignore: cast_nullable_to_non_nullable
as bool,chunkCount: freezed == chunkCount ? _self.chunkCount : chunkCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$CommLogStats {

/// Total entries in the log
 int get totalEntries;/// Total TX entries
 int get txCount;/// Total RX entries
 int get rxCount;/// Total bytes sent
 int get totalTxBytes;/// Total bytes received
 int get totalRxBytes;/// Oldest entry timestamp
 DateTime? get oldestEntry;/// Newest entry timestamp
 DateTime? get newestEntry;
/// Create a copy of CommLogStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommLogStatsCopyWith<CommLogStats> get copyWith => _$CommLogStatsCopyWithImpl<CommLogStats>(this as CommLogStats, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommLogStats&&(identical(other.totalEntries, totalEntries) || other.totalEntries == totalEntries)&&(identical(other.txCount, txCount) || other.txCount == txCount)&&(identical(other.rxCount, rxCount) || other.rxCount == rxCount)&&(identical(other.totalTxBytes, totalTxBytes) || other.totalTxBytes == totalTxBytes)&&(identical(other.totalRxBytes, totalRxBytes) || other.totalRxBytes == totalRxBytes)&&(identical(other.oldestEntry, oldestEntry) || other.oldestEntry == oldestEntry)&&(identical(other.newestEntry, newestEntry) || other.newestEntry == newestEntry));
}


@override
int get hashCode => Object.hash(runtimeType,totalEntries,txCount,rxCount,totalTxBytes,totalRxBytes,oldestEntry,newestEntry);

@override
String toString() {
  return 'CommLogStats(totalEntries: $totalEntries, txCount: $txCount, rxCount: $rxCount, totalTxBytes: $totalTxBytes, totalRxBytes: $totalRxBytes, oldestEntry: $oldestEntry, newestEntry: $newestEntry)';
}


}

/// @nodoc
abstract mixin class $CommLogStatsCopyWith<$Res>  {
  factory $CommLogStatsCopyWith(CommLogStats value, $Res Function(CommLogStats) _then) = _$CommLogStatsCopyWithImpl;
@useResult
$Res call({
 int totalEntries, int txCount, int rxCount, int totalTxBytes, int totalRxBytes, DateTime? oldestEntry, DateTime? newestEntry
});




}
/// @nodoc
class _$CommLogStatsCopyWithImpl<$Res>
    implements $CommLogStatsCopyWith<$Res> {
  _$CommLogStatsCopyWithImpl(this._self, this._then);

  final CommLogStats _self;
  final $Res Function(CommLogStats) _then;

/// Create a copy of CommLogStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalEntries = null,Object? txCount = null,Object? rxCount = null,Object? totalTxBytes = null,Object? totalRxBytes = null,Object? oldestEntry = freezed,Object? newestEntry = freezed,}) {
  return _then(_self.copyWith(
totalEntries: null == totalEntries ? _self.totalEntries : totalEntries // ignore: cast_nullable_to_non_nullable
as int,txCount: null == txCount ? _self.txCount : txCount // ignore: cast_nullable_to_non_nullable
as int,rxCount: null == rxCount ? _self.rxCount : rxCount // ignore: cast_nullable_to_non_nullable
as int,totalTxBytes: null == totalTxBytes ? _self.totalTxBytes : totalTxBytes // ignore: cast_nullable_to_non_nullable
as int,totalRxBytes: null == totalRxBytes ? _self.totalRxBytes : totalRxBytes // ignore: cast_nullable_to_non_nullable
as int,oldestEntry: freezed == oldestEntry ? _self.oldestEntry : oldestEntry // ignore: cast_nullable_to_non_nullable
as DateTime?,newestEntry: freezed == newestEntry ? _self.newestEntry : newestEntry // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [CommLogStats].
extension CommLogStatsPatterns on CommLogStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommLogStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommLogStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommLogStats value)  $default,){
final _that = this;
switch (_that) {
case _CommLogStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommLogStats value)?  $default,){
final _that = this;
switch (_that) {
case _CommLogStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalEntries,  int txCount,  int rxCount,  int totalTxBytes,  int totalRxBytes,  DateTime? oldestEntry,  DateTime? newestEntry)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommLogStats() when $default != null:
return $default(_that.totalEntries,_that.txCount,_that.rxCount,_that.totalTxBytes,_that.totalRxBytes,_that.oldestEntry,_that.newestEntry);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalEntries,  int txCount,  int rxCount,  int totalTxBytes,  int totalRxBytes,  DateTime? oldestEntry,  DateTime? newestEntry)  $default,) {final _that = this;
switch (_that) {
case _CommLogStats():
return $default(_that.totalEntries,_that.txCount,_that.rxCount,_that.totalTxBytes,_that.totalRxBytes,_that.oldestEntry,_that.newestEntry);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalEntries,  int txCount,  int rxCount,  int totalTxBytes,  int totalRxBytes,  DateTime? oldestEntry,  DateTime? newestEntry)?  $default,) {final _that = this;
switch (_that) {
case _CommLogStats() when $default != null:
return $default(_that.totalEntries,_that.txCount,_that.rxCount,_that.totalTxBytes,_that.totalRxBytes,_that.oldestEntry,_that.newestEntry);case _:
  return null;

}
}

}

/// @nodoc


class _CommLogStats extends CommLogStats {
  const _CommLogStats({this.totalEntries = 0, this.txCount = 0, this.rxCount = 0, this.totalTxBytes = 0, this.totalRxBytes = 0, this.oldestEntry, this.newestEntry}): super._();
  

/// Total entries in the log
@override@JsonKey() final  int totalEntries;
/// Total TX entries
@override@JsonKey() final  int txCount;
/// Total RX entries
@override@JsonKey() final  int rxCount;
/// Total bytes sent
@override@JsonKey() final  int totalTxBytes;
/// Total bytes received
@override@JsonKey() final  int totalRxBytes;
/// Oldest entry timestamp
@override final  DateTime? oldestEntry;
/// Newest entry timestamp
@override final  DateTime? newestEntry;

/// Create a copy of CommLogStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommLogStatsCopyWith<_CommLogStats> get copyWith => __$CommLogStatsCopyWithImpl<_CommLogStats>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommLogStats&&(identical(other.totalEntries, totalEntries) || other.totalEntries == totalEntries)&&(identical(other.txCount, txCount) || other.txCount == txCount)&&(identical(other.rxCount, rxCount) || other.rxCount == rxCount)&&(identical(other.totalTxBytes, totalTxBytes) || other.totalTxBytes == totalTxBytes)&&(identical(other.totalRxBytes, totalRxBytes) || other.totalRxBytes == totalRxBytes)&&(identical(other.oldestEntry, oldestEntry) || other.oldestEntry == oldestEntry)&&(identical(other.newestEntry, newestEntry) || other.newestEntry == newestEntry));
}


@override
int get hashCode => Object.hash(runtimeType,totalEntries,txCount,rxCount,totalTxBytes,totalRxBytes,oldestEntry,newestEntry);

@override
String toString() {
  return 'CommLogStats(totalEntries: $totalEntries, txCount: $txCount, rxCount: $rxCount, totalTxBytes: $totalTxBytes, totalRxBytes: $totalRxBytes, oldestEntry: $oldestEntry, newestEntry: $newestEntry)';
}


}

/// @nodoc
abstract mixin class _$CommLogStatsCopyWith<$Res> implements $CommLogStatsCopyWith<$Res> {
  factory _$CommLogStatsCopyWith(_CommLogStats value, $Res Function(_CommLogStats) _then) = __$CommLogStatsCopyWithImpl;
@override @useResult
$Res call({
 int totalEntries, int txCount, int rxCount, int totalTxBytes, int totalRxBytes, DateTime? oldestEntry, DateTime? newestEntry
});




}
/// @nodoc
class __$CommLogStatsCopyWithImpl<$Res>
    implements _$CommLogStatsCopyWith<$Res> {
  __$CommLogStatsCopyWithImpl(this._self, this._then);

  final _CommLogStats _self;
  final $Res Function(_CommLogStats) _then;

/// Create a copy of CommLogStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalEntries = null,Object? txCount = null,Object? rxCount = null,Object? totalTxBytes = null,Object? totalRxBytes = null,Object? oldestEntry = freezed,Object? newestEntry = freezed,}) {
  return _then(_CommLogStats(
totalEntries: null == totalEntries ? _self.totalEntries : totalEntries // ignore: cast_nullable_to_non_nullable
as int,txCount: null == txCount ? _self.txCount : txCount // ignore: cast_nullable_to_non_nullable
as int,rxCount: null == rxCount ? _self.rxCount : rxCount // ignore: cast_nullable_to_non_nullable
as int,totalTxBytes: null == totalTxBytes ? _self.totalTxBytes : totalTxBytes // ignore: cast_nullable_to_non_nullable
as int,totalRxBytes: null == totalRxBytes ? _self.totalRxBytes : totalRxBytes // ignore: cast_nullable_to_non_nullable
as int,oldestEntry: freezed == oldestEntry ? _self.oldestEntry : oldestEntry // ignore: cast_nullable_to_non_nullable
as DateTime?,newestEntry: freezed == newestEntry ? _self.newestEntry : newestEntry // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
