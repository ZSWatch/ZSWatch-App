import 'package:freezed_annotation/freezed_annotation.dart';

part 'watch.freezed.dart';

/// Watch model representing a paired ZSWatch device
///
/// This is a domain model used throughout the app. It's mapped from
/// the database entity (WatchEntity) and contains business logic.
@freezed
abstract class Watch with _$Watch {
  const Watch._();

  const factory Watch({
    /// BLE device identifier (MAC address on Android, UUID on iOS)
    required String id,

    /// Advertised device name
    required String name,

    /// User-defined custom name for the watch (FR-099 to FR-102)
    String? customName,

    /// Last known firmware version
    String? firmwareVersion,

    /// Hardware revision
    String? hardwareVersion,

    /// Last known battery level (0-100)
    int? batteryLevel,

    /// Whether this is the currently selected watch
    @Default(false) bool isPrimary,

    /// Whether firmware supports Extended ZSWatch API
    @Default(false) bool supportsExtendedApi,

    /// Last successful connection timestamp
    DateTime? lastConnectedAt,

    /// When the device was first paired
    required DateTime createdAt,
  }) = _Watch;

  /// Create a Watch from a scanned device (before pairing)
  factory Watch.fromScan({required String id, required String name}) {
    return Watch(id: id, name: name, createdAt: DateTime.now());
  }

  /// Whether the watch has been connected at least once
  bool get hasConnected => lastConnectedAt != null;

  /// Whether battery level is known
  bool get hasBatteryInfo => batteryLevel != null;

  /// Whether battery is low (below 20%)
  bool get isBatteryLow => batteryLevel != null && batteryLevel! < 20;

  /// Whether battery is critical (below 10%)
  bool get isBatteryCritical => batteryLevel != null && batteryLevel! < 10;

  /// Display name (prefers customName, falls back to name, then shortened ID)
  String get displayName {
    if (customName != null && customName!.isNotEmpty) return customName!;
    if (name.isNotEmpty) return name;
    // Show last 4 chars of ID as fallback
    if (id.length > 4) return '...${id.substring(id.length - 4)}';
    return id;
  }

  /// Short firmware version (just version number)
  String? get shortFirmwareVersion {
    if (firmwareVersion == null) return null;
    // Remove common prefixes like "v" or "ZSWatch "
    return firmwareVersion!
        .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^ZSWatch\s*', caseSensitive: false), '')
        .trim();
  }
}
