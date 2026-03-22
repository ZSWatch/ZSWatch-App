import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/watch_service_provider.dart';

/// Debug section for sending test music metadata to the watch.
///
/// Features (FR-098):
/// - Buttons for sample tracks with different static metadata
/// - Play/Pause state toggle
/// - Useful for testing music display without actual playback
class MusicDebugSection extends ConsumerStatefulWidget {
  const MusicDebugSection({super.key});

  @override
  ConsumerState<MusicDebugSection> createState() => _MusicDebugSectionState();
}

class _MusicDebugSectionState extends ConsumerState<MusicDebugSection> {
  bool _isPlaying = false;
  int? _currentTrack;
  bool _isSending = false;

  static const List<_SampleTrack> _sampleTracks = [
    _SampleTrack(
      id: 1,
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      album: 'A Night at the Opera',
      durationSeconds: 354,
    ),
    _SampleTrack(
      id: 2,
      title: 'Stairway to Heaven',
      artist: 'Led Zeppelin',
      album: 'Led Zeppelin IV',
      durationSeconds: 482,
    ),
  ];

  Future<void> _sendTrack(_SampleTrack track) async {
    if (_isSending) return;

    final watchService = ref.read(watchServiceProvider);
    if (!watchService.isConnected) {
      _showSnackBar('Watch not connected', isError: true);
      return;
    }

    setState(() {
      _isSending = true;
      _currentTrack = track.id;
    });

    try {
      // Send track info
      await watchService.sendMusicInfo(
        artist: track.artist,
        album: track.album,
        track: track.title,
        durationSeconds: track.durationSeconds,
        trackNumber: track.id,
        trackCount: _sampleTracks.length,
      );

      // Also send play state
      await watchService.sendMusicState(
        state: _isPlaying ? 'play' : 'pause',
        positionSeconds: 0,
      );

      _showSnackBar('Sent: ${track.artist} - ${track.title}');
    } catch (e) {
      _showSnackBar('Failed to send: $e', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _togglePlayState() async {
    final watchService = ref.read(watchServiceProvider);
    if (!watchService.isConnected) {
      _showSnackBar('Watch not connected', isError: true);
      return;
    }

    final newState = !_isPlaying;
    setState(() => _isPlaying = newState);

    try {
      await watchService.sendMusicState(
        state: newState ? 'play' : 'pause',
        positionSeconds: 0,
      );
      _showSnackBar(newState ? 'Playing' : 'Paused');
    } catch (e) {
      _showSnackBar('Failed to send: $e', isError: true);
    }
  }

  Future<void> _stopMusic() async {
    final watchService = ref.read(watchServiceProvider);
    if (!watchService.isConnected) {
      _showSnackBar('Watch not connected', isError: true);
      return;
    }

    setState(() {
      _isPlaying = false;
      _currentTrack = null;
    });

    try {
      await watchService.sendMusicState(state: 'stop', positionSeconds: 0);
      _showSnackBar('Stopped');
    } catch (e) {
      _showSnackBar('Failed to send: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(watchConnectionProvider);
    final isConnected = connection.isConnected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.music_note,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  'Music Debug',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: isConnected ? _stopMusic : null,
                  icon: const Icon(Icons.stop),
                  tooltip: 'Stop',
                  iconSize: 28,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                FilledButton.icon(
                  onPressed: isConnected ? _togglePlayState : null,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? 'Pause' : 'Play'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(100, 40),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Sample tracks section
            Text(
              'Sample Tracks',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingSm),

            // Track list
            ...List.generate(_sampleTracks.length, (index) {
              final track = _sampleTracks[index];
              final isSelected = _currentTrack == track.id;
              return _TrackTile(
                track: track,
                isSelected: isSelected,
                isPlaying: isSelected && _isPlaying,
                enabled: isConnected && !_isSending,
                onTap: () => _sendTrack(track),
              );
            }),

            if (!isConnected) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Connect to watch to send music info',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.warningColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SampleTrack {
  final int id;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;

  const _SampleTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
  });

  String get durationString {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _TrackTile extends StatelessWidget {
  final _SampleTrack track;
  final bool isSelected;
  final bool isPlaying;
  final bool enabled;
  final VoidCallback onTap;

  const _TrackTile({
    required this.track,
    required this.isSelected,
    required this.isPlaying,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
      ),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isSelected
            ? AppTheme.primaryColor
            : AppTheme.surfaceColor,
        child: isPlaying
            ? const Icon(Icons.equalizer, size: 16, color: Colors.white)
            : Text(
                '${track.id}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
      ),
      title: Text(
        track.title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${track.artist} • ${track.durationString}',
        style: const TextStyle(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      enabled: enabled,
      onTap: onTap,
    );
  }
}
