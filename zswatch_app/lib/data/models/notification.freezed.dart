// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PhoneNotification {

/// Stable positive ID (mapped from Android StatusBarNotification.id)
 int get id;/// Package name of the source app
 String get packageName;/// Human-readable app name
 String get appName;/// Notification title (may be null for some apps)
 String? get title;/// Notification body text
 String? get body;/// Sender name (for messaging apps)
 String? get sender;/// Subject (for email apps)
 String? get subject;/// Phone number (for calls/SMS)
 String? get phoneNumber;/// Notification category
 NotificationCategory get category;/// Whether this notification supports reply action
 bool get canReply;/// Whether this notification is a group summary
 bool get isGroupSummary;/// Timestamp when the notification was posted
 DateTime get postedAt;/// Android notification key for dismissal
 String? get key;
/// Create a copy of PhoneNotification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneNotificationCopyWith<PhoneNotification> get copyWith => _$PhoneNotificationCopyWithImpl<PhoneNotification>(this as PhoneNotification, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.packageName, packageName) || other.packageName == packageName)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.category, category) || other.category == category)&&(identical(other.canReply, canReply) || other.canReply == canReply)&&(identical(other.isGroupSummary, isGroupSummary) || other.isGroupSummary == isGroupSummary)&&(identical(other.postedAt, postedAt) || other.postedAt == postedAt)&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode => Object.hash(runtimeType,id,packageName,appName,title,body,sender,subject,phoneNumber,category,canReply,isGroupSummary,postedAt,key);

@override
String toString() {
  return 'PhoneNotification(id: $id, packageName: $packageName, appName: $appName, title: $title, body: $body, sender: $sender, subject: $subject, phoneNumber: $phoneNumber, category: $category, canReply: $canReply, isGroupSummary: $isGroupSummary, postedAt: $postedAt, key: $key)';
}


}

/// @nodoc
abstract mixin class $PhoneNotificationCopyWith<$Res>  {
  factory $PhoneNotificationCopyWith(PhoneNotification value, $Res Function(PhoneNotification) _then) = _$PhoneNotificationCopyWithImpl;
@useResult
$Res call({
 int id, String packageName, String appName, String? title, String? body, String? sender, String? subject, String? phoneNumber, NotificationCategory category, bool canReply, bool isGroupSummary, DateTime postedAt, String? key
});




}
/// @nodoc
class _$PhoneNotificationCopyWithImpl<$Res>
    implements $PhoneNotificationCopyWith<$Res> {
  _$PhoneNotificationCopyWithImpl(this._self, this._then);

  final PhoneNotification _self;
  final $Res Function(PhoneNotification) _then;

/// Create a copy of PhoneNotification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? packageName = null,Object? appName = null,Object? title = freezed,Object? body = freezed,Object? sender = freezed,Object? subject = freezed,Object? phoneNumber = freezed,Object? category = null,Object? canReply = null,Object? isGroupSummary = null,Object? postedAt = null,Object? key = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,packageName: null == packageName ? _self.packageName : packageName // ignore: cast_nullable_to_non_nullable
as String,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,sender: freezed == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as String?,subject: freezed == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as NotificationCategory,canReply: null == canReply ? _self.canReply : canReply // ignore: cast_nullable_to_non_nullable
as bool,isGroupSummary: null == isGroupSummary ? _self.isGroupSummary : isGroupSummary // ignore: cast_nullable_to_non_nullable
as bool,postedAt: null == postedAt ? _self.postedAt : postedAt // ignore: cast_nullable_to_non_nullable
as DateTime,key: freezed == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PhoneNotification].
extension PhoneNotificationPatterns on PhoneNotification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhoneNotification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhoneNotification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhoneNotification value)  $default,){
final _that = this;
switch (_that) {
case _PhoneNotification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhoneNotification value)?  $default,){
final _that = this;
switch (_that) {
case _PhoneNotification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String packageName,  String appName,  String? title,  String? body,  String? sender,  String? subject,  String? phoneNumber,  NotificationCategory category,  bool canReply,  bool isGroupSummary,  DateTime postedAt,  String? key)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhoneNotification() when $default != null:
return $default(_that.id,_that.packageName,_that.appName,_that.title,_that.body,_that.sender,_that.subject,_that.phoneNumber,_that.category,_that.canReply,_that.isGroupSummary,_that.postedAt,_that.key);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String packageName,  String appName,  String? title,  String? body,  String? sender,  String? subject,  String? phoneNumber,  NotificationCategory category,  bool canReply,  bool isGroupSummary,  DateTime postedAt,  String? key)  $default,) {final _that = this;
switch (_that) {
case _PhoneNotification():
return $default(_that.id,_that.packageName,_that.appName,_that.title,_that.body,_that.sender,_that.subject,_that.phoneNumber,_that.category,_that.canReply,_that.isGroupSummary,_that.postedAt,_that.key);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String packageName,  String appName,  String? title,  String? body,  String? sender,  String? subject,  String? phoneNumber,  NotificationCategory category,  bool canReply,  bool isGroupSummary,  DateTime postedAt,  String? key)?  $default,) {final _that = this;
switch (_that) {
case _PhoneNotification() when $default != null:
return $default(_that.id,_that.packageName,_that.appName,_that.title,_that.body,_that.sender,_that.subject,_that.phoneNumber,_that.category,_that.canReply,_that.isGroupSummary,_that.postedAt,_that.key);case _:
  return null;

}
}

}

/// @nodoc


class _PhoneNotification extends PhoneNotification {
  const _PhoneNotification({required this.id, required this.packageName, required this.appName, this.title, this.body, this.sender, this.subject, this.phoneNumber, this.category = NotificationCategory.other, this.canReply = false, this.isGroupSummary = false, required this.postedAt, this.key}): super._();
  

/// Stable positive ID (mapped from Android StatusBarNotification.id)
@override final  int id;
/// Package name of the source app
@override final  String packageName;
/// Human-readable app name
@override final  String appName;
/// Notification title (may be null for some apps)
@override final  String? title;
/// Notification body text
@override final  String? body;
/// Sender name (for messaging apps)
@override final  String? sender;
/// Subject (for email apps)
@override final  String? subject;
/// Phone number (for calls/SMS)
@override final  String? phoneNumber;
/// Notification category
@override@JsonKey() final  NotificationCategory category;
/// Whether this notification supports reply action
@override@JsonKey() final  bool canReply;
/// Whether this notification is a group summary
@override@JsonKey() final  bool isGroupSummary;
/// Timestamp when the notification was posted
@override final  DateTime postedAt;
/// Android notification key for dismissal
@override final  String? key;

/// Create a copy of PhoneNotification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhoneNotificationCopyWith<_PhoneNotification> get copyWith => __$PhoneNotificationCopyWithImpl<_PhoneNotification>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhoneNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.packageName, packageName) || other.packageName == packageName)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.category, category) || other.category == category)&&(identical(other.canReply, canReply) || other.canReply == canReply)&&(identical(other.isGroupSummary, isGroupSummary) || other.isGroupSummary == isGroupSummary)&&(identical(other.postedAt, postedAt) || other.postedAt == postedAt)&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode => Object.hash(runtimeType,id,packageName,appName,title,body,sender,subject,phoneNumber,category,canReply,isGroupSummary,postedAt,key);

@override
String toString() {
  return 'PhoneNotification(id: $id, packageName: $packageName, appName: $appName, title: $title, body: $body, sender: $sender, subject: $subject, phoneNumber: $phoneNumber, category: $category, canReply: $canReply, isGroupSummary: $isGroupSummary, postedAt: $postedAt, key: $key)';
}


}

/// @nodoc
abstract mixin class _$PhoneNotificationCopyWith<$Res> implements $PhoneNotificationCopyWith<$Res> {
  factory _$PhoneNotificationCopyWith(_PhoneNotification value, $Res Function(_PhoneNotification) _then) = __$PhoneNotificationCopyWithImpl;
@override @useResult
$Res call({
 int id, String packageName, String appName, String? title, String? body, String? sender, String? subject, String? phoneNumber, NotificationCategory category, bool canReply, bool isGroupSummary, DateTime postedAt, String? key
});




}
/// @nodoc
class __$PhoneNotificationCopyWithImpl<$Res>
    implements _$PhoneNotificationCopyWith<$Res> {
  __$PhoneNotificationCopyWithImpl(this._self, this._then);

  final _PhoneNotification _self;
  final $Res Function(_PhoneNotification) _then;

/// Create a copy of PhoneNotification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? packageName = null,Object? appName = null,Object? title = freezed,Object? body = freezed,Object? sender = freezed,Object? subject = freezed,Object? phoneNumber = freezed,Object? category = null,Object? canReply = null,Object? isGroupSummary = null,Object? postedAt = null,Object? key = freezed,}) {
  return _then(_PhoneNotification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,packageName: null == packageName ? _self.packageName : packageName // ignore: cast_nullable_to_non_nullable
as String,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,sender: freezed == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as String?,subject: freezed == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as NotificationCategory,canReply: null == canReply ? _self.canReply : canReply // ignore: cast_nullable_to_non_nullable
as bool,isGroupSummary: null == isGroupSummary ? _self.isGroupSummary : isGroupSummary // ignore: cast_nullable_to_non_nullable
as bool,postedAt: null == postedAt ? _self.postedAt : postedAt // ignore: cast_nullable_to_non_nullable
as DateTime,key: freezed == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$AppNotificationFilter {

/// Package name of the app
 String get packageName;/// Human-readable app name
 String get appName;/// Whether notifications from this app should be forwarded
 bool get enabled;/// App icon (base64 encoded, if available)
 String? get iconBase64;
/// Create a copy of AppNotificationFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppNotificationFilterCopyWith<AppNotificationFilter> get copyWith => _$AppNotificationFilterCopyWithImpl<AppNotificationFilter>(this as AppNotificationFilter, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppNotificationFilter&&(identical(other.packageName, packageName) || other.packageName == packageName)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.iconBase64, iconBase64) || other.iconBase64 == iconBase64));
}


@override
int get hashCode => Object.hash(runtimeType,packageName,appName,enabled,iconBase64);

@override
String toString() {
  return 'AppNotificationFilter(packageName: $packageName, appName: $appName, enabled: $enabled, iconBase64: $iconBase64)';
}


}

/// @nodoc
abstract mixin class $AppNotificationFilterCopyWith<$Res>  {
  factory $AppNotificationFilterCopyWith(AppNotificationFilter value, $Res Function(AppNotificationFilter) _then) = _$AppNotificationFilterCopyWithImpl;
@useResult
$Res call({
 String packageName, String appName, bool enabled, String? iconBase64
});




}
/// @nodoc
class _$AppNotificationFilterCopyWithImpl<$Res>
    implements $AppNotificationFilterCopyWith<$Res> {
  _$AppNotificationFilterCopyWithImpl(this._self, this._then);

  final AppNotificationFilter _self;
  final $Res Function(AppNotificationFilter) _then;

/// Create a copy of AppNotificationFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? packageName = null,Object? appName = null,Object? enabled = null,Object? iconBase64 = freezed,}) {
  return _then(_self.copyWith(
packageName: null == packageName ? _self.packageName : packageName // ignore: cast_nullable_to_non_nullable
as String,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,iconBase64: freezed == iconBase64 ? _self.iconBase64 : iconBase64 // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppNotificationFilter].
extension AppNotificationFilterPatterns on AppNotificationFilter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppNotificationFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppNotificationFilter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppNotificationFilter value)  $default,){
final _that = this;
switch (_that) {
case _AppNotificationFilter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppNotificationFilter value)?  $default,){
final _that = this;
switch (_that) {
case _AppNotificationFilter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String packageName,  String appName,  bool enabled,  String? iconBase64)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppNotificationFilter() when $default != null:
return $default(_that.packageName,_that.appName,_that.enabled,_that.iconBase64);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String packageName,  String appName,  bool enabled,  String? iconBase64)  $default,) {final _that = this;
switch (_that) {
case _AppNotificationFilter():
return $default(_that.packageName,_that.appName,_that.enabled,_that.iconBase64);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String packageName,  String appName,  bool enabled,  String? iconBase64)?  $default,) {final _that = this;
switch (_that) {
case _AppNotificationFilter() when $default != null:
return $default(_that.packageName,_that.appName,_that.enabled,_that.iconBase64);case _:
  return null;

}
}

}

/// @nodoc


class _AppNotificationFilter extends AppNotificationFilter {
  const _AppNotificationFilter({required this.packageName, required this.appName, this.enabled = true, this.iconBase64}): super._();
  

/// Package name of the app
@override final  String packageName;
/// Human-readable app name
@override final  String appName;
/// Whether notifications from this app should be forwarded
@override@JsonKey() final  bool enabled;
/// App icon (base64 encoded, if available)
@override final  String? iconBase64;

/// Create a copy of AppNotificationFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppNotificationFilterCopyWith<_AppNotificationFilter> get copyWith => __$AppNotificationFilterCopyWithImpl<_AppNotificationFilter>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppNotificationFilter&&(identical(other.packageName, packageName) || other.packageName == packageName)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.iconBase64, iconBase64) || other.iconBase64 == iconBase64));
}


@override
int get hashCode => Object.hash(runtimeType,packageName,appName,enabled,iconBase64);

@override
String toString() {
  return 'AppNotificationFilter(packageName: $packageName, appName: $appName, enabled: $enabled, iconBase64: $iconBase64)';
}


}

/// @nodoc
abstract mixin class _$AppNotificationFilterCopyWith<$Res> implements $AppNotificationFilterCopyWith<$Res> {
  factory _$AppNotificationFilterCopyWith(_AppNotificationFilter value, $Res Function(_AppNotificationFilter) _then) = __$AppNotificationFilterCopyWithImpl;
@override @useResult
$Res call({
 String packageName, String appName, bool enabled, String? iconBase64
});




}
/// @nodoc
class __$AppNotificationFilterCopyWithImpl<$Res>
    implements _$AppNotificationFilterCopyWith<$Res> {
  __$AppNotificationFilterCopyWithImpl(this._self, this._then);

  final _AppNotificationFilter _self;
  final $Res Function(_AppNotificationFilter) _then;

/// Create a copy of AppNotificationFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? packageName = null,Object? appName = null,Object? enabled = null,Object? iconBase64 = freezed,}) {
  return _then(_AppNotificationFilter(
packageName: null == packageName ? _self.packageName : packageName // ignore: cast_nullable_to_non_nullable
as String,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,iconBase64: freezed == iconBase64 ? _self.iconBase64 : iconBase64 // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
