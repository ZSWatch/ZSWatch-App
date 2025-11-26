/// BLE Service and Characteristic UUIDs for ZSWatch
///
/// Contains all UUID constants for communication with ZSWatch:
/// - Nordic UART Service (NUS) for Gadgetbridge protocol
/// - Extended ZSWatch API service
/// - Standard BLE services (Heart Rate, Battery, Device Info)
/// - MCUmgr/SMP service for firmware updates
library;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Nordic UART Service (NUS) UUIDs for Gadgetbridge protocol
abstract final class NusUuids {
  /// Nordic UART Service UUID
  static final Guid service =
      Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');

  /// TX Characteristic - Write (App to Watch)
  static final Guid txCharacteristic =
      Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');

  /// RX Characteristic - Notify (Watch to App)
  static final Guid rxCharacteristic =
      Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');
}

/// ZSWatch Extended API Service UUIDs
abstract final class ZswatchExtendedUuids {
  /// ZSWatch Extended Service UUID
  static final Guid service =
      Guid('12345678-1234-5678-1234-56789abcdef0');

  /// TX Characteristic - Write (App to Watch)
  static final Guid txCharacteristic =
      Guid('12345678-1234-5678-1234-56789abcdef1');

  /// RX Characteristic - Notify (Watch to App)
  static final Guid rxCharacteristic =
      Guid('12345678-1234-5678-1234-56789abcdef2');
}

/// Standard Heart Rate Service UUIDs (GATT 0x180D)
abstract final class HeartRateUuids {
  /// Heart Rate Service UUID
  static final Guid service =
      Guid('0000180d-0000-1000-8000-00805f9b34fb');

  /// Heart Rate Measurement Characteristic
  static final Guid measurement =
      Guid('00002a37-0000-1000-8000-00805f9b34fb');

  /// Body Sensor Location Characteristic
  static final Guid bodySensorLocation =
      Guid('00002a38-0000-1000-8000-00805f9b34fb');
}

/// Standard Battery Service UUIDs (GATT 0x180F)
abstract final class BatteryUuids {
  /// Battery Service UUID
  static final Guid service =
      Guid('0000180f-0000-1000-8000-00805f9b34fb');

  /// Battery Level Characteristic
  static final Guid level =
      Guid('00002a19-0000-1000-8000-00805f9b34fb');
}

/// Standard Device Information Service UUIDs (GATT 0x180A)
abstract final class DeviceInfoUuids {
  /// Device Information Service UUID
  static final Guid service =
      Guid('0000180a-0000-1000-8000-00805f9b34fb');

  /// Manufacturer Name String
  static final Guid manufacturerName =
      Guid('00002a29-0000-1000-8000-00805f9b34fb');

  /// Model Number String
  static final Guid modelNumber =
      Guid('00002a24-0000-1000-8000-00805f9b34fb');

  /// Firmware Revision String
  static final Guid firmwareRevision =
      Guid('00002a26-0000-1000-8000-00805f9b34fb');

  /// Hardware Revision String
  static final Guid hardwareRevision =
      Guid('00002a27-0000-1000-8000-00805f9b34fb');

  /// Software Revision String
  static final Guid softwareRevision =
      Guid('00002a28-0000-1000-8000-00805f9b34fb');
}

/// MCUmgr/SMP Service UUIDs for firmware updates
abstract final class McumgrUuids {
  /// SMP Service UUID
  static final Guid service =
      Guid('8d53dc1d-1db7-4cd3-868b-8a527460aa84');

  /// SMP Characteristic (bidirectional)
  static final Guid characteristic =
      Guid('da2e7828-fbce-4e01-ae9e-261174997c48');
}

/// ZSWatch Sensor Service UUIDs
abstract final class SensorServiceUuids {
  /// ZSWatch Sensor Service UUID
  static final Guid service =
      Guid('e6c90001-2a76-4094-917e-9af7d7a7a5b1');

  /// Accelerometer Data Characteristic
  static final Guid accelerometer =
      Guid('e6c90002-2a76-4094-917e-9af7d7a7a5b1');

  /// Gyroscope Data Characteristic
  static final Guid gyroscope =
      Guid('e6c90003-2a76-4094-917e-9af7d7a7a5b1');

  /// PPG (Photoplethysmography) Data Characteristic
  static final Guid ppg =
      Guid('e6c90004-2a76-4094-917e-9af7d7a7a5b1');

  /// Temperature Data Characteristic
  static final Guid temperature =
      Guid('e6c90005-2a76-4094-917e-9af7d7a7a5b1');
}

