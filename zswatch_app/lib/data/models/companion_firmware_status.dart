import 'dart:typed_data';

import 'dfu_state.dart';

/// Metadata only. Native Nordic owns payloads, upgrade and boot verification.
class CompanionFirmwareStatus {
  static const maxImageBytes = 8 * 1024 * 1024;
  static const activePhases = {
    'validating',
    'uploading',
    'applying',
    'rebooting',
    'reconnecting',
    'verifying',
  };
  final String id, address, phase;
  final int generation, current, total;
  final List<int> indices;
  final String? error;
  final bool resultUnknown, cancelRequested;
  const CompanionFirmwareStatus._(
    this.id,
    this.address,
    this.phase,
    this.generation,
    this.current,
    this.total,
    this.indices,
    this.error,
    this.resultUnknown,
    this.cancelRequested,
  );
  bool get busy => activePhases.contains(phase);
  bool get canCancel => phase == 'uploading' && !cancelRequested;

  static bool validId(Object? id) =>
      id is String && id.isNotEmpty && id.length <= 64;
  static CompanionFirmwareStatus? decode(Map<String, Object?> fields) {
    final value = fields['firmware_operation'];
    if (value == null) return null;
    if (value is! Map ||
        !validId(value['id']) ||
        value['address'] is! String ||
        !RegExp(
          r'^[0-9A-F]{2}(:[0-9A-F]{2}){5}$',
        ).hasMatch(value['address'] as String) ||
        value['generation'] is! int ||
        (value['generation'] as int) < 0 ||
        !{
          ...activePhases,
          'completed',
          'failed',
          'cancelled',
        }.contains(value['phase']) ||
        value['current'] is! int ||
        value['total'] is! int ||
        (value['current'] as int) < 0 ||
        (value['total'] as int) < 0 ||
        (value['current'] as int) > (value['total'] as int) ||
        (value['total'] as int) > maxImageBytes ||
        value['result_unknown'] is! bool ||
        value['cancel_requested'] is! bool ||
        (value['phase'] == 'completed' &&
            (value['result_unknown'] != false || value['error'] != null)) ||
        (value['error'] != null && (!validId(value['error']))) ||
        value['targets'] is! List) {
      throw const FormatException('Unsupported firmware operation status');
    }
    final targets = value['targets'] as List;
    if (targets.isEmpty || targets.length > 3) {
      throw const FormatException('Unsupported firmware targets');
    }
    final indices = <int>[];
    for (final target in targets) {
      if (target is! Map ||
          target['index'] is! int ||
          (target['index'] as int) < 0 ||
          (target['index'] as int) > 2 ||
          indices.contains(target['index']) ||
          target['bytes'] is! int ||
          (target['bytes'] as int) < 1 ||
          (target['bytes'] as int) > maxImageBytes ||
          target['hash'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(target['hash'] as String)) {
        throw const FormatException('Unsupported firmware target');
      }
      indices.add(target['index'] as int);
    }
    return CompanionFirmwareStatus._(
      value['id'] as String,
      value['address'] as String,
      value['phase'] as String,
      value['generation'] as int,
      value['current'] as int,
      value['total'] as int,
      List.unmodifiable(indices),
      value['error'] as String?,
      value['result_unknown'] as bool,
      value['cancel_requested'] as bool,
    );
  }

  String? get errorMessage {
    if (error == null && !resultUnknown) return null;
    final reason = switch (error) {
      'boot_check_unavailable' =>
        'The watch does not report every selected image after reboot.',
      'boot_check_failed' =>
        'The active images could not be verified after reboot.',
      'boot_check_timeout' =>
        'The watch did not reconnect and verify the update in time.',
      'interrupted' => 'The firmware operation was interrupted.',
      'cancelled' => 'The firmware upload was cancelled.',
      _ => 'The firmware operation did not complete.',
    };
    return resultUnknown
        ? '$reason The installed firmware is unverified. Check the watch before starting another update.'
        : reason;
  }

  DfuState get dfuState => DfuState(
    status: switch (phase) {
      'uploading' => DfuStatus.uploading,
      'validating' => DfuStatus.validating,
      'applying' => DfuStatus.applying,
      'rebooting' => DfuStatus.rebooting,
      'reconnecting' || 'verifying' => DfuStatus.reconnecting,
      'completed' => DfuStatus.completed,
      'cancelled' when !resultUnknown => DfuStatus.cancelled,
      _ => DfuStatus.failed,
    },
    progress: phase == 'completed'
        ? 1
        : total == 0
        ? 0
        : current / total,
    bytesTransferred: current,
    totalBytes: total,
    // SDK progress is for the current image; its callback has no image index.
    totalImages: 1,
    currentImageName: phase == 'verifying'
        ? 'Checking active firmware after reboot'
        : indices.length > 1
        ? 'Current image transfer (${indices.length} images selected)'
        : null,
    errorMessage: errorMessage,
  );
}

class CompanionFirmwareImage {
  final int index;
  final Uint8List bytes;
  const CompanionFirmwareImage(this.index, this.bytes);
  static void validate(List<CompanionFirmwareImage> images) {
    if (images.isEmpty ||
        images.length > 3 ||
        images.map((image) => image.index).toSet().length != images.length ||
        images.any(
          (image) =>
              image.index < 0 ||
              image.index > 2 ||
              image.bytes.isEmpty ||
              image.bytes.length > CompanionFirmwareStatus.maxImageBytes,
        )) {
      throw const FormatException(
        'Expected one to three distinct firmware images',
      );
    }
  }
}

class CompanionFirmwareAcceptance {
  final String id;
  final int generation;
  const CompanionFirmwareAcceptance(this.id, this.generation);
}
