// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dfu_providers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DfuOperationState implements DiagnosticableTreeMixin {

 GitHubRelease? get selectedRelease; WorkflowRun? get selectedWorkflowRun; WorkflowArtifact? get selectedArtifact; FirmwareImage? get downloadedImage; FilesystemImage? get filesystemImage; List<FirmwareImage> get preparedImages; bool get isDownloading; bool get isUpdating; bool get isFilesystemUploading; bool get isBothUpdating; int get currentStep; int get totalSteps; String? get error;
/// Create a copy of DfuOperationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DfuOperationStateCopyWith<DfuOperationState> get copyWith => _$DfuOperationStateCopyWithImpl<DfuOperationState>(this as DfuOperationState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'DfuOperationState'))
    ..add(DiagnosticsProperty('selectedRelease', selectedRelease))..add(DiagnosticsProperty('selectedWorkflowRun', selectedWorkflowRun))..add(DiagnosticsProperty('selectedArtifact', selectedArtifact))..add(DiagnosticsProperty('downloadedImage', downloadedImage))..add(DiagnosticsProperty('filesystemImage', filesystemImage))..add(DiagnosticsProperty('preparedImages', preparedImages))..add(DiagnosticsProperty('isDownloading', isDownloading))..add(DiagnosticsProperty('isUpdating', isUpdating))..add(DiagnosticsProperty('isFilesystemUploading', isFilesystemUploading))..add(DiagnosticsProperty('isBothUpdating', isBothUpdating))..add(DiagnosticsProperty('currentStep', currentStep))..add(DiagnosticsProperty('totalSteps', totalSteps))..add(DiagnosticsProperty('error', error));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DfuOperationState&&(identical(other.selectedRelease, selectedRelease) || other.selectedRelease == selectedRelease)&&(identical(other.selectedWorkflowRun, selectedWorkflowRun) || other.selectedWorkflowRun == selectedWorkflowRun)&&(identical(other.selectedArtifact, selectedArtifact) || other.selectedArtifact == selectedArtifact)&&(identical(other.downloadedImage, downloadedImage) || other.downloadedImage == downloadedImage)&&(identical(other.filesystemImage, filesystemImage) || other.filesystemImage == filesystemImage)&&const DeepCollectionEquality().equals(other.preparedImages, preparedImages)&&(identical(other.isDownloading, isDownloading) || other.isDownloading == isDownloading)&&(identical(other.isUpdating, isUpdating) || other.isUpdating == isUpdating)&&(identical(other.isFilesystemUploading, isFilesystemUploading) || other.isFilesystemUploading == isFilesystemUploading)&&(identical(other.isBothUpdating, isBothUpdating) || other.isBothUpdating == isBothUpdating)&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep)&&(identical(other.totalSteps, totalSteps) || other.totalSteps == totalSteps)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,selectedRelease,selectedWorkflowRun,selectedArtifact,downloadedImage,filesystemImage,const DeepCollectionEquality().hash(preparedImages),isDownloading,isUpdating,isFilesystemUploading,isBothUpdating,currentStep,totalSteps,error);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'DfuOperationState(selectedRelease: $selectedRelease, selectedWorkflowRun: $selectedWorkflowRun, selectedArtifact: $selectedArtifact, downloadedImage: $downloadedImage, filesystemImage: $filesystemImage, preparedImages: $preparedImages, isDownloading: $isDownloading, isUpdating: $isUpdating, isFilesystemUploading: $isFilesystemUploading, isBothUpdating: $isBothUpdating, currentStep: $currentStep, totalSteps: $totalSteps, error: $error)';
}


}

/// @nodoc
abstract mixin class $DfuOperationStateCopyWith<$Res>  {
  factory $DfuOperationStateCopyWith(DfuOperationState value, $Res Function(DfuOperationState) _then) = _$DfuOperationStateCopyWithImpl;
@useResult
$Res call({
 GitHubRelease? selectedRelease, WorkflowRun? selectedWorkflowRun, WorkflowArtifact? selectedArtifact, FirmwareImage? downloadedImage, FilesystemImage? filesystemImage, List<FirmwareImage> preparedImages, bool isDownloading, bool isUpdating, bool isFilesystemUploading, bool isBothUpdating, int currentStep, int totalSteps, String? error
});


$GitHubReleaseCopyWith<$Res>? get selectedRelease;$FirmwareImageCopyWith<$Res>? get downloadedImage;$FilesystemImageCopyWith<$Res>? get filesystemImage;

}
/// @nodoc
class _$DfuOperationStateCopyWithImpl<$Res>
    implements $DfuOperationStateCopyWith<$Res> {
  _$DfuOperationStateCopyWithImpl(this._self, this._then);

  final DfuOperationState _self;
  final $Res Function(DfuOperationState) _then;

/// Create a copy of DfuOperationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedRelease = freezed,Object? selectedWorkflowRun = freezed,Object? selectedArtifact = freezed,Object? downloadedImage = freezed,Object? filesystemImage = freezed,Object? preparedImages = null,Object? isDownloading = null,Object? isUpdating = null,Object? isFilesystemUploading = null,Object? isBothUpdating = null,Object? currentStep = null,Object? totalSteps = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
selectedRelease: freezed == selectedRelease ? _self.selectedRelease : selectedRelease // ignore: cast_nullable_to_non_nullable
as GitHubRelease?,selectedWorkflowRun: freezed == selectedWorkflowRun ? _self.selectedWorkflowRun : selectedWorkflowRun // ignore: cast_nullable_to_non_nullable
as WorkflowRun?,selectedArtifact: freezed == selectedArtifact ? _self.selectedArtifact : selectedArtifact // ignore: cast_nullable_to_non_nullable
as WorkflowArtifact?,downloadedImage: freezed == downloadedImage ? _self.downloadedImage : downloadedImage // ignore: cast_nullable_to_non_nullable
as FirmwareImage?,filesystemImage: freezed == filesystemImage ? _self.filesystemImage : filesystemImage // ignore: cast_nullable_to_non_nullable
as FilesystemImage?,preparedImages: null == preparedImages ? _self.preparedImages : preparedImages // ignore: cast_nullable_to_non_nullable
as List<FirmwareImage>,isDownloading: null == isDownloading ? _self.isDownloading : isDownloading // ignore: cast_nullable_to_non_nullable
as bool,isUpdating: null == isUpdating ? _self.isUpdating : isUpdating // ignore: cast_nullable_to_non_nullable
as bool,isFilesystemUploading: null == isFilesystemUploading ? _self.isFilesystemUploading : isFilesystemUploading // ignore: cast_nullable_to_non_nullable
as bool,isBothUpdating: null == isBothUpdating ? _self.isBothUpdating : isBothUpdating // ignore: cast_nullable_to_non_nullable
as bool,currentStep: null == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as int,totalSteps: null == totalSteps ? _self.totalSteps : totalSteps // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of DfuOperationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GitHubReleaseCopyWith<$Res>? get selectedRelease {
    if (_self.selectedRelease == null) {
    return null;
  }

  return $GitHubReleaseCopyWith<$Res>(_self.selectedRelease!, (value) {
    return _then(_self.copyWith(selectedRelease: value));
  });
}/// Create a copy of DfuOperationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FirmwareImageCopyWith<$Res>? get downloadedImage {
    if (_self.downloadedImage == null) {
    return null;
  }

  return $FirmwareImageCopyWith<$Res>(_self.downloadedImage!, (value) {
    return _then(_self.copyWith(downloadedImage: value));
  });
}/// Create a copy of DfuOperationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FilesystemImageCopyWith<$Res>? get filesystemImage {
    if (_self.filesystemImage == null) {
    return null;
  }

  return $FilesystemImageCopyWith<$Res>(_self.filesystemImage!, (value) {
    return _then(_self.copyWith(filesystemImage: value));
  });
}
}


/// Adds pattern-matching-related methods to [DfuOperationState].
extension DfuOperationStatePatterns on DfuOperationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DfuOperationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DfuOperationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DfuOperationState value)  $default,){
final _that = this;
switch (_that) {
case _DfuOperationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DfuOperationState value)?  $default,){
final _that = this;
switch (_that) {
case _DfuOperationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GitHubRelease? selectedRelease,  WorkflowRun? selectedWorkflowRun,  WorkflowArtifact? selectedArtifact,  FirmwareImage? downloadedImage,  FilesystemImage? filesystemImage,  List<FirmwareImage> preparedImages,  bool isDownloading,  bool isUpdating,  bool isFilesystemUploading,  bool isBothUpdating,  int currentStep,  int totalSteps,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DfuOperationState() when $default != null:
return $default(_that.selectedRelease,_that.selectedWorkflowRun,_that.selectedArtifact,_that.downloadedImage,_that.filesystemImage,_that.preparedImages,_that.isDownloading,_that.isUpdating,_that.isFilesystemUploading,_that.isBothUpdating,_that.currentStep,_that.totalSteps,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GitHubRelease? selectedRelease,  WorkflowRun? selectedWorkflowRun,  WorkflowArtifact? selectedArtifact,  FirmwareImage? downloadedImage,  FilesystemImage? filesystemImage,  List<FirmwareImage> preparedImages,  bool isDownloading,  bool isUpdating,  bool isFilesystemUploading,  bool isBothUpdating,  int currentStep,  int totalSteps,  String? error)  $default,) {final _that = this;
switch (_that) {
case _DfuOperationState():
return $default(_that.selectedRelease,_that.selectedWorkflowRun,_that.selectedArtifact,_that.downloadedImage,_that.filesystemImage,_that.preparedImages,_that.isDownloading,_that.isUpdating,_that.isFilesystemUploading,_that.isBothUpdating,_that.currentStep,_that.totalSteps,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GitHubRelease? selectedRelease,  WorkflowRun? selectedWorkflowRun,  WorkflowArtifact? selectedArtifact,  FirmwareImage? downloadedImage,  FilesystemImage? filesystemImage,  List<FirmwareImage> preparedImages,  bool isDownloading,  bool isUpdating,  bool isFilesystemUploading,  bool isBothUpdating,  int currentStep,  int totalSteps,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _DfuOperationState() when $default != null:
return $default(_that.selectedRelease,_that.selectedWorkflowRun,_that.selectedArtifact,_that.downloadedImage,_that.filesystemImage,_that.preparedImages,_that.isDownloading,_that.isUpdating,_that.isFilesystemUploading,_that.isBothUpdating,_that.currentStep,_that.totalSteps,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _DfuOperationState extends DfuOperationState with DiagnosticableTreeMixin {
  const _DfuOperationState({this.selectedRelease, this.selectedWorkflowRun, this.selectedArtifact, this.downloadedImage, this.filesystemImage, final  List<FirmwareImage> preparedImages = const <FirmwareImage>[], this.isDownloading = false, this.isUpdating = false, this.isFilesystemUploading = false, this.isBothUpdating = false, this.currentStep = 0, this.totalSteps = 0, this.error}): _preparedImages = preparedImages,super._();
  

@override final  GitHubRelease? selectedRelease;
@override final  WorkflowRun? selectedWorkflowRun;
@override final  WorkflowArtifact? selectedArtifact;
@override final  FirmwareImage? downloadedImage;
@override final  FilesystemImage? filesystemImage;
 final  List<FirmwareImage> _preparedImages;
@override@JsonKey() List<FirmwareImage> get preparedImages {
  if (_preparedImages is EqualUnmodifiableListView) return _preparedImages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_preparedImages);
}

@override@JsonKey() final  bool isDownloading;
@override@JsonKey() final  bool isUpdating;
@override@JsonKey() final  bool isFilesystemUploading;
@override@JsonKey() final  bool isBothUpdating;
@override@JsonKey() final  int currentStep;
@override@JsonKey() final  int totalSteps;
@override final  String? error;

/// Create a copy of DfuOperationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DfuOperationStateCopyWith<_DfuOperationState> get copyWith => __$DfuOperationStateCopyWithImpl<_DfuOperationState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'DfuOperationState'))
    ..add(DiagnosticsProperty('selectedRelease', selectedRelease))..add(DiagnosticsProperty('selectedWorkflowRun', selectedWorkflowRun))..add(DiagnosticsProperty('selectedArtifact', selectedArtifact))..add(DiagnosticsProperty('downloadedImage', downloadedImage))..add(DiagnosticsProperty('filesystemImage', filesystemImage))..add(DiagnosticsProperty('preparedImages', preparedImages))..add(DiagnosticsProperty('isDownloading', isDownloading))..add(DiagnosticsProperty('isUpdating', isUpdating))..add(DiagnosticsProperty('isFilesystemUploading', isFilesystemUploading))..add(DiagnosticsProperty('isBothUpdating', isBothUpdating))..add(DiagnosticsProperty('currentStep', currentStep))..add(DiagnosticsProperty('totalSteps', totalSteps))..add(DiagnosticsProperty('error', error));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DfuOperationState&&(identical(other.selectedRelease, selectedRelease) || other.selectedRelease == selectedRelease)&&(identical(other.selectedWorkflowRun, selectedWorkflowRun) || other.selectedWorkflowRun == selectedWorkflowRun)&&(identical(other.selectedArtifact, selectedArtifact) || other.selectedArtifact == selectedArtifact)&&(identical(other.downloadedImage, downloadedImage) || other.downloadedImage == downloadedImage)&&(identical(other.filesystemImage, filesystemImage) || other.filesystemImage == filesystemImage)&&const DeepCollectionEquality().equals(other._preparedImages, _preparedImages)&&(identical(other.isDownloading, isDownloading) || other.isDownloading == isDownloading)&&(identical(other.isUpdating, isUpdating) || other.isUpdating == isUpdating)&&(identical(other.isFilesystemUploading, isFilesystemUploading) || other.isFilesystemUploading == isFilesystemUploading)&&(identical(other.isBothUpdating, isBothUpdating) || other.isBothUpdating == isBothUpdating)&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep)&&(identical(other.totalSteps, totalSteps) || other.totalSteps == totalSteps)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,selectedRelease,selectedWorkflowRun,selectedArtifact,downloadedImage,filesystemImage,const DeepCollectionEquality().hash(_preparedImages),isDownloading,isUpdating,isFilesystemUploading,isBothUpdating,currentStep,totalSteps,error);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'DfuOperationState(selectedRelease: $selectedRelease, selectedWorkflowRun: $selectedWorkflowRun, selectedArtifact: $selectedArtifact, downloadedImage: $downloadedImage, filesystemImage: $filesystemImage, preparedImages: $preparedImages, isDownloading: $isDownloading, isUpdating: $isUpdating, isFilesystemUploading: $isFilesystemUploading, isBothUpdating: $isBothUpdating, currentStep: $currentStep, totalSteps: $totalSteps, error: $error)';
}


}

/// @nodoc
abstract mixin class _$DfuOperationStateCopyWith<$Res> implements $DfuOperationStateCopyWith<$Res> {
  factory _$DfuOperationStateCopyWith(_DfuOperationState value, $Res Function(_DfuOperationState) _then) = __$DfuOperationStateCopyWithImpl;
@override @useResult
$Res call({
 GitHubRelease? selectedRelease, WorkflowRun? selectedWorkflowRun, WorkflowArtifact? selectedArtifact, FirmwareImage? downloadedImage, FilesystemImage? filesystemImage, List<FirmwareImage> preparedImages, bool isDownloading, bool isUpdating, bool isFilesystemUploading, bool isBothUpdating, int currentStep, int totalSteps, String? error
});


@override $GitHubReleaseCopyWith<$Res>? get selectedRelease;@override $FirmwareImageCopyWith<$Res>? get downloadedImage;@override $FilesystemImageCopyWith<$Res>? get filesystemImage;

}
/// @nodoc
class __$DfuOperationStateCopyWithImpl<$Res>
    implements _$DfuOperationStateCopyWith<$Res> {
  __$DfuOperationStateCopyWithImpl(this._self, this._then);

  final _DfuOperationState _self;
  final $Res Function(_DfuOperationState) _then;

/// Create a copy of DfuOperationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedRelease = freezed,Object? selectedWorkflowRun = freezed,Object? selectedArtifact = freezed,Object? downloadedImage = freezed,Object? filesystemImage = freezed,Object? preparedImages = null,Object? isDownloading = null,Object? isUpdating = null,Object? isFilesystemUploading = null,Object? isBothUpdating = null,Object? currentStep = null,Object? totalSteps = null,Object? error = freezed,}) {
  return _then(_DfuOperationState(
selectedRelease: freezed == selectedRelease ? _self.selectedRelease : selectedRelease // ignore: cast_nullable_to_non_nullable
as GitHubRelease?,selectedWorkflowRun: freezed == selectedWorkflowRun ? _self.selectedWorkflowRun : selectedWorkflowRun // ignore: cast_nullable_to_non_nullable
as WorkflowRun?,selectedArtifact: freezed == selectedArtifact ? _self.selectedArtifact : selectedArtifact // ignore: cast_nullable_to_non_nullable
as WorkflowArtifact?,downloadedImage: freezed == downloadedImage ? _self.downloadedImage : downloadedImage // ignore: cast_nullable_to_non_nullable
as FirmwareImage?,filesystemImage: freezed == filesystemImage ? _self.filesystemImage : filesystemImage // ignore: cast_nullable_to_non_nullable
as FilesystemImage?,preparedImages: null == preparedImages ? _self._preparedImages : preparedImages // ignore: cast_nullable_to_non_nullable
as List<FirmwareImage>,isDownloading: null == isDownloading ? _self.isDownloading : isDownloading // ignore: cast_nullable_to_non_nullable
as bool,isUpdating: null == isUpdating ? _self.isUpdating : isUpdating // ignore: cast_nullable_to_non_nullable
as bool,isFilesystemUploading: null == isFilesystemUploading ? _self.isFilesystemUploading : isFilesystemUploading // ignore: cast_nullable_to_non_nullable
as bool,isBothUpdating: null == isBothUpdating ? _self.isBothUpdating : isBothUpdating // ignore: cast_nullable_to_non_nullable
as bool,currentStep: null == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as int,totalSteps: null == totalSteps ? _self.totalSteps : totalSteps // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of DfuOperationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GitHubReleaseCopyWith<$Res>? get selectedRelease {
    if (_self.selectedRelease == null) {
    return null;
  }

  return $GitHubReleaseCopyWith<$Res>(_self.selectedRelease!, (value) {
    return _then(_self.copyWith(selectedRelease: value));
  });
}/// Create a copy of DfuOperationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FirmwareImageCopyWith<$Res>? get downloadedImage {
    if (_self.downloadedImage == null) {
    return null;
  }

  return $FirmwareImageCopyWith<$Res>(_self.downloadedImage!, (value) {
    return _then(_self.copyWith(downloadedImage: value));
  });
}/// Create a copy of DfuOperationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FilesystemImageCopyWith<$Res>? get filesystemImage {
    if (_self.filesystemImage == null) {
    return null;
  }

  return $FilesystemImageCopyWith<$Res>(_self.filesystemImage!, (value) {
    return _then(_self.copyWith(filesystemImage: value));
  });
}
}

// dart format on
