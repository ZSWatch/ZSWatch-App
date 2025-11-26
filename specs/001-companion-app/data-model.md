# Data Model: ZSWatch Companion App

**Branch**: `001-companion-app` | **Date**: 2025-11-26

## Overview

This document defines the data entities, their attributes, relationships, and lifecycle for the ZSWatch Companion App. All data is stored locally on the device (SQLite via drift).

**Scope Note**: This data model covers app-side storage only. Watch settings (display timeout, vibration, etc.) are stored and configured on the watch directly - the app does not sync or modify watch settings.

---

## Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────────┐
│      Watch      │───────│     Connection      │
│  (saved device) │ 1   1 │  (active session)   │
└────────┬────────┘       └─────────────────────┘
         │
         │ 1
         │
         │ *
┌────────┴────────┐
│                 │
▼                 ▼
┌─────────────┐   ┌─────────────────┐   ┌─────────────────┐
│HealthSample │   │ BatteryReading  │   │  CommLogEntry   │
│ (steps, HR) │   │ (drain history) │   │ (debug logs)    │
└─────────────┘   └─────────────────┘   └─────────────────┘

┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  SensorReading  │   │    LogEntry     │   │  ShellCommand   │
│ (raw accel/gyro)│   │ (watch logs)    │   │ (terminal cmds) │
└─────────────────┘   └─────────────────┘   └─────────────────┘

┌─────────────────┐   ┌─────────────────┐
│  FirmwareImage  │   │   VoiceMemo     │
│ (DFU files)     │   │ [placeholder]   │
└─────────────────┘   └─────────────────┘
```

---

## Entities

### 1. Watch

Represents a ZSWatch device that has been paired with the app.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | String | PK, UUID | Unique identifier (BLE device ID) |
| `name` | String | NOT NULL | Advertised device name |
| `firmware_version` | String | NULLABLE | Last known firmware version |
| `hardware_version` | String | NULLABLE | Hardware revision if available |
| `battery_level` | Integer | NULLABLE, 0-100 | Last known battery percentage |
| `is_primary` | Boolean | DEFAULT false | Currently selected watch |
| `supports_extended_api` | Boolean | DEFAULT false | Firmware supports Extended API |
| `bonding_key` | String | NULLABLE, encrypted | Secure storage reference |
| `last_connected_at` | DateTime | NULLABLE | Last successful connection |
| `created_at` | DateTime | NOT NULL | When device was first paired |

**Lifecycle States**: `paired` → `connected` → `disconnected` → (reconnecting) → `connected`

**Validation Rules**:
- `id` must be valid BLE device identifier format
- `battery_level` must be 0-100 or null
- Only one watch can have `is_primary = true`

---

### 2. Connection

Represents the current BLE connection state and metadata. Transient (not persisted to database, held in memory).

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `watch_id` | String | FK → Watch.id | Associated watch |
| `state` | Enum | NOT NULL | Current connection state |
| `rssi` | Integer | NULLABLE | Signal strength in dBm |
| `mtu` | Integer | NULLABLE | Negotiated MTU size |
| `phy_mode` | Enum | NULLABLE | 1M or 2M PHY |
| `dle_enabled` | Boolean | DEFAULT false | Data Length Extension active |
| `reconnection_count` | Integer | DEFAULT 0 | Reconnect attempts this session |
| `connected_at` | DateTime | NULLABLE | Connection established time |
| `last_activity_at` | DateTime | NULLABLE | Last data exchange |

**Connection States**:
```dart
enum ConnectionState {
  disconnected,
  scanning,
  connecting,
  bonding,
  connected,
  reconnecting,
  error
}
```

**PHY Modes**:
```dart
enum PhyMode {
  phy1M,  // 1 Mbps
  phy2M,  // 2 Mbps (preferred)
}
```

---

### 3. HealthSample

Time-series health data from the watch.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | Integer | PK, AUTO | Row identifier |
| `watch_id` | String | FK → Watch.id, INDEX | Source watch |
| `type` | Enum | NOT NULL | Type of health data |
| `value` | Double | NOT NULL | Measured value |
| `timestamp` | DateTime | NOT NULL, INDEX | When measured |
| `granularity` | Enum | NOT NULL | Time granularity |
| `synced_at` | DateTime | NOT NULL | When received by app |

**Health Types**:
```dart
enum HealthType {
  steps,      // Daily/hourly step count
  heartRate,  // BPM
  sleep,      // Minutes (future)
}
```

**Granularities**:
```dart
enum Granularity {
  realtime,   // Live streaming
  hourly,     // Per-hour aggregates
  daily,      // Per-day totals
  weekly,     // Per-week totals
  monthly,    // Per-month totals
}
```

**Retention**: 60 days, automatic cleanup via scheduled job

**Indexes**:
- `(watch_id, type, timestamp)` - Primary query pattern
- `(timestamp)` - For retention cleanup

---

### 4. BatteryReading

Battery level samples for analytics graphs.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | Integer | PK, AUTO | Row identifier |
| `watch_id` | String | FK → Watch.id, INDEX | Source watch |
| `level` | Integer | NOT NULL, 0-100 | Battery percentage |
| `is_charging` | Boolean | DEFAULT false | Charging state |
| `timestamp` | DateTime | NOT NULL, INDEX | When sampled |

**Sampling Rate**: Every 5 minutes when connected

**Retention**: 60 days

**Indexes**:
- `(watch_id, timestamp)` - For 24h/7d graph queries

---

### 5. SensorReading

Raw sensor data for developer debugging (in-memory only, not persisted).

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `type` | Enum | NOT NULL | Sensor type |
| `x` | Double | NULLABLE | X-axis value (accel/gyro) |
| `y` | Double | NULLABLE | Y-axis value (accel/gyro) |
| `z` | Double | NULLABLE | Z-axis value (accel/gyro) |
| `value` | Double | NULLABLE | Single value (PPG/temp) |
| `timestamp` | DateTime | NOT NULL | Sample time |

**Sensor Types**:
```dart
enum SensorType {
  accelerometer,
  gyroscope,
  ppg,          // Photoplethysmography (HR sensor)
  temperature,
}
```

**Storage**: In-memory circular buffer (last 1000 samples per sensor type)

---

### 6. Notification

Phone notification to be forwarded to watch (Android only). Transient.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | Integer | NOT NULL | System notification ID |
| `package_name` | String | NOT NULL | Source app package |
| `app_name` | String | NULLABLE | Human-readable app name |
| `title` | String | NULLABLE | Notification title |
| `body` | String | NULLABLE | Notification body |
| `timestamp` | DateTime | NOT NULL | When received |
| `icon` | Bytes | NULLABLE | App icon (base64 for BLE) |

**Lifecycle**: Created on receive → Sent to watch → Discarded

---

### 7. FirmwareImage

Firmware file prepared for upload.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `name` | String | NOT NULL | Display name |
| `version` | String | NULLABLE | Firmware version string |
| `type` | Enum | NOT NULL | Image type |
| `file_path` | String | NOT NULL | Local file path |
| `size` | Integer | NOT NULL | File size in bytes |
| `hash` | String | NULLABLE | SHA256 hash |
| `downloaded_at` | DateTime | NULLABLE | When downloaded |

**Image Types**:
```dart
enum FirmwareImageType {
  appCore,      // Main application
  netCore,      // Network processor
  filesystem,   // LittleFS image
  combined,     // Zip containing multiple
}
```

**Lifecycle**: Downloaded → Extracted → Uploaded → Cleaned up

---

### 8. LogEntry

Debug log entries from the watch.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | Integer | PK, AUTO | Row identifier |
| `watch_id` | String | FK → Watch.id | Source watch |
| `level` | Enum | NOT NULL | Log level |
| `module` | String | NULLABLE | Source module name |
| `message` | String | NOT NULL | Log message |
| `timestamp` | DateTime | NOT NULL | When logged |
| `received_at` | DateTime | NOT NULL | When received by app |

**Log Levels**:
```dart
enum LogLevel {
  debug,
  info,
  warning,
  error,
}
```

**Storage**: In-memory circular buffer (last 5000 entries)

---

### 9. CommLogEntry

BLE communication log for debugging.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | Integer | PK, AUTO | Row identifier |
| `direction` | Enum | NOT NULL | In or Out |
| `protocol` | Enum | NOT NULL | Which API used |
| `characteristic` | String | NULLABLE | GATT characteristic UUID |
| `payload` | String | NOT NULL | Message content (truncated) |
| `payload_size` | Integer | NOT NULL | Original size in bytes |
| `timestamp` | DateTime | NOT NULL | When sent/received |

**Directions**:
```dart
enum CommDirection {
  incoming,  // Watch → App
  outgoing,  // App → Watch
}
```

**Protocols**:
```dart
enum ProtocolType {
  gadgetbridge,
  extended,
  mcumgr,
  unknown,
}
```

**Storage**: SQLite table with rotation at 5,000 entries or 5MB (FR-066)

---

### 10. ShellCommand

Terminal command history.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | Integer | PK, AUTO | Row identifier |
| `command` | String | NOT NULL | Command sent |
| `response` | String | NULLABLE | Response received |
| `success` | Boolean | DEFAULT true | Command succeeded |
| `timestamp` | DateTime | NOT NULL | When executed |

**Storage**: In-memory, last 100 commands

---

### 11. VoiceMemo [PLACEHOLDER]

Voice recording from watch (future feature).

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | String | PK, UUID | Unique identifier |
| `watch_id` | String | FK → Watch.id | Source watch |
| `duration_ms` | Integer | NOT NULL | Recording duration |
| `file_path` | String | NOT NULL | Local audio file |
| `format` | String | NOT NULL | Audio format (e.g., "opus") |
| `recorded_at` | DateTime | NOT NULL | When recorded on watch |
| `synced_at` | DateTime | NOT NULL | When received by app |

---

## Database Schema (drift)

```dart
// watches table
class Watches extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get firmwareVersion => text().nullable()();
  TextColumn get hardwareVersion => text().nullable()();
  IntColumn get batteryLevel => integer().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get supportsExtendedApi => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastConnectedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}

// health_samples table
class HealthSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get watchId => text().references(Watches, #id)();
  TextColumn get type => text()(); // enum as string
  RealColumn get value => real()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get granularity => text()();
  DateTimeColumn get syncedAt => dateTime()();
}

// battery_readings table
class BatteryReadings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get watchId => text().references(Watches, #id)();
  IntColumn get level => integer()();
  BoolColumn get isCharging => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime()();
}

// comm_log_entries table
class CommLogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get direction => text()();
  TextColumn get protocol => text()();
  TextColumn get characteristic => text().nullable()();
  TextColumn get payload => text()();
  IntColumn get payloadSize => integer()();
  DateTimeColumn get timestamp => dateTime()();
}
```

---

## Data Retention Policy

| Entity | Retention | Cleanup Trigger |
|--------|-----------|-----------------|
| Watch | Permanent | Manual "Forget" only |
| HealthSample | 60 days | Daily scheduled job |
| BatteryReading | 60 days | Daily scheduled job |
| CommLogEntry | 5,000 entries / 5MB | On insert, rotate oldest |
| LogEntry | Session only | On app restart |
| SensorReading | Session only | On app restart |
| ShellCommand | Session only | On app restart |
| FirmwareImage | After upload | Success callback |

---

## Validation Rules Summary

1. **Watch.id**: Must match BLE device identifier pattern
2. **Watch.battery_level**: Range 0-100 or null
3. **Watch.is_primary**: Only one true at a time (enforce in repository)
4. **HealthSample.value**: Non-negative for steps, 30-250 for heartRate
5. **BatteryReading.level**: Range 0-100
6. **CommLogEntry.payload**: Truncate at 1KB, store original size
7. **All timestamps**: Must be valid DateTime, not in future

