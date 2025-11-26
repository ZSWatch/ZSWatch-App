# Tasks: ZSWatch Companion App

**Input**: Design documents from `/specs/001-companion-app/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- File paths relative to `zswatch_app/` (Flutter project root)

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Initialize Flutter project and configure dependencies

**⚠️ IMPORTANT**: The Flutter project MUST be created via `flutter create zswatch_app`. AI assistants must assume this structure already exists.

- [ ] T001 Configure dependencies in pubspec.yaml (flutter_blue_plus, mcumgr_flutter, flutter_riverpod, drift, fl_chart, etc.)
- [ ] T002 [P] Configure Android permissions in android/app/src/main/AndroidManifest.xml
- [ ] T003 [P] Configure iOS permissions and background modes in ios/Runner/Info.plist
- [ ] T004 [P] Create core constants in lib/core/constants/ble_constants.dart (service UUIDs, characteristic UUIDs)
- [ ] T005 [P] Create app theme in lib/core/theme/app_theme.dart (dark theme, ZSWatch colors)
- [ ] T006 [P] Create core extensions in lib/core/extensions/datetime_extensions.dart
- [ ] T007 [P] Setup analysis_options.yaml with Flutter lints

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Database Layer

- [ ] T008 Create drift database configuration in lib/data/database/app_database.dart
- [ ] T009 [P] Create Watch table schema in lib/data/database/tables/watches_table.dart
- [ ] T010 [P] Create HealthSamples table schema in lib/data/database/tables/health_samples_table.dart
- [ ] T011 [P] Create BatteryReadings table schema in lib/data/database/tables/battery_readings_table.dart
- [ ] T012 [P] Create CommLogEntries table schema in lib/data/database/tables/comm_log_entries_table.dart
- [ ] T013 Generate drift database code via build_runner

### BLE Abstraction Layer

- [ ] T014 Create BLE service interface in lib/services/ble/ble_service.dart
- [ ] T015 Create BLE service implementation in lib/services/ble/ble_service_impl.dart (flutter_blue_plus)
- [ ] T016 Create GATT operations helper in lib/services/ble/gatt_operations.dart
- [ ] T017 Create BLE constants (NUS UUIDs, ZSWatch UUIDs) in lib/core/constants/ble_uuids.dart

### Protocol Layer

- [ ] T018 Create protocol service interface in lib/services/protocol/protocol_service.dart
- [ ] T019 Create Gadgetbridge protocol implementation in lib/services/protocol/gadgetbridge_protocol.dart
- [ ] T020 Create message types enum/classes in lib/services/protocol/message_types.dart

### State Management Foundation

- [ ] T021 Create BLE providers in lib/providers/ble_providers.dart (connection state, scanning state)
- [ ] T022 [P] Create watch providers in lib/providers/watch_providers.dart
- [ ] T023 [P] Create settings providers in lib/providers/settings_providers.dart

### Base UI Components

- [ ] T024 [P] Create ConnectionStatusPill widget in lib/ui/widgets/connection_status_pill.dart
- [ ] T025 [P] Create BatteryRing widget in lib/ui/widgets/battery_ring.dart
- [ ] T026 [P] Create ProgressCard widget in lib/ui/widgets/progress_card.dart
- [ ] T027 Create app router/navigation in lib/ui/navigation/app_router.dart

### App Entry Points

- [ ] T028 Configure main.dart with ProviderScope in lib/main.dart
- [ ] T029 Create App widget in lib/app.dart with theme and router

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Connect to Watch (Priority: P1) 🎯 MVP

**Goal**: User can discover, pair, and connect to a ZSWatch via BLE

**Independent Test**: Open app → Tap "Add Watch" → See ZSWatch in list → Tap to connect → See connection status and device info

### Models

- [ ] T030 [P] [US1] Create Watch model in lib/data/models/watch.dart
- [ ] T031 [P] [US1] Create Connection model (in-memory state) in lib/data/models/connection.dart
- [ ] T032 [P] [US1] Create ConnectionState enum in lib/data/models/connection_state.dart

### BLE Services

- [ ] T033 [US1] Implement BLE scanner in lib/services/ble/ble_scanner.dart
- [ ] T034 [US1] Implement BLE connection manager in lib/services/ble/ble_connection_manager.dart
- [ ] T035 [US1] Add MTU negotiation and DLE enable to connection manager
- [ ] T036 [US1] Add 2M PHY request to connection manager
- [ ] T037 [US1] Implement bonding/pairing flow with secure key storage

### Repository

- [ ] T038 [US1] Create watch repository in lib/data/repositories/watch_repository.dart

### Providers

- [ ] T039 [US1] Update BLE providers with scanner and connection state

### UI Screens

- [ ] T040 [P] [US1] Create scan screen in lib/ui/screens/connection/scan_screen.dart
- [ ] T041 [US1] Create device list component in lib/ui/screens/connection/device_list_screen.dart
- [ ] T042 [US1] Add connection progress UI with state transitions
- [ ] T043 [US1] Add permission request handling (Bluetooth, Location for Android)

### Gadgetbridge Integration

- [ ] T044 [US1] Implement device info request (`t:"ver"`) in gadgetbridge_protocol.dart
- [ ] T045 [US1] Implement time sync on connect in lib/services/time/time_sync_service.dart

**Checkpoint**: User can discover, connect, and see basic device info. MVP complete!

---

## Phase 4: User Story 2 - Firmware Update (Priority: P2)

**Goal**: User can update watch firmware via MCUmgr/SMP

**Independent Test**: Connect to watch → Navigate to Firmware Update → Select firmware from GitHub → Upload → Verify new version after reboot

### Models

- [ ] T046 [P] [US2] Create FirmwareImage model in lib/data/models/firmware_image.dart
- [ ] T047 [P] [US2] Create DfuState enum in lib/data/models/dfu_state.dart

### Services

- [ ] T048 [US2] Create DFU service wrapping mcumgr_flutter in lib/services/dfu/dfu_service.dart
- [ ] T049 [US2] Create firmware manager for GitHub API in lib/services/dfu/firmware_manager.dart
- [ ] T050 [US2] Implement firmware download from GitHub artifacts
- [ ] T051 [US2] Implement zip extraction for multi-image firmware files
- [ ] T052 [US2] Implement single .bin file handling

### Providers

- [ ] T053 [US2] Create DFU providers in lib/providers/dfu_providers.dart

### UI

- [ ] T054 [US2] Create firmware update screen in lib/ui/screens/firmware/firmware_update_screen.dart
- [ ] T055 [US2] Add prebuilt firmware list (branches from GitHub)
- [ ] T056 [US2] Add local file picker for .zip/.bin
- [ ] T057 [US2] Add upload progress UI with percentage, speed, stage
- [ ] T058 [US2] Add battery level display (informational)
- [ ] T059 [US2] Handle navigation lock during critical upload phase
- [ ] T060 [US2] Implement reconnection after watch reboot

**Checkpoint**: User can update firmware from GitHub or local file with full progress visibility

---

## Phase 5: User Story 3 - Notification & Media Integration (Priority: P3)

**Goal**: User receives phone notifications and can control media on watch (platform-specific)

**Independent Test**:
- Android: Enable forwarding → Send test notification → Verify appears on watch
- iOS: Verify ANCS/AMS works between watch and iOS (app not involved)

### Models

- [ ] T061 [P] [US3] Create Notification model in lib/data/models/notification.dart

### Android Native (Platform Channel)

- [ ] T062 [US3] Create NotificationListenerServiceImpl in android/app/src/main/kotlin/.../NotificationListenerServiceImpl.kt
- [ ] T063 [US3] Create MediaSessionBridge in android/app/src/main/kotlin/.../MediaSessionBridge.kt
- [ ] T064 [US3] Register services in AndroidManifest.xml

### Flutter Services

- [ ] T065 [US3] Create notification service with MethodChannel in lib/services/notification/notification_service.dart
- [ ] T066 [US3] Create media service with MethodChannel in lib/services/media/media_service.dart
- [ ] T067 [US3] Implement notification → Gadgetbridge protocol translation
- [ ] T068 [US3] Implement music state/info → Gadgetbridge protocol translation

### Gadgetbridge Protocol Messages

- [ ] T069 [US3] Implement notify message (`t:"notify"`) in gadgetbridge_protocol.dart
- [ ] T070 [US3] Implement musicstate message (`t:"musicstate"`) in gadgetbridge_protocol.dart
- [ ] T071 [US3] Implement musicinfo message (`t:"musicinfo"`) in gadgetbridge_protocol.dart
- [ ] T072 [US3] Implement music control responses (`t:"music"`) from watch

### UI

- [ ] T073 [US3] Create notification settings screen in lib/ui/screens/notifications/notification_settings_screen.dart
- [ ] T074 [US3] Add app filter list for notification sources (Android)
- [ ] T075 [US3] Add NotificationListenerService permission flow (Android)

**Checkpoint**: Notifications forwarded (Android) or ANCS configured (iOS). Media control works.

---

## Phase 6: User Story 4 - Dashboard & Device Info (Priority: P4)

**Goal**: User sees at-a-glance watch info and navigates to all features

**Independent Test**: Connect to watch → See dashboard with connection status, battery, firmware version → Tap through to each section

### UI

- [ ] T076 [US4] Create dashboard screen in lib/ui/screens/dashboard/dashboard_screen.dart
- [ ] T077 [US4] Add watch status card (name, battery ring, firmware version)
- [ ] T078 [US4] Add connection status display with real-time updates
- [ ] T079 [US4] Add navigation tiles to: Settings, Notifications, Health, Firmware, Developer
- [ ] T080 [US4] Implement pull-to-refresh for device info sync

**Checkpoint**: Dashboard provides complete overview and navigation hub

---

## Phase 7: User Story 5 - Health & Activity Data (Priority: P5)

**Goal**: User views step counts, heart rate history, and live HR streaming

**Independent Test**: Connect → View Health → See today's steps (hourly breakdown) → Open HR view → See live plot

### Models

- [ ] T081 [P] [US5] Create HealthSample model in lib/data/models/health_sample.dart
- [ ] T082 [P] [US5] Create HealthType and Granularity enums

### Repository

- [ ] T083 [US5] Create health repository in lib/data/repositories/health_repository.dart
- [ ] T084 [US5] Implement 60-day data cleanup query

### Services

- [ ] T085 [US5] Create health sync service in lib/services/health/health_sync_service.dart
- [ ] T086 [US5] Implement Gadgetbridge activity messages (`t:"act"`, `t:"actfetch"`)
- [ ] T087 [US5] Implement HR GATT service subscription (standard 0x180D)

### Providers

- [ ] T088 [US5] Create health providers in lib/providers/health_providers.dart

### UI

- [ ] T089 [US5] Create health screen in lib/ui/screens/health/health_screen.dart
- [ ] T090 [US5] Add daily step summary with hourly breakdown chart
- [ ] T091 [US5] Add daily/weekly/monthly history tabs
- [ ] T092 [US5] Create heart rate screen in lib/ui/screens/health/heart_rate_screen.dart
- [ ] T093 [US5] Add real-time HR chart widget using fl_chart
- [ ] T094 [US5] Create RealTimeChart widget in lib/ui/widgets/real_time_chart.dart

**Checkpoint**: Health data syncs, persists, and displays with live HR streaming

---

## Phase 8: User Story 6 - Developer Tools (Priority: P6)

**Goal**: Developer enables Developer Mode and accesses diagnostics, logs, shell, sensor streaming

**Independent Test**: Enable Developer Mode → View live logs → Send shell command → Stream raw sensor data → View comm log

### Models

- [ ] T095 [P] [US6] Create LogEntry model in lib/data/models/log_entry.dart
- [ ] T096 [P] [US6] Create CommLogEntry model in lib/data/models/comm_log_entry.dart
- [ ] T097 [P] [US6] Create ShellCommand model in lib/data/models/shell_command.dart
- [ ] T098 [P] [US6] Create SensorReading model (in-memory) in lib/data/models/sensor_reading.dart

### Services

- [ ] T099 [US6] Create Extended API protocol in lib/services/protocol/extended_protocol.dart
- [ ] T100 [US6] Implement log streaming messages (Extended API `log_stream`)
- [ ] T101 [US6] Implement shell command messages (Extended API `shell`)
- [ ] T102 [US6] Create sensor GATT service client in lib/services/ble/sensor_gatt_service.dart
- [ ] T103 [US6] Implement comm log recording in protocol service

### Repository

- [ ] T104 [US6] Create comm log repository with rotation (5000 entries / 5MB)

### Providers

- [ ] T105 [US6] Create developer providers in lib/providers/developer_providers.dart

### UI

- [ ] T106 [US6] Create developer screen (hub) in lib/ui/screens/developer/developer_screen.dart
- [ ] T107 [US6] Add BLE diagnostics display (MTU, PHY, RSSI, reconnection count)
- [ ] T108 [US6] Create log viewer screen in lib/ui/screens/developer/log_viewer_screen.dart
- [ ] T109 [US6] Create shell terminal screen in lib/ui/screens/developer/shell_terminal_screen.dart
- [ ] T110 [US6] Create sensor debug screen in lib/ui/screens/developer/sensor_debug_screen.dart
- [ ] T111 [US6] Add real-time sensor charts (accel, gyro, PPG, temp)
- [ ] T112 [US6] Create comm log screen in lib/ui/screens/developer/comm_log_screen.dart
- [ ] T113 [US6] Add Developer Mode toggle in settings

**Checkpoint**: Full developer diagnostics available when Developer Mode enabled

---

## Phase 9: User Story 7 - Multiple Watch Management (Priority: P7)

**Goal**: User manages multiple paired ZSWatch devices

**Independent Test**: Pair two watches → View saved devices → Switch between them → Forget one

### Repository Updates

- [ ] T114 [US7] Extend watch repository for multi-watch management
- [ ] T115 [US7] Implement `is_primary` toggle logic

### UI

- [ ] T116 [US7] Create saved watches list in lib/ui/screens/connection/saved_watches_screen.dart
- [ ] T117 [US7] Add switch watch flow
- [ ] T118 [US7] Add forget device flow with confirmation
- [ ] T119 [US7] Update dashboard to show current watch selection

**Checkpoint**: User can manage and switch between multiple watches

---

## Phase 10: User Story 8 - App Settings (Priority: P8)

**Goal**: User configures app-specific settings (not watch settings)

**Independent Test**: Open Settings → Change a preference → Restart app → Verify persisted

### Repository

- [ ] T120 [US8] Create settings repository in lib/data/repositories/settings_repository.dart (SharedPreferences)

### UI

- [ ] T121 [US8] Create settings screen in lib/ui/screens/settings/settings_screen.dart
- [ ] T122 [US8] Add notification filter preferences (Android)
- [ ] T123 [US8] Add Developer Mode toggle (reference T113)
- [ ] T124 [US8] Add About section (app version, links)

**Checkpoint**: App settings persist across sessions

---

## Phase 11: User Story 9 - Battery & Connection Analytics (Priority: P9)

**Goal**: User analyzes battery drain and connection quality over time

**Independent Test**: Connect watch → View Battery Analytics → See 24h drain graph → View weekly trend

### Models

- [ ] T125 [P] [US9] Create BatteryReading model in lib/data/models/battery_reading.dart

### Repository

- [ ] T126 [US9] Create battery repository in lib/data/repositories/battery_repository.dart
- [ ] T127 [US9] Implement battery sampling (every 5 min when connected)
- [ ] T128 [US9] Implement RSSI history tracking

### Providers

- [ ] T129 [US9] Create analytics providers in lib/providers/analytics_providers.dart

### UI

- [ ] T130 [US9] Create battery analytics screen in lib/ui/screens/analytics/battery_analytics_screen.dart
- [ ] T131 [US9] Add 24-hour battery drain chart
- [ ] T132 [US9] Add 7-day battery trend chart
- [ ] T133 [US9] Add connection signal (RSSI) history chart

**Checkpoint**: Battery and connection analytics visualized over time

---

## Phase 12: User Story 10 - Voice Recording Playback (Priority: P10) [PLACEHOLDER]

**Goal**: User plays back voice memos from watch (depends on future firmware feature)

**Independent Test**: Record memo on watch → Sync to app → Play back audio

**Note**: This is a placeholder for future firmware capability. Only create stubs.

### Models

- [ ] T134 [P] [US10] Create VoiceMemo model stub in lib/data/models/voice_memo.dart

### Services

- [ ] T135 [US10] Create voice memo service stub in lib/services/voice/voice_memo_service.dart
- [ ] T136 [US10] Implement Extended API voice_memo messages (stub)

### UI

- [ ] T137 [US10] Create voice memos screen stub in lib/ui/screens/voice/voice_memos_screen.dart

**Checkpoint**: Voice recording structure ready for future firmware support

---

## Phase 13: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements affecting multiple user stories

- [ ] T138 [P] Add error handling and user-friendly error messages throughout
- [ ] T139 [P] Add loading states and empty states to all screens
- [ ] T140 Implement data retention cleanup scheduler (60-day purge)
- [ ] T141 Add app state restoration after background/kill
- [ ] T142 [P] Add micro-animations (fade transitions, button feedback)
- [ ] T143 Performance tuning for real-time charts (target 10Hz)
- [ ] T144 Verify all success criteria (SC-001 through SC-014)
- [ ] T145 Run quickstart.md validation scenarios
- [ ] T146 [P] Create README.md with setup and usage instructions

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup ─────────────────────────────────────┐
                                                    │
Phase 2: Foundational ◄─────────────────────────────┤
    │                                               │
    │ ⚠️ BLOCKS ALL USER STORIES                    │
    ▼                                               │
┌───────────────────────────────────────────────────┘
│
├──► Phase 3: US1 - Connect (P1) 🎯 MVP
│       └──► Phase 4: US2 - Firmware (P2)
│       └──► Phase 5: US3 - Notifications (P3)
│       └──► Phase 6: US4 - Dashboard (P4)
│       └──► Phase 7: US5 - Health (P5)
│       └──► Phase 8: US6 - Developer Tools (P6)
│       └──► Phase 9: US7 - Multi-Watch (P7)
│       └──► Phase 10: US8 - Settings (P8)
│       └──► Phase 11: US9 - Analytics (P9)
│       └──► Phase 12: US10 - Voice [STUB] (P10)
│
└──► Phase 13: Polish (after desired stories complete)
```

### User Story Dependencies

| Story | Depends On | Can Parallel With |
|-------|------------|-------------------|
| US1 (Connect) | Foundational | None - MVP foundation |
| US2 (Firmware) | US1 (needs connection) | US3, US4, US5, US6 |
| US3 (Notifications) | US1 (needs connection) | US2, US4, US5, US6 |
| US4 (Dashboard) | US1 (needs connection) | US2, US3, US5, US6 |
| US5 (Health) | US1 (needs connection) | US2, US3, US4, US6 |
| US6 (Developer) | US1 (needs connection) | US2, US3, US4, US5 |
| US7 (Multi-Watch) | US1 (needs watch model) | US2-US6 |
| US8 (Settings) | Foundational | All stories |
| US9 (Analytics) | US1 (needs connection) | US2-US8 |
| US10 (Voice) | US1 (stub only) | All stories |

### Parallel Opportunities Per Phase

**Phase 1 (Setup)**:
```
Parallel: T002, T003, T004, T005, T006, T007
```

**Phase 2 (Foundational)**:
```
Parallel Set 1: T009, T010, T011, T012 (tables)
Parallel Set 2: T021, T022, T023 (providers)
Parallel Set 3: T024, T025, T026 (widgets)
```

**Phase 3 (US1)**:
```
Parallel: T030, T031, T032 (models)
Parallel: T040 (scan screen can start early)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational ⚠️ CRITICAL
3. Complete Phase 3: User Story 1 (Connect to Watch)
4. **STOP AND VALIDATE**: Test connection flow end-to-end
5. Deploy/demo the MVP

### Recommended Build Order

| Order | Story | Rationale |
|-------|-------|-----------|
| 1 | US1 (Connect) | Foundation for everything |
| 2 | US4 (Dashboard) | Provides navigation hub |
| 3 | US2 (Firmware) | High user value, critical |
| 4 | US3 (Notifications) | Core smartwatch feature |
| 5 | US5 (Health) | Key value proposition |
| 6 | US8 (Settings) | Enhances UX |
| 7 | US7 (Multi-Watch) | Convenience feature |
| 8 | US9 (Analytics) | Power user feature |
| 9 | US6 (Developer) | Developer-focused |
| 10 | US10 (Voice) | Future placeholder |

### Parallel Team Strategy

With 2+ developers after Foundational phase:
- **Developer A**: US1 → US2 → US5
- **Developer B**: US4 → US3 → US6

---

## Task Summary

| Phase | Task Count | Stories |
|-------|------------|---------|
| Phase 1: Setup | 7 | - |
| Phase 2: Foundational | 22 | - |
| Phase 3: US1 Connect | 16 | P1 MVP |
| Phase 4: US2 Firmware | 15 | P2 |
| Phase 5: US3 Notifications | 15 | P3 |
| Phase 6: US4 Dashboard | 5 | P4 |
| Phase 7: US5 Health | 14 | P5 |
| Phase 8: US6 Developer | 19 | P6 |
| Phase 9: US7 Multi-Watch | 6 | P7 |
| Phase 10: US8 Settings | 5 | P8 |
| Phase 11: US9 Analytics | 9 | P9 |
| Phase 12: US10 Voice | 4 | P10 |
| Phase 13: Polish | 9 | - |
| **Total** | **146** | 10 stories |

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story should be independently testable after completion
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Voice Recording (US10) is a placeholder stub - full implementation depends on firmware

