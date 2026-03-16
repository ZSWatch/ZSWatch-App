// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_phase.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConnectionPhase {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionPhase);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionPhase()';
}


}

/// @nodoc
class $ConnectionPhaseCopyWith<$Res>  {
$ConnectionPhaseCopyWith(ConnectionPhase _, $Res Function(ConnectionPhase) __);
}


/// Adds pattern-matching-related methods to [ConnectionPhase].
extension ConnectionPhasePatterns on ConnectionPhase {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Disconnected value)?  disconnected,TResult Function( Scanning value)?  scanning,TResult Function( Connecting value)?  connecting,TResult Function( SettingUp value)?  settingUp,TResult Function( Connected value)?  connected,TResult Function( Reconnecting value)?  reconnecting,TResult Function( PhaseError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Disconnected() when disconnected != null:
return disconnected(_that);case Scanning() when scanning != null:
return scanning(_that);case Connecting() when connecting != null:
return connecting(_that);case SettingUp() when settingUp != null:
return settingUp(_that);case Connected() when connected != null:
return connected(_that);case Reconnecting() when reconnecting != null:
return reconnecting(_that);case PhaseError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Disconnected value)  disconnected,required TResult Function( Scanning value)  scanning,required TResult Function( Connecting value)  connecting,required TResult Function( SettingUp value)  settingUp,required TResult Function( Connected value)  connected,required TResult Function( Reconnecting value)  reconnecting,required TResult Function( PhaseError value)  error,}){
final _that = this;
switch (_that) {
case Disconnected():
return disconnected(_that);case Scanning():
return scanning(_that);case Connecting():
return connecting(_that);case SettingUp():
return settingUp(_that);case Connected():
return connected(_that);case Reconnecting():
return reconnecting(_that);case PhaseError():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Disconnected value)?  disconnected,TResult? Function( Scanning value)?  scanning,TResult? Function( Connecting value)?  connecting,TResult? Function( SettingUp value)?  settingUp,TResult? Function( Connected value)?  connected,TResult? Function( Reconnecting value)?  reconnecting,TResult? Function( PhaseError value)?  error,}){
final _that = this;
switch (_that) {
case Disconnected() when disconnected != null:
return disconnected(_that);case Scanning() when scanning != null:
return scanning(_that);case Connecting() when connecting != null:
return connecting(_that);case SettingUp() when settingUp != null:
return settingUp(_that);case Connected() when connected != null:
return connected(_that);case Reconnecting() when reconnecting != null:
return reconnecting(_that);case PhaseError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  disconnected,TResult Function()?  scanning,TResult Function()?  connecting,TResult Function( SetupStep step)?  settingUp,TResult Function()?  connected,TResult Function( int attempt,  bool isBackground)?  reconnecting,TResult Function( ConnectionErrorType type,  String? details)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Disconnected() when disconnected != null:
return disconnected();case Scanning() when scanning != null:
return scanning();case Connecting() when connecting != null:
return connecting();case SettingUp() when settingUp != null:
return settingUp(_that.step);case Connected() when connected != null:
return connected();case Reconnecting() when reconnecting != null:
return reconnecting(_that.attempt,_that.isBackground);case PhaseError() when error != null:
return error(_that.type,_that.details);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  disconnected,required TResult Function()  scanning,required TResult Function()  connecting,required TResult Function( SetupStep step)  settingUp,required TResult Function()  connected,required TResult Function( int attempt,  bool isBackground)  reconnecting,required TResult Function( ConnectionErrorType type,  String? details)  error,}) {final _that = this;
switch (_that) {
case Disconnected():
return disconnected();case Scanning():
return scanning();case Connecting():
return connecting();case SettingUp():
return settingUp(_that.step);case Connected():
return connected();case Reconnecting():
return reconnecting(_that.attempt,_that.isBackground);case PhaseError():
return error(_that.type,_that.details);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  disconnected,TResult? Function()?  scanning,TResult? Function()?  connecting,TResult? Function( SetupStep step)?  settingUp,TResult? Function()?  connected,TResult? Function( int attempt,  bool isBackground)?  reconnecting,TResult? Function( ConnectionErrorType type,  String? details)?  error,}) {final _that = this;
switch (_that) {
case Disconnected() when disconnected != null:
return disconnected();case Scanning() when scanning != null:
return scanning();case Connecting() when connecting != null:
return connecting();case SettingUp() when settingUp != null:
return settingUp(_that.step);case Connected() when connected != null:
return connected();case Reconnecting() when reconnecting != null:
return reconnecting(_that.attempt,_that.isBackground);case PhaseError() when error != null:
return error(_that.type,_that.details);case _:
  return null;

}
}

}

/// @nodoc


class Disconnected extends ConnectionPhase {
  const Disconnected(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Disconnected);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionPhase.disconnected()';
}


}




/// @nodoc


class Scanning extends ConnectionPhase {
  const Scanning(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Scanning);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionPhase.scanning()';
}


}




/// @nodoc


class Connecting extends ConnectionPhase {
  const Connecting(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Connecting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionPhase.connecting()';
}


}




/// @nodoc


class SettingUp extends ConnectionPhase {
  const SettingUp({this.step = SetupStep.bonding}): super._();
  

/// Which sub-step of setup we're in (for UI status text)
@JsonKey() final  SetupStep step;

/// Create a copy of ConnectionPhase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingUpCopyWith<SettingUp> get copyWith => _$SettingUpCopyWithImpl<SettingUp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingUp&&(identical(other.step, step) || other.step == step));
}


@override
int get hashCode => Object.hash(runtimeType,step);

@override
String toString() {
  return 'ConnectionPhase.settingUp(step: $step)';
}


}

/// @nodoc
abstract mixin class $SettingUpCopyWith<$Res> implements $ConnectionPhaseCopyWith<$Res> {
  factory $SettingUpCopyWith(SettingUp value, $Res Function(SettingUp) _then) = _$SettingUpCopyWithImpl;
@useResult
$Res call({
 SetupStep step
});




}
/// @nodoc
class _$SettingUpCopyWithImpl<$Res>
    implements $SettingUpCopyWith<$Res> {
  _$SettingUpCopyWithImpl(this._self, this._then);

  final SettingUp _self;
  final $Res Function(SettingUp) _then;

/// Create a copy of ConnectionPhase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? step = null,}) {
  return _then(SettingUp(
step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as SetupStep,
  ));
}


}

/// @nodoc


class Connected extends ConnectionPhase {
  const Connected(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Connected);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionPhase.connected()';
}


}




/// @nodoc


class Reconnecting extends ConnectionPhase {
  const Reconnecting({required this.attempt, this.isBackground = false}): super._();
  

 final  int attempt;
@JsonKey() final  bool isBackground;

/// Create a copy of ConnectionPhase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReconnectingCopyWith<Reconnecting> get copyWith => _$ReconnectingCopyWithImpl<Reconnecting>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Reconnecting&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.isBackground, isBackground) || other.isBackground == isBackground));
}


@override
int get hashCode => Object.hash(runtimeType,attempt,isBackground);

@override
String toString() {
  return 'ConnectionPhase.reconnecting(attempt: $attempt, isBackground: $isBackground)';
}


}

/// @nodoc
abstract mixin class $ReconnectingCopyWith<$Res> implements $ConnectionPhaseCopyWith<$Res> {
  factory $ReconnectingCopyWith(Reconnecting value, $Res Function(Reconnecting) _then) = _$ReconnectingCopyWithImpl;
@useResult
$Res call({
 int attempt, bool isBackground
});




}
/// @nodoc
class _$ReconnectingCopyWithImpl<$Res>
    implements $ReconnectingCopyWith<$Res> {
  _$ReconnectingCopyWithImpl(this._self, this._then);

  final Reconnecting _self;
  final $Res Function(Reconnecting) _then;

/// Create a copy of ConnectionPhase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? attempt = null,Object? isBackground = null,}) {
  return _then(Reconnecting(
attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int,isBackground: null == isBackground ? _self.isBackground : isBackground // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class PhaseError extends ConnectionPhase {
  const PhaseError({required this.type, this.details}): super._();
  

 final  ConnectionErrorType type;
 final  String? details;

/// Create a copy of ConnectionPhase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhaseErrorCopyWith<PhaseError> get copyWith => _$PhaseErrorCopyWithImpl<PhaseError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhaseError&&(identical(other.type, type) || other.type == type)&&(identical(other.details, details) || other.details == details));
}


@override
int get hashCode => Object.hash(runtimeType,type,details);

@override
String toString() {
  return 'ConnectionPhase.error(type: $type, details: $details)';
}


}

/// @nodoc
abstract mixin class $PhaseErrorCopyWith<$Res> implements $ConnectionPhaseCopyWith<$Res> {
  factory $PhaseErrorCopyWith(PhaseError value, $Res Function(PhaseError) _then) = _$PhaseErrorCopyWithImpl;
@useResult
$Res call({
 ConnectionErrorType type, String? details
});




}
/// @nodoc
class _$PhaseErrorCopyWithImpl<$Res>
    implements $PhaseErrorCopyWith<$Res> {
  _$PhaseErrorCopyWithImpl(this._self, this._then);

  final PhaseError _self;
  final $Res Function(PhaseError) _then;

/// Create a copy of ConnectionPhase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? type = null,Object? details = freezed,}) {
  return _then(PhaseError(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ConnectionErrorType,details: freezed == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
