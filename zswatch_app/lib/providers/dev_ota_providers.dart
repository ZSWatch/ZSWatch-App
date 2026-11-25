import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/dfu_state.dart';
import '../services/dev_ota/dev_ota_client.dart';
import 'companion_runtime_providers.dart';
import 'dfu_providers.dart';
import 'settings_providers.dart';

abstract final class _Keys {
  static const url = 'dev_ota_url';
  static const token = 'dev_ota_token';
  static const handled = 'dev_ota_handled_build';
}

@immutable
class DevOtaState {
  final String url;
  final String token;
  final DevOtaBuild? latest;

  /// A build the user has not answered yet; the app shows a dialog for it.
  final DevOtaBuild? offer;
  final String? installingId;
  final String? phase;
  final String? error;
  final bool reachable;

  const DevOtaState({
    this.url = '',
    this.token = '',
    this.latest,
    this.offer,
    this.installingId,
    this.phase,
    this.error,
    this.reachable = false,
  });

  bool get configured => url.isNotEmpty && token.isNotEmpty;

  DevOtaState copyWith({
    String? url,
    String? token,
    DevOtaBuild? latest,
    DevOtaBuild? Function()? offer,
    String? Function()? installingId,
    String? Function()? phase,
    String? Function()? error,
    bool? reachable,
  }) => DevOtaState(
    url: url ?? this.url,
    token: token ?? this.token,
    latest: latest ?? this.latest,
    offer: offer != null ? offer() : this.offer,
    installingId: installingId != null ? installingId() : this.installingId,
    phase: phase != null ? phase() : this.phase,
    error: error != null ? error() : this.error,
    reachable: reachable ?? this.reachable,
  );
}

final devOtaProvider = StateNotifierProvider<DevOtaController, DevOtaState>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return DevOtaController(ref, prefs);
});

/// Long-polls the dev OTA server while the app is in the foreground and
/// installs a build through the normal native DFU path when asked.
class DevOtaController extends StateNotifier<DevOtaState> {
  static const _wait = Duration(seconds: 25);
  static const _retry = Duration(seconds: 15);

  final Ref _ref;
  final SharedPreferences? _prefs;
  late final AppLifecycleListener _lifecycle;
  DevOtaClient? _client;
  int _loopGeneration = 0;
  bool _foreground = true;
  ProviderSubscription<DfuStatus>? _dfuWatch;
  ProviderSubscription<Object?>? _connectionWatch;
  int _uploadStartedMs = 0;

  DevOtaController(this._ref, this._prefs)
    : super(
        DevOtaState(
          url: _prefs?.getString(_Keys.url) ?? '',
          token: _prefs?.getString(_Keys.token) ?? '',
        ),
      ) {
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        _restart();
      },
      onPause: () {
        _foreground = false;
        _loopGeneration++;
      },
    );
    _restart();
  }

  String? get _handled => _prefs?.getString(_Keys.handled);

  Future<void> configure(String url, String token) async {
    final cleanUrl = url.trim();
    final cleanToken = token.trim();
    await _prefs?.setString(_Keys.url, cleanUrl);
    await _prefs?.setString(_Keys.token, cleanToken);
    state = DevOtaState(url: cleanUrl, token: cleanToken);
    _restart();
  }

  /// Fetches the latest build once, so the settings screen can test a URL.
  Future<void> refresh() async {
    final client = _client;
    if (client == null) return;
    try {
      _accept(await client.latest());
    } catch (error) {
      _fail(error);
    }
  }

  void _restart() {
    final generation = ++_loopGeneration;
    _client?.close();
    _client = state.configured ? DevOtaClient(state.url, state.token) : null;
    if (_client != null && _foreground) unawaited(_poll(generation));
  }

  Future<void> _poll(int generation) async {
    final client = _client!;
    while (mounted && generation == _loopGeneration) {
      try {
        final build = await client.latest(
          after: state.latest?.id,
          wait: state.latest == null ? null : _wait,
        );
        if (!mounted || generation != _loopGeneration) return;
        _accept(build);
      } catch (error) {
        if (!mounted || generation != _loopGeneration) return;
        _fail(error);
        await Future<void>.delayed(_retry);
      }
    }
  }

  void _accept(DevOtaBuild? build) {
    final isNew =
        build != null &&
        build.id != _handled &&
        state.installingId == null &&
        state.offer?.id != build.id;
    state = state.copyWith(
      latest: build,
      reachable: true,
      error: () => null,
      offer: isNew ? () => build : null,
    );
  }

  void _fail(Object error) {
    debugPrint('[DevOtaController] $error');
    state = state.copyWith(reachable: false, error: () => '$error');
  }

  Future<void> decline(DevOtaBuild build) async {
    await _prefs?.setString(_Keys.handled, build.id);
    state = state.copyWith(offer: () => null);
    await _report(build.id, 'declined');
  }

  Future<void> install(DevOtaBuild build) async {
    final client = _client;
    if (client == null || state.installingId != null) return;
    await _prefs?.setString(_Keys.handled, build.id);
    state = state.copyWith(
      offer: () => null,
      installingId: () => build.id,
      phase: () => 'Downloading',
      error: () => null,
    );
    try {
      await _report(build.id, 'downloading');
      final dir = await getTemporaryDirectory();
      final file = await client.download(
        build,
        File('${dir.path}/dev_ota_${build.id}.zip'),
      );
      final dfu = _ref.read(dfuNotifierProvider.notifier);
      dfu.reset();
      await dfu.loadLocalFile(file.path);
      _throwDfuError();
      _watchDfu(build);
      _uploadStartedMs = DateTime.now().millisecondsSinceEpoch;
      state = state.copyWith(phase: () => 'Updating watch');
      await _report(build.id, 'uploading');
      if (_ref.read(dfuNotifierProvider).hasFilesystem) {
        await dfu.startBothUpdates();
      } else {
        await dfu.startUpdate();
      }
      _throwDfuError();
    } catch (error) {
      await _finish(build, 'failed', '$error');
    }
  }

  void _throwDfuError() {
    final error = _ref.read(dfuNotifierProvider).error;
    if (error != null) throw DevOtaException(error);
  }

  void _watchDfu(DevOtaBuild build) {
    _dfuWatch?.close();
    var started = false;
    _dfuWatch = _ref.listen<DfuStatus>(dfuStatusProvider, (_, status) {
      if (status.isInProgress) started = true;
      if (!started) return;
      switch (status) {
        case DfuStatus.completed:
          _dfuWatch?.close();
          state = state.copyWith(phase: () => 'Waiting for the watch');
          _awaitReconnect(build);
          unawaited(_report(build.id, 'completed'));
        case DfuStatus.failed:
          final error = _ref.read(dfuStateProvider).errorMessage;
          unawaited(_finish(build, 'failed', error ?? 'DFU failed'));
        case DfuStatus.cancelled:
          unawaited(_finish(build, 'cancelled', null));
        default:
          break;
      }
    });
  }

  /// Waits for the watch to report its version after the update. Firmware
  /// that reports its git sha is checked against the published commit.
  void _awaitReconnect(DevOtaBuild build) {
    _connectionWatch?.close();
    Timer? noSha;
    void done() {
      noSha?.cancel();
      _connectionWatch?.close();
      final snapshot = _ref.read(companionSnapshotProvider).valueOrNull;
      final version = snapshot?.watch?.firmwareVersion;
      final fresh = (snapshot?.versionObservedMs ?? 0) > _uploadStartedMs;
      final sha = fresh ? snapshot?.firmwareSha : null;
      final detail = [
        if (version != null) 'fw $version',
        if (sha != null) 'sha $sha',
      ].join(' ');
      final matches =
          sha == null ||
          build.commit.isEmpty ||
          sha.startsWith(build.shortCommit);
      unawaited(_finish(build, matches ? 'running' : 'mismatch', detail));
    }

    void check() {
      final snapshot = _ref.read(companionSnapshotProvider).valueOrNull;
      if (snapshot == null || !snapshot.protocolReady) return;
      final fresh = (snapshot.versionObservedMs ?? 0) > _uploadStartedMs;
      if (fresh && snapshot.firmwareSha != null) return done();
      // Older firmware sends no sha; give the version message time to arrive.
      noSha ??= Timer(const Duration(seconds: 20), done);
    }

    _connectionWatch = _ref.listen<Object?>(
      companionSnapshotProvider,
      (_, _) => check(),
    );
    check();
  }

  Future<void> _finish(DevOtaBuild build, String result, String? detail) async {
    _dfuWatch?.close();
    _connectionWatch?.close();
    state = state.copyWith(
      installingId: () => null,
      phase: () => result == 'running' ? 'Installed ${build.id}' : null,
      error: () => switch (result) {
        'failed' => detail,
        'mismatch' => 'Watch reports a different build: $detail',
        _ => null,
      },
    );
    await _report(build.id, result, detail: detail);
  }

  Future<void> _report(String id, String result, {String? detail}) async {
    for (var attempt = 1; attempt <= 4; attempt++) {
      try {
        await _client?.report(id, result, detail: detail);
        return;
      } catch (error) {
        debugPrint(
          '[DevOtaController] report $result attempt $attempt: $error',
        );
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }

  @override
  void dispose() {
    _loopGeneration++;
    _lifecycle.dispose();
    _dfuWatch?.close();
    _connectionWatch?.close();
    _client?.close();
    super.dispose();
  }
}
