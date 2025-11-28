/// BLE Constants for ZSWatch communication
///
/// Contains UUIDs for Nordic UART Service (NUS), Gadgetbridge protocol,
/// and ZSWatch-specific services.
library;

/// Nordic UART Service (NUS) UUIDs
///
/// Used for Gadgetbridge protocol communication over BLE.
abstract final class NusUuids {
  /// Nordic UART Service UUID
  static const String service = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

  /// TX Characteristic - Write (App to Watch)
  static const String txCharacteristic = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  /// RX Characteristic - Notify (Watch to App)
  static const String rxCharacteristic = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
}

/// ZSWatch Extended API Service UUIDs
///
/// Used for features not covered by Gadgetbridge:
/// - Bulk health sync
/// - Log streaming
/// - Shell commands
/// - Voice memo transfer
abstract final class ZswatchExtendedUuids {
  /// ZSWatch Extended Service UUID (TBD - coordinate with firmware)
  static const String service = '12345678-1234-5678-1234-56789abcdef0';

  /// TX Characteristic - Write (App to Watch)
  static const String txCharacteristic = '12345678-1234-5678-1234-56789abcdef1';

  /// RX Characteristic - Notify (Watch to App)
  static const String rxCharacteristic = '12345678-1234-5678-1234-56789abcdef2';
}

/// Standard Bluetooth Heart Rate Service UUIDs (GATT)
abstract final class HeartRateUuids {
  /// Heart Rate Service UUID (0x180D)
  static const String service = '0000180d-0000-1000-8000-00805f9b34fb';

  /// Heart Rate Measurement Characteristic (0x2A37)
  static const String measurement = '00002a37-0000-1000-8000-00805f9b34fb';

  /// Body Sensor Location Characteristic (0x2A38)
  static const String bodySensorLocation = '00002a38-0000-1000-8000-00805f9b34fb';
}

/// ZSWatch Sensor Service UUIDs (Adafruit Bluefruit format)
///
/// GATT services for streaming raw sensor data.
/// Implemented in zsw_gatt_sensor_server.c on firmware using Adafruit UUIDs.
/// Each sensor is a separate GATT service with one characteristic.
abstract final class SensorServiceUuids {
  /// Temperature Service UUID (ADAFRUIT_SERVICE_TEMPERATURE 0xADAF0100)
  static const String temperatureService = 'adaf0100-c332-42a8-93bd-25e905756cb8';
  
  /// Temperature Characteristic UUID (ADAFRUIT_CHAR_TEMPERATURE 0xADAF0101)
  static const String temperatureChar = 'adaf0101-c332-42a8-93bd-25e905756cb8';

  /// Accelerometer Service UUID (ADAFRUIT_SERVICE_ACCEL 0xADAF0200)
  static const String accelerometerService = 'adaf0200-c332-42a8-93bd-25e905756cb8';
  
  /// Accelerometer Characteristic UUID (ADAFRUIT_CHAR_ACCEL 0xADAF0201)
  static const String accelerometerChar = 'adaf0201-c332-42a8-93bd-25e905756cb8';

  /// Light Sensor Service UUID (ADAFRUIT_SERVICE_LIGHT 0xADAF0300)
  static const String lightService = 'adaf0300-c332-42a8-93bd-25e905756cb8';
  
  /// Light Sensor Characteristic UUID (ADAFRUIT_CHAR_LIGHT 0xADAF0301)
  static const String lightChar = 'adaf0301-c332-42a8-93bd-25e905756cb8';

  /// Gyroscope Service UUID (ADAFRUIT_SERVICE_GYRO 0xADAF0400)
  static const String gyroscopeService = 'adaf0400-c332-42a8-93bd-25e905756cb8';
  
  /// Gyroscope Characteristic UUID (ADAFRUIT_CHAR_GYRO 0xADAF0401)
  static const String gyroscopeChar = 'adaf0401-c332-42a8-93bd-25e905756cb8';

  /// Magnetometer Service UUID (ADAFRUIT_SERVICE_MAG 0xADAF0500)
  static const String magnetometerService = 'adaf0500-c332-42a8-93bd-25e905756cb8';
  
  /// Magnetometer Characteristic UUID (ADAFRUIT_CHAR_MAG 0xADAF0501)
  static const String magnetometerChar = 'adaf0501-c332-42a8-93bd-25e905756cb8';

  /// Humidity Service UUID (ADAFRUIT_SERVICE_HUMIDITY 0xADAF0700)
  static const String humidityService = 'adaf0700-c332-42a8-93bd-25e905756cb8';
  
  /// Humidity Characteristic UUID (ADAFRUIT_CHAR_HUMIDITY 0xADAF0701)
  static const String humidityChar = 'adaf0701-c332-42a8-93bd-25e905756cb8';

  /// Pressure Service UUID (ADAFRUIT_SERVICE_PRESSURE 0xADAF0800)
  static const String pressureService = 'adaf0800-c332-42a8-93bd-25e905756cb8';
  
  /// Pressure Characteristic UUID (ADAFRUIT_CHAR_PRESSURE 0xADAF0801)
  static const String pressureChar = 'adaf0801-c332-42a8-93bd-25e905756cb8';
}

/// MCUmgr/SMP Service UUIDs
///
/// Used for firmware updates via nRF Connect Device Manager protocol.
abstract final class McumgrUuids {
  /// SMP Service UUID
  static const String service = '8d53dc1d-1db7-4cd3-868b-8a527460aa84';

  /// SMP Characteristic (bidirectional)
  static const String characteristic = 'da2e7828-fbce-4e01-ae9e-261174997c48';
}

/// Device Information Service UUIDs (Standard BLE)
abstract final class DeviceInfoUuids {
  /// Device Information Service UUID (0x180A)
  static const String service = '0000180a-0000-1000-8000-00805f9b34fb';

  /// Manufacturer Name String (0x2A29)
  static const String manufacturerName = '00002a29-0000-1000-8000-00805f9b34fb';

  /// Model Number String (0x2A24)
  static const String modelNumber = '00002a24-0000-1000-8000-00805f9b34fb';

  /// Firmware Revision String (0x2A26)
  static const String firmwareRevision = '00002a26-0000-1000-8000-00805f9b34fb';

  /// Hardware Revision String (0x2A27)
  static const String hardwareRevision = '00002a27-0000-1000-8000-00805f9b34fb';

  /// Software Revision String (0x2A28)
  static const String softwareRevision = '00002a28-0000-1000-8000-00805f9b34fb';
}

/// Battery Service UUIDs (Standard BLE)
abstract final class BatteryUuids {
  /// Battery Service UUID (0x180F)
  static const String service = '0000180f-0000-1000-8000-00805f9b34fb';

  /// Battery Level Characteristic (0x2A19)
  static const String level = '00002a19-0000-1000-8000-00805f9b34fb';
}

/// BLE Connection Configuration
abstract final class BleConfig {
  /// Scan timeout duration
  static const Duration scanTimeout = Duration(seconds: 15);

  /// Connection timeout duration
  static const Duration connectionTimeout = Duration(seconds: 30);

  /// Reconnection delay after unexpected disconnect
  static const Duration reconnectionDelay = Duration(seconds: 2);

  /// Maximum reconnection attempts before giving up
  static const int maxReconnectionAttempts = 5;

  /// Preferred MTU size (maximum supported by BLE 4.2+)
  static const int preferredMtu = 512;

  /// Minimum MTU size (BLE default)
  static const int minimumMtu = 23;

  /// Target connection interval (7.5ms - 15ms for responsive BLE)
  static const double targetConnectionIntervalMs = 15.0;

  /// ZSWatch device name prefix for scanning
  static const String deviceNamePrefix = 'ZSWatch';

  /// Alternative device name pattern
  static const String deviceNamePattern = 'ZSWatch';
}

