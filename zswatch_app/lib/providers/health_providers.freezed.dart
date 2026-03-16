// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_providers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HeartRateStreamingState {

 bool get isStreaming; int? get currentBpm; List<HeartRateReading> get recentReadings; DateTime? get lastUpdate;
/// Create a copy of HeartRateStreamingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HeartRateStreamingStateCopyWith<HeartRateStreamingState> get copyWith => _$HeartRateStreamingStateCopyWithImpl<HeartRateStreamingState>(this as HeartRateStreamingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HeartRateStreamingState&&(identical(other.isStreaming, isStreaming) || other.isStreaming == isStreaming)&&(identical(other.currentBpm, currentBpm) || other.currentBpm == currentBpm)&&const DeepCollectionEquality().equals(other.recentReadings, recentReadings)&&(identical(other.lastUpdate, lastUpdate) || other.lastUpdate == lastUpdate));
}


@override
int get hashCode => Object.hash(runtimeType,isStreaming,currentBpm,const DeepCollectionEquality().hash(recentReadings),lastUpdate);

@override
String toString() {
  return 'HeartRateStreamingState(isStreaming: $isStreaming, currentBpm: $currentBpm, recentReadings: $recentReadings, lastUpdate: $lastUpdate)';
}


}

/// @nodoc
abstract mixin class $HeartRateStreamingStateCopyWith<$Res>  {
  factory $HeartRateStreamingStateCopyWith(HeartRateStreamingState value, $Res Function(HeartRateStreamingState) _then) = _$HeartRateStreamingStateCopyWithImpl;
@useResult
$Res call({
 bool isStreaming, int? currentBpm, List<HeartRateReading> recentReadings, DateTime? lastUpdate
});




}
/// @nodoc
class _$HeartRateStreamingStateCopyWithImpl<$Res>
    implements $HeartRateStreamingStateCopyWith<$Res> {
  _$HeartRateStreamingStateCopyWithImpl(this._self, this._then);

  final HeartRateStreamingState _self;
  final $Res Function(HeartRateStreamingState) _then;

/// Create a copy of HeartRateStreamingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isStreaming = null,Object? currentBpm = freezed,Object? recentReadings = null,Object? lastUpdate = freezed,}) {
  return _then(_self.copyWith(
isStreaming: null == isStreaming ? _self.isStreaming : isStreaming // ignore: cast_nullable_to_non_nullable
as bool,currentBpm: freezed == currentBpm ? _self.currentBpm : currentBpm // ignore: cast_nullable_to_non_nullable
as int?,recentReadings: null == recentReadings ? _self.recentReadings : recentReadings // ignore: cast_nullable_to_non_nullable
as List<HeartRateReading>,lastUpdate: freezed == lastUpdate ? _self.lastUpdate : lastUpdate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [HeartRateStreamingState].
extension HeartRateStreamingStatePatterns on HeartRateStreamingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HeartRateStreamingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HeartRateStreamingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HeartRateStreamingState value)  $default,){
final _that = this;
switch (_that) {
case _HeartRateStreamingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HeartRateStreamingState value)?  $default,){
final _that = this;
switch (_that) {
case _HeartRateStreamingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isStreaming,  int? currentBpm,  List<HeartRateReading> recentReadings,  DateTime? lastUpdate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HeartRateStreamingState() when $default != null:
return $default(_that.isStreaming,_that.currentBpm,_that.recentReadings,_that.lastUpdate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isStreaming,  int? currentBpm,  List<HeartRateReading> recentReadings,  DateTime? lastUpdate)  $default,) {final _that = this;
switch (_that) {
case _HeartRateStreamingState():
return $default(_that.isStreaming,_that.currentBpm,_that.recentReadings,_that.lastUpdate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isStreaming,  int? currentBpm,  List<HeartRateReading> recentReadings,  DateTime? lastUpdate)?  $default,) {final _that = this;
switch (_that) {
case _HeartRateStreamingState() when $default != null:
return $default(_that.isStreaming,_that.currentBpm,_that.recentReadings,_that.lastUpdate);case _:
  return null;

}
}

}

/// @nodoc


class _HeartRateStreamingState extends HeartRateStreamingState {
  const _HeartRateStreamingState({this.isStreaming = false, this.currentBpm, final  List<HeartRateReading> recentReadings = const <HeartRateReading>[], this.lastUpdate}): _recentReadings = recentReadings,super._();
  

@override@JsonKey() final  bool isStreaming;
@override final  int? currentBpm;
 final  List<HeartRateReading> _recentReadings;
@override@JsonKey() List<HeartRateReading> get recentReadings {
  if (_recentReadings is EqualUnmodifiableListView) return _recentReadings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentReadings);
}

@override final  DateTime? lastUpdate;

/// Create a copy of HeartRateStreamingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HeartRateStreamingStateCopyWith<_HeartRateStreamingState> get copyWith => __$HeartRateStreamingStateCopyWithImpl<_HeartRateStreamingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HeartRateStreamingState&&(identical(other.isStreaming, isStreaming) || other.isStreaming == isStreaming)&&(identical(other.currentBpm, currentBpm) || other.currentBpm == currentBpm)&&const DeepCollectionEquality().equals(other._recentReadings, _recentReadings)&&(identical(other.lastUpdate, lastUpdate) || other.lastUpdate == lastUpdate));
}


@override
int get hashCode => Object.hash(runtimeType,isStreaming,currentBpm,const DeepCollectionEquality().hash(_recentReadings),lastUpdate);

@override
String toString() {
  return 'HeartRateStreamingState(isStreaming: $isStreaming, currentBpm: $currentBpm, recentReadings: $recentReadings, lastUpdate: $lastUpdate)';
}


}

/// @nodoc
abstract mixin class _$HeartRateStreamingStateCopyWith<$Res> implements $HeartRateStreamingStateCopyWith<$Res> {
  factory _$HeartRateStreamingStateCopyWith(_HeartRateStreamingState value, $Res Function(_HeartRateStreamingState) _then) = __$HeartRateStreamingStateCopyWithImpl;
@override @useResult
$Res call({
 bool isStreaming, int? currentBpm, List<HeartRateReading> recentReadings, DateTime? lastUpdate
});




}
/// @nodoc
class __$HeartRateStreamingStateCopyWithImpl<$Res>
    implements _$HeartRateStreamingStateCopyWith<$Res> {
  __$HeartRateStreamingStateCopyWithImpl(this._self, this._then);

  final _HeartRateStreamingState _self;
  final $Res Function(_HeartRateStreamingState) _then;

/// Create a copy of HeartRateStreamingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isStreaming = null,Object? currentBpm = freezed,Object? recentReadings = null,Object? lastUpdate = freezed,}) {
  return _then(_HeartRateStreamingState(
isStreaming: null == isStreaming ? _self.isStreaming : isStreaming // ignore: cast_nullable_to_non_nullable
as bool,currentBpm: freezed == currentBpm ? _self.currentBpm : currentBpm // ignore: cast_nullable_to_non_nullable
as int?,recentReadings: null == recentReadings ? _self._recentReadings : recentReadings // ignore: cast_nullable_to_non_nullable
as List<HeartRateReading>,lastUpdate: freezed == lastUpdate ? _self.lastUpdate : lastUpdate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$ActivityBreakdownState {

 StepsHistoryRange get range; ActivityBreakdown get breakdown; bool get isLoading; String? get error;
/// Create a copy of ActivityBreakdownState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityBreakdownStateCopyWith<ActivityBreakdownState> get copyWith => _$ActivityBreakdownStateCopyWithImpl<ActivityBreakdownState>(this as ActivityBreakdownState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivityBreakdownState&&(identical(other.range, range) || other.range == range)&&(identical(other.breakdown, breakdown) || other.breakdown == breakdown)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,range,breakdown,isLoading,error);

@override
String toString() {
  return 'ActivityBreakdownState(range: $range, breakdown: $breakdown, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class $ActivityBreakdownStateCopyWith<$Res>  {
  factory $ActivityBreakdownStateCopyWith(ActivityBreakdownState value, $Res Function(ActivityBreakdownState) _then) = _$ActivityBreakdownStateCopyWithImpl;
@useResult
$Res call({
 StepsHistoryRange range, ActivityBreakdown breakdown, bool isLoading, String? error
});




}
/// @nodoc
class _$ActivityBreakdownStateCopyWithImpl<$Res>
    implements $ActivityBreakdownStateCopyWith<$Res> {
  _$ActivityBreakdownStateCopyWithImpl(this._self, this._then);

  final ActivityBreakdownState _self;
  final $Res Function(ActivityBreakdownState) _then;

/// Create a copy of ActivityBreakdownState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? range = null,Object? breakdown = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
range: null == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as StepsHistoryRange,breakdown: null == breakdown ? _self.breakdown : breakdown // ignore: cast_nullable_to_non_nullable
as ActivityBreakdown,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivityBreakdownState].
extension ActivityBreakdownStatePatterns on ActivityBreakdownState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivityBreakdownState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivityBreakdownState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivityBreakdownState value)  $default,){
final _that = this;
switch (_that) {
case _ActivityBreakdownState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivityBreakdownState value)?  $default,){
final _that = this;
switch (_that) {
case _ActivityBreakdownState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StepsHistoryRange range,  ActivityBreakdown breakdown,  bool isLoading,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivityBreakdownState() when $default != null:
return $default(_that.range,_that.breakdown,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StepsHistoryRange range,  ActivityBreakdown breakdown,  bool isLoading,  String? error)  $default,) {final _that = this;
switch (_that) {
case _ActivityBreakdownState():
return $default(_that.range,_that.breakdown,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StepsHistoryRange range,  ActivityBreakdown breakdown,  bool isLoading,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _ActivityBreakdownState() when $default != null:
return $default(_that.range,_that.breakdown,_that.isLoading,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _ActivityBreakdownState implements ActivityBreakdownState {
  const _ActivityBreakdownState({this.range = StepsHistoryRange.day, this.breakdown = const ActivityBreakdown(), this.isLoading = false, this.error});
  

@override@JsonKey() final  StepsHistoryRange range;
@override@JsonKey() final  ActivityBreakdown breakdown;
@override@JsonKey() final  bool isLoading;
@override final  String? error;

/// Create a copy of ActivityBreakdownState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivityBreakdownStateCopyWith<_ActivityBreakdownState> get copyWith => __$ActivityBreakdownStateCopyWithImpl<_ActivityBreakdownState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivityBreakdownState&&(identical(other.range, range) || other.range == range)&&(identical(other.breakdown, breakdown) || other.breakdown == breakdown)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,range,breakdown,isLoading,error);

@override
String toString() {
  return 'ActivityBreakdownState(range: $range, breakdown: $breakdown, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ActivityBreakdownStateCopyWith<$Res> implements $ActivityBreakdownStateCopyWith<$Res> {
  factory _$ActivityBreakdownStateCopyWith(_ActivityBreakdownState value, $Res Function(_ActivityBreakdownState) _then) = __$ActivityBreakdownStateCopyWithImpl;
@override @useResult
$Res call({
 StepsHistoryRange range, ActivityBreakdown breakdown, bool isLoading, String? error
});




}
/// @nodoc
class __$ActivityBreakdownStateCopyWithImpl<$Res>
    implements _$ActivityBreakdownStateCopyWith<$Res> {
  __$ActivityBreakdownStateCopyWithImpl(this._self, this._then);

  final _ActivityBreakdownState _self;
  final $Res Function(_ActivityBreakdownState) _then;

/// Create a copy of ActivityBreakdownState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? range = null,Object? breakdown = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_ActivityBreakdownState(
range: null == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as StepsHistoryRange,breakdown: null == breakdown ? _self.breakdown : breakdown // ignore: cast_nullable_to_non_nullable
as ActivityBreakdown,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$HealthSummaryState {

 int get todaySteps; int? get latestHeartRate; List<HealthAggregate> get weeklySteps; bool get isLoading; String? get error;
/// Create a copy of HealthSummaryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthSummaryStateCopyWith<HealthSummaryState> get copyWith => _$HealthSummaryStateCopyWithImpl<HealthSummaryState>(this as HealthSummaryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthSummaryState&&(identical(other.todaySteps, todaySteps) || other.todaySteps == todaySteps)&&(identical(other.latestHeartRate, latestHeartRate) || other.latestHeartRate == latestHeartRate)&&const DeepCollectionEquality().equals(other.weeklySteps, weeklySteps)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,todaySteps,latestHeartRate,const DeepCollectionEquality().hash(weeklySteps),isLoading,error);

@override
String toString() {
  return 'HealthSummaryState(todaySteps: $todaySteps, latestHeartRate: $latestHeartRate, weeklySteps: $weeklySteps, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class $HealthSummaryStateCopyWith<$Res>  {
  factory $HealthSummaryStateCopyWith(HealthSummaryState value, $Res Function(HealthSummaryState) _then) = _$HealthSummaryStateCopyWithImpl;
@useResult
$Res call({
 int todaySteps, int? latestHeartRate, List<HealthAggregate> weeklySteps, bool isLoading, String? error
});




}
/// @nodoc
class _$HealthSummaryStateCopyWithImpl<$Res>
    implements $HealthSummaryStateCopyWith<$Res> {
  _$HealthSummaryStateCopyWithImpl(this._self, this._then);

  final HealthSummaryState _self;
  final $Res Function(HealthSummaryState) _then;

/// Create a copy of HealthSummaryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? todaySteps = null,Object? latestHeartRate = freezed,Object? weeklySteps = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
todaySteps: null == todaySteps ? _self.todaySteps : todaySteps // ignore: cast_nullable_to_non_nullable
as int,latestHeartRate: freezed == latestHeartRate ? _self.latestHeartRate : latestHeartRate // ignore: cast_nullable_to_non_nullable
as int?,weeklySteps: null == weeklySteps ? _self.weeklySteps : weeklySteps // ignore: cast_nullable_to_non_nullable
as List<HealthAggregate>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [HealthSummaryState].
extension HealthSummaryStatePatterns on HealthSummaryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HealthSummaryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HealthSummaryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HealthSummaryState value)  $default,){
final _that = this;
switch (_that) {
case _HealthSummaryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HealthSummaryState value)?  $default,){
final _that = this;
switch (_that) {
case _HealthSummaryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int todaySteps,  int? latestHeartRate,  List<HealthAggregate> weeklySteps,  bool isLoading,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HealthSummaryState() when $default != null:
return $default(_that.todaySteps,_that.latestHeartRate,_that.weeklySteps,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int todaySteps,  int? latestHeartRate,  List<HealthAggregate> weeklySteps,  bool isLoading,  String? error)  $default,) {final _that = this;
switch (_that) {
case _HealthSummaryState():
return $default(_that.todaySteps,_that.latestHeartRate,_that.weeklySteps,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int todaySteps,  int? latestHeartRate,  List<HealthAggregate> weeklySteps,  bool isLoading,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _HealthSummaryState() when $default != null:
return $default(_that.todaySteps,_that.latestHeartRate,_that.weeklySteps,_that.isLoading,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _HealthSummaryState implements HealthSummaryState {
  const _HealthSummaryState({this.todaySteps = 0, this.latestHeartRate, final  List<HealthAggregate> weeklySteps = const <HealthAggregate>[], this.isLoading = false, this.error}): _weeklySteps = weeklySteps;
  

@override@JsonKey() final  int todaySteps;
@override final  int? latestHeartRate;
 final  List<HealthAggregate> _weeklySteps;
@override@JsonKey() List<HealthAggregate> get weeklySteps {
  if (_weeklySteps is EqualUnmodifiableListView) return _weeklySteps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_weeklySteps);
}

@override@JsonKey() final  bool isLoading;
@override final  String? error;

/// Create a copy of HealthSummaryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthSummaryStateCopyWith<_HealthSummaryState> get copyWith => __$HealthSummaryStateCopyWithImpl<_HealthSummaryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthSummaryState&&(identical(other.todaySteps, todaySteps) || other.todaySteps == todaySteps)&&(identical(other.latestHeartRate, latestHeartRate) || other.latestHeartRate == latestHeartRate)&&const DeepCollectionEquality().equals(other._weeklySteps, _weeklySteps)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,todaySteps,latestHeartRate,const DeepCollectionEquality().hash(_weeklySteps),isLoading,error);

@override
String toString() {
  return 'HealthSummaryState(todaySteps: $todaySteps, latestHeartRate: $latestHeartRate, weeklySteps: $weeklySteps, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class _$HealthSummaryStateCopyWith<$Res> implements $HealthSummaryStateCopyWith<$Res> {
  factory _$HealthSummaryStateCopyWith(_HealthSummaryState value, $Res Function(_HealthSummaryState) _then) = __$HealthSummaryStateCopyWithImpl;
@override @useResult
$Res call({
 int todaySteps, int? latestHeartRate, List<HealthAggregate> weeklySteps, bool isLoading, String? error
});




}
/// @nodoc
class __$HealthSummaryStateCopyWithImpl<$Res>
    implements _$HealthSummaryStateCopyWith<$Res> {
  __$HealthSummaryStateCopyWithImpl(this._self, this._then);

  final _HealthSummaryState _self;
  final $Res Function(_HealthSummaryState) _then;

/// Create a copy of HealthSummaryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? todaySteps = null,Object? latestHeartRate = freezed,Object? weeklySteps = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_HealthSummaryState(
todaySteps: null == todaySteps ? _self.todaySteps : todaySteps // ignore: cast_nullable_to_non_nullable
as int,latestHeartRate: freezed == latestHeartRate ? _self.latestHeartRate : latestHeartRate // ignore: cast_nullable_to_non_nullable
as int?,weeklySteps: null == weeklySteps ? _self._weeklySteps : weeklySteps // ignore: cast_nullable_to_non_nullable
as List<HealthAggregate>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$StepsHistoryState {

 StepsHistoryRange get range; List<HealthAggregate> get data; int get totalSteps; bool get isLoading; String? get error;
/// Create a copy of StepsHistoryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StepsHistoryStateCopyWith<StepsHistoryState> get copyWith => _$StepsHistoryStateCopyWithImpl<StepsHistoryState>(this as StepsHistoryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StepsHistoryState&&(identical(other.range, range) || other.range == range)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.totalSteps, totalSteps) || other.totalSteps == totalSteps)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,range,const DeepCollectionEquality().hash(data),totalSteps,isLoading,error);

@override
String toString() {
  return 'StepsHistoryState(range: $range, data: $data, totalSteps: $totalSteps, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class $StepsHistoryStateCopyWith<$Res>  {
  factory $StepsHistoryStateCopyWith(StepsHistoryState value, $Res Function(StepsHistoryState) _then) = _$StepsHistoryStateCopyWithImpl;
@useResult
$Res call({
 StepsHistoryRange range, List<HealthAggregate> data, int totalSteps, bool isLoading, String? error
});




}
/// @nodoc
class _$StepsHistoryStateCopyWithImpl<$Res>
    implements $StepsHistoryStateCopyWith<$Res> {
  _$StepsHistoryStateCopyWithImpl(this._self, this._then);

  final StepsHistoryState _self;
  final $Res Function(StepsHistoryState) _then;

/// Create a copy of StepsHistoryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? range = null,Object? data = null,Object? totalSteps = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
range: null == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as StepsHistoryRange,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<HealthAggregate>,totalSteps: null == totalSteps ? _self.totalSteps : totalSteps // ignore: cast_nullable_to_non_nullable
as int,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StepsHistoryState].
extension StepsHistoryStatePatterns on StepsHistoryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StepsHistoryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StepsHistoryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StepsHistoryState value)  $default,){
final _that = this;
switch (_that) {
case _StepsHistoryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StepsHistoryState value)?  $default,){
final _that = this;
switch (_that) {
case _StepsHistoryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StepsHistoryRange range,  List<HealthAggregate> data,  int totalSteps,  bool isLoading,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StepsHistoryState() when $default != null:
return $default(_that.range,_that.data,_that.totalSteps,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StepsHistoryRange range,  List<HealthAggregate> data,  int totalSteps,  bool isLoading,  String? error)  $default,) {final _that = this;
switch (_that) {
case _StepsHistoryState():
return $default(_that.range,_that.data,_that.totalSteps,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StepsHistoryRange range,  List<HealthAggregate> data,  int totalSteps,  bool isLoading,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _StepsHistoryState() when $default != null:
return $default(_that.range,_that.data,_that.totalSteps,_that.isLoading,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _StepsHistoryState implements StepsHistoryState {
  const _StepsHistoryState({this.range = StepsHistoryRange.day, final  List<HealthAggregate> data = const <HealthAggregate>[], this.totalSteps = 0, this.isLoading = false, this.error}): _data = data;
  

@override@JsonKey() final  StepsHistoryRange range;
 final  List<HealthAggregate> _data;
@override@JsonKey() List<HealthAggregate> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override@JsonKey() final  int totalSteps;
@override@JsonKey() final  bool isLoading;
@override final  String? error;

/// Create a copy of StepsHistoryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StepsHistoryStateCopyWith<_StepsHistoryState> get copyWith => __$StepsHistoryStateCopyWithImpl<_StepsHistoryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StepsHistoryState&&(identical(other.range, range) || other.range == range)&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.totalSteps, totalSteps) || other.totalSteps == totalSteps)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,range,const DeepCollectionEquality().hash(_data),totalSteps,isLoading,error);

@override
String toString() {
  return 'StepsHistoryState(range: $range, data: $data, totalSteps: $totalSteps, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class _$StepsHistoryStateCopyWith<$Res> implements $StepsHistoryStateCopyWith<$Res> {
  factory _$StepsHistoryStateCopyWith(_StepsHistoryState value, $Res Function(_StepsHistoryState) _then) = __$StepsHistoryStateCopyWithImpl;
@override @useResult
$Res call({
 StepsHistoryRange range, List<HealthAggregate> data, int totalSteps, bool isLoading, String? error
});




}
/// @nodoc
class __$StepsHistoryStateCopyWithImpl<$Res>
    implements _$StepsHistoryStateCopyWith<$Res> {
  __$StepsHistoryStateCopyWithImpl(this._self, this._then);

  final _StepsHistoryState _self;
  final $Res Function(_StepsHistoryState) _then;

/// Create a copy of StepsHistoryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? range = null,Object? data = null,Object? totalSteps = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_StepsHistoryState(
range: null == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as StepsHistoryRange,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<HealthAggregate>,totalSteps: null == totalSteps ? _self.totalSteps : totalSteps // ignore: cast_nullable_to_non_nullable
as int,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
