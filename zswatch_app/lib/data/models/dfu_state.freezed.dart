// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dfu_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DfuState {

/// Current status of the DFU process
 DfuStatus get status;/// Overall progress (0.0 to 1.0)
 double get progress;/// Bytes transferred so far
 int get bytesTransferred;/// Total bytes to transfer
 int get totalBytes;/// Current upload speed in bytes per second
 int get speedBytesPerSecond;/// Speed history for chart (bytes per second samples)
 List<int> get speedHistory;/// Current image being uploaded (for multi-image updates)
 int get currentImage;/// Total number of images to upload
 int get totalImages;/// Name of the current image being processed
 String? get currentImageName;/// Error message if status is failed
 String? get errorMessage;/// When the DFU started
 DateTime? get startedAt;/// When the DFU completed/failed
 DateTime? get completedAt;
/// Create a copy of DfuState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DfuStateCopyWith<DfuState> get copyWith => _$DfuStateCopyWithImpl<DfuState>(this as DfuState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DfuState&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.bytesTransferred, bytesTransferred) || other.bytesTransferred == bytesTransferred)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.speedBytesPerSecond, speedBytesPerSecond) || other.speedBytesPerSecond == speedBytesPerSecond)&&const DeepCollectionEquality().equals(other.speedHistory, speedHistory)&&(identical(other.currentImage, currentImage) || other.currentImage == currentImage)&&(identical(other.totalImages, totalImages) || other.totalImages == totalImages)&&(identical(other.currentImageName, currentImageName) || other.currentImageName == currentImageName)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}


@override
int get hashCode => Object.hash(runtimeType,status,progress,bytesTransferred,totalBytes,speedBytesPerSecond,const DeepCollectionEquality().hash(speedHistory),currentImage,totalImages,currentImageName,errorMessage,startedAt,completedAt);

@override
String toString() {
  return 'DfuState(status: $status, progress: $progress, bytesTransferred: $bytesTransferred, totalBytes: $totalBytes, speedBytesPerSecond: $speedBytesPerSecond, speedHistory: $speedHistory, currentImage: $currentImage, totalImages: $totalImages, currentImageName: $currentImageName, errorMessage: $errorMessage, startedAt: $startedAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $DfuStateCopyWith<$Res>  {
  factory $DfuStateCopyWith(DfuState value, $Res Function(DfuState) _then) = _$DfuStateCopyWithImpl;
@useResult
$Res call({
 DfuStatus status, double progress, int bytesTransferred, int totalBytes, int speedBytesPerSecond, List<int> speedHistory, int currentImage, int totalImages, String? currentImageName, String? errorMessage, DateTime? startedAt, DateTime? completedAt
});




}
/// @nodoc
class _$DfuStateCopyWithImpl<$Res>
    implements $DfuStateCopyWith<$Res> {
  _$DfuStateCopyWithImpl(this._self, this._then);

  final DfuState _self;
  final $Res Function(DfuState) _then;

/// Create a copy of DfuState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? progress = null,Object? bytesTransferred = null,Object? totalBytes = null,Object? speedBytesPerSecond = null,Object? speedHistory = null,Object? currentImage = null,Object? totalImages = null,Object? currentImageName = freezed,Object? errorMessage = freezed,Object? startedAt = freezed,Object? completedAt = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DfuStatus,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,bytesTransferred: null == bytesTransferred ? _self.bytesTransferred : bytesTransferred // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,speedBytesPerSecond: null == speedBytesPerSecond ? _self.speedBytesPerSecond : speedBytesPerSecond // ignore: cast_nullable_to_non_nullable
as int,speedHistory: null == speedHistory ? _self.speedHistory : speedHistory // ignore: cast_nullable_to_non_nullable
as List<int>,currentImage: null == currentImage ? _self.currentImage : currentImage // ignore: cast_nullable_to_non_nullable
as int,totalImages: null == totalImages ? _self.totalImages : totalImages // ignore: cast_nullable_to_non_nullable
as int,currentImageName: freezed == currentImageName ? _self.currentImageName : currentImageName // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [DfuState].
extension DfuStatePatterns on DfuState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DfuState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DfuState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DfuState value)  $default,){
final _that = this;
switch (_that) {
case _DfuState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DfuState value)?  $default,){
final _that = this;
switch (_that) {
case _DfuState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DfuStatus status,  double progress,  int bytesTransferred,  int totalBytes,  int speedBytesPerSecond,  List<int> speedHistory,  int currentImage,  int totalImages,  String? currentImageName,  String? errorMessage,  DateTime? startedAt,  DateTime? completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DfuState() when $default != null:
return $default(_that.status,_that.progress,_that.bytesTransferred,_that.totalBytes,_that.speedBytesPerSecond,_that.speedHistory,_that.currentImage,_that.totalImages,_that.currentImageName,_that.errorMessage,_that.startedAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DfuStatus status,  double progress,  int bytesTransferred,  int totalBytes,  int speedBytesPerSecond,  List<int> speedHistory,  int currentImage,  int totalImages,  String? currentImageName,  String? errorMessage,  DateTime? startedAt,  DateTime? completedAt)  $default,) {final _that = this;
switch (_that) {
case _DfuState():
return $default(_that.status,_that.progress,_that.bytesTransferred,_that.totalBytes,_that.speedBytesPerSecond,_that.speedHistory,_that.currentImage,_that.totalImages,_that.currentImageName,_that.errorMessage,_that.startedAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DfuStatus status,  double progress,  int bytesTransferred,  int totalBytes,  int speedBytesPerSecond,  List<int> speedHistory,  int currentImage,  int totalImages,  String? currentImageName,  String? errorMessage,  DateTime? startedAt,  DateTime? completedAt)?  $default,) {final _that = this;
switch (_that) {
case _DfuState() when $default != null:
return $default(_that.status,_that.progress,_that.bytesTransferred,_that.totalBytes,_that.speedBytesPerSecond,_that.speedHistory,_that.currentImage,_that.totalImages,_that.currentImageName,_that.errorMessage,_that.startedAt,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc


class _DfuState extends DfuState {
  const _DfuState({this.status = DfuStatus.idle, this.progress = 0.0, this.bytesTransferred = 0, this.totalBytes = 0, this.speedBytesPerSecond = 0, final  List<int> speedHistory = const [], this.currentImage = 0, this.totalImages = 1, this.currentImageName, this.errorMessage, this.startedAt, this.completedAt}): _speedHistory = speedHistory,super._();
  

/// Current status of the DFU process
@override@JsonKey() final  DfuStatus status;
/// Overall progress (0.0 to 1.0)
@override@JsonKey() final  double progress;
/// Bytes transferred so far
@override@JsonKey() final  int bytesTransferred;
/// Total bytes to transfer
@override@JsonKey() final  int totalBytes;
/// Current upload speed in bytes per second
@override@JsonKey() final  int speedBytesPerSecond;
/// Speed history for chart (bytes per second samples)
 final  List<int> _speedHistory;
/// Speed history for chart (bytes per second samples)
@override@JsonKey() List<int> get speedHistory {
  if (_speedHistory is EqualUnmodifiableListView) return _speedHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_speedHistory);
}

/// Current image being uploaded (for multi-image updates)
@override@JsonKey() final  int currentImage;
/// Total number of images to upload
@override@JsonKey() final  int totalImages;
/// Name of the current image being processed
@override final  String? currentImageName;
/// Error message if status is failed
@override final  String? errorMessage;
/// When the DFU started
@override final  DateTime? startedAt;
/// When the DFU completed/failed
@override final  DateTime? completedAt;

/// Create a copy of DfuState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DfuStateCopyWith<_DfuState> get copyWith => __$DfuStateCopyWithImpl<_DfuState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DfuState&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.bytesTransferred, bytesTransferred) || other.bytesTransferred == bytesTransferred)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.speedBytesPerSecond, speedBytesPerSecond) || other.speedBytesPerSecond == speedBytesPerSecond)&&const DeepCollectionEquality().equals(other._speedHistory, _speedHistory)&&(identical(other.currentImage, currentImage) || other.currentImage == currentImage)&&(identical(other.totalImages, totalImages) || other.totalImages == totalImages)&&(identical(other.currentImageName, currentImageName) || other.currentImageName == currentImageName)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}


@override
int get hashCode => Object.hash(runtimeType,status,progress,bytesTransferred,totalBytes,speedBytesPerSecond,const DeepCollectionEquality().hash(_speedHistory),currentImage,totalImages,currentImageName,errorMessage,startedAt,completedAt);

@override
String toString() {
  return 'DfuState(status: $status, progress: $progress, bytesTransferred: $bytesTransferred, totalBytes: $totalBytes, speedBytesPerSecond: $speedBytesPerSecond, speedHistory: $speedHistory, currentImage: $currentImage, totalImages: $totalImages, currentImageName: $currentImageName, errorMessage: $errorMessage, startedAt: $startedAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$DfuStateCopyWith<$Res> implements $DfuStateCopyWith<$Res> {
  factory _$DfuStateCopyWith(_DfuState value, $Res Function(_DfuState) _then) = __$DfuStateCopyWithImpl;
@override @useResult
$Res call({
 DfuStatus status, double progress, int bytesTransferred, int totalBytes, int speedBytesPerSecond, List<int> speedHistory, int currentImage, int totalImages, String? currentImageName, String? errorMessage, DateTime? startedAt, DateTime? completedAt
});




}
/// @nodoc
class __$DfuStateCopyWithImpl<$Res>
    implements _$DfuStateCopyWith<$Res> {
  __$DfuStateCopyWithImpl(this._self, this._then);

  final _DfuState _self;
  final $Res Function(_DfuState) _then;

/// Create a copy of DfuState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? progress = null,Object? bytesTransferred = null,Object? totalBytes = null,Object? speedBytesPerSecond = null,Object? speedHistory = null,Object? currentImage = null,Object? totalImages = null,Object? currentImageName = freezed,Object? errorMessage = freezed,Object? startedAt = freezed,Object? completedAt = freezed,}) {
  return _then(_DfuState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DfuStatus,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,bytesTransferred: null == bytesTransferred ? _self.bytesTransferred : bytesTransferred // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,speedBytesPerSecond: null == speedBytesPerSecond ? _self.speedBytesPerSecond : speedBytesPerSecond // ignore: cast_nullable_to_non_nullable
as int,speedHistory: null == speedHistory ? _self._speedHistory : speedHistory // ignore: cast_nullable_to_non_nullable
as List<int>,currentImage: null == currentImage ? _self.currentImage : currentImage // ignore: cast_nullable_to_non_nullable
as int,totalImages: null == totalImages ? _self.totalImages : totalImages // ignore: cast_nullable_to_non_nullable
as int,currentImageName: freezed == currentImageName ? _self.currentImageName : currentImageName // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
