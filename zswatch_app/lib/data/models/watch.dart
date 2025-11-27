import 'package:equatable/equatable.dart';

/// Watch model representing a paired ZSWatch device
///
/// This is a domain model used throughout the app. It's mapped from
/// the database entity (WatchEntity) and contains business logic.
class Watch extends Equatable {
  /// BLE device identifier (MAC address on Android, UUID on iOS)
  final String id;

  /// Advertised device name
  final String name;

  /// User-defined custom name for the watch (FR-099 to FR-102)
  final String? customName;

  /// Last known firmware version
  final String? firmwareVersion;

  /// Hardware revision
  final String? hardwareVersion;

  /// Last known battery level (0-100)
  final int? batteryLevel;

  /// Whether this is the currently selected watch
  final bool isPrimary;

  /// Whether firmware supports Extended ZSWatch API
  final bool supportsExtendedApi;

  /// Last successful connection timestamp
  final DateTime? lastConnectedAt;

  /// When the device was first paired
  final DateTime createdAt;

  const Watch({
    required this.id,
    required this.name,
    this.customName,
    this.firmwareVersion,
    this.hardwareVersion,
    this.batteryLevel,
    this.isPrimary = false,
    this.supportsExtendedApi = false,
    this.lastConnectedAt,
    required this.createdAt,
  });

  /// Create a Watch from a scanned device (before pairing)
  factory Watch.fromScan({
    required String id,
    required String name,
  }) {
    return Watch(
      id: id,
      name: name,
      createdAt: DateTime.now(),
    );
  }

  /// Copy with modified fields
  Watch copyWith({
    String? id,
    String? name,
    String? customName,
    String? firmwareVersion,
    String? hardwareVersion,
    int? batteryLevel,
    bool? isPrimary,
    bool? supportsExtendedApi,
    DateTime? lastConnectedAt,
    DateTime? createdAt,
  }) {
    return Watch(
      id: id ?? this.id,
      name: name ?? this.name,
      customName: customName ?? this.customName,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isPrimary: isPrimary ?? this.isPrimary,
      supportsExtendedApi: supportsExtendedApi ?? this.supportsExtendedApi,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      createdAt: createdAt ?? this.createdAt,
    );
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

  @override
  List<Object?> get props => [
        id,
        name,
        customName,
        firmwareVersion,
        hardwareVersion,
        batteryLevel,
        isPrimary,
        supportsExtendedApi,
        lastConnectedAt,
        createdAt,
      ];

  @override
  String toString() {
    return 'Watch(id: $id, name: $name, battery: $batteryLevel%, fw: $firmwareVersion)';
  }
}

