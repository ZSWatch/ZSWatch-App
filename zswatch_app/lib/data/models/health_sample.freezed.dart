// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_sample.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HealthSample {

/// Database row identifier (null for new samples)
 int? get id;/// Foreign key to source watch
 String get watchId;/// Type of health data
 HealthType get type;/// Measured value (steps count, BPM, minutes, etc.)
 double get value;/// When the measurement was taken on the watch
 DateTime get timestamp;/// Time granularity of this sample
 Granularity get granularity;/// When the data was received by the app
 DateTime get syncedAt;
/// Create a copy of HealthSample
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthSampleCopyWith<HealthSample> get copyWith => _$HealthSampleCopyWithImpl<HealthSample>(this as HealthSample, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthSample&&(identical(other.id, id) || other.id == id)&&(identical(other.watchId, watchId) || other.watchId == watchId)&&(identical(other.type, type) || other.type == type)&&(identical(other.value, value) || other.value == value)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.granularity, granularity) || other.granularity == granularity)&&(identical(other.syncedAt, syncedAt) || other.syncedAt == syncedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,watchId,type,value,timestamp,granularity,syncedAt);

@override
String toString() {
  return 'HealthSample(id: $id, watchId: $watchId, type: $type, value: $value, timestamp: $timestamp, granularity: $granularity, syncedAt: $syncedAt)';
}


}

/// @nodoc
abstract mixin class $HealthSampleCopyWith<$Res>  {
  factory $HealthSampleCopyWith(HealthSample value, $Res Function(HealthSample) _then) = _$HealthSampleCopyWithImpl;
@useResult
$Res call({
 int? id, String watchId, HealthType type, double value, DateTime timestamp, Granularity granularity, DateTime syncedAt
});




}
/// @nodoc
class _$HealthSampleCopyWithImpl<$Res>
    implements $HealthSampleCopyWith<$Res> {
  _$HealthSampleCopyWithImpl(this._self, this._then);

  final HealthSample _self;
  final $Res Function(HealthSample) _then;

/// Create a copy of HealthSample
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? watchId = null,Object? type = null,Object? value = null,Object? timestamp = null,Object? granularity = null,Object? syncedAt = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,watchId: null == watchId ? _self.watchId : watchId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as HealthType,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,granularity: null == granularity ? _self.granularity : granularity // ignore: cast_nullable_to_non_nullable
as Granularity,syncedAt: null == syncedAt ? _self.syncedAt : syncedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [HealthSample].
extension HealthSamplePatterns on HealthSample {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HealthSample value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HealthSample() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HealthSample value)  $default,){
final _that = this;
switch (_that) {
case _HealthSample():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HealthSample value)?  $default,){
final _that = this;
switch (_that) {
case _HealthSample() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String watchId,  HealthType type,  double value,  DateTime timestamp,  Granularity granularity,  DateTime syncedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HealthSample() when $default != null:
return $default(_that.id,_that.watchId,_that.type,_that.value,_that.timestamp,_that.granularity,_that.syncedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String watchId,  HealthType type,  double value,  DateTime timestamp,  Granularity granularity,  DateTime syncedAt)  $default,) {final _that = this;
switch (_that) {
case _HealthSample():
return $default(_that.id,_that.watchId,_that.type,_that.value,_that.timestamp,_that.granularity,_that.syncedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String watchId,  HealthType type,  double value,  DateTime timestamp,  Granularity granularity,  DateTime syncedAt)?  $default,) {final _that = this;
switch (_that) {
case _HealthSample() when $default != null:
return $default(_that.id,_that.watchId,_that.type,_that.value,_that.timestamp,_that.granularity,_that.syncedAt);case _:
  return null;

}
}

}

/// @nodoc


class _HealthSample extends HealthSample {
  const _HealthSample({this.id, required this.watchId, required this.type, required this.value, required this.timestamp, required this.granularity, required this.syncedAt}): super._();
  

/// Database row identifier (null for new samples)
@override final  int? id;
/// Foreign key to source watch
@override final  String watchId;
/// Type of health data
@override final  HealthType type;
/// Measured value (steps count, BPM, minutes, etc.)
@override final  double value;
/// When the measurement was taken on the watch
@override final  DateTime timestamp;
/// Time granularity of this sample
@override final  Granularity granularity;
/// When the data was received by the app
@override final  DateTime syncedAt;

/// Create a copy of HealthSample
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthSampleCopyWith<_HealthSample> get copyWith => __$HealthSampleCopyWithImpl<_HealthSample>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthSample&&(identical(other.id, id) || other.id == id)&&(identical(other.watchId, watchId) || other.watchId == watchId)&&(identical(other.type, type) || other.type == type)&&(identical(other.value, value) || other.value == value)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.granularity, granularity) || other.granularity == granularity)&&(identical(other.syncedAt, syncedAt) || other.syncedAt == syncedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,watchId,type,value,timestamp,granularity,syncedAt);

@override
String toString() {
  return 'HealthSample(id: $id, watchId: $watchId, type: $type, value: $value, timestamp: $timestamp, granularity: $granularity, syncedAt: $syncedAt)';
}


}

/// @nodoc
abstract mixin class _$HealthSampleCopyWith<$Res> implements $HealthSampleCopyWith<$Res> {
  factory _$HealthSampleCopyWith(_HealthSample value, $Res Function(_HealthSample) _then) = __$HealthSampleCopyWithImpl;
@override @useResult
$Res call({
 int? id, String watchId, HealthType type, double value, DateTime timestamp, Granularity granularity, DateTime syncedAt
});




}
/// @nodoc
class __$HealthSampleCopyWithImpl<$Res>
    implements _$HealthSampleCopyWith<$Res> {
  __$HealthSampleCopyWithImpl(this._self, this._then);

  final _HealthSample _self;
  final $Res Function(_HealthSample) _then;

/// Create a copy of HealthSample
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? watchId = null,Object? type = null,Object? value = null,Object? timestamp = null,Object? granularity = null,Object? syncedAt = null,}) {
  return _then(_HealthSample(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,watchId: null == watchId ? _self.watchId : watchId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as HealthType,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,granularity: null == granularity ? _self.granularity : granularity // ignore: cast_nullable_to_non_nullable
as Granularity,syncedAt: null == syncedAt ? _self.syncedAt : syncedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$HealthAggregate {

/// Type of health data
 HealthType get type;/// Start of the period
 DateTime get periodStart;/// End of the period
 DateTime get periodEnd;/// Granularity of the aggregate
 Granularity get granularity;/// Total/sum value (for steps)
 double get total;/// Average value (for heart rate)
 double get average;/// Minimum value in the period
 double get min;/// Maximum value in the period
 double get max;/// Number of samples in the aggregate
 int get sampleCount;
/// Create a copy of HealthAggregate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthAggregateCopyWith<HealthAggregate> get copyWith => _$HealthAggregateCopyWithImpl<HealthAggregate>(this as HealthAggregate, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthAggregate&&(identical(other.type, type) || other.type == type)&&(identical(other.periodStart, periodStart) || other.periodStart == periodStart)&&(identical(other.periodEnd, periodEnd) || other.periodEnd == periodEnd)&&(identical(other.granularity, granularity) || other.granularity == granularity)&&(identical(other.total, total) || other.total == total)&&(identical(other.average, average) || other.average == average)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&(identical(other.sampleCount, sampleCount) || other.sampleCount == sampleCount));
}


@override
int get hashCode => Object.hash(runtimeType,type,periodStart,periodEnd,granularity,total,average,min,max,sampleCount);

@override
String toString() {
  return 'HealthAggregate(type: $type, periodStart: $periodStart, periodEnd: $periodEnd, granularity: $granularity, total: $total, average: $average, min: $min, max: $max, sampleCount: $sampleCount)';
}


}

/// @nodoc
abstract mixin class $HealthAggregateCopyWith<$Res>  {
  factory $HealthAggregateCopyWith(HealthAggregate value, $Res Function(HealthAggregate) _then) = _$HealthAggregateCopyWithImpl;
@useResult
$Res call({
 HealthType type, DateTime periodStart, DateTime periodEnd, Granularity granularity, double total, double average, double min, double max, int sampleCount
});




}
/// @nodoc
class _$HealthAggregateCopyWithImpl<$Res>
    implements $HealthAggregateCopyWith<$Res> {
  _$HealthAggregateCopyWithImpl(this._self, this._then);

  final HealthAggregate _self;
  final $Res Function(HealthAggregate) _then;

/// Create a copy of HealthAggregate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? periodStart = null,Object? periodEnd = null,Object? granularity = null,Object? total = null,Object? average = null,Object? min = null,Object? max = null,Object? sampleCount = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as HealthType,periodStart: null == periodStart ? _self.periodStart : periodStart // ignore: cast_nullable_to_non_nullable
as DateTime,periodEnd: null == periodEnd ? _self.periodEnd : periodEnd // ignore: cast_nullable_to_non_nullable
as DateTime,granularity: null == granularity ? _self.granularity : granularity // ignore: cast_nullable_to_non_nullable
as Granularity,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,average: null == average ? _self.average : average // ignore: cast_nullable_to_non_nullable
as double,min: null == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [HealthAggregate].
extension HealthAggregatePatterns on HealthAggregate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HealthAggregate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HealthAggregate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HealthAggregate value)  $default,){
final _that = this;
switch (_that) {
case _HealthAggregate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HealthAggregate value)?  $default,){
final _that = this;
switch (_that) {
case _HealthAggregate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( HealthType type,  DateTime periodStart,  DateTime periodEnd,  Granularity granularity,  double total,  double average,  double min,  double max,  int sampleCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HealthAggregate() when $default != null:
return $default(_that.type,_that.periodStart,_that.periodEnd,_that.granularity,_that.total,_that.average,_that.min,_that.max,_that.sampleCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( HealthType type,  DateTime periodStart,  DateTime periodEnd,  Granularity granularity,  double total,  double average,  double min,  double max,  int sampleCount)  $default,) {final _that = this;
switch (_that) {
case _HealthAggregate():
return $default(_that.type,_that.periodStart,_that.periodEnd,_that.granularity,_that.total,_that.average,_that.min,_that.max,_that.sampleCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( HealthType type,  DateTime periodStart,  DateTime periodEnd,  Granularity granularity,  double total,  double average,  double min,  double max,  int sampleCount)?  $default,) {final _that = this;
switch (_that) {
case _HealthAggregate() when $default != null:
return $default(_that.type,_that.periodStart,_that.periodEnd,_that.granularity,_that.total,_that.average,_that.min,_that.max,_that.sampleCount);case _:
  return null;

}
}

}

/// @nodoc


class _HealthAggregate extends HealthAggregate {
  const _HealthAggregate({required this.type, required this.periodStart, required this.periodEnd, required this.granularity, required this.total, required this.average, required this.min, required this.max, required this.sampleCount}): super._();
  

/// Type of health data
@override final  HealthType type;
/// Start of the period
@override final  DateTime periodStart;
/// End of the period
@override final  DateTime periodEnd;
/// Granularity of the aggregate
@override final  Granularity granularity;
/// Total/sum value (for steps)
@override final  double total;
/// Average value (for heart rate)
@override final  double average;
/// Minimum value in the period
@override final  double min;
/// Maximum value in the period
@override final  double max;
/// Number of samples in the aggregate
@override final  int sampleCount;

/// Create a copy of HealthAggregate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthAggregateCopyWith<_HealthAggregate> get copyWith => __$HealthAggregateCopyWithImpl<_HealthAggregate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthAggregate&&(identical(other.type, type) || other.type == type)&&(identical(other.periodStart, periodStart) || other.periodStart == periodStart)&&(identical(other.periodEnd, periodEnd) || other.periodEnd == periodEnd)&&(identical(other.granularity, granularity) || other.granularity == granularity)&&(identical(other.total, total) || other.total == total)&&(identical(other.average, average) || other.average == average)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&(identical(other.sampleCount, sampleCount) || other.sampleCount == sampleCount));
}


@override
int get hashCode => Object.hash(runtimeType,type,periodStart,periodEnd,granularity,total,average,min,max,sampleCount);

@override
String toString() {
  return 'HealthAggregate(type: $type, periodStart: $periodStart, periodEnd: $periodEnd, granularity: $granularity, total: $total, average: $average, min: $min, max: $max, sampleCount: $sampleCount)';
}


}

/// @nodoc
abstract mixin class _$HealthAggregateCopyWith<$Res> implements $HealthAggregateCopyWith<$Res> {
  factory _$HealthAggregateCopyWith(_HealthAggregate value, $Res Function(_HealthAggregate) _then) = __$HealthAggregateCopyWithImpl;
@override @useResult
$Res call({
 HealthType type, DateTime periodStart, DateTime periodEnd, Granularity granularity, double total, double average, double min, double max, int sampleCount
});




}
/// @nodoc
class __$HealthAggregateCopyWithImpl<$Res>
    implements _$HealthAggregateCopyWith<$Res> {
  __$HealthAggregateCopyWithImpl(this._self, this._then);

  final _HealthAggregate _self;
  final $Res Function(_HealthAggregate) _then;

/// Create a copy of HealthAggregate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? periodStart = null,Object? periodEnd = null,Object? granularity = null,Object? total = null,Object? average = null,Object? min = null,Object? max = null,Object? sampleCount = null,}) {
  return _then(_HealthAggregate(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as HealthType,periodStart: null == periodStart ? _self.periodStart : periodStart // ignore: cast_nullable_to_non_nullable
as DateTime,periodEnd: null == periodEnd ? _self.periodEnd : periodEnd // ignore: cast_nullable_to_non_nullable
as DateTime,granularity: null == granularity ? _self.granularity : granularity // ignore: cast_nullable_to_non_nullable
as Granularity,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,average: null == average ? _self.average : average // ignore: cast_nullable_to_non_nullable
as double,min: null == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
