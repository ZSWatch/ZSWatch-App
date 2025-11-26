# Research: ZSWatch Companion App

**Branch**: `001-companion-app` | **Date**: 2025-11-26

## Overview

This document captures technology decisions, research findings, and rationale for the ZSWatch Companion App implementation.

---

## 1. BLE Library Selection

### Decision: `flutter_blue_plus`

### Rationale
- Most actively maintained Flutter BLE plugin (fork of flutter_blue with fixes)
- Supports iOS 13+ and Android API 21+
- Full GATT support: scanning, connecting, service/characteristic discovery, read/write/notify
- Supports MTU negotiation and connection parameter updates
- Good documentation and community support

### Alternatives Considered

| Library | Pros | Cons | Why Rejected |
|---------|------|------|--------------|
| `flutter_reactive_ble` | Clean reactive API | Less mature, smaller community | flutter_blue_plus has better stability track record |
| `flutter_ble_lib` | Multiplatform support | Abandoned, last update 2021 | Not maintained |
| Native only (MethodChannels) | Full control | Duplicate code, more maintenance | Constitution allows plugins; unnecessary complexity |

---

## 2. DFU / MCUmgr Library Selection

### Decision: `mcumgr_flutter` (nRF Connect Device Manager)

### Rationale
- Official Nordic Semiconductor Flutter wrapper for MCUmgr
- Wraps battle-tested native iOS/Android MCUmgr libraries
- Full SMP protocol support: image upload, slot management, confirmation, reset
- Handles chunking, progress reporting, and error recovery
- Used in production by Nordic's own apps

### Alternatives Considered

| Library | Pros | Cons | Why Rejected |
|---------|------|------|--------------|
| Pure Dart mcumgr | Single codebase | Would need to reimplement entire SMP protocol | Massive effort, error-prone |
| Custom native MethodChannels | Full control | Duplicates Nordic's work | Constitution prefers existing plugins |
| Web-based DFU only | Already exists on ZSWatch website | Not mobile-native UX | Spec requires native app experience |

### Reference
- [mcumgr_flutter GitHub](https://github.com/NordicSemiconductor/Flutter-nRF-Connect-Device-Manager)
- Supports iOS 13.0+, Android minSdk 19 (we target 21)

---

## 3. State Management Selection

### Decision: `Riverpod` (flutter_riverpod)

### Rationale
- Constitution specifies Riverpod as preferred
- Compile-time safety with providers
- Excellent for dependency injection and testability
- Works well with async streams (BLE connection state, sensor data)
- No BuildContext required for accessing state

### Alternatives Considered

| Library | Pros | Cons | Why Rejected |
|---------|------|------|--------------|
| Bloc | Well-established, event-driven | More boilerplate, BuildContext required | Constitution prefers Riverpod |
| Provider | Simple | Less type-safe, Riverpod is evolution | Riverpod is strictly better |
| GetX | Minimal boilerplate | Poor testability, magic | Violates modular architecture principle |

---

## 4. Local Database Selection

### Decision: `drift` (formerly moor)

### Rationale
- Type-safe SQL queries in Dart
- Excellent for time-series data (health samples, battery readings)
- Supports complex queries needed for 60-day retention cleanup
- Stream-based reactive queries for real-time UI updates
- Migration support for schema evolution

### Alternatives Considered

| Library | Pros | Cons | Why Rejected |
|---------|------|------|--------------|
| `sqflite` | Simple, widely used | Raw SQL strings, no type safety | drift provides better DX |
| `hive` | Fast, pure Dart | No SQL queries, poor for date ranges | 60-day cleanup queries awkward |
| `isar` | Fast, full-text search | Newer, less proven | drift more mature |
| `shared_preferences` | Simple key-value | Not suitable for structured data | Only for simple settings |

### Schema Considerations
- `HealthSample`: partitioned by date for efficient range queries
- `BatteryReading`: indexed by timestamp
- `CommLogEntry`: capped table with rotation trigger
- All tables include `created_at` for 60-day cleanup

---

## 5. Android Notification Access

### Decision: Native `NotificationListenerService` via MethodChannel

### Rationale
- Android requires a system service to access notifications
- No pure Flutter equivalent exists
- Must be implemented in native Kotlin/Java
- MethodChannel bridges native service to Flutter

### Implementation Approach
```
Android Native (Kotlin):
  NotificationListenerServiceImpl extends NotificationListenerService
    → onNotificationPosted() → sends to Flutter via MethodChannel
    → onNotificationRemoved() → sends to Flutter via MethodChannel

Flutter:
  NotificationService
    → listens to MethodChannel events
    → translates to Gadgetbridge protocol
    → sends via BLE to watch
```

### Permissions Required (AndroidManifest.xml)
- `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE`
- User must explicitly enable in system settings

---

## 6. Android Media Access

### Decision: Native `MediaSession` / `MediaController` via MethodChannel

### Rationale
- Android media metadata requires MediaSession APIs
- No pure Flutter plugin provides full media control integration
- Native implementation needed for play/pause/next/previous commands

### Implementation Approach
```
Android Native (Kotlin):
  MediaSessionBridge
    → MediaController.Callback for metadata changes
    → Exposes transport controls to Flutter

Flutter:
  MediaService
    → receives metadata updates via MethodChannel
    → translates to Gadgetbridge protocol
    → sends via BLE to watch
```

---

## 7. iOS Background BLE

### Decision: Info.plist `UIBackgroundModes` with `bluetooth-central`

### Rationale
- iOS requires explicit declaration for background BLE
- App must be registered as bluetooth-central
- Connection restoration handled by CoreBluetooth

### Configuration (Info.plist)
```xml
<key>UIBackgroundModes</key>
<array>
  <string>bluetooth-central</string>
</array>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>ZSWatch needs Bluetooth to communicate with your watch</string>
```

### Limitations
- iOS may terminate app after extended background time
- Connection state restoration via `willRestoreState`
- flutter_blue_plus handles restoration callbacks

---

## 8. Charting Library Selection

### Decision: `fl_chart`

### Rationale
- Pure Flutter implementation (no platform views)
- Supports line charts for HR, battery, sensor data
- Real-time updates with good performance
- Customizable styling to match ZSWatch theme

### Alternatives Considered

| Library | Pros | Cons | Why Rejected |
|---------|------|------|--------------|
| `syncfusion_flutter_charts` | Full-featured | Requires license for commercial | Open-source project needs free library |
| `charts_flutter` (Google) | Official Google | Deprecated, minimal updates | Not actively maintained |
| `graphic` | Declarative | Less documentation | fl_chart more mature |

---

## 9. BLE Protocol Architecture

### Decision: Gadgetbridge-primary with minimal Extended API

### Rationale
- Gadgetbridge API is comprehensive and already implemented in firmware
- Extended API only needed for features Gadgetbridge doesn't cover
- Existing GATT services used where available (sensors, heart rate)
- No need for custom protocols when standard solutions exist

### Architecture
```
Feature Modules (Health, Notifications, etc.)
         │
         ▼
   ProtocolService (interface)
         │
    ┌────┴────────────┬─────────────┐
    ▼                 ▼             ▼
Gadgetbridge      Extended     Standard GATT
  Protocol        Protocol      Services
(NUS + GB(...))   (minimal)    (sensors, HR)
    │                 │             │
    └────────┬────────┴─────────────┘
             ▼
         BLE Service
```

### Protocol Routing
| Feature | Protocol | Rationale |
|---------|----------|-----------|
| Notifications | Gadgetbridge | Fully supported |
| Music | Gadgetbridge | Fully supported |
| Weather | Gadgetbridge | Fully supported |
| GPS | Gadgetbridge | Fully supported |
| Device Info | Gadgetbridge `t:"ver"` | Already implemented |
| Activity Data | Gadgetbridge `t:"act"` | Realtime + fetch |
| Alarms | Gadgetbridge | Fully supported |
| Sensor Streaming | zsw_gatt_sensor_server | Existing GATT service |
| Heart Rate | Standard HR GATT (0x180D) | Bluetooth standard |
| Bulk Health Sync | Extended API | Not in Gadgetbridge |
| Log Streaming | Extended API | Developer tool |
| Shell Commands | Extended API | Developer tool |
| Voice Memos | Extended API | Future feature |

### Key Principle
Use existing protocols and GATT services. Only create Extended API messages when absolutely necessary.

---

## 10. Secure Storage for Bonding Keys

### Decision: `flutter_secure_storage`

### Rationale
- Platform-native secure storage (Keychain on iOS, EncryptedSharedPreferences on Android)
- BLE bonding keys must be stored securely (FR-061)
- Encrypted at rest

### Usage
- Store bonding keys by device identifier
- Retrieve on reconnection attempts
- Delete on "Forget" device action

---

## 11. GitHub API for Firmware Downloads

### Decision: Direct GitHub REST API with `http` package

### Rationale
- ZSWatch firmware builds are GitHub Actions artifacts
- API provides artifact listing and download URLs
- No authentication required for public repository

### Endpoints Used
- `GET /repos/ZSWatch/ZSWatch/actions/runs` - List workflow runs
- `GET /repos/ZSWatch/ZSWatch/actions/runs/{run_id}/artifacts` - List artifacts
- Artifact download via redirect URL

### Caching Strategy
- Cache artifact list for 5 minutes
- Download firmware to temp directory
- Clean up after successful upload

---

## Summary of Key Decisions

| Area | Decision | Key Rationale |
|------|----------|---------------|
| BLE | flutter_blue_plus | Most mature, full GATT support |
| DFU | mcumgr_flutter | Official Nordic, battle-tested |
| State | Riverpod | Constitution preference, testable |
| Database | drift | Type-safe SQL, time-series queries |
| Charts | fl_chart | Pure Flutter, real-time capable |
| Android Notifications | Native NotificationListenerService | No Flutter alternative exists |
| Android Media | Native MediaSession | No Flutter alternative exists |
| iOS Background | bluetooth-central mode | Required for BLE persistence |
| Secure Storage | flutter_secure_storage | Platform-native encryption |

