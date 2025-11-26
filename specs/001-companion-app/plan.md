# Implementation Plan: ZSWatch Companion App

**Branch**: `001-companion-app` | **Date**: 2025-11-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-companion-app/spec.md`

## Summary

Cross-platform Flutter companion app for ZSWatch smartwatch providing BLE communication, firmware updates via MCUmgr/SMP, notification forwarding (Android), health data visualization, and developer tools. The app implements a dual-protocol architecture: Gadgetbridge API for backwards compatibility and Extended ZSWatch API for new features.

## Implementation Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Setup | ✅ Complete | Project initialized, dependencies configured |
| Phase 2: Foundational | ✅ Complete | Database, BLE abstraction, protocol layer |
| Phase 3: Connect (US1) | ✅ Complete | Scan, connect, bond, dashboard |
| Phase 3.5: Gap Tasks | ✅ Complete | Unified WatchService, reconnection fixes |
| Phase 4: Firmware (US2) | ✅ Complete | GitHub releases, CI builds, local files, MCUmgr DFU |
| Phase 5: Notifications (US3) | 🔲 Not Started | |
| Phase 6+: Remaining | 🔲 Not Started | |

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
