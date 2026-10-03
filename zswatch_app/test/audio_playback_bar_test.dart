import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:zswatch_app/ui/widgets/voice_memos/audio_playback_bar.dart';

class PlaybackPlatform extends JustAudioPlatform {
  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async => DisposeAllPlayersResponse();
  final players = <PlaybackPlayer>[];
  bool holdLoad = false;
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = PlaybackPlayer(request.id, holdLoad);
    players.add(player);
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    final player = players.singleWhere((p) => p.id == request.id);
    player.disposed = true;
    return DisposePlayerResponse();
  }
}

class PlaybackPlayer extends AudioPlayerPlatform {
  PlaybackPlayer(super.id, this.holdLoad);
  final bool holdLoad;
  final gate = Completer<void>();
  final events = StreamController<PlaybackEventMessage>.broadcast();
  int plays = 0;
  int pauses = 0;
  bool disposed = false;
  final seeks = <Duration?>[];
  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;
  void emit(ProcessingStateMessage state) => events.add(
    PlaybackEventMessage(
      processingState: state,
      updateTime: DateTime.now(),
      updatePosition: Duration.zero,
      bufferedPosition: const Duration(seconds: 5),
      duration: const Duration(seconds: 5),
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    ),
  );
  @override
  Future<LoadResponse> load(LoadRequest request) async {
    if (holdLoad) await gate.future;
    if (!disposed) emit(ProcessingStateMessage.ready);
    return LoadResponse(duration: const Duration(seconds: 5));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    plays++;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    pauses++;
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    seeks.add(request.position);
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();
  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();
  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();
  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();
}

void main() {
  late Directory root;
  late File file;
  late PlaybackPlatform platform;
  late JustAudioPlatform previous;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('audio-bar-');
    file = await File('${root.path}/fixture.ogg').writeAsBytes([1]);
    previous = JustAudioPlatform.instance;
    platform = PlaybackPlatform();
    JustAudioPlatform.instance = platform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => call.method == 'setActive' ? true : null,
        );
  });
  tearDown(() async {
    JustAudioPlatform.instance = previous;
    for (final player in platform.players) {
      await player.events.close();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          null,
        );
    await root.delete(recursive: true);
  });
  Widget view(String? path) => MaterialApp(
    home: Scaffold(body: AudioPlaybackBar(filePath: path)),
  );

  testWidgets(
    'loads without autoplay; explicit controls and completion reset are local',
    (tester) async {
      await tester.pumpWidget(view(file.path));
      await tester.pumpAndSettle();
      final player = platform.players.single;
      expect(player.plays, 0);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(
        find.text('0:00 / 0:05'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .toString(),
      );
      await tester.tap(find.byTooltip('Play audio'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(
        player.plays,
        1,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .toString(),
      );
      await tester.tap(find.byTooltip('Pause audio'));
      await tester.pumpAndSettle();
      expect(player.pauses, greaterThan(0));
      player.emit(ProcessingStateMessage.completed);
      await tester.pump();
      await tester.pump();
      expect(player.seeks.last, Duration.zero);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(player.disposed, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposal fences a pending audio load', (tester) async {
    platform.holdLoad = true;
    await tester.pumpWidget(view(file.path));
    await tester.pumpAndSettle();
    final player = platform.players.single;
    await tester.pumpWidget(const SizedBox());
    player.gate.complete();
    await tester.pumpAndSettle();
    expect(player.disposed, true);
    expect(player.plays, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'changing path releases the old player; a missing file creates none',
    (tester) async {
      await tester.pumpWidget(view(file.path));
      await tester.pumpAndSettle();
      final old = platform.players.single;
      await tester.pumpWidget(view('${root.path}/missing.ogg'));
      await tester.pumpAndSettle();
      expect(old.disposed, true);
      expect(find.text('Audio file not found'), findsOneWidget);
      expect(platform.players, hasLength(1));
      await tester.pumpWidget(view(file.path));
      await tester.pumpAndSettle();
      expect(platform.players, hasLength(2));
      expect(platform.players.last.plays, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
