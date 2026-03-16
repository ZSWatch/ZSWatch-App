// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_providers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NotificationForwardingState implements DiagnosticableTreeMixin {

 bool get isEnabled; bool get hasPermission; bool get isServiceRunning; Set<String> get blockedApps; int get forwardedCount; int get dismissedCount;
/// Create a copy of NotificationForwardingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationForwardingStateCopyWith<NotificationForwardingState> get copyWith => _$NotificationForwardingStateCopyWithImpl<NotificationForwardingState>(this as NotificationForwardingState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'NotificationForwardingState'))
    ..add(DiagnosticsProperty('isEnabled', isEnabled))..add(DiagnosticsProperty('hasPermission', hasPermission))..add(DiagnosticsProperty('isServiceRunning', isServiceRunning))..add(DiagnosticsProperty('blockedApps', blockedApps))..add(DiagnosticsProperty('forwardedCount', forwardedCount))..add(DiagnosticsProperty('dismissedCount', dismissedCount));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationForwardingState&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.hasPermission, hasPermission) || other.hasPermission == hasPermission)&&(identical(other.isServiceRunning, isServiceRunning) || other.isServiceRunning == isServiceRunning)&&const DeepCollectionEquality().equals(other.blockedApps, blockedApps)&&(identical(other.forwardedCount, forwardedCount) || other.forwardedCount == forwardedCount)&&(identical(other.dismissedCount, dismissedCount) || other.dismissedCount == dismissedCount));
}


@override
int get hashCode => Object.hash(runtimeType,isEnabled,hasPermission,isServiceRunning,const DeepCollectionEquality().hash(blockedApps),forwardedCount,dismissedCount);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'NotificationForwardingState(isEnabled: $isEnabled, hasPermission: $hasPermission, isServiceRunning: $isServiceRunning, blockedApps: $blockedApps, forwardedCount: $forwardedCount, dismissedCount: $dismissedCount)';
}


}

/// @nodoc
abstract mixin class $NotificationForwardingStateCopyWith<$Res>  {
  factory $NotificationForwardingStateCopyWith(NotificationForwardingState value, $Res Function(NotificationForwardingState) _then) = _$NotificationForwardingStateCopyWithImpl;
@useResult
$Res call({
 bool isEnabled, bool hasPermission, bool isServiceRunning, Set<String> blockedApps, int forwardedCount, int dismissedCount
});




}
/// @nodoc
class _$NotificationForwardingStateCopyWithImpl<$Res>
    implements $NotificationForwardingStateCopyWith<$Res> {
  _$NotificationForwardingStateCopyWithImpl(this._self, this._then);

  final NotificationForwardingState _self;
  final $Res Function(NotificationForwardingState) _then;

/// Create a copy of NotificationForwardingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isEnabled = null,Object? hasPermission = null,Object? isServiceRunning = null,Object? blockedApps = null,Object? forwardedCount = null,Object? dismissedCount = null,}) {
  return _then(_self.copyWith(
isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,hasPermission: null == hasPermission ? _self.hasPermission : hasPermission // ignore: cast_nullable_to_non_nullable
as bool,isServiceRunning: null == isServiceRunning ? _self.isServiceRunning : isServiceRunning // ignore: cast_nullable_to_non_nullable
as bool,blockedApps: null == blockedApps ? _self.blockedApps : blockedApps // ignore: cast_nullable_to_non_nullable
as Set<String>,forwardedCount: null == forwardedCount ? _self.forwardedCount : forwardedCount // ignore: cast_nullable_to_non_nullable
as int,dismissedCount: null == dismissedCount ? _self.dismissedCount : dismissedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationForwardingState].
extension NotificationForwardingStatePatterns on NotificationForwardingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationForwardingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationForwardingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationForwardingState value)  $default,){
final _that = this;
switch (_that) {
case _NotificationForwardingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationForwardingState value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationForwardingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isEnabled,  bool hasPermission,  bool isServiceRunning,  Set<String> blockedApps,  int forwardedCount,  int dismissedCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationForwardingState() when $default != null:
return $default(_that.isEnabled,_that.hasPermission,_that.isServiceRunning,_that.blockedApps,_that.forwardedCount,_that.dismissedCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isEnabled,  bool hasPermission,  bool isServiceRunning,  Set<String> blockedApps,  int forwardedCount,  int dismissedCount)  $default,) {final _that = this;
switch (_that) {
case _NotificationForwardingState():
return $default(_that.isEnabled,_that.hasPermission,_that.isServiceRunning,_that.blockedApps,_that.forwardedCount,_that.dismissedCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isEnabled,  bool hasPermission,  bool isServiceRunning,  Set<String> blockedApps,  int forwardedCount,  int dismissedCount)?  $default,) {final _that = this;
switch (_that) {
case _NotificationForwardingState() when $default != null:
return $default(_that.isEnabled,_that.hasPermission,_that.isServiceRunning,_that.blockedApps,_that.forwardedCount,_that.dismissedCount);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationForwardingState with DiagnosticableTreeMixin implements NotificationForwardingState {
  const _NotificationForwardingState({this.isEnabled = false, this.hasPermission = false, this.isServiceRunning = false, final  Set<String> blockedApps = const <String>{}, this.forwardedCount = 0, this.dismissedCount = 0}): _blockedApps = blockedApps;
  

@override@JsonKey() final  bool isEnabled;
@override@JsonKey() final  bool hasPermission;
@override@JsonKey() final  bool isServiceRunning;
 final  Set<String> _blockedApps;
@override@JsonKey() Set<String> get blockedApps {
  if (_blockedApps is EqualUnmodifiableSetView) return _blockedApps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_blockedApps);
}

@override@JsonKey() final  int forwardedCount;
@override@JsonKey() final  int dismissedCount;

/// Create a copy of NotificationForwardingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationForwardingStateCopyWith<_NotificationForwardingState> get copyWith => __$NotificationForwardingStateCopyWithImpl<_NotificationForwardingState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'NotificationForwardingState'))
    ..add(DiagnosticsProperty('isEnabled', isEnabled))..add(DiagnosticsProperty('hasPermission', hasPermission))..add(DiagnosticsProperty('isServiceRunning', isServiceRunning))..add(DiagnosticsProperty('blockedApps', blockedApps))..add(DiagnosticsProperty('forwardedCount', forwardedCount))..add(DiagnosticsProperty('dismissedCount', dismissedCount));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationForwardingState&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.hasPermission, hasPermission) || other.hasPermission == hasPermission)&&(identical(other.isServiceRunning, isServiceRunning) || other.isServiceRunning == isServiceRunning)&&const DeepCollectionEquality().equals(other._blockedApps, _blockedApps)&&(identical(other.forwardedCount, forwardedCount) || other.forwardedCount == forwardedCount)&&(identical(other.dismissedCount, dismissedCount) || other.dismissedCount == dismissedCount));
}


@override
int get hashCode => Object.hash(runtimeType,isEnabled,hasPermission,isServiceRunning,const DeepCollectionEquality().hash(_blockedApps),forwardedCount,dismissedCount);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'NotificationForwardingState(isEnabled: $isEnabled, hasPermission: $hasPermission, isServiceRunning: $isServiceRunning, blockedApps: $blockedApps, forwardedCount: $forwardedCount, dismissedCount: $dismissedCount)';
}


}

/// @nodoc
abstract mixin class _$NotificationForwardingStateCopyWith<$Res> implements $NotificationForwardingStateCopyWith<$Res> {
  factory _$NotificationForwardingStateCopyWith(_NotificationForwardingState value, $Res Function(_NotificationForwardingState) _then) = __$NotificationForwardingStateCopyWithImpl;
@override @useResult
$Res call({
 bool isEnabled, bool hasPermission, bool isServiceRunning, Set<String> blockedApps, int forwardedCount, int dismissedCount
});




}
/// @nodoc
class __$NotificationForwardingStateCopyWithImpl<$Res>
    implements _$NotificationForwardingStateCopyWith<$Res> {
  __$NotificationForwardingStateCopyWithImpl(this._self, this._then);

  final _NotificationForwardingState _self;
  final $Res Function(_NotificationForwardingState) _then;

/// Create a copy of NotificationForwardingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isEnabled = null,Object? hasPermission = null,Object? isServiceRunning = null,Object? blockedApps = null,Object? forwardedCount = null,Object? dismissedCount = null,}) {
  return _then(_NotificationForwardingState(
isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,hasPermission: null == hasPermission ? _self.hasPermission : hasPermission // ignore: cast_nullable_to_non_nullable
as bool,isServiceRunning: null == isServiceRunning ? _self.isServiceRunning : isServiceRunning // ignore: cast_nullable_to_non_nullable
as bool,blockedApps: null == blockedApps ? _self._blockedApps : blockedApps // ignore: cast_nullable_to_non_nullable
as Set<String>,forwardedCount: null == forwardedCount ? _self.forwardedCount : forwardedCount // ignore: cast_nullable_to_non_nullable
as int,dismissedCount: null == dismissedCount ? _self.dismissedCount : dismissedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$MediaControlState implements DiagnosticableTreeMixin {

 bool get isInitialized; String? get playbackState;// play, pause, stop
 int get positionSeconds; String? get artist; String? get album; String? get track; int? get durationSeconds;
/// Create a copy of MediaControlState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaControlStateCopyWith<MediaControlState> get copyWith => _$MediaControlStateCopyWithImpl<MediaControlState>(this as MediaControlState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'MediaControlState'))
    ..add(DiagnosticsProperty('isInitialized', isInitialized))..add(DiagnosticsProperty('playbackState', playbackState))..add(DiagnosticsProperty('positionSeconds', positionSeconds))..add(DiagnosticsProperty('artist', artist))..add(DiagnosticsProperty('album', album))..add(DiagnosticsProperty('track', track))..add(DiagnosticsProperty('durationSeconds', durationSeconds));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaControlState&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.playbackState, playbackState) || other.playbackState == playbackState)&&(identical(other.positionSeconds, positionSeconds) || other.positionSeconds == positionSeconds)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.album, album) || other.album == album)&&(identical(other.track, track) || other.track == track)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,isInitialized,playbackState,positionSeconds,artist,album,track,durationSeconds);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'MediaControlState(isInitialized: $isInitialized, playbackState: $playbackState, positionSeconds: $positionSeconds, artist: $artist, album: $album, track: $track, durationSeconds: $durationSeconds)';
}


}

/// @nodoc
abstract mixin class $MediaControlStateCopyWith<$Res>  {
  factory $MediaControlStateCopyWith(MediaControlState value, $Res Function(MediaControlState) _then) = _$MediaControlStateCopyWithImpl;
@useResult
$Res call({
 bool isInitialized, String? playbackState, int positionSeconds, String? artist, String? album, String? track, int? durationSeconds
});




}
/// @nodoc
class _$MediaControlStateCopyWithImpl<$Res>
    implements $MediaControlStateCopyWith<$Res> {
  _$MediaControlStateCopyWithImpl(this._self, this._then);

  final MediaControlState _self;
  final $Res Function(MediaControlState) _then;

/// Create a copy of MediaControlState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isInitialized = null,Object? playbackState = freezed,Object? positionSeconds = null,Object? artist = freezed,Object? album = freezed,Object? track = freezed,Object? durationSeconds = freezed,}) {
  return _then(_self.copyWith(
isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,playbackState: freezed == playbackState ? _self.playbackState : playbackState // ignore: cast_nullable_to_non_nullable
as String?,positionSeconds: null == positionSeconds ? _self.positionSeconds : positionSeconds // ignore: cast_nullable_to_non_nullable
as int,artist: freezed == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String?,album: freezed == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as String?,track: freezed == track ? _self.track : track // ignore: cast_nullable_to_non_nullable
as String?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaControlState].
extension MediaControlStatePatterns on MediaControlState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaControlState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaControlState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaControlState value)  $default,){
final _that = this;
switch (_that) {
case _MediaControlState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaControlState value)?  $default,){
final _that = this;
switch (_that) {
case _MediaControlState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isInitialized,  String? playbackState,  int positionSeconds,  String? artist,  String? album,  String? track,  int? durationSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaControlState() when $default != null:
return $default(_that.isInitialized,_that.playbackState,_that.positionSeconds,_that.artist,_that.album,_that.track,_that.durationSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isInitialized,  String? playbackState,  int positionSeconds,  String? artist,  String? album,  String? track,  int? durationSeconds)  $default,) {final _that = this;
switch (_that) {
case _MediaControlState():
return $default(_that.isInitialized,_that.playbackState,_that.positionSeconds,_that.artist,_that.album,_that.track,_that.durationSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isInitialized,  String? playbackState,  int positionSeconds,  String? artist,  String? album,  String? track,  int? durationSeconds)?  $default,) {final _that = this;
switch (_that) {
case _MediaControlState() when $default != null:
return $default(_that.isInitialized,_that.playbackState,_that.positionSeconds,_that.artist,_that.album,_that.track,_that.durationSeconds);case _:
  return null;

}
}

}

/// @nodoc


class _MediaControlState extends MediaControlState with DiagnosticableTreeMixin {
  const _MediaControlState({this.isInitialized = false, this.playbackState, this.positionSeconds = 0, this.artist, this.album, this.track, this.durationSeconds}): super._();
  

@override@JsonKey() final  bool isInitialized;
@override final  String? playbackState;
// play, pause, stop
@override@JsonKey() final  int positionSeconds;
@override final  String? artist;
@override final  String? album;
@override final  String? track;
@override final  int? durationSeconds;

/// Create a copy of MediaControlState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaControlStateCopyWith<_MediaControlState> get copyWith => __$MediaControlStateCopyWithImpl<_MediaControlState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'MediaControlState'))
    ..add(DiagnosticsProperty('isInitialized', isInitialized))..add(DiagnosticsProperty('playbackState', playbackState))..add(DiagnosticsProperty('positionSeconds', positionSeconds))..add(DiagnosticsProperty('artist', artist))..add(DiagnosticsProperty('album', album))..add(DiagnosticsProperty('track', track))..add(DiagnosticsProperty('durationSeconds', durationSeconds));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaControlState&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.playbackState, playbackState) || other.playbackState == playbackState)&&(identical(other.positionSeconds, positionSeconds) || other.positionSeconds == positionSeconds)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.album, album) || other.album == album)&&(identical(other.track, track) || other.track == track)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,isInitialized,playbackState,positionSeconds,artist,album,track,durationSeconds);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'MediaControlState(isInitialized: $isInitialized, playbackState: $playbackState, positionSeconds: $positionSeconds, artist: $artist, album: $album, track: $track, durationSeconds: $durationSeconds)';
}


}

/// @nodoc
abstract mixin class _$MediaControlStateCopyWith<$Res> implements $MediaControlStateCopyWith<$Res> {
  factory _$MediaControlStateCopyWith(_MediaControlState value, $Res Function(_MediaControlState) _then) = __$MediaControlStateCopyWithImpl;
@override @useResult
$Res call({
 bool isInitialized, String? playbackState, int positionSeconds, String? artist, String? album, String? track, int? durationSeconds
});




}
/// @nodoc
class __$MediaControlStateCopyWithImpl<$Res>
    implements _$MediaControlStateCopyWith<$Res> {
  __$MediaControlStateCopyWithImpl(this._self, this._then);

  final _MediaControlState _self;
  final $Res Function(_MediaControlState) _then;

/// Create a copy of MediaControlState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isInitialized = null,Object? playbackState = freezed,Object? positionSeconds = null,Object? artist = freezed,Object? album = freezed,Object? track = freezed,Object? durationSeconds = freezed,}) {
  return _then(_MediaControlState(
isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,playbackState: freezed == playbackState ? _self.playbackState : playbackState // ignore: cast_nullable_to_non_nullable
as String?,positionSeconds: null == positionSeconds ? _self.positionSeconds : positionSeconds // ignore: cast_nullable_to_non_nullable
as int,artist: freezed == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String?,album: freezed == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as String?,track: freezed == track ? _self.track : track // ignore: cast_nullable_to_non_nullable
as String?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
