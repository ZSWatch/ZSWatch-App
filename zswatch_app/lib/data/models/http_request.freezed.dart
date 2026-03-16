// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'http_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HttpRequest {

/// The URL to fetch
 String get url;/// Optional XPath expression to evaluate against XML response
 String? get xpath;/// Whether to disable TLS certificate validation (default: false)
 bool get insecure;/// Request ID from watch (echoed back in response for concurrent request handling)
 String? get id;/// Response body or XPath result (populated after successful fetch)
 String? get response;/// Error message (populated on failure)
 String? get error;/// When the request was received from the watch
 DateTime? get startedAt;/// When the request completed (success or failure)
 DateTime? get completedAt;
/// Create a copy of HttpRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HttpRequestCopyWith<HttpRequest> get copyWith => _$HttpRequestCopyWithImpl<HttpRequest>(this as HttpRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HttpRequest&&(identical(other.url, url) || other.url == url)&&(identical(other.xpath, xpath) || other.xpath == xpath)&&(identical(other.insecure, insecure) || other.insecure == insecure)&&(identical(other.id, id) || other.id == id)&&(identical(other.response, response) || other.response == response)&&(identical(other.error, error) || other.error == error)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}


@override
int get hashCode => Object.hash(runtimeType,url,xpath,insecure,id,response,error,startedAt,completedAt);

@override
String toString() {
  return 'HttpRequest(url: $url, xpath: $xpath, insecure: $insecure, id: $id, response: $response, error: $error, startedAt: $startedAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $HttpRequestCopyWith<$Res>  {
  factory $HttpRequestCopyWith(HttpRequest value, $Res Function(HttpRequest) _then) = _$HttpRequestCopyWithImpl;
@useResult
$Res call({
 String url, String? xpath, bool insecure, String? id, String? response, String? error, DateTime? startedAt, DateTime? completedAt
});




}
/// @nodoc
class _$HttpRequestCopyWithImpl<$Res>
    implements $HttpRequestCopyWith<$Res> {
  _$HttpRequestCopyWithImpl(this._self, this._then);

  final HttpRequest _self;
  final $Res Function(HttpRequest) _then;

/// Create a copy of HttpRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? xpath = freezed,Object? insecure = null,Object? id = freezed,Object? response = freezed,Object? error = freezed,Object? startedAt = freezed,Object? completedAt = freezed,}) {
  return _then(_self.copyWith(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,xpath: freezed == xpath ? _self.xpath : xpath // ignore: cast_nullable_to_non_nullable
as String?,insecure: null == insecure ? _self.insecure : insecure // ignore: cast_nullable_to_non_nullable
as bool,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,response: freezed == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [HttpRequest].
extension HttpRequestPatterns on HttpRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HttpRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HttpRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HttpRequest value)  $default,){
final _that = this;
switch (_that) {
case _HttpRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HttpRequest value)?  $default,){
final _that = this;
switch (_that) {
case _HttpRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String? xpath,  bool insecure,  String? id,  String? response,  String? error,  DateTime? startedAt,  DateTime? completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HttpRequest() when $default != null:
return $default(_that.url,_that.xpath,_that.insecure,_that.id,_that.response,_that.error,_that.startedAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String? xpath,  bool insecure,  String? id,  String? response,  String? error,  DateTime? startedAt,  DateTime? completedAt)  $default,) {final _that = this;
switch (_that) {
case _HttpRequest():
return $default(_that.url,_that.xpath,_that.insecure,_that.id,_that.response,_that.error,_that.startedAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String? xpath,  bool insecure,  String? id,  String? response,  String? error,  DateTime? startedAt,  DateTime? completedAt)?  $default,) {final _that = this;
switch (_that) {
case _HttpRequest() when $default != null:
return $default(_that.url,_that.xpath,_that.insecure,_that.id,_that.response,_that.error,_that.startedAt,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc


class _HttpRequest extends HttpRequest {
  const _HttpRequest({required this.url, this.xpath, this.insecure = false, this.id, this.response, this.error, this.startedAt, this.completedAt}): super._();
  

/// The URL to fetch
@override final  String url;
/// Optional XPath expression to evaluate against XML response
@override final  String? xpath;
/// Whether to disable TLS certificate validation (default: false)
@override@JsonKey() final  bool insecure;
/// Request ID from watch (echoed back in response for concurrent request handling)
@override final  String? id;
/// Response body or XPath result (populated after successful fetch)
@override final  String? response;
/// Error message (populated on failure)
@override final  String? error;
/// When the request was received from the watch
@override final  DateTime? startedAt;
/// When the request completed (success or failure)
@override final  DateTime? completedAt;

/// Create a copy of HttpRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HttpRequestCopyWith<_HttpRequest> get copyWith => __$HttpRequestCopyWithImpl<_HttpRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HttpRequest&&(identical(other.url, url) || other.url == url)&&(identical(other.xpath, xpath) || other.xpath == xpath)&&(identical(other.insecure, insecure) || other.insecure == insecure)&&(identical(other.id, id) || other.id == id)&&(identical(other.response, response) || other.response == response)&&(identical(other.error, error) || other.error == error)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}


@override
int get hashCode => Object.hash(runtimeType,url,xpath,insecure,id,response,error,startedAt,completedAt);

@override
String toString() {
  return 'HttpRequest(url: $url, xpath: $xpath, insecure: $insecure, id: $id, response: $response, error: $error, startedAt: $startedAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$HttpRequestCopyWith<$Res> implements $HttpRequestCopyWith<$Res> {
  factory _$HttpRequestCopyWith(_HttpRequest value, $Res Function(_HttpRequest) _then) = __$HttpRequestCopyWithImpl;
@override @useResult
$Res call({
 String url, String? xpath, bool insecure, String? id, String? response, String? error, DateTime? startedAt, DateTime? completedAt
});




}
/// @nodoc
class __$HttpRequestCopyWithImpl<$Res>
    implements _$HttpRequestCopyWith<$Res> {
  __$HttpRequestCopyWithImpl(this._self, this._then);

  final _HttpRequest _self;
  final $Res Function(_HttpRequest) _then;

/// Create a copy of HttpRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? xpath = freezed,Object? insecure = null,Object? id = freezed,Object? response = freezed,Object? error = freezed,Object? startedAt = freezed,Object? completedAt = freezed,}) {
  return _then(_HttpRequest(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,xpath: freezed == xpath ? _self.xpath : xpath // ignore: cast_nullable_to_non_nullable
as String?,insecure: null == insecure ? _self.insecure : insecure // ignore: cast_nullable_to_non_nullable
as bool,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,response: freezed == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
