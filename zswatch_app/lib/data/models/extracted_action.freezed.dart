// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'extracted_action.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ExtractedAction {

 int get id; int get memoId; ExtractedActionType get actionType; String get title; String? get notes; DateTime? get startTime; DateTime? get endTime; DateTime? get dueDate; String? get location; int? get reminderMinutes; int? get durationSeconds; bool get created; bool get dismissed; String? get platformTargetId; DateTime? get createdAt;
/// Create a copy of ExtractedAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExtractedActionCopyWith<ExtractedAction> get copyWith => _$ExtractedActionCopyWithImpl<ExtractedAction>(this as ExtractedAction, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExtractedAction&&(identical(other.id, id) || other.id == id)&&(identical(other.memoId, memoId) || other.memoId == memoId)&&(identical(other.actionType, actionType) || other.actionType == actionType)&&(identical(other.title, title) || other.title == title)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.location, location) || other.location == location)&&(identical(other.reminderMinutes, reminderMinutes) || other.reminderMinutes == reminderMinutes)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.created, created) || other.created == created)&&(identical(other.dismissed, dismissed) || other.dismissed == dismissed)&&(identical(other.platformTargetId, platformTargetId) || other.platformTargetId == platformTargetId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,memoId,actionType,title,notes,startTime,endTime,dueDate,location,reminderMinutes,durationSeconds,created,dismissed,platformTargetId,createdAt);

@override
String toString() {
  return 'ExtractedAction(id: $id, memoId: $memoId, actionType: $actionType, title: $title, notes: $notes, startTime: $startTime, endTime: $endTime, dueDate: $dueDate, location: $location, reminderMinutes: $reminderMinutes, durationSeconds: $durationSeconds, created: $created, dismissed: $dismissed, platformTargetId: $platformTargetId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ExtractedActionCopyWith<$Res>  {
  factory $ExtractedActionCopyWith(ExtractedAction value, $Res Function(ExtractedAction) _then) = _$ExtractedActionCopyWithImpl;
@useResult
$Res call({
 int id, int memoId, ExtractedActionType actionType, String title, String? notes, DateTime? startTime, DateTime? endTime, DateTime? dueDate, String? location, int? reminderMinutes, int? durationSeconds, bool created, bool dismissed, String? platformTargetId, DateTime? createdAt
});




}
/// @nodoc
class _$ExtractedActionCopyWithImpl<$Res>
    implements $ExtractedActionCopyWith<$Res> {
  _$ExtractedActionCopyWithImpl(this._self, this._then);

  final ExtractedAction _self;
  final $Res Function(ExtractedAction) _then;

/// Create a copy of ExtractedAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? memoId = null,Object? actionType = null,Object? title = null,Object? notes = freezed,Object? startTime = freezed,Object? endTime = freezed,Object? dueDate = freezed,Object? location = freezed,Object? reminderMinutes = freezed,Object? durationSeconds = freezed,Object? created = null,Object? dismissed = null,Object? platformTargetId = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,memoId: null == memoId ? _self.memoId : memoId // ignore: cast_nullable_to_non_nullable
as int,actionType: null == actionType ? _self.actionType : actionType // ignore: cast_nullable_to_non_nullable
as ExtractedActionType,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as DateTime?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as DateTime?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,reminderMinutes: freezed == reminderMinutes ? _self.reminderMinutes : reminderMinutes // ignore: cast_nullable_to_non_nullable
as int?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as bool,dismissed: null == dismissed ? _self.dismissed : dismissed // ignore: cast_nullable_to_non_nullable
as bool,platformTargetId: freezed == platformTargetId ? _self.platformTargetId : platformTargetId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExtractedAction].
extension ExtractedActionPatterns on ExtractedAction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExtractedAction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExtractedAction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExtractedAction value)  $default,){
final _that = this;
switch (_that) {
case _ExtractedAction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExtractedAction value)?  $default,){
final _that = this;
switch (_that) {
case _ExtractedAction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int memoId,  ExtractedActionType actionType,  String title,  String? notes,  DateTime? startTime,  DateTime? endTime,  DateTime? dueDate,  String? location,  int? reminderMinutes,  int? durationSeconds,  bool created,  bool dismissed,  String? platformTargetId,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExtractedAction() when $default != null:
return $default(_that.id,_that.memoId,_that.actionType,_that.title,_that.notes,_that.startTime,_that.endTime,_that.dueDate,_that.location,_that.reminderMinutes,_that.durationSeconds,_that.created,_that.dismissed,_that.platformTargetId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int memoId,  ExtractedActionType actionType,  String title,  String? notes,  DateTime? startTime,  DateTime? endTime,  DateTime? dueDate,  String? location,  int? reminderMinutes,  int? durationSeconds,  bool created,  bool dismissed,  String? platformTargetId,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _ExtractedAction():
return $default(_that.id,_that.memoId,_that.actionType,_that.title,_that.notes,_that.startTime,_that.endTime,_that.dueDate,_that.location,_that.reminderMinutes,_that.durationSeconds,_that.created,_that.dismissed,_that.platformTargetId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int memoId,  ExtractedActionType actionType,  String title,  String? notes,  DateTime? startTime,  DateTime? endTime,  DateTime? dueDate,  String? location,  int? reminderMinutes,  int? durationSeconds,  bool created,  bool dismissed,  String? platformTargetId,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ExtractedAction() when $default != null:
return $default(_that.id,_that.memoId,_that.actionType,_that.title,_that.notes,_that.startTime,_that.endTime,_that.dueDate,_that.location,_that.reminderMinutes,_that.durationSeconds,_that.created,_that.dismissed,_that.platformTargetId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _ExtractedAction extends ExtractedAction {
  const _ExtractedAction({required this.id, required this.memoId, required this.actionType, required this.title, this.notes, this.startTime, this.endTime, this.dueDate, this.location, this.reminderMinutes, this.durationSeconds, this.created = false, this.dismissed = false, this.platformTargetId, this.createdAt}): super._();
  

@override final  int id;
@override final  int memoId;
@override final  ExtractedActionType actionType;
@override final  String title;
@override final  String? notes;
@override final  DateTime? startTime;
@override final  DateTime? endTime;
@override final  DateTime? dueDate;
@override final  String? location;
@override final  int? reminderMinutes;
@override final  int? durationSeconds;
@override@JsonKey() final  bool created;
@override@JsonKey() final  bool dismissed;
@override final  String? platformTargetId;
@override final  DateTime? createdAt;

/// Create a copy of ExtractedAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExtractedActionCopyWith<_ExtractedAction> get copyWith => __$ExtractedActionCopyWithImpl<_ExtractedAction>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExtractedAction&&(identical(other.id, id) || other.id == id)&&(identical(other.memoId, memoId) || other.memoId == memoId)&&(identical(other.actionType, actionType) || other.actionType == actionType)&&(identical(other.title, title) || other.title == title)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.location, location) || other.location == location)&&(identical(other.reminderMinutes, reminderMinutes) || other.reminderMinutes == reminderMinutes)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.created, created) || other.created == created)&&(identical(other.dismissed, dismissed) || other.dismissed == dismissed)&&(identical(other.platformTargetId, platformTargetId) || other.platformTargetId == platformTargetId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,memoId,actionType,title,notes,startTime,endTime,dueDate,location,reminderMinutes,durationSeconds,created,dismissed,platformTargetId,createdAt);

@override
String toString() {
  return 'ExtractedAction(id: $id, memoId: $memoId, actionType: $actionType, title: $title, notes: $notes, startTime: $startTime, endTime: $endTime, dueDate: $dueDate, location: $location, reminderMinutes: $reminderMinutes, durationSeconds: $durationSeconds, created: $created, dismissed: $dismissed, platformTargetId: $platformTargetId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ExtractedActionCopyWith<$Res> implements $ExtractedActionCopyWith<$Res> {
  factory _$ExtractedActionCopyWith(_ExtractedAction value, $Res Function(_ExtractedAction) _then) = __$ExtractedActionCopyWithImpl;
@override @useResult
$Res call({
 int id, int memoId, ExtractedActionType actionType, String title, String? notes, DateTime? startTime, DateTime? endTime, DateTime? dueDate, String? location, int? reminderMinutes, int? durationSeconds, bool created, bool dismissed, String? platformTargetId, DateTime? createdAt
});




}
/// @nodoc
class __$ExtractedActionCopyWithImpl<$Res>
    implements _$ExtractedActionCopyWith<$Res> {
  __$ExtractedActionCopyWithImpl(this._self, this._then);

  final _ExtractedAction _self;
  final $Res Function(_ExtractedAction) _then;

/// Create a copy of ExtractedAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? memoId = null,Object? actionType = null,Object? title = null,Object? notes = freezed,Object? startTime = freezed,Object? endTime = freezed,Object? dueDate = freezed,Object? location = freezed,Object? reminderMinutes = freezed,Object? durationSeconds = freezed,Object? created = null,Object? dismissed = null,Object? platformTargetId = freezed,Object? createdAt = freezed,}) {
  return _then(_ExtractedAction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,memoId: null == memoId ? _self.memoId : memoId // ignore: cast_nullable_to_non_nullable
as int,actionType: null == actionType ? _self.actionType : actionType // ignore: cast_nullable_to_non_nullable
as ExtractedActionType,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as DateTime?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as DateTime?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,reminderMinutes: freezed == reminderMinutes ? _self.reminderMinutes : reminderMinutes // ignore: cast_nullable_to_non_nullable
as int?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as bool,dismissed: null == dismissed ? _self.dismissed : dismissed // ignore: cast_nullable_to_non_nullable
as bool,platformTargetId: freezed == platformTargetId ? _self.platformTargetId : platformTargetId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
