import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_theme.dart';

class AudioPlaybackBar extends StatefulWidget {
  final String? filePath;
  const AudioPlaybackBar({super.key, required this.filePath});

  @override
  State<AudioPlaybackBar> createState() => _AudioPlaybackBarState();
}

class _AudioPlaybackBarState extends State<AudioPlaybackBar> {
  AudioPlayer? _player;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  String? _error;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant AudioPlaybackBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _releasePlayer();
      _position = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
      _error = null;
      unawaited(_initPlayer());
    }
  }

  Future<void> _initPlayer() async {
    final generation = ++_generation;
    final path = widget.filePath;
    if (path == null || !File(path).existsSync()) {
      setState(() => _error = 'Audio file not found');
      return;
    }
    try {
      final player = AudioPlayer();
      _player = player;
      _durationSubscription = player.durationStream.listen(
        (duration) {
          if (duration != null && mounted && generation == _generation) {
            setState(() => _duration = duration);
          }
        },
        onError: (Object error, StackTrace stack) => _playbackError(generation),
      );
      _positionSubscription = player.positionStream.listen(
        (position) {
          if (mounted && generation == _generation) {
            setState(() => _position = position);
          }
        },
        onError: (Object error, StackTrace stack) => _playbackError(generation),
      );
      _stateSubscription = player.playerStateStream.listen(
        (state) {
          if (!mounted || generation != _generation) return;
          setState(() => _isPlaying = state.playing);
          if (state.processingState == ProcessingState.completed) {
            _control(() async {
              await player.pause();
              await player.seek(Duration.zero);
            });
          }
        },
        onError: (Object error, StackTrace stack) => _playbackError(generation),
      );
      final duration = await player.setFilePath(path);
      if (duration != null && mounted && generation == _generation) {
        setState(() => _duration = duration);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Failed to load audio');
      }
    }
  }

  void _playbackError(int generation) {
    if (mounted && generation == _generation) {
      setState(() => _error = 'Could not play audio');
    }
  }

  void _control(Future<void> Function() action) {
    final generation = _generation;
    unawaited(() async {
      try {
        await action();
      } catch (error) {
        if (mounted && generation == _generation) {
          setState(() => _error = 'Could not play audio');
        }
      }
    }());
  }

  void _releasePlayer() {
    _generation++;
    unawaited(_positionSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    final player = _player;
    _player = null;
    if (player != null) unawaited(player.dispose());
  }

  @override
  void dispose() {
    _releasePlayer();
    super.dispose();
  }

  String _formatDuration(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: AppTheme.errorColor));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurfaceColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Play button
          Tooltip(
            message: _isPlaying ? 'Pause audio' : 'Play audio',
            child: GestureDetector(
              onTap: () {
                if (_isPlaying) {
                  _control(() async => _player?.pause());
                } else {
                  _control(() async => _player?.play());
                }
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                padding: EdgeInsets.zero,
                value: _duration.inMilliseconds == 0
                    ? 0
                    : _position.inMilliseconds
                          .clamp(0, _duration.inMilliseconds)
                          .toDouble(),
                max: _duration.inMilliseconds == 0
                    ? 1
                    : _duration.inMilliseconds.toDouble(),
                onChanged: (value) => _control(
                  () async =>
                      _player?.seek(Duration(milliseconds: value.toInt())),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
