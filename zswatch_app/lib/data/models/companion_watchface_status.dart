import 'dart:typed_data';
import 'companion_watch_identity.dart';

class CompanionWatchfaceStatus {
  final String id, address, action, phase, name;
  final int generation, current, total;
  final String? error;
  final bool applicationUncertain;
  const CompanionWatchfaceStatus._(
    this.id,
    this.address,
    this.action,
    this.phase,
    this.name,
    this.generation,
    this.current,
    this.total,
    this.error,
    this.applicationUncertain,
  );
  static const imageBytes = 12 + 240 * 240 * 2;
  static const activePhases = {
    'uploading',
    'verifying',
    'applying',
    'resetting',
  };
  bool get busy => activePhases.contains(phase);
  bool get uploading => phase == 'uploading' || phase == 'verifying';
  double get progress => total == 0 ? 0 : current / total;

  static void validateImage(Uint8List bytes) {
    const header = [0x19, 0x12, 0, 0, 0xf0, 0, 0xf0, 0, 0xe0, 1, 0, 0];
    if (bytes.length != imageBytes ||
        List.generate(12, (i) => bytes[i] == header[i]).contains(false)) {
      throw const FormatException('Expected a 240x240 RGB565 background');
    }
  }

  static CompanionWatchfaceStatus? decode(Map<String, Object?> fields) {
    final value = fields['watchface_operation'];
    if (value == null) return null;
    if (value is! Map ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        (value['id'] as String).length > 64 ||
        value['address'] is! String ||
        !isCompanionWatchAddress(value['address'] as String) ||
        value['generation'] is! int ||
        (value['generation'] as int) < 0 ||
        !{'apply', 'reset'}.contains(value['action']) ||
        !{...activePhases, 'completed', 'failed'}.contains(value['phase']) ||
        value['name'] is! String ||
        (value['name'] as String).isEmpty ||
        (value['name'] as String).length > 64 ||
        value['current'] is! int ||
        value['total'] is! int ||
        (value['current'] as int) < 0 ||
        (value['current'] as int) > (value['total'] as int) ||
        (value['total'] != 0 && value['total'] != imageBytes) ||
        (value['action'] == 'reset' && value['total'] != 0) ||
        (value['action'] == 'apply' && value['total'] != imageBytes) ||
        value['application_uncertain'] is! bool ||
        (value['error'] != null &&
            (value['error'] is! String ||
                (value['error'] as String).length > 64))) {
      throw const FormatException('Unsupported watchface operation status');
    }
    return CompanionWatchfaceStatus._(
      value['id'] as String,
      value['address'] as String,
      value['action'] as String,
      value['phase'] as String,
      value['name'] as String,
      value['generation'] as int,
      value['current'] as int,
      value['total'] as int,
      value['error'] as String?,
      value['application_uncertain'] as bool,
    );
  }
}
