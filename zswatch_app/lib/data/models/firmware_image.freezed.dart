// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'firmware_image.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FirmwareImage {

/// Display name for the firmware
 String get name;/// Firmware version string (e.g., "3.0.0", "v3.0.0-rc1")
 String? get version;/// Local file path where the firmware is stored
 String get filePath;/// File size in bytes
 int get size;/// MCUmgr image slot from manifest.json (0=app internal, 1=netCore, 2=app external)
 int? get slot;/// Board identifier from manifest.json (e.g., "watchdk" or "watchdk@1/nrf5340/cpunet")
 String? get board;/// SHA256 hash of the file (optional, for verification)
 String? get hash;/// When the firmware was downloaded (null for local files)
 DateTime? get downloadedAt;/// Source URL if downloaded from GitHub
 String? get sourceUrl;/// Git branch or tag name
 String? get branch;
/// Create a copy of FirmwareImage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirmwareImageCopyWith<FirmwareImage> get copyWith => _$FirmwareImageCopyWithImpl<FirmwareImage>(this as FirmwareImage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirmwareImage&&(identical(other.name, name) || other.name == name)&&(identical(other.version, version) || other.version == version)&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.size, size) || other.size == size)&&(identical(other.slot, slot) || other.slot == slot)&&(identical(other.board, board) || other.board == board)&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.downloadedAt, downloadedAt) || other.downloadedAt == downloadedAt)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.branch, branch) || other.branch == branch));
}


@override
int get hashCode => Object.hash(runtimeType,name,version,filePath,size,slot,board,hash,downloadedAt,sourceUrl,branch);

@override
String toString() {
  return 'FirmwareImage(name: $name, version: $version, filePath: $filePath, size: $size, slot: $slot, board: $board, hash: $hash, downloadedAt: $downloadedAt, sourceUrl: $sourceUrl, branch: $branch)';
}


}

/// @nodoc
abstract mixin class $FirmwareImageCopyWith<$Res>  {
  factory $FirmwareImageCopyWith(FirmwareImage value, $Res Function(FirmwareImage) _then) = _$FirmwareImageCopyWithImpl;
@useResult
$Res call({
 String name, String? version, String filePath, int size, int? slot, String? board, String? hash, DateTime? downloadedAt, String? sourceUrl, String? branch
});




}
/// @nodoc
class _$FirmwareImageCopyWithImpl<$Res>
    implements $FirmwareImageCopyWith<$Res> {
  _$FirmwareImageCopyWithImpl(this._self, this._then);

  final FirmwareImage _self;
  final $Res Function(FirmwareImage) _then;

/// Create a copy of FirmwareImage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? version = freezed,Object? filePath = null,Object? size = null,Object? slot = freezed,Object? board = freezed,Object? hash = freezed,Object? downloadedAt = freezed,Object? sourceUrl = freezed,Object? branch = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,slot: freezed == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as int?,board: freezed == board ? _self.board : board // ignore: cast_nullable_to_non_nullable
as String?,hash: freezed == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String?,downloadedAt: freezed == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sourceUrl: freezed == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String?,branch: freezed == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FirmwareImage].
extension FirmwareImagePatterns on FirmwareImage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FirmwareImage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FirmwareImage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FirmwareImage value)  $default,){
final _that = this;
switch (_that) {
case _FirmwareImage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FirmwareImage value)?  $default,){
final _that = this;
switch (_that) {
case _FirmwareImage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? version,  String filePath,  int size,  int? slot,  String? board,  String? hash,  DateTime? downloadedAt,  String? sourceUrl,  String? branch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FirmwareImage() when $default != null:
return $default(_that.name,_that.version,_that.filePath,_that.size,_that.slot,_that.board,_that.hash,_that.downloadedAt,_that.sourceUrl,_that.branch);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? version,  String filePath,  int size,  int? slot,  String? board,  String? hash,  DateTime? downloadedAt,  String? sourceUrl,  String? branch)  $default,) {final _that = this;
switch (_that) {
case _FirmwareImage():
return $default(_that.name,_that.version,_that.filePath,_that.size,_that.slot,_that.board,_that.hash,_that.downloadedAt,_that.sourceUrl,_that.branch);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? version,  String filePath,  int size,  int? slot,  String? board,  String? hash,  DateTime? downloadedAt,  String? sourceUrl,  String? branch)?  $default,) {final _that = this;
switch (_that) {
case _FirmwareImage() when $default != null:
return $default(_that.name,_that.version,_that.filePath,_that.size,_that.slot,_that.board,_that.hash,_that.downloadedAt,_that.sourceUrl,_that.branch);case _:
  return null;

}
}

}

/// @nodoc


class _FirmwareImage extends FirmwareImage {
  const _FirmwareImage({required this.name, this.version, required this.filePath, required this.size, this.slot, this.board, this.hash, this.downloadedAt, this.sourceUrl, this.branch}): super._();
  

/// Display name for the firmware
@override final  String name;
/// Firmware version string (e.g., "3.0.0", "v3.0.0-rc1")
@override final  String? version;
/// Local file path where the firmware is stored
@override final  String filePath;
/// File size in bytes
@override final  int size;
/// MCUmgr image slot from manifest.json (0=app internal, 1=netCore, 2=app external)
@override final  int? slot;
/// Board identifier from manifest.json (e.g., "watchdk" or "watchdk@1/nrf5340/cpunet")
@override final  String? board;
/// SHA256 hash of the file (optional, for verification)
@override final  String? hash;
/// When the firmware was downloaded (null for local files)
@override final  DateTime? downloadedAt;
/// Source URL if downloaded from GitHub
@override final  String? sourceUrl;
/// Git branch or tag name
@override final  String? branch;

/// Create a copy of FirmwareImage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FirmwareImageCopyWith<_FirmwareImage> get copyWith => __$FirmwareImageCopyWithImpl<_FirmwareImage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FirmwareImage&&(identical(other.name, name) || other.name == name)&&(identical(other.version, version) || other.version == version)&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.size, size) || other.size == size)&&(identical(other.slot, slot) || other.slot == slot)&&(identical(other.board, board) || other.board == board)&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.downloadedAt, downloadedAt) || other.downloadedAt == downloadedAt)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.branch, branch) || other.branch == branch));
}


@override
int get hashCode => Object.hash(runtimeType,name,version,filePath,size,slot,board,hash,downloadedAt,sourceUrl,branch);

@override
String toString() {
  return 'FirmwareImage(name: $name, version: $version, filePath: $filePath, size: $size, slot: $slot, board: $board, hash: $hash, downloadedAt: $downloadedAt, sourceUrl: $sourceUrl, branch: $branch)';
}


}

/// @nodoc
abstract mixin class _$FirmwareImageCopyWith<$Res> implements $FirmwareImageCopyWith<$Res> {
  factory _$FirmwareImageCopyWith(_FirmwareImage value, $Res Function(_FirmwareImage) _then) = __$FirmwareImageCopyWithImpl;
@override @useResult
$Res call({
 String name, String? version, String filePath, int size, int? slot, String? board, String? hash, DateTime? downloadedAt, String? sourceUrl, String? branch
});




}
/// @nodoc
class __$FirmwareImageCopyWithImpl<$Res>
    implements _$FirmwareImageCopyWith<$Res> {
  __$FirmwareImageCopyWithImpl(this._self, this._then);

  final _FirmwareImage _self;
  final $Res Function(_FirmwareImage) _then;

/// Create a copy of FirmwareImage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? version = freezed,Object? filePath = null,Object? size = null,Object? slot = freezed,Object? board = freezed,Object? hash = freezed,Object? downloadedAt = freezed,Object? sourceUrl = freezed,Object? branch = freezed,}) {
  return _then(_FirmwareImage(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,slot: freezed == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as int?,board: freezed == board ? _self.board : board // ignore: cast_nullable_to_non_nullable
as String?,hash: freezed == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String?,downloadedAt: freezed == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sourceUrl: freezed == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String?,branch: freezed == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ReleaseAsset {

/// Asset file name (e.g., "watchdk@1_nrf5340_cpuapp_debug.zip")
 String get name;/// Download URL
 String get downloadUrl;/// File size in bytes
 int get size;
/// Create a copy of ReleaseAsset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReleaseAssetCopyWith<ReleaseAsset> get copyWith => _$ReleaseAssetCopyWithImpl<ReleaseAsset>(this as ReleaseAsset, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReleaseAsset&&(identical(other.name, name) || other.name == name)&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.size, size) || other.size == size));
}


@override
int get hashCode => Object.hash(runtimeType,name,downloadUrl,size);

@override
String toString() {
  return 'ReleaseAsset(name: $name, downloadUrl: $downloadUrl, size: $size)';
}


}

/// @nodoc
abstract mixin class $ReleaseAssetCopyWith<$Res>  {
  factory $ReleaseAssetCopyWith(ReleaseAsset value, $Res Function(ReleaseAsset) _then) = _$ReleaseAssetCopyWithImpl;
@useResult
$Res call({
 String name, String downloadUrl, int size
});




}
/// @nodoc
class _$ReleaseAssetCopyWithImpl<$Res>
    implements $ReleaseAssetCopyWith<$Res> {
  _$ReleaseAssetCopyWithImpl(this._self, this._then);

  final ReleaseAsset _self;
  final $Res Function(ReleaseAsset) _then;

/// Create a copy of ReleaseAsset
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? downloadUrl = null,Object? size = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,downloadUrl: null == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReleaseAsset].
extension ReleaseAssetPatterns on ReleaseAsset {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReleaseAsset value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReleaseAsset() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReleaseAsset value)  $default,){
final _that = this;
switch (_that) {
case _ReleaseAsset():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReleaseAsset value)?  $default,){
final _that = this;
switch (_that) {
case _ReleaseAsset() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String downloadUrl,  int size)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReleaseAsset() when $default != null:
return $default(_that.name,_that.downloadUrl,_that.size);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String downloadUrl,  int size)  $default,) {final _that = this;
switch (_that) {
case _ReleaseAsset():
return $default(_that.name,_that.downloadUrl,_that.size);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String downloadUrl,  int size)?  $default,) {final _that = this;
switch (_that) {
case _ReleaseAsset() when $default != null:
return $default(_that.name,_that.downloadUrl,_that.size);case _:
  return null;

}
}

}

/// @nodoc


class _ReleaseAsset extends ReleaseAsset {
  const _ReleaseAsset({required this.name, required this.downloadUrl, required this.size}): super._();
  

/// Asset file name (e.g., "watchdk@1_nrf5340_cpuapp_debug.zip")
@override final  String name;
/// Download URL
@override final  String downloadUrl;
/// File size in bytes
@override final  int size;

/// Create a copy of ReleaseAsset
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReleaseAssetCopyWith<_ReleaseAsset> get copyWith => __$ReleaseAssetCopyWithImpl<_ReleaseAsset>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReleaseAsset&&(identical(other.name, name) || other.name == name)&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.size, size) || other.size == size));
}


@override
int get hashCode => Object.hash(runtimeType,name,downloadUrl,size);

@override
String toString() {
  return 'ReleaseAsset(name: $name, downloadUrl: $downloadUrl, size: $size)';
}


}

/// @nodoc
abstract mixin class _$ReleaseAssetCopyWith<$Res> implements $ReleaseAssetCopyWith<$Res> {
  factory _$ReleaseAssetCopyWith(_ReleaseAsset value, $Res Function(_ReleaseAsset) _then) = __$ReleaseAssetCopyWithImpl;
@override @useResult
$Res call({
 String name, String downloadUrl, int size
});




}
/// @nodoc
class __$ReleaseAssetCopyWithImpl<$Res>
    implements _$ReleaseAssetCopyWith<$Res> {
  __$ReleaseAssetCopyWithImpl(this._self, this._then);

  final _ReleaseAsset _self;
  final $Res Function(_ReleaseAsset) _then;

/// Create a copy of ReleaseAsset
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? downloadUrl = null,Object? size = null,}) {
  return _then(_ReleaseAsset(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,downloadUrl: null == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$GitHubRelease {

/// Release tag name (e.g., "v3.0.0")
 String get tagName;/// Release title
 String get name;/// Release description/body
 String? get body;/// Whether this is a prerelease
 bool get isPrerelease;/// When the release was published
 DateTime get publishedAt;/// All available firmware assets in this release
 List<ReleaseAsset> get assets;
/// Create a copy of GitHubRelease
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubReleaseCopyWith<GitHubRelease> get copyWith => _$GitHubReleaseCopyWithImpl<GitHubRelease>(this as GitHubRelease, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubRelease&&(identical(other.tagName, tagName) || other.tagName == tagName)&&(identical(other.name, name) || other.name == name)&&(identical(other.body, body) || other.body == body)&&(identical(other.isPrerelease, isPrerelease) || other.isPrerelease == isPrerelease)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&const DeepCollectionEquality().equals(other.assets, assets));
}


@override
int get hashCode => Object.hash(runtimeType,tagName,name,body,isPrerelease,publishedAt,const DeepCollectionEquality().hash(assets));

@override
String toString() {
  return 'GitHubRelease(tagName: $tagName, name: $name, body: $body, isPrerelease: $isPrerelease, publishedAt: $publishedAt, assets: $assets)';
}


}

/// @nodoc
abstract mixin class $GitHubReleaseCopyWith<$Res>  {
  factory $GitHubReleaseCopyWith(GitHubRelease value, $Res Function(GitHubRelease) _then) = _$GitHubReleaseCopyWithImpl;
@useResult
$Res call({
 String tagName, String name, String? body, bool isPrerelease, DateTime publishedAt, List<ReleaseAsset> assets
});




}
/// @nodoc
class _$GitHubReleaseCopyWithImpl<$Res>
    implements $GitHubReleaseCopyWith<$Res> {
  _$GitHubReleaseCopyWithImpl(this._self, this._then);

  final GitHubRelease _self;
  final $Res Function(GitHubRelease) _then;

/// Create a copy of GitHubRelease
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tagName = null,Object? name = null,Object? body = freezed,Object? isPrerelease = null,Object? publishedAt = null,Object? assets = null,}) {
  return _then(_self.copyWith(
tagName: null == tagName ? _self.tagName : tagName // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isPrerelease: null == isPrerelease ? _self.isPrerelease : isPrerelease // ignore: cast_nullable_to_non_nullable
as bool,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,assets: null == assets ? _self.assets : assets // ignore: cast_nullable_to_non_nullable
as List<ReleaseAsset>,
  ));
}

}


/// Adds pattern-matching-related methods to [GitHubRelease].
extension GitHubReleasePatterns on GitHubRelease {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitHubRelease value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitHubRelease() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitHubRelease value)  $default,){
final _that = this;
switch (_that) {
case _GitHubRelease():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitHubRelease value)?  $default,){
final _that = this;
switch (_that) {
case _GitHubRelease() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tagName,  String name,  String? body,  bool isPrerelease,  DateTime publishedAt,  List<ReleaseAsset> assets)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitHubRelease() when $default != null:
return $default(_that.tagName,_that.name,_that.body,_that.isPrerelease,_that.publishedAt,_that.assets);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tagName,  String name,  String? body,  bool isPrerelease,  DateTime publishedAt,  List<ReleaseAsset> assets)  $default,) {final _that = this;
switch (_that) {
case _GitHubRelease():
return $default(_that.tagName,_that.name,_that.body,_that.isPrerelease,_that.publishedAt,_that.assets);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tagName,  String name,  String? body,  bool isPrerelease,  DateTime publishedAt,  List<ReleaseAsset> assets)?  $default,) {final _that = this;
switch (_that) {
case _GitHubRelease() when $default != null:
return $default(_that.tagName,_that.name,_that.body,_that.isPrerelease,_that.publishedAt,_that.assets);case _:
  return null;

}
}

}

/// @nodoc


class _GitHubRelease extends GitHubRelease {
  const _GitHubRelease({required this.tagName, required this.name, this.body, required this.isPrerelease, required this.publishedAt, required final  List<ReleaseAsset> assets}): _assets = assets,super._();
  

/// Release tag name (e.g., "v3.0.0")
@override final  String tagName;
/// Release title
@override final  String name;
/// Release description/body
@override final  String? body;
/// Whether this is a prerelease
@override final  bool isPrerelease;
/// When the release was published
@override final  DateTime publishedAt;
/// All available firmware assets in this release
 final  List<ReleaseAsset> _assets;
/// All available firmware assets in this release
@override List<ReleaseAsset> get assets {
  if (_assets is EqualUnmodifiableListView) return _assets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_assets);
}


/// Create a copy of GitHubRelease
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubReleaseCopyWith<_GitHubRelease> get copyWith => __$GitHubReleaseCopyWithImpl<_GitHubRelease>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubRelease&&(identical(other.tagName, tagName) || other.tagName == tagName)&&(identical(other.name, name) || other.name == name)&&(identical(other.body, body) || other.body == body)&&(identical(other.isPrerelease, isPrerelease) || other.isPrerelease == isPrerelease)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&const DeepCollectionEquality().equals(other._assets, _assets));
}


@override
int get hashCode => Object.hash(runtimeType,tagName,name,body,isPrerelease,publishedAt,const DeepCollectionEquality().hash(_assets));

@override
String toString() {
  return 'GitHubRelease(tagName: $tagName, name: $name, body: $body, isPrerelease: $isPrerelease, publishedAt: $publishedAt, assets: $assets)';
}


}

/// @nodoc
abstract mixin class _$GitHubReleaseCopyWith<$Res> implements $GitHubReleaseCopyWith<$Res> {
  factory _$GitHubReleaseCopyWith(_GitHubRelease value, $Res Function(_GitHubRelease) _then) = __$GitHubReleaseCopyWithImpl;
@override @useResult
$Res call({
 String tagName, String name, String? body, bool isPrerelease, DateTime publishedAt, List<ReleaseAsset> assets
});




}
/// @nodoc
class __$GitHubReleaseCopyWithImpl<$Res>
    implements _$GitHubReleaseCopyWith<$Res> {
  __$GitHubReleaseCopyWithImpl(this._self, this._then);

  final _GitHubRelease _self;
  final $Res Function(_GitHubRelease) _then;

/// Create a copy of GitHubRelease
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tagName = null,Object? name = null,Object? body = freezed,Object? isPrerelease = null,Object? publishedAt = null,Object? assets = null,}) {
  return _then(_GitHubRelease(
tagName: null == tagName ? _self.tagName : tagName // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isPrerelease: null == isPrerelease ? _self.isPrerelease : isPrerelease // ignore: cast_nullable_to_non_nullable
as bool,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,assets: null == assets ? _self._assets : assets // ignore: cast_nullable_to_non_nullable
as List<ReleaseAsset>,
  ));
}


}

/// @nodoc
mixin _$GitHubArtifact {

/// Branch name
 String get branch;/// Workflow run ID
 String get runId;/// Artifact name
 String get name;/// Artifact size in bytes
 int get size;/// When the artifact was created
 DateTime get createdAt;/// Download URL (requires authentication)
 String get downloadUrl;/// Commit SHA
 String? get commitSha;/// Commit message
 String? get commitMessage;
/// Create a copy of GitHubArtifact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubArtifactCopyWith<GitHubArtifact> get copyWith => _$GitHubArtifactCopyWithImpl<GitHubArtifact>(this as GitHubArtifact, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubArtifact&&(identical(other.branch, branch) || other.branch == branch)&&(identical(other.runId, runId) || other.runId == runId)&&(identical(other.name, name) || other.name == name)&&(identical(other.size, size) || other.size == size)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.commitSha, commitSha) || other.commitSha == commitSha)&&(identical(other.commitMessage, commitMessage) || other.commitMessage == commitMessage));
}


@override
int get hashCode => Object.hash(runtimeType,branch,runId,name,size,createdAt,downloadUrl,commitSha,commitMessage);

@override
String toString() {
  return 'GitHubArtifact(branch: $branch, runId: $runId, name: $name, size: $size, createdAt: $createdAt, downloadUrl: $downloadUrl, commitSha: $commitSha, commitMessage: $commitMessage)';
}


}

/// @nodoc
abstract mixin class $GitHubArtifactCopyWith<$Res>  {
  factory $GitHubArtifactCopyWith(GitHubArtifact value, $Res Function(GitHubArtifact) _then) = _$GitHubArtifactCopyWithImpl;
@useResult
$Res call({
 String branch, String runId, String name, int size, DateTime createdAt, String downloadUrl, String? commitSha, String? commitMessage
});




}
/// @nodoc
class _$GitHubArtifactCopyWithImpl<$Res>
    implements $GitHubArtifactCopyWith<$Res> {
  _$GitHubArtifactCopyWithImpl(this._self, this._then);

  final GitHubArtifact _self;
  final $Res Function(GitHubArtifact) _then;

/// Create a copy of GitHubArtifact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? branch = null,Object? runId = null,Object? name = null,Object? size = null,Object? createdAt = null,Object? downloadUrl = null,Object? commitSha = freezed,Object? commitMessage = freezed,}) {
  return _then(_self.copyWith(
branch: null == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,downloadUrl: null == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String,commitSha: freezed == commitSha ? _self.commitSha : commitSha // ignore: cast_nullable_to_non_nullable
as String?,commitMessage: freezed == commitMessage ? _self.commitMessage : commitMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GitHubArtifact].
extension GitHubArtifactPatterns on GitHubArtifact {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitHubArtifact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitHubArtifact() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitHubArtifact value)  $default,){
final _that = this;
switch (_that) {
case _GitHubArtifact():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitHubArtifact value)?  $default,){
final _that = this;
switch (_that) {
case _GitHubArtifact() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String branch,  String runId,  String name,  int size,  DateTime createdAt,  String downloadUrl,  String? commitSha,  String? commitMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitHubArtifact() when $default != null:
return $default(_that.branch,_that.runId,_that.name,_that.size,_that.createdAt,_that.downloadUrl,_that.commitSha,_that.commitMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String branch,  String runId,  String name,  int size,  DateTime createdAt,  String downloadUrl,  String? commitSha,  String? commitMessage)  $default,) {final _that = this;
switch (_that) {
case _GitHubArtifact():
return $default(_that.branch,_that.runId,_that.name,_that.size,_that.createdAt,_that.downloadUrl,_that.commitSha,_that.commitMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String branch,  String runId,  String name,  int size,  DateTime createdAt,  String downloadUrl,  String? commitSha,  String? commitMessage)?  $default,) {final _that = this;
switch (_that) {
case _GitHubArtifact() when $default != null:
return $default(_that.branch,_that.runId,_that.name,_that.size,_that.createdAt,_that.downloadUrl,_that.commitSha,_that.commitMessage);case _:
  return null;

}
}

}

/// @nodoc


class _GitHubArtifact extends GitHubArtifact {
  const _GitHubArtifact({required this.branch, required this.runId, required this.name, required this.size, required this.createdAt, required this.downloadUrl, this.commitSha, this.commitMessage}): super._();
  

/// Branch name
@override final  String branch;
/// Workflow run ID
@override final  String runId;
/// Artifact name
@override final  String name;
/// Artifact size in bytes
@override final  int size;
/// When the artifact was created
@override final  DateTime createdAt;
/// Download URL (requires authentication)
@override final  String downloadUrl;
/// Commit SHA
@override final  String? commitSha;
/// Commit message
@override final  String? commitMessage;

/// Create a copy of GitHubArtifact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubArtifactCopyWith<_GitHubArtifact> get copyWith => __$GitHubArtifactCopyWithImpl<_GitHubArtifact>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubArtifact&&(identical(other.branch, branch) || other.branch == branch)&&(identical(other.runId, runId) || other.runId == runId)&&(identical(other.name, name) || other.name == name)&&(identical(other.size, size) || other.size == size)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.commitSha, commitSha) || other.commitSha == commitSha)&&(identical(other.commitMessage, commitMessage) || other.commitMessage == commitMessage));
}


@override
int get hashCode => Object.hash(runtimeType,branch,runId,name,size,createdAt,downloadUrl,commitSha,commitMessage);

@override
String toString() {
  return 'GitHubArtifact(branch: $branch, runId: $runId, name: $name, size: $size, createdAt: $createdAt, downloadUrl: $downloadUrl, commitSha: $commitSha, commitMessage: $commitMessage)';
}


}

/// @nodoc
abstract mixin class _$GitHubArtifactCopyWith<$Res> implements $GitHubArtifactCopyWith<$Res> {
  factory _$GitHubArtifactCopyWith(_GitHubArtifact value, $Res Function(_GitHubArtifact) _then) = __$GitHubArtifactCopyWithImpl;
@override @useResult
$Res call({
 String branch, String runId, String name, int size, DateTime createdAt, String downloadUrl, String? commitSha, String? commitMessage
});




}
/// @nodoc
class __$GitHubArtifactCopyWithImpl<$Res>
    implements _$GitHubArtifactCopyWith<$Res> {
  __$GitHubArtifactCopyWithImpl(this._self, this._then);

  final _GitHubArtifact _self;
  final $Res Function(_GitHubArtifact) _then;

/// Create a copy of GitHubArtifact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? branch = null,Object? runId = null,Object? name = null,Object? size = null,Object? createdAt = null,Object? downloadUrl = null,Object? commitSha = freezed,Object? commitMessage = freezed,}) {
  return _then(_GitHubArtifact(
branch: null == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,downloadUrl: null == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String,commitSha: freezed == commitSha ? _self.commitSha : commitSha // ignore: cast_nullable_to_non_nullable
as String?,commitMessage: freezed == commitMessage ? _self.commitMessage : commitMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
