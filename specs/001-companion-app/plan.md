# Implementation Plan: ZSWatch Companion App

**Branch**: `001-companion-app` | **Date**: 2025-11-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-companion-app/spec.md`

## Summary

Cross-platform Flutter companion app for ZSWatch smartwatch providing BLE communication, firmware updates via MCUmgr/SMP, notification forwarding (Android), health data visualization, and developer tools. The app implements a dual-protocol architecture: Gadgetbridge API for backwards compatibility and Extended ZSWatch API for new features. Enhanced with start page showing stored watches, auto-reconnect behavior, bi-directional notification dismiss sync, music control forwarding, persistent BLE connections, and GPS location support.

## Implementation Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Setup | ✅ Complete | Project initialized, dependencies configured |
| Phase 2: Foundational | ✅ Complete | Database, BLE abstraction, protocol layer |
| Phase 3: Connect (US1) | ✅ Complete | Scan, connect, bond, dashboard |
| Phase 3.5: Gap Tasks | ✅ Complete | Unified WatchService, reconnection fixes |
| Phase 3.6: Start Page | 🆕 Not Started | FR-067 to FR-070: Stored watches display, connect flow |
| Phase 3.7: Auto-Reconnect & Initial Sync | 🆕 Not Started | FR-071 to FR-074, FR-084 to FR-088 |
| Phase 3.8: Persistent BLE | 🆕 Not Started | FR-089 to FR-092: Background connection ⚠️ CRITICAL |
| Phase 4: Firmware (US2) | ✅ Complete | GitHub releases, CI builds, local files, MCUmgr DFU |
| Phase 4.5: Filesystem (US2) | ✅ Complete | MCUmgr filesystem upload for lvgl_resources_raw.bin |
| Phase 5: Notifications (US3) | ✅ Complete | Android NotificationListener, MediaSession, Gadgetbridge protocol |
| Phase 5.5: Notification Dismiss Sync | 🆕 Not Started | FR-075 to FR-078: Bi-directional dismiss sync |
| Phase 5.6: Music Control | 🆕 Not Started | FR-079 to FR-083: Music forwarding & control |
| Phase 6: Dashboard (US4) | ✅ Complete | Connection status, battery, firmware, navigation |
| Phase 7: Health (US5) | 🔲 Not Started | |
| Phase 8: Developer Tools (US6) | 🔲 Not Started | |
| Phase 8.5: Debug Tools | 🆕 Not Started | FR-093 to FR-098: Notification & music debug |
| Phase 9: Multiple Watches (US7) | 🔲 Not Started | |
| Phase 10: Settings (US8) | 🔲 Not Started | |
| Phase 10.5: Watch Rename | 🆕 Not Started | FR-099 to FR-102 |
| Phase 11: Analytics (US9) | 🔲 Not Started | |
| Phase 11.6: GPS Support | 🆕 Not Started | FR-103 to FR-107: Gadgetbridge GPS |
| Phase 12: Voice Recording (US10) | 🔲 Placeholder | Depends on firmware |

## Technical Context

**Language/Version**: Dart 3.x (Flutter 3.x stable)
**Primary Dependencies**:
- `flutter_blue_plus` - BLE scanning, connection, GATT operations
- `mcumgr_flutter` (nRF Connect Device Manager) - MCUmgr/SMP firmware updates
- `flutter_riverpod` - State management
- `drift` or `sqflite` - Local SQLite database for health/analytics data
- `shared_preferences` - Simple key-value settings storage
- `path_provider` - File system access for firmware files
- `http` / `dio` - GitHub API for firmware downloads
- `fl_chart` - Real-time graphs (HR, battery, sensors)
- `permission_handler` - Runtime permissions
- `geolocator` - GPS location for Gadgetbridge GPS support (FR-103 to FR-107)
- `flutter_local_notifications` - Debug notification testing (FR-097)
- `audio_service` / platform MediaSession APIs - Media control forwarding (FR-079 to FR-083)

**Storage**: SQLite (drift/sqflite) for structured data (health samples, battery readings, logs); SharedPreferences for app settings; Secure storage (flutter_secure_storage) for BLE bonding keys

**Testing**: `flutter_test` (unit), `integration_test` (widget/integration), `mockito` (mocking BLE layer)

**Target Platform**: iOS 13.0+, Android API 21+ (minSdkVersion raised from 19 for BLE reliability)

**Project Type**: Mobile (Flutter cross-platform)

**Performance Goals**:
- Connection within 30 seconds (SC-001)
- DFU under 10 minutes (SC-002)
- Notification latency < 3 seconds (SC-003)
- Reconnection within 10 seconds (SC-004)
- Sensor streaming at 10 Hz (SC-011)
- HR plot update within 500ms (SC-012)
- Screen navigation < 300ms (SC-014)
- Start page render < 1 second (SC-015)
- Auto-reconnect begin < 5 seconds (SC-016)
- Notification dismiss sync < 2 seconds (SC-017)
- Music metadata update < 1 second (SC-018)
- Initial sync < 3 seconds (SC-019)
- GPS response < 5 seconds (SC-020)
- Background BLE stability ≥ 8 hours (SC-021)

**Constraints**:
- Local-only data storage (no cloud)
- 60-day data retention with automatic cleanup
- 5,000 entry / 5MB communication log rotation
- BLE bonding required (encrypted connections only)
- Privacy-first: no telemetry, no accounts

**Scale/Scope**: Single-user app, 1 active watch connection, multiple saved watches, ~15-20 screens

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Compliance | Notes |
|-----------|------------|-------|
| I. Flutter-First | ✅ Pass | Dart/Flutter only; native code via flutter_blue_plus and mcumgr_flutter plugins for BLE/DFU |
| II. BLE Abstraction | ✅ Pass | BLE layer isolated behind interfaces; UI never touches GATT directly; reconnection logic in service layer |
| III. Privacy by Default | ✅ Pass | All data local; no cloud; no accounts; no telemetry; FR-056/057/058 enforce this |
| IV. Modular Architecture | ✅ Pass | Layered: UI → Features → Services → BLE; Riverpod state management |
| Platform-Specific (Notif) | ✅ Pass | iOS: ANCS/AMS watch-direct; Android: NotificationListenerService bridge |

## Project Structure

### Documentation (this feature)

```text
specs/001-companion-app/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (BLE protocol specs)
│   ├── gadgetbridge-api.md
│   └── extended-api.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

**⚠️ Project Initialization**: The Flutter project MUST be created via `flutter create zswatch_app`. AI assistants must assume this structure exists and only add/modify files within it.

```text
zswatch_app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   │
│   ├── core/                      # Shared utilities and constants
│   │   ├── constants/
│   │   ├── utils/
│   │   ├── extensions/
│   │   └── theme/
│   │
│   ├── data/                      # Data layer
│   │   ├── models/                # Data classes / entities
│   │   │   ├── watch.dart
│   │   │   ├── connection.dart
│   │   │   ├── health_sample.dart
│   │   │   ├── battery_reading.dart
│   │   │   ├── notification.dart
│   │   │   ├── firmware_image.dart
│   │   │   ├── sensor_reading.dart
│   │   │   ├── log_entry.dart
│   │   │   └── comm_log_entry.dart
│   │   ├── repositories/          # Data access abstraction
│   │   │   ├── watch_repository.dart
│   │   │   ├── health_repository.dart
│   │   │   └── settings_repository.dart
│   │   └── database/              # SQLite/Drift setup
│   │       └── app_database.dart
│   │
│   ├── services/                  # Business logic / device communication
│   │   ├── watch_service.dart     # Unified watch service (connection + protocol)
│   │   ├── ble/                   # BLE abstraction layer
│   │   │   ├── ble_service.dart           # Interface
│   │   │   ├── ble_service_impl.dart      # flutter_blue_plus implementation
│   │   │   ├── ble_scanner.dart           # Device discovery with filtering
│   │   │   ├── ble_connection_manager.dart
│   │   │   ├── gatt_operations.dart
│   │   │   └── sensor_gatt_service.dart   # zsw_gatt_sensor_server client
│   │   ├── protocol/              # Watch communication protocols
│   │   │   ├── protocol_service.dart      # Interface
│   │   │   ├── gadgetbridge_protocol.dart # Primary: Gadgetbridge API
│   │   │   ├── extended_protocol.dart     # Minimal: health sync, logs, shell
│   │   │   └── message_types.dart
│   │   ├── dfu/                   # Firmware update
│   │   │   ├── dfu_service.dart
│   │   │   └── firmware_manager.dart
│   │   ├── notification/          # Android notification bridge
│   │   │   └── notification_service.dart
│   │   ├── media/                 # Android media bridge
│   │   │   └── media_service.dart
│   │   ├── health/
│   │   │   └── health_sync_service.dart
│   │   └── time/
│   │       └── time_sync_service.dart
│   │
│   ├── providers/                 # Riverpod providers
│   │   ├── ble_providers.dart
│   │   ├── watch_providers.dart
│   │   ├── watch_service_provider.dart  # Unified watch state & operations
│   │   ├── health_providers.dart
│   │   ├── settings_providers.dart
│   │   └── dfu_providers.dart
│   │
│   └── ui/                        # Presentation layer
│       ├── screens/
│       │   ├── dashboard/
│       │   │   └── dashboard_screen.dart
│       │   ├── connection/
│       │   │   ├── scan_screen.dart
│       │   │   └── device_list_screen.dart
│       │   ├── firmware/
│       │   │   └── firmware_update_screen.dart
│       │   ├── health/
│       │   │   ├── health_screen.dart
│       │   │   └── heart_rate_screen.dart
│       │   ├── notifications/
│       │   │   └── notification_settings_screen.dart
│       │   ├── settings/
│       │   │   ├── settings_screen.dart
│       │   │   └── watch_settings_screen.dart
│       │   ├── developer/
│       │   │   ├── developer_screen.dart
│       │   │   ├── log_viewer_screen.dart
│       │   │   ├── shell_terminal_screen.dart
│       │   │   ├── sensor_debug_screen.dart
│       │   │   └── comm_log_screen.dart
│       │   └── analytics/
│       │       └── battery_analytics_screen.dart
│       ├── widgets/               # Reusable UI components
│       │   ├── connection_status_pill.dart
│       │   ├── battery_ring.dart
│       │   ├── progress_card.dart
│       │   └── real_time_chart.dart
│       └── navigation/
│           └── app_router.dart
│
├── android/
│   └── app/src/main/
│       ├── kotlin/.../           # Native Android code
│       │   ├── NotificationListenerServiceImpl.kt
│       │   └── MediaSessionBridge.kt
│       └── AndroidManifest.xml   # Permissions, services
│
├── ios/
│   └── Runner/
│       └── Info.plist            # Background modes, permissions
│
├── test/
│   ├── unit/
│   │   ├── services/
│   │   └── providers/
│   ├── widget/
│   └── mocks/
│
├── integration_test/
│   └── app_test.dart
│
├── pubspec.yaml
└── README.md
```

**Structure Decision**: Flutter mobile project with clean architecture layers. Native Android code required for NotificationListenerService and MediaSession bridges. iOS uses native Info.plist configuration for Bluetooth background modes. BLE operations isolated in services layer with protocol abstraction for Gadgetbridge/Extended APIs.

## Development Workflow

**Distributed Flutter iOS Workflow**: Develop on Windows/Linux + Auxiliary Mac

| Activity | Platform | Frequency |
|----------|----------|-----------|
| UI, business logic, BLE (Android) | Windows/Linux | Daily |
| Unit & widget tests | Windows/Linux | Daily |
| Android builds & testing | Windows/Linux | Daily |
| iOS builds, signing, device testing | macOS | Weekly/Release |

- **95% of development** on Windows/Linux
- Mac required **only** for iOS builds, signing, and physical device testing
- All Dart/Flutter code testable without Mac
- See `quickstart.md` for detailed workflow

## Complexity Tracking

> No constitution violations requiring justification.

| Decision | Rationale | Alternative Considered |
|----------|-----------|------------------------|
| Native Android code for notifications | Android has no ANCS equivalent; NotificationListenerService requires native implementation | Pure Dart approach impossible - OS doesn't expose notifications to Flutter directly |
| Dual protocol architecture | Backwards compatibility with existing Gadgetbridge while enabling new features | Single protocol would break existing watch firmware users |
| SQLite over Hive | Better query support for time-series health data, 60-day retention cleanup | Hive simpler but lacks query flexibility for date-range operations |
| Android Foreground Service for background BLE | Required for reliable persistent BLE connection (FR-089 to FR-092) | Background execution without foreground service is unreliable on modern Android |
| geolocator for GPS | Cross-platform GPS access for Gadgetbridge GPS support (FR-103 to FR-107) | Platform-specific implementations would increase maintenance burden |

## New Requirements Summary (FR-067 to FR-107)

### Start Page & Stored Watches (FR-067 to FR-070)
- Display stored watches prominently on start page
- "Connect new watch" button for new pairings
- Direct selection to connect to stored watch
- Auto-navigate to dashboard on connection

### Auto-Reconnect Behavior (FR-071 to FR-074)
- Auto-reconnect to last watch on app reopen
- Periodic reconnect attempts (platform limits apply)
- Non-blocking manual selection during auto-reconnect
- Navigate to connected screen on success

### Initial Sync on Connect (FR-084 to FR-088)
- Send critical state data immediately on connection
- Include current time
- Include current "now playing" info if media active
- Include other relevant state (notifications, weather)
- Complete sync before connection considered established

### Notification Dismiss Sync (FR-075 to FR-078)
- Stable unique notification IDs for all forwarded notifications
- Watch-to-phone dismiss sync via ID callback
- Phone-to-watch dismiss sync via "-" prefixed command
- Watch dismisses matching notification on "-" command

### Music Control Integration (FR-079 to FR-083)
- Forward music control commands from watch to phone media
- Immediate music info updates on track change
- Immediate updates on playback state change
- Periodic updates while playing
- Send "now playing" immediately after connection

### Persistent BLE Connection (FR-089 to FR-092)
- Reliable background BLE connection
- Support all BLE features in background
- Platform-specific background rules compliance
- Android foreground service notification

### Notification Debug Tools (FR-093 to FR-097)
- Notification debug section in developer tools
- App name selection for test notifications
- Custom notification text entry
- Send debug notification to watch
- Create phone notification for dismiss sync testing

### Music Debug Tools (FR-098)
- Send static sample "now playing" metadata to watch

### Watch Rename (FR-099 to FR-102)
- Rename bonded watches for identification
- Access via App Settings
- Persist custom names
- Display throughout app

### GPS Support (FR-103 to FR-107)
- Implement Gadgetbridge GPSPower command
- Obtain location from phone on watch request
- Respect OS location permissions
- Send location in Gadgetbridge format
- Handle permission denial gracefully

## New Success Criteria (SC-015 to SC-021)

| ID | Criterion | Target |
|----|-----------|--------|
| SC-015 | Start page displays stored watches | < 1 second after launch |
| SC-016 | Auto-reconnect begins | < 5 seconds after app launch |
| SC-017 | Notification dismiss sync (bidirectional) | < 2 seconds |
| SC-018 | Music metadata updates on watch | < 1 second after change |
| SC-019 | Initial sync completes | < 3 seconds after connection |
| SC-020 | GPS location response to watch | < 5 seconds (subject to GPS) |
| SC-021 | Background BLE connection stability | ≥ 8 hours (within OS limits) |

## Architecture Notes for New Features

### Start Page Flow
```
App Launch → Start Page
  ├── Has stored watches? → Display list with connection status
  │   ├── Tap stored watch → Connect → Dashboard
  │   └── Tap "Connect new watch" → Scan screen
  └── No stored watches? → Show "Connect new watch" only
```

### Auto-Reconnect Flow
```
App Launch/Resume
  └── Last connected watch exists?
      └── Yes → Start periodic reconnect attempts
          ├── Success → Navigate to Dashboard
          ├── Failure → Continue attempts (within platform limits)
          └── User selects different watch → Cancel auto-reconnect
```

### Initial Sync Sequence
```
Connection Established
  └── Initial Sync Phase
      ├── Send current time (FR-085)
      ├── Send "now playing" if active (FR-086)
      ├── Send other state (FR-087)
      └── Mark connection as fully established (FR-088)
```

### Notification Dismiss Sync Flow
```
Phone Notification Dismissed
  └── NotificationListenerService.onNotificationRemoved()
      └── Send "-{notificationId}" to watch (FR-077)

Watch Notification Dismissed
  └── Watch sends notification ID back
      └── App cancels notification on phone (FR-076)
```

### Music Control Flow
```
Watch sends music command (play/pause/next/prev)
  └── App receives via BLE
      └── App forwards to MediaSession controller (FR-079)

Phone media state changes
  └── MediaSession callback
      └── App sends updated metadata to watch (FR-080, FR-081)
```

### GPS Request Flow
```
Watch sends GPSPower command
  └── App receives request
      ├── Check location permission
      │   ├── Granted → Get location → Send to watch (FR-106)
      │   └── Denied → Send error response (FR-107)
      └── Handle timeout/errors gracefully
```

## Dependencies Between New Features

| Feature | Depends On | Notes |
|---------|------------|-------|
| Start Page (3.6) | Existing watch storage | Uses existing paired watch data |
| Auto-Reconnect (3.7) | Start Page (3.6) | Builds on start page navigation |
| Initial Sync (3.7) | Auto-Reconnect (3.7) | Triggered after any connection |
| Music Control (5.6) | Initial Sync (3.7) | "Now playing" sent during initial sync |
| Notification Dismiss (5.5) | Existing notification service | Extends current notification forwarding |
| Persistent BLE (3.8) | Auto-Reconnect (3.7) | Critical for notification reliability |
| GPS Support (11.6) | Persistent BLE (3.8) | May need background location access |
| Debug Tools (8.5) | Notification (5.5), Music (5.6) | Tests notification/music features |
| Watch Rename (10.5) | Existing settings | Extends settings screen |

## Recommended Implementation Order

1. **Phase 3.6**: Start Page Enhancement (FR-067 to FR-070)
2. **Phase 3.7**: Auto-Reconnect + Initial Sync (FR-071 to FR-074, FR-084 to FR-088)
3. **Phase 3.8**: Persistent BLE Connection (FR-089 to FR-092) ← Critical early foundation
4. **Phase 5.5**: Notification Dismiss Sync (FR-075 to FR-078)
5. **Phase 5.6**: Music Control Integration (FR-079 to FR-083)
6. **Phase 8.5**: Notification & Music Debug Tools (FR-093 to FR-098)
7. **Phase 10.5**: Watch Rename (FR-099 to FR-102)
8. **Phase 11.6**: GPS Support (FR-103 to FR-107)
