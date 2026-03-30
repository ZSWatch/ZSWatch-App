// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_memo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VoiceMemo {

 int get id; String get filename; DateTime get timestampUtc; int get durationMs; int get sizeBytes; String? get localFilePath; String? get transcription; bool get syncedFromWatch; bool get deletedOnWatch; DateTime? get downloadedAt; DateTime? get transcribedAt; String? get convertedFilePath;// AI-enhanced fields
 String? get summary; String? get category; String? get processingStatus; String? get aiModel; DateTime? get aiProcessedAt; bool get taskCreated; bool get calendarEventCreated; String? get actionReviewState; bool get archived;
/// Create a copy of VoiceMemo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceMemoCopyWith<VoiceMemo> get copyWith => _$VoiceMemoCopyWithImpl<VoiceMemo>(this as VoiceMemo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceMemo&&(identical(other.id, id) || other.id == id)&&(identical(other.filename, filename) || other.filename == filename)&&(identical(other.timestampUtc, timestampUtc) || other.timestampUtc == timestampUtc)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.localFilePath, localFilePath) || other.localFilePath == localFilePath)&&(identical(other.transcription, transcription) || other.transcription == transcription)&&(identical(other.syncedFromWatch, syncedFromWatch) || other.syncedFromWatch == syncedFromWatch)&&(identical(other.deletedOnWatch, deletedOnWatch) || other.deletedOnWatch == deletedOnWatch)&&(identical(other.downloadedAt, downloadedAt) || other.downloadedAt == downloadedAt)&&(identical(other.transcribedAt, transcribedAt) || other.transcribedAt == transcribedAt)&&(identical(other.convertedFilePath, convertedFilePath) || other.convertedFilePath == convertedFilePath)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.category, category) || other.category == category)&&(identical(other.processingStatus, processingStatus) || other.processingStatus == processingStatus)&&(identical(other.aiModel, aiModel) || other.aiModel == aiModel)&&(identical(other.aiProcessedAt, aiProcessedAt) || other.aiProcessedAt == aiProcessedAt)&&(identical(other.taskCreated, taskCreated) || other.taskCreated == taskCreated)&&(identical(other.calendarEventCreated, calendarEventCreated) || other.calendarEventCreated == calendarEventCreated)&&(identical(other.actionReviewState, actionReviewState) || other.actionReviewState == actionReviewState)&&(identical(other.archived, archived) || other.archived == archived));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,filename,timestampUtc,durationMs,sizeBytes,localFilePath,transcription,syncedFromWatch,deletedOnWatch,downloadedAt,transcribedAt,convertedFilePath,summary,category,processingStatus,aiModel,aiProcessedAt,taskCreated,calendarEventCreated,actionReviewState,archived]);

@override
String toString() {
  return 'VoiceMemo(id: $id, filename: $filename, timestampUtc: $timestampUtc, durationMs: $durationMs, sizeBytes: $sizeBytes, localFilePath: $localFilePath, transcription: $transcription, syncedFromWatch: $syncedFromWatch, deletedOnWatch: $deletedOnWatch, downloadedAt: $downloadedAt, transcribedAt: $transcribedAt, convertedFilePath: $convertedFilePath, summary: $summary, category: $category, processingStatus: $processingStatus, aiModel: $aiModel, aiProcessedAt: $aiProcessedAt, taskCreated: $taskCreated, calendarEventCreated: $calendarEventCreated, actionReviewState: $actionReviewState, archived: $archived)';
}


}

/// @nodoc
abstract mixin class $VoiceMemoCopyWith<$Res>  {
  factory $VoiceMemoCopyWith(VoiceMemo value, $Res Function(VoiceMemo) _then) = _$VoiceMemoCopyWithImpl;
@useResult
$Res call({
 int id, String filename, DateTime timestampUtc, int durationMs, int sizeBytes, String? localFilePath, String? transcription, bool syncedFromWatch, bool deletedOnWatch, DateTime? downloadedAt, DateTime? transcribedAt, String? convertedFilePath, String? summary, String? category, String? processingStatus, String? aiModel, DateTime? aiProcessedAt, bool taskCreated, bool calendarEventCreated, String? actionReviewState, bool archived
});




}
/// @nodoc
class _$VoiceMemoCopyWithImpl<$Res>
    implements $VoiceMemoCopyWith<$Res> {
  _$VoiceMemoCopyWithImpl(this._self, this._then);

  final VoiceMemo _self;
  final $Res Function(VoiceMemo) _then;

/// Create a copy of VoiceMemo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? filename = null,Object? timestampUtc = null,Object? durationMs = null,Object? sizeBytes = null,Object? localFilePath = freezed,Object? transcription = freezed,Object? syncedFromWatch = null,Object? deletedOnWatch = null,Object? downloadedAt = freezed,Object? transcribedAt = freezed,Object? convertedFilePath = freezed,Object? summary = freezed,Object? category = freezed,Object? processingStatus = freezed,Object? aiModel = freezed,Object? aiProcessedAt = freezed,Object? taskCreated = null,Object? calendarEventCreated = null,Object? actionReviewState = freezed,Object? archived = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,filename: null == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String,timestampUtc: null == timestampUtc ? _self.timestampUtc : timestampUtc // ignore: cast_nullable_to_non_nullable
as DateTime,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,localFilePath: freezed == localFilePath ? _self.localFilePath : localFilePath // ignore: cast_nullable_to_non_nullable
as String?,transcription: freezed == transcription ? _self.transcription : transcription // ignore: cast_nullable_to_non_nullable
as String?,syncedFromWatch: null == syncedFromWatch ? _self.syncedFromWatch : syncedFromWatch // ignore: cast_nullable_to_non_nullable
as bool,deletedOnWatch: null == deletedOnWatch ? _self.deletedOnWatch : deletedOnWatch // ignore: cast_nullable_to_non_nullable
as bool,downloadedAt: freezed == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,transcribedAt: freezed == transcribedAt ? _self.transcribedAt : transcribedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,convertedFilePath: freezed == convertedFilePath ? _self.convertedFilePath : convertedFilePath // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,processingStatus: freezed == processingStatus ? _self.processingStatus : processingStatus // ignore: cast_nullable_to_non_nullable
as String?,aiModel: freezed == aiModel ? _self.aiModel : aiModel // ignore: cast_nullable_to_non_nullable
as String?,aiProcessedAt: freezed == aiProcessedAt ? _self.aiProcessedAt : aiProcessedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,taskCreated: null == taskCreated ? _self.taskCreated : taskCreated // ignore: cast_nullable_to_non_nullable
as bool,calendarEventCreated: null == calendarEventCreated ? _self.calendarEventCreated : calendarEventCreated // ignore: cast_nullable_to_non_nullable
as bool,actionReviewState: freezed == actionReviewState ? _self.actionReviewState : actionReviewState // ignore: cast_nullable_to_non_nullable
as String?,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VoiceMemo].
extension VoiceMemoPatterns on VoiceMemo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoiceMemo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoiceMemo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoiceMemo value)  $default,){
final _that = this;
switch (_that) {
case _VoiceMemo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoiceMemo value)?  $default,){
final _that = this;
switch (_that) {
case _VoiceMemo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String filename,  DateTime timestampUtc,  int durationMs,  int sizeBytes,  String? localFilePath,  String? transcription,  bool syncedFromWatch,  bool deletedOnWatch,  DateTime? downloadedAt,  DateTime? transcribedAt,  String? convertedFilePath,  String? summary,  String? category,  String? processingStatus,  String? aiModel,  DateTime? aiProcessedAt,  bool taskCreated,  bool calendarEventCreated,  String? actionReviewState,  bool archived)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoiceMemo() when $default != null:
return $default(_that.id,_that.filename,_that.timestampUtc,_that.durationMs,_that.sizeBytes,_that.localFilePath,_that.transcription,_that.syncedFromWatch,_that.deletedOnWatch,_that.downloadedAt,_that.transcribedAt,_that.convertedFilePath,_that.summary,_that.category,_that.processingStatus,_that.aiModel,_that.aiProcessedAt,_that.taskCreated,_that.calendarEventCreated,_that.actionReviewState,_that.archived);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String filename,  DateTime timestampUtc,  int durationMs,  int sizeBytes,  String? localFilePath,  String? transcription,  bool syncedFromWatch,  bool deletedOnWatch,  DateTime? downloadedAt,  DateTime? transcribedAt,  String? convertedFilePath,  String? summary,  String? category,  String? processingStatus,  String? aiModel,  DateTime? aiProcessedAt,  bool taskCreated,  bool calendarEventCreated,  String? actionReviewState,  bool archived)  $default,) {final _that = this;
switch (_that) {
case _VoiceMemo():
return $default(_that.id,_that.filename,_that.timestampUtc,_that.durationMs,_that.sizeBytes,_that.localFilePath,_that.transcription,_that.syncedFromWatch,_that.deletedOnWatch,_that.downloadedAt,_that.transcribedAt,_that.convertedFilePath,_that.summary,_that.category,_that.processingStatus,_that.aiModel,_that.aiProcessedAt,_that.taskCreated,_that.calendarEventCreated,_that.actionReviewState,_that.archived);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String filename,  DateTime timestampUtc,  int durationMs,  int sizeBytes,  String? localFilePath,  String? transcription,  bool syncedFromWatch,  bool deletedOnWatch,  DateTime? downloadedAt,  DateTime? transcribedAt,  String? convertedFilePath,  String? summary,  String? category,  String? processingStatus,  String? aiModel,  DateTime? aiProcessedAt,  bool taskCreated,  bool calendarEventCreated,  String? actionReviewState,  bool archived)?  $default,) {final _that = this;
switch (_that) {
case _VoiceMemo() when $default != null:
return $default(_that.id,_that.filename,_that.timestampUtc,_that.durationMs,_that.sizeBytes,_that.localFilePath,_that.transcription,_that.syncedFromWatch,_that.deletedOnWatch,_that.downloadedAt,_that.transcribedAt,_that.convertedFilePath,_that.summary,_that.category,_that.processingStatus,_that.aiModel,_that.aiProcessedAt,_that.taskCreated,_that.calendarEventCreated,_that.actionReviewState,_that.archived);case _:
  return null;

}
}

}

/// @nodoc


class _VoiceMemo extends VoiceMemo {
  const _VoiceMemo({required this.id, required this.filename, required this.timestampUtc, required this.durationMs, required this.sizeBytes, this.localFilePath, this.transcription, this.syncedFromWatch = false, this.deletedOnWatch = false, this.downloadedAt, this.transcribedAt, this.convertedFilePath, this.summary, this.category, this.processingStatus, this.aiModel, this.aiProcessedAt, this.taskCreated = false, this.calendarEventCreated = false, this.actionReviewState, this.archived = false}): super._();
  

@override final  int id;
@override final  String filename;
@override final  DateTime timestampUtc;
@override final  int durationMs;
@override final  int sizeBytes;
@override final  String? localFilePath;
@override final  String? transcription;
@override@JsonKey() final  bool syncedFromWatch;
@override@JsonKey() final  bool deletedOnWatch;
@override final  DateTime? downloadedAt;
@override final  DateTime? transcribedAt;
@override final  String? convertedFilePath;
// AI-enhanced fields
@override final  String? summary;
@override final  String? category;
@override final  String? processingStatus;
@override final  String? aiModel;
@override final  DateTime? aiProcessedAt;
@override@JsonKey() final  bool taskCreated;
@override@JsonKey() final  bool calendarEventCreated;
@override final  String? actionReviewState;
@override@JsonKey() final  bool archived;

/// Create a copy of VoiceMemo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoiceMemoCopyWith<_VoiceMemo> get copyWith => __$VoiceMemoCopyWithImpl<_VoiceMemo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoiceMemo&&(identical(other.id, id) || other.id == id)&&(identical(other.filename, filename) || other.filename == filename)&&(identical(other.timestampUtc, timestampUtc) || other.timestampUtc == timestampUtc)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.localFilePath, localFilePath) || other.localFilePath == localFilePath)&&(identical(other.transcription, transcription) || other.transcription == transcription)&&(identical(other.syncedFromWatch, syncedFromWatch) || other.syncedFromWatch == syncedFromWatch)&&(identical(other.deletedOnWatch, deletedOnWatch) || other.deletedOnWatch == deletedOnWatch)&&(identical(other.downloadedAt, downloadedAt) || other.downloadedAt == downloadedAt)&&(identical(other.transcribedAt, transcribedAt) || other.transcribedAt == transcribedAt)&&(identical(other.convertedFilePath, convertedFilePath) || other.convertedFilePath == convertedFilePath)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.category, category) || other.category == category)&&(identical(other.processingStatus, processingStatus) || other.processingStatus == processingStatus)&&(identical(other.aiModel, aiModel) || other.aiModel == aiModel)&&(identical(other.aiProcessedAt, aiProcessedAt) || other.aiProcessedAt == aiProcessedAt)&&(identical(other.taskCreated, taskCreated) || other.taskCreated == taskCreated)&&(identical(other.calendarEventCreated, calendarEventCreated) || other.calendarEventCreated == calendarEventCreated)&&(identical(other.actionReviewState, actionReviewState) || other.actionReviewState == actionReviewState)&&(identical(other.archived, archived) || other.archived == archived));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,filename,timestampUtc,durationMs,sizeBytes,localFilePath,transcription,syncedFromWatch,deletedOnWatch,downloadedAt,transcribedAt,convertedFilePath,summary,category,processingStatus,aiModel,aiProcessedAt,taskCreated,calendarEventCreated,actionReviewState,archived]);

@override
String toString() {
  return 'VoiceMemo(id: $id, filename: $filename, timestampUtc: $timestampUtc, durationMs: $durationMs, sizeBytes: $sizeBytes, localFilePath: $localFilePath, transcription: $transcription, syncedFromWatch: $syncedFromWatch, deletedOnWatch: $deletedOnWatch, downloadedAt: $downloadedAt, transcribedAt: $transcribedAt, convertedFilePath: $convertedFilePath, summary: $summary, category: $category, processingStatus: $processingStatus, aiModel: $aiModel, aiProcessedAt: $aiProcessedAt, taskCreated: $taskCreated, calendarEventCreated: $calendarEventCreated, actionReviewState: $actionReviewState, archived: $archived)';
}


}

/// @nodoc
abstract mixin class _$VoiceMemoCopyWith<$Res> implements $VoiceMemoCopyWith<$Res> {
  factory _$VoiceMemoCopyWith(_VoiceMemo value, $Res Function(_VoiceMemo) _then) = __$VoiceMemoCopyWithImpl;
@override @useResult
$Res call({
 int id, String filename, DateTime timestampUtc, int durationMs, int sizeBytes, String? localFilePath, String? transcription, bool syncedFromWatch, bool deletedOnWatch, DateTime? downloadedAt, DateTime? transcribedAt, String? convertedFilePath, String? summary, String? category, String? processingStatus, String? aiModel, DateTime? aiProcessedAt, bool taskCreated, bool calendarEventCreated, String? actionReviewState, bool archived
});




}
/// @nodoc
class __$VoiceMemoCopyWithImpl<$Res>
    implements _$VoiceMemoCopyWith<$Res> {
  __$VoiceMemoCopyWithImpl(this._self, this._then);

  final _VoiceMemo _self;
  final $Res Function(_VoiceMemo) _then;

/// Create a copy of VoiceMemo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? filename = null,Object? timestampUtc = null,Object? durationMs = null,Object? sizeBytes = null,Object? localFilePath = freezed,Object? transcription = freezed,Object? syncedFromWatch = null,Object? deletedOnWatch = null,Object? downloadedAt = freezed,Object? transcribedAt = freezed,Object? convertedFilePath = freezed,Object? summary = freezed,Object? category = freezed,Object? processingStatus = freezed,Object? aiModel = freezed,Object? aiProcessedAt = freezed,Object? taskCreated = null,Object? calendarEventCreated = null,Object? actionReviewState = freezed,Object? archived = null,}) {
  return _then(_VoiceMemo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,filename: null == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String,timestampUtc: null == timestampUtc ? _self.timestampUtc : timestampUtc // ignore: cast_nullable_to_non_nullable
as DateTime,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,localFilePath: freezed == localFilePath ? _self.localFilePath : localFilePath // ignore: cast_nullable_to_non_nullable
as String?,transcription: freezed == transcription ? _self.transcription : transcription // ignore: cast_nullable_to_non_nullable
as String?,syncedFromWatch: null == syncedFromWatch ? _self.syncedFromWatch : syncedFromWatch // ignore: cast_nullable_to_non_nullable
as bool,deletedOnWatch: null == deletedOnWatch ? _self.deletedOnWatch : deletedOnWatch // ignore: cast_nullable_to_non_nullable
as bool,downloadedAt: freezed == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,transcribedAt: freezed == transcribedAt ? _self.transcribedAt : transcribedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,convertedFilePath: freezed == convertedFilePath ? _self.convertedFilePath : convertedFilePath // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,processingStatus: freezed == processingStatus ? _self.processingStatus : processingStatus // ignore: cast_nullable_to_non_nullable
as String?,aiModel: freezed == aiModel ? _self.aiModel : aiModel // ignore: cast_nullable_to_non_nullable
as String?,aiProcessedAt: freezed == aiProcessedAt ? _self.aiProcessedAt : aiProcessedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,taskCreated: null == taskCreated ? _self.taskCreated : taskCreated // ignore: cast_nullable_to_non_nullable
as bool,calendarEventCreated: null == calendarEventCreated ? _self.calendarEventCreated : calendarEventCreated // ignore: cast_nullable_to_non_nullable
as bool,actionReviewState: freezed == actionReviewState ? _self.actionReviewState : actionReviewState // ignore: cast_nullable_to_non_nullable
as String?,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
