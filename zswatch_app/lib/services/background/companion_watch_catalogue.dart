import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import 'companion_prototype_client.dart';

bool isCompanionWatchAddress(String id) =>
    RegExp(r'^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$').hasMatch(id);

/// A native Ready receipt is historical metadata, never running intent.
class CompanionWatchMetadata {
  final String address;
  final int generation;
  final DateTime readyAt;
  final String? firmware;
  final String? hardware;
  final int? battery;

  const CompanionWatchMetadata({
    required this.address,
    required this.generation,
    required this.readyAt,
    this.firmware,
    this.hardware,
    this.battery,
  });

  static CompanionWatchMetadata? fromSnapshot(
    CompanionPrototypeSnapshot snapshot,
  ) {
    final fields = snapshot.fields;
    final receipt = fields['last_ready'];
    if (receipt is! Map) return null;
    final address = receipt['address'];
    final generation = receipt['generation'];
    final millis = receipt['utc_ms'];
    if (address is! String ||
        !isCompanionWatchAddress(address) ||
        address != fields['address'] ||
        generation is! int ||
        generation < 1 ||
        generation > snapshot.generation ||
        millis is! int ||
        millis <= 0 ||
        millis > 8640000000000000) {
      return null;
    }
    final forgotten = fields['forgotten_watches'];
    final forgottenGeneration = forgotten is Map
        ? forgotten[address.toUpperCase()]
        : null;
    if (forgottenGeneration is int && generation <= forgottenGeneration) {
      return null;
    }
    final info = fields['watch_info'];
    final matching = info is Map && info['address'] == address;
    String? version(String key) {
      if (!matching || info['version_generation'] != generation) return null;
      final value = info[key];
      return value is String &&
              value.trim().isNotEmpty &&
              utf8.encode(value).length <= 160
          ? value
          : null;
    }

    final battery = matching && info['status_generation'] == generation
        ? info['battery_level']
        : null;
    return CompanionWatchMetadata(
      address: address.toUpperCase(),
      generation: generation,
      // Drift stores seconds. Normalize once for idempotent reattachment.
      readyAt: DateTime.fromMillisecondsSinceEpoch(
        millis ~/ 1000 * 1000,
        isUtc: true,
      ),
      firmware: version('firmware_version'),
      hardware: version('hardware_version'),
      battery: battery is int && battery >= 0 && battery <= 100
          ? battery
          : null,
    );
  }

  String get fingerprint => jsonEncode([
    address,
    generation,
    readyAt.millisecondsSinceEpoch,
    firmware,
    hardware,
    battery,
  ]);
}

/// Projects only verified native metadata. It never changes primary selection,
/// custom names, row identity/history, voice state, or native running intent.
class CompanionWatchCatalogue {
  final AppDatabase db;
  const CompanionWatchCatalogue(this.db);

  Future<void> save(
    CompanionWatchMetadata metadata,
  ) => db.transaction(() async {
    final matches = await (db.select(
      db.watches,
    )..where((row) => row.id.upper().equals(metadata.address))).get();
    final exact = matches.where((row) => row.id == metadata.address).toList();
    final selected = exact.isNotEmpty ? exact : matches;
    if (selected.length > 1) throw StateError('Ambiguous saved watch aliases');
    final existing = selected.isEmpty ? null : selected.single;
    if (existing == null) {
      await db
          .into(db.watches)
          .insert(
            WatchesCompanion.insert(
              id: metadata.address,
              name: 'ZSWatch',
              createdAt: metadata.readyAt,
              lastConnectedAt: Value(metadata.readyAt),
              firmwareVersion: Value(metadata.firmware),
              hardwareVersion: Value(metadata.hardware),
              batteryLevel: Value(metadata.battery),
            ),
          );
      return;
    }
    // Out-of-order observations cannot regress newer saved metadata/history.
    if (existing.lastConnectedAt != null &&
        existing.lastConnectedAt!.isAfter(metadata.readyAt)) {
      return;
    }
    final changes = WatchesCompanion(
      lastConnectedAt:
          existing.lastConnectedAt?.isAtSameMomentAs(metadata.readyAt) == true
          ? const Value.absent()
          : Value(metadata.readyAt),
      firmwareVersion:
          metadata.firmware == null ||
              metadata.firmware == existing.firmwareVersion
          ? const Value.absent()
          : Value(metadata.firmware),
      hardwareVersion:
          metadata.hardware == null ||
              metadata.hardware == existing.hardwareVersion
          ? const Value.absent()
          : Value(metadata.hardware),
      batteryLevel:
          metadata.battery == null || metadata.battery == existing.batteryLevel
          ? const Value.absent()
          : Value(metadata.battery),
    );
    if (changes.toColumns(false).isNotEmpty) {
      await (db.update(
        db.watches,
      )..where((row) => row.id.equals(existing.id))).write(changes);
    }
  });
}
