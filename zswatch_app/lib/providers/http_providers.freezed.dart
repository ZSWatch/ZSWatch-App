// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'http_providers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HttpRelayState implements DiagnosticableTreeMixin {

/// Currently pending requests (keyed by request ID)
 Map<String, HttpRequest> get pendingRequests;/// Recently completed requests (for debugging/logging)
 List<HttpRequest> get recentRequests;/// Whether HTTP relay is enabled
 bool get isEnabled;
/// Create a copy of HttpRelayState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HttpRelayStateCopyWith<HttpRelayState> get copyWith => _$HttpRelayStateCopyWithImpl<HttpRelayState>(this as HttpRelayState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'HttpRelayState'))
    ..add(DiagnosticsProperty('pendingRequests', pendingRequests))..add(DiagnosticsProperty('recentRequests', recentRequests))..add(DiagnosticsProperty('isEnabled', isEnabled));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HttpRelayState&&const DeepCollectionEquality().equals(other.pendingRequests, pendingRequests)&&const DeepCollectionEquality().equals(other.recentRequests, recentRequests)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(pendingRequests),const DeepCollectionEquality().hash(recentRequests),isEnabled);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'HttpRelayState(pendingRequests: $pendingRequests, recentRequests: $recentRequests, isEnabled: $isEnabled)';
}


}

/// @nodoc
abstract mixin class $HttpRelayStateCopyWith<$Res>  {
  factory $HttpRelayStateCopyWith(HttpRelayState value, $Res Function(HttpRelayState) _then) = _$HttpRelayStateCopyWithImpl;
@useResult
$Res call({
 Map<String, HttpRequest> pendingRequests, List<HttpRequest> recentRequests, bool isEnabled
});




}
/// @nodoc
class _$HttpRelayStateCopyWithImpl<$Res>
    implements $HttpRelayStateCopyWith<$Res> {
  _$HttpRelayStateCopyWithImpl(this._self, this._then);

  final HttpRelayState _self;
  final $Res Function(HttpRelayState) _then;

/// Create a copy of HttpRelayState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pendingRequests = null,Object? recentRequests = null,Object? isEnabled = null,}) {
  return _then(_self.copyWith(
pendingRequests: null == pendingRequests ? _self.pendingRequests : pendingRequests // ignore: cast_nullable_to_non_nullable
as Map<String, HttpRequest>,recentRequests: null == recentRequests ? _self.recentRequests : recentRequests // ignore: cast_nullable_to_non_nullable
as List<HttpRequest>,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [HttpRelayState].
extension HttpRelayStatePatterns on HttpRelayState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HttpRelayState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HttpRelayState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HttpRelayState value)  $default,){
final _that = this;
switch (_that) {
case _HttpRelayState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HttpRelayState value)?  $default,){
final _that = this;
switch (_that) {
case _HttpRelayState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, HttpRequest> pendingRequests,  List<HttpRequest> recentRequests,  bool isEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HttpRelayState() when $default != null:
return $default(_that.pendingRequests,_that.recentRequests,_that.isEnabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, HttpRequest> pendingRequests,  List<HttpRequest> recentRequests,  bool isEnabled)  $default,) {final _that = this;
switch (_that) {
case _HttpRelayState():
return $default(_that.pendingRequests,_that.recentRequests,_that.isEnabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, HttpRequest> pendingRequests,  List<HttpRequest> recentRequests,  bool isEnabled)?  $default,) {final _that = this;
switch (_that) {
case _HttpRelayState() when $default != null:
return $default(_that.pendingRequests,_that.recentRequests,_that.isEnabled);case _:
  return null;

}
}

}

/// @nodoc


class _HttpRelayState extends HttpRelayState with DiagnosticableTreeMixin {
  const _HttpRelayState({final  Map<String, HttpRequest> pendingRequests = const <String, HttpRequest>{}, final  List<HttpRequest> recentRequests = const <HttpRequest>[], this.isEnabled = true}): _pendingRequests = pendingRequests,_recentRequests = recentRequests,super._();
  

/// Currently pending requests (keyed by request ID)
 final  Map<String, HttpRequest> _pendingRequests;
/// Currently pending requests (keyed by request ID)
@override@JsonKey() Map<String, HttpRequest> get pendingRequests {
  if (_pendingRequests is EqualUnmodifiableMapView) return _pendingRequests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_pendingRequests);
}

/// Recently completed requests (for debugging/logging)
 final  List<HttpRequest> _recentRequests;
/// Recently completed requests (for debugging/logging)
@override@JsonKey() List<HttpRequest> get recentRequests {
  if (_recentRequests is EqualUnmodifiableListView) return _recentRequests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentRequests);
}

/// Whether HTTP relay is enabled
@override@JsonKey() final  bool isEnabled;

/// Create a copy of HttpRelayState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HttpRelayStateCopyWith<_HttpRelayState> get copyWith => __$HttpRelayStateCopyWithImpl<_HttpRelayState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'HttpRelayState'))
    ..add(DiagnosticsProperty('pendingRequests', pendingRequests))..add(DiagnosticsProperty('recentRequests', recentRequests))..add(DiagnosticsProperty('isEnabled', isEnabled));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HttpRelayState&&const DeepCollectionEquality().equals(other._pendingRequests, _pendingRequests)&&const DeepCollectionEquality().equals(other._recentRequests, _recentRequests)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_pendingRequests),const DeepCollectionEquality().hash(_recentRequests),isEnabled);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'HttpRelayState(pendingRequests: $pendingRequests, recentRequests: $recentRequests, isEnabled: $isEnabled)';
}


}

/// @nodoc
abstract mixin class _$HttpRelayStateCopyWith<$Res> implements $HttpRelayStateCopyWith<$Res> {
  factory _$HttpRelayStateCopyWith(_HttpRelayState value, $Res Function(_HttpRelayState) _then) = __$HttpRelayStateCopyWithImpl;
@override @useResult
$Res call({
 Map<String, HttpRequest> pendingRequests, List<HttpRequest> recentRequests, bool isEnabled
});




}
/// @nodoc
class __$HttpRelayStateCopyWithImpl<$Res>
    implements _$HttpRelayStateCopyWith<$Res> {
  __$HttpRelayStateCopyWithImpl(this._self, this._then);

  final _HttpRelayState _self;
  final $Res Function(_HttpRelayState) _then;

/// Create a copy of HttpRelayState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pendingRequests = null,Object? recentRequests = null,Object? isEnabled = null,}) {
  return _then(_HttpRelayState(
pendingRequests: null == pendingRequests ? _self._pendingRequests : pendingRequests // ignore: cast_nullable_to_non_nullable
as Map<String, HttpRequest>,recentRequests: null == recentRequests ? _self._recentRequests : recentRequests // ignore: cast_nullable_to_non_nullable
as List<HttpRequest>,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
