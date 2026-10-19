# iOS Whisper wrapper

The wrapper is retained from this Mac's existing whisper_ggml_plus 1.3.5 iOS
integration; the package license is included. It preserves the local abort and
mutex-protected context disposal fixes required by shared Dart cancellation.
The package version/archive remains pinned in pubspec.lock, and its underlying
Whisper/GGML source is still supplied by that dependency.

CocoaPods replaces only the wrapper's source reference with this checked-in file;
it does not edit the pub cache. Initial mode is CPU. The pod's wrapper path is
reviewable and normal builds use it. CoreML is disabled to avoid an implicit
GPU/ANE execution path during background CPU processing. The existing fllama
request already selects numGpuLayers=0. There is no GPU background capability
or continued-processing entitlement claimed by this implementation.

The companion processor awaits the package's native dispose request after STT
before loading the analysis model. Dart stream disposal alone does not unload
the cached native Whisper context. The processing FlutterEngine is retained
idle after first use because the pinned fllama fork keeps native logger callback
pointers until its next request. This avoids invalid callbacks into a destroyed
Dart isolate. It provides no extra iOS execution permission.

The upstream 1.3.5 archive was downloaded and verified against pubspec.lock:
67ffeae30a4e9a5f3b54651fb0d6a27c7de23ea6855aa54118bb894e2b32e205.
Comparing all cached iOS files against that archive found only the wrapper was
modified, with no additional cached iOS files. The underlying iOS sources and
podspec therefore need no cache patches for this integration.
