// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'filesystem_image.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FilesystemImage {

/// Display name for the image
 String get name;/// Local file path to the image
 String get filePath;/// Target path on the device where the file will be uploaded
 String get targetPath;/// File size in bytes
 int get size;/// Optional source URL (if downloaded from GitHub)
 String? get sourceUrl;/// Version string (if known)
 String? get version;
/// Create a copy of FilesystemImage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FilesystemImageCopyWith<FilesystemImage> get copyWith => _$FilesystemImageCopyWithImpl<FilesystemImage>(this as FilesystemImage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FilesystemImage&&(identical(other.name, name) || other.name == name)&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.targetPath, targetPath) || other.targetPath == targetPath)&&(identical(other.size, size) || other.size == size)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.version, version) || other.version == version));
}


@override
int get hashCode => Object.hash(runtimeType,name,filePath,targetPath,size,sourceUrl,version);

@override
String toString() {
  return 'FilesystemImage(name: $name, filePath: $filePath, targetPath: $targetPath, size: $size, sourceUrl: $sourceUrl, version: $version)';
}


}

/// @nodoc
abstract mixin class $FilesystemImageCopyWith<$Res>  {
  factory $FilesystemImageCopyWith(FilesystemImage value, $Res Function(FilesystemImage) _then) = _$FilesystemImageCopyWithImpl;
@useResult
$Res call({
 String name, String filePath, String targetPath, int size, String? sourceUrl, String? version
});




}
/// @nodoc
class _$FilesystemImageCopyWithImpl<$Res>
    implements $FilesystemImageCopyWith<$Res> {
  _$FilesystemImageCopyWithImpl(this._self, this._then);

  final FilesystemImage _self;
  final $Res Function(FilesystemImage) _then;

/// Create a copy of FilesystemImage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? filePath = null,Object? targetPath = null,Object? size = null,Object? sourceUrl = freezed,Object? version = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,targetPath: null == targetPath ? _self.targetPath : targetPath // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,sourceUrl: freezed == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FilesystemImage].
extension FilesystemImagePatterns on FilesystemImage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FilesystemImage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FilesystemImage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FilesystemImage value)  $default,){
final _that = this;
switch (_that) {
case _FilesystemImage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FilesystemImage value)?  $default,){
final _that = this;
switch (_that) {
case _FilesystemImage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String filePath,  String targetPath,  int size,  String? sourceUrl,  String? version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FilesystemImage() when $default != null:
return $default(_that.name,_that.filePath,_that.targetPath,_that.size,_that.sourceUrl,_that.version);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String filePath,  String targetPath,  int size,  String? sourceUrl,  String? version)  $default,) {final _that = this;
switch (_that) {
case _FilesystemImage():
return $default(_that.name,_that.filePath,_that.targetPath,_that.size,_that.sourceUrl,_that.version);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String filePath,  String targetPath,  int size,  String? sourceUrl,  String? version)?  $default,) {final _that = this;
switch (_that) {
case _FilesystemImage() when $default != null:
return $default(_that.name,_that.filePath,_that.targetPath,_that.size,_that.sourceUrl,_that.version);case _:
  return null;

}
}

}

/// @nodoc


class _FilesystemImage extends FilesystemImage {
  const _FilesystemImage({required this.name, required this.filePath, required this.targetPath, required this.size, this.sourceUrl, this.version}): super._();
  

/// Display name for the image
@override final  String name;
/// Local file path to the image
@override final  String filePath;
/// Target path on the device where the file will be uploaded
@override final  String targetPath;
/// File size in bytes
@override final  int size;
/// Optional source URL (if downloaded from GitHub)
@override final  String? sourceUrl;
/// Version string (if known)
@override final  String? version;

/// Create a copy of FilesystemImage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FilesystemImageCopyWith<_FilesystemImage> get copyWith => __$FilesystemImageCopyWithImpl<_FilesystemImage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FilesystemImage&&(identical(other.name, name) || other.name == name)&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.targetPath, targetPath) || other.targetPath == targetPath)&&(identical(other.size, size) || other.size == size)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.version, version) || other.version == version));
}


@override
int get hashCode => Object.hash(runtimeType,name,filePath,targetPath,size,sourceUrl,version);

@override
String toString() {
  return 'FilesystemImage(name: $name, filePath: $filePath, targetPath: $targetPath, size: $size, sourceUrl: $sourceUrl, version: $version)';
}


}

/// @nodoc
abstract mixin class _$FilesystemImageCopyWith<$Res> implements $FilesystemImageCopyWith<$Res> {
  factory _$FilesystemImageCopyWith(_FilesystemImage value, $Res Function(_FilesystemImage) _then) = __$FilesystemImageCopyWithImpl;
@override @useResult
$Res call({
 String name, String filePath, String targetPath, int size, String? sourceUrl, String? version
});




}
/// @nodoc
class __$FilesystemImageCopyWithImpl<$Res>
    implements _$FilesystemImageCopyWith<$Res> {
  __$FilesystemImageCopyWithImpl(this._self, this._then);

  final _FilesystemImage _self;
  final $Res Function(_FilesystemImage) _then;

/// Create a copy of FilesystemImage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? filePath = null,Object? targetPath = null,Object? size = null,Object? sourceUrl = freezed,Object? version = freezed,}) {
  return _then(_FilesystemImage(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,targetPath: null == targetPath ? _self.targetPath : targetPath // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,sourceUrl: freezed == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$FilesystemUploadState {

/// Current status
 FilesystemUploadStatus get status;/// Progress (0.0 to 1.0)
 double get progress;/// Bytes transferred
 int get bytesTransferred;/// Total bytes to transfer
 int get totalBytes;/// Upload speed in bytes per second
 int get speedBytesPerSecond;/// Speed history for chart (bytes per second samples)
 List<int> get speedHistory;/// When the upload started
 DateTime? get startedAt;/// Error message (if failed)
 String? get errorMessage;/// Current image being uploaded
 String? get imageName;
/// Create a copy of FilesystemUploadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FilesystemUploadStateCopyWith<FilesystemUploadState> get copyWith => _$FilesystemUploadStateCopyWithImpl<FilesystemUploadState>(this as FilesystemUploadState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FilesystemUploadState&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.bytesTransferred, bytesTransferred) || other.bytesTransferred == bytesTransferred)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.speedBytesPerSecond, speedBytesPerSecond) || other.speedBytesPerSecond == speedBytesPerSecond)&&const DeepCollectionEquality().equals(other.speedHistory, speedHistory)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.imageName, imageName) || other.imageName == imageName));
}


@override
int get hashCode => Object.hash(runtimeType,status,progress,bytesTransferred,totalBytes,speedBytesPerSecond,const DeepCollectionEquality().hash(speedHistory),startedAt,errorMessage,imageName);

@override
String toString() {
  return 'FilesystemUploadState(status: $status, progress: $progress, bytesTransferred: $bytesTransferred, totalBytes: $totalBytes, speedBytesPerSecond: $speedBytesPerSecond, speedHistory: $speedHistory, startedAt: $startedAt, errorMessage: $errorMessage, imageName: $imageName)';
}


}

/// @nodoc
abstract mixin class $FilesystemUploadStateCopyWith<$Res>  {
  factory $FilesystemUploadStateCopyWith(FilesystemUploadState value, $Res Function(FilesystemUploadState) _then) = _$FilesystemUploadStateCopyWithImpl;
@useResult
$Res call({
 FilesystemUploadStatus status, double progress, int bytesTransferred, int totalBytes, int speedBytesPerSecond, List<int> speedHistory, DateTime? startedAt, String? errorMessage, String? imageName
});




}
/// @nodoc
class _$FilesystemUploadStateCopyWithImpl<$Res>
    implements $FilesystemUploadStateCopyWith<$Res> {
  _$FilesystemUploadStateCopyWithImpl(this._self, this._then);

  final FilesystemUploadState _self;
  final $Res Function(FilesystemUploadState) _then;

/// Create a copy of FilesystemUploadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? progress = null,Object? bytesTransferred = null,Object? totalBytes = null,Object? speedBytesPerSecond = null,Object? speedHistory = null,Object? startedAt = freezed,Object? errorMessage = freezed,Object? imageName = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FilesystemUploadStatus,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,bytesTransferred: null == bytesTransferred ? _self.bytesTransferred : bytesTransferred // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,speedBytesPerSecond: null == speedBytesPerSecond ? _self.speedBytesPerSecond : speedBytesPerSecond // ignore: cast_nullable_to_non_nullable
as int,speedHistory: null == speedHistory ? _self.speedHistory : speedHistory // ignore: cast_nullable_to_non_nullable
as List<int>,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,imageName: freezed == imageName ? _self.imageName : imageName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FilesystemUploadState].
extension FilesystemUploadStatePatterns on FilesystemUploadState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FilesystemUploadState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FilesystemUploadState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FilesystemUploadState value)  $default,){
final _that = this;
switch (_that) {
case _FilesystemUploadState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FilesystemUploadState value)?  $default,){
final _that = this;
switch (_that) {
case _FilesystemUploadState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( FilesystemUploadStatus status,  double progress,  int bytesTransferred,  int totalBytes,  int speedBytesPerSecond,  List<int> speedHistory,  DateTime? startedAt,  String? errorMessage,  String? imageName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FilesystemUploadState() when $default != null:
return $default(_that.status,_that.progress,_that.bytesTransferred,_that.totalBytes,_that.speedBytesPerSecond,_that.speedHistory,_that.startedAt,_that.errorMessage,_that.imageName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( FilesystemUploadStatus status,  double progress,  int bytesTransferred,  int totalBytes,  int speedBytesPerSecond,  List<int> speedHistory,  DateTime? startedAt,  String? errorMessage,  String? imageName)  $default,) {final _that = this;
switch (_that) {
case _FilesystemUploadState():
return $default(_that.status,_that.progress,_that.bytesTransferred,_that.totalBytes,_that.speedBytesPerSecond,_that.speedHistory,_that.startedAt,_that.errorMessage,_that.imageName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( FilesystemUploadStatus status,  double progress,  int bytesTransferred,  int totalBytes,  int speedBytesPerSecond,  List<int> speedHistory,  DateTime? startedAt,  String? errorMessage,  String? imageName)?  $default,) {final _that = this;
switch (_that) {
case _FilesystemUploadState() when $default != null:
return $default(_that.status,_that.progress,_that.bytesTransferred,_that.totalBytes,_that.speedBytesPerSecond,_that.speedHistory,_that.startedAt,_that.errorMessage,_that.imageName);case _:
  return null;

}
}

}

/// @nodoc


class _FilesystemUploadState extends FilesystemUploadState {
  const _FilesystemUploadState({this.status = FilesystemUploadStatus.idle, this.progress = 0.0, this.bytesTransferred = 0, this.totalBytes = 0, this.speedBytesPerSecond = 0, final  List<int> speedHistory = const [], this.startedAt, this.errorMessage, this.imageName}): _speedHistory = speedHistory,super._();
  

/// Current status
@override@JsonKey() final  FilesystemUploadStatus status;
/// Progress (0.0 to 1.0)
@override@JsonKey() final  double progress;
/// Bytes transferred
@override@JsonKey() final  int bytesTransferred;
/// Total bytes to transfer
@override@JsonKey() final  int totalBytes;
/// Upload speed in bytes per second
@override@JsonKey() final  int speedBytesPerSecond;
/// Speed history for chart (bytes per second samples)
 final  List<int> _speedHistory;
/// Speed history for chart (bytes per second samples)
@override@JsonKey() List<int> get speedHistory {
  if (_speedHistory is EqualUnmodifiableListView) return _speedHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_speedHistory);
}

/// When the upload started
@override final  DateTime? startedAt;
/// Error message (if failed)
@override final  String? errorMessage;
/// Current image being uploaded
@override final  String? imageName;

/// Create a copy of FilesystemUploadState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FilesystemUploadStateCopyWith<_FilesystemUploadState> get copyWith => __$FilesystemUploadStateCopyWithImpl<_FilesystemUploadState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FilesystemUploadState&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.bytesTransferred, bytesTransferred) || other.bytesTransferred == bytesTransferred)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.speedBytesPerSecond, speedBytesPerSecond) || other.speedBytesPerSecond == speedBytesPerSecond)&&const DeepCollectionEquality().equals(other._speedHistory, _speedHistory)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.imageName, imageName) || other.imageName == imageName));
}


@override
int get hashCode => Object.hash(runtimeType,status,progress,bytesTransferred,totalBytes,speedBytesPerSecond,const DeepCollectionEquality().hash(_speedHistory),startedAt,errorMessage,imageName);

@override
String toString() {
  return 'FilesystemUploadState(status: $status, progress: $progress, bytesTransferred: $bytesTransferred, totalBytes: $totalBytes, speedBytesPerSecond: $speedBytesPerSecond, speedHistory: $speedHistory, startedAt: $startedAt, errorMessage: $errorMessage, imageName: $imageName)';
}


}

/// @nodoc
abstract mixin class _$FilesystemUploadStateCopyWith<$Res> implements $FilesystemUploadStateCopyWith<$Res> {
  factory _$FilesystemUploadStateCopyWith(_FilesystemUploadState value, $Res Function(_FilesystemUploadState) _then) = __$FilesystemUploadStateCopyWithImpl;
@override @useResult
$Res call({
 FilesystemUploadStatus status, double progress, int bytesTransferred, int totalBytes, int speedBytesPerSecond, List<int> speedHistory, DateTime? startedAt, String? errorMessage, String? imageName
});




}
/// @nodoc
class __$FilesystemUploadStateCopyWithImpl<$Res>
    implements _$FilesystemUploadStateCopyWith<$Res> {
  __$FilesystemUploadStateCopyWithImpl(this._self, this._then);

  final _FilesystemUploadState _self;
  final $Res Function(_FilesystemUploadState) _then;

/// Create a copy of FilesystemUploadState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? progress = null,Object? bytesTransferred = null,Object? totalBytes = null,Object? speedBytesPerSecond = null,Object? speedHistory = null,Object? startedAt = freezed,Object? errorMessage = freezed,Object? imageName = freezed,}) {
  return _then(_FilesystemUploadState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FilesystemUploadStatus,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,bytesTransferred: null == bytesTransferred ? _self.bytesTransferred : bytesTransferred // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,speedBytesPerSecond: null == speedBytesPerSecond ? _self.speedBytesPerSecond : speedBytesPerSecond // ignore: cast_nullable_to_non_nullable
as int,speedHistory: null == speedHistory ? _self._speedHistory : speedHistory // ignore: cast_nullable_to_non_nullable
as List<int>,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,imageName: freezed == imageName ? _self.imageName : imageName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
