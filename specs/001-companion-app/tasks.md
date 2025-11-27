# Tasks: ZSWatch Companion App

**Input**: Design documents from `/specs/001-companion-app/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

**Updated**: 2025-11-27 - Added tasks for new requirements (Start Page, Auto-Reconnect, Notification Sync, Music Control, Debug Tools, GPS Support)

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- File paths relative to `zswatch_app/` (Flutter project root)

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Initialize Flutter project and configure dependencies

**⚠️ IMPORTANT**: The Flutter project MUST be created via `flutter create zswatch_app`. AI assistants must assume this structure already exists.

- [X] T001 Configure dependencies in pubspec.yaml (flutter_blue_plus, mcumgr_flutter, flutter_riverpod, drift, fl_chart, etc.)
- [X] T002 [P] Configure Android permissions in android/app/src/main/AndroidManifest.xml
- [X] T003 [P] Configure iOS permissions and background modes in ios/Runner/Info.plist
- [X] T004 [P] Create core constants in lib/core/constants/ble_constants.dart (service UUIDs, characteristic UUIDs)
- [X] T005 [P] Create app theme in lib/core/theme/app_theme.dart (dark theme, ZSWatch colors)
- [X] T006 [P] Create core extensions in lib/core/extensions/datetime_extensions.dart
- [X] T007 [P] Setup analysis_options.yaml with Flutter lints

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Database Layer

- [X] T008 Create drift database configuration in lib/data/database/app_database.dart
- [X] T009 [P] Create Watch table schema in lib/data/database/tables/watches_table.dart
- [X] T010 [P] Create HealthSamples table schema in lib/data/database/tables/health_samples_table.dart
- [X] T011 [P] Create BatteryReadings table schema in lib/data/database/tables/battery_readings_table.dart
- [X] T012 [P] Create CommLogEntries table schema in lib/data/database/tables/comm_log_entries_table.dart
- [X] T013 Generate drift database code via build_runner

### BLE Abstraction Layer

- [X] T014 Create BLE service interface in lib/services/ble/ble_service.dart
- [X] T015 Create BLE service implementation in lib/services/ble/ble_service_impl.dart (flutter_blue_plus)
- [X] T016 Create GATT operations helper in lib/services/ble/gatt_operations.dart
- [X] T017 Create BLE constants (NUS UUIDs, ZSWatch UUIDs) in lib/core/constants/ble_uuids.dart

### Protocol Layer

- [X] T018 Create protocol service interface in lib/services/protocol/protocol_service.dart
- [X] T019 Create Gadgetbridge protocol implementation in lib/services/protocol/gadgetbridge_protocol.dart
- [X] T020 Create message types enum/classes in lib/services/protocol/message_types.dart

### State Management Foundation

- [X] T021 Create BLE providers in lib/providers/ble_providers.dart (connection state, scanning state)
- [X] T022 [P] Create watch providers in lib/providers/watch_providers.dart
- [X] T023 [P] Create settings providers in lib/providers/settings_providers.dart

### Base UI Components

- [X] T024 [P] Create ConnectionStatusPill widget in lib/ui/widgets/connection_status_pill.dart
- [X] T025 [P] Create BatteryRing widget in lib/ui/widgets/battery_ring.dart
- [X] T026 [P] Create ProgressCard widget in lib/ui/widgets/progress_card.dart
- [X] T027 Create app router/navigation in lib/ui/navigation/app_router.dart

### App Entry Points

- [X] T028 Configure main.dart with ProviderScope in lib/main.dart
- [X] T029 Create App widget in lib/app.dart with theme and router

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Connect to Watch (Priority: P1) 🎯 MVP

**Goal**: User can discover, pair, and connect to a ZSWatch via BLE

**Independent Test**: Open app → Tap "Add Watch" → See ZSWatch in list → Tap to connect → See connection status and device info

### Models

- [X] T030 [P] [US1] Create Watch model in lib/data/models/watch.dart
- [X] T031 [P] [US1] Create Connection model (in-memory state) in lib/data/models/connection.dart
- [X] T032 [P] [US1] Create ConnectionState enum in lib/data/models/connection_state.dart

### BLE Services

- [X] T033 [US1] Implement BLE scanner in lib/services/ble/ble_scanner.dart
- [X] T034 [US1] Implement BLE connection manager in lib/services/ble/ble_connection_manager.dart
- [X] T035 [US1] Add MTU negotiation and DLE enable to connection manager
- [X] T036 [US1] Add 2M PHY request to connection manager
- [X] T037 [US1] Implement bonding/pairing flow with secure key storage

### Repository

- [X] T038 [US1] Create watch repository in lib/data/repositories/watch_repository.dart

### Providers

- [X] T039 [US1] Update BLE providers with scanner and connection state

### UI Screens

- [X] T040 [P] [US1] Create scan screen in lib/ui/screens/connection/scan_screen.dart
- [X] T041 [US1] Create device list component in lib/ui/screens/connection/device_list_screen.dart
- [X] T042 [US1] Add connection progress UI with state transitions
- [X] T043 [US1] Add permission request handling (Bluetooth, Location for Android)

### Gadgetbridge Integration

- [X] T044 [US1] Implement device info request (`t:"ver"`) in gadgetbridge_protocol.dart
- [X] T045 [US1] Implement time sync on connect in lib/services/time/time_sync_service.dart

**Checkpoint**: User can discover, connect, and see basic device info. MVP complete!

---

## Phase 3.5: Connection Flow Completion (Gap Tasks)

**Goal**: Complete the connection flow with dashboard, device info display, and proper state management

**Note**: These tasks were identified as missing during Phase 3 implementation

### Unified Watch Service

- [X] T045a [US1] Create unified WatchService in lib/services/watch_service.dart
  - Combines BLE connection, protocol, and device info in one service
  - Handles connection lifecycle, bonding, MTU negotiation
  - Requests device info and syncs time on connect
  - Subscribes to battery notifications

### Dashboard Screen

- [X] T045b [US1] Create dashboard screen in lib/ui/screens/dashboard/dashboard_screen.dart
  - Connection status card with RSSI and MTU
  - Battery level ring display
  - Firmware version display
  - Device info card (name, ID, hardware)
  - Disconnect button
  - Feature shortcuts grid

### Watch State Provider

- [X] T045c [US1] Create watch service providers in lib/providers/watch_service_provider.dart
  - watchServiceProvider - singleton WatchService
  - watchConnectionProvider - reactive connection state
  - currentWatchProvider - watch info with battery/firmware
  - watchNotifierProvider - connect/disconnect actions
  - knownWatchIdsProvider - saved watch IDs for filtering

### Home Screen Updates

- [X] T045d [US1] Update home screen to show dashboard when connected
  - Welcome screen when disconnected
  - Progress indicator when connecting
  - Dashboard when connected

### Scan Screen Enhancements

- [X] T045e [US1] Show already connected devices in scan list
  - Display system-connected devices
  - Filter bonded devices to only show saved watches
  - Show "Connected", "Saved", or RSSI status appropriately
  - Track advertising vs bonded-only devices

### Navigation Fixes

- [X] T045f [US1] Fix navigation to use push() instead of go() for sub-screens
  - Enables Android back button to work correctly

---

## Phase 3.6: Start Page & Auto-Reconnect (US1 Extension) 🆕

**Goal**: Implement start page with stored watches and auto-reconnect behavior per FR-067 to FR-074

**Independent Test**: Open app → See stored watches → Tap stored watch to connect → Close app → Reopen → Auto-reconnect starts

### Models

- [X] T045g [P] [US1] Update Watch model with customName and lastConnected fields in lib/data/models/watch.dart

### Services

- [X] T045h [US1] Create auto-reconnect service in lib/services/ble/auto_reconnect_service.dart
  - Periodic reconnect attempts within platform limits (FR-072)
  - Non-blocking reconnect that allows manual watch selection (FR-073)
  - Configurable retry intervals

### Repository

- [X] T045i [US1] Update watch_repository.dart to track last connected watch
  - Add getLastConnectedWatch() method
  - Add updateLastConnected() method

### Providers

- [X] T045j [US1] Create auto_reconnect_provider.dart in lib/providers/
  - autoReconnectStateProvider - current reconnect status
  - autoReconnectEnabledProvider - user preference
  - lastConnectedWatchProvider - for auto-reconnect target

### UI: Start Page

- [X] T045k [US1] Create start page screen in lib/ui/screens/start/start_page_screen.dart
  - Display all stored/previously paired watches prominently (FR-067)
  - "Connect new watch" button for scanning (FR-068)
  - Tap stored watch to initiate connection (FR-069)
  - Show connection status per stored watch (connecting, out of range)

- [X] T045l [US1] Create stored_watch_card.dart widget (implemented as _WatchListTile in start_page_screen.dart)
  - Watch name (custom or default)
  - Last connected timestamp
  - Connection status indicator
  - Tap to connect action

- [X] T045m [US1] Update app_router.dart to use start page as initial route
  - Navigate to dashboard on successful connection (FR-070, FR-074)
  - Show auto-reconnect progress indicator

### Auto-Reconnect Logic

- [X] T045n [US1] Implement auto-reconnect on app launch in watch_service.dart
  - Attempt reconnect to last connected watch (FR-071)
  - Run periodically until connected or user selects different watch (FR-072)
  - Allow user to manually select different watch (FR-073)

**Checkpoint**: Start page shows stored watches, auto-reconnect works on app launch ✅

---

## Phase 3.7: Initial Sync on Connect (US1 Extension) 🆕

**Goal**: Send critical state data to watch immediately on connection per FR-084 to FR-088

**Independent Test**: Connect to watch → Verify time synced → Verify music info sent (if playing) → Connection fully established

### Services

- [X] T045o [US1] Create initial_sync_service.dart in lib/services/sync/
  - Orchestrate all initial sync operations
  - Time sync (FR-085)
  - Music state sync (FR-086)
  - Other relevant state (FR-087)
  - Mark connection complete only after sync (FR-088)

### Integration

- [X] T045p [US1] Update watch_service.dart to call initial sync on connect
  - Call initial_sync_service after BLE connection established
  - Send time via Gadgetbridge protocol
  - Query media service for current playback state
  - Send music info if playing/paused
  - Emit "fully connected" only after sync completes

- [X] T045q [US1] Update connection state to include sync status
  - Add `syncing` state between `connected` and `ready`
  - Update ConnectionStatusPill to show sync progress

**Checkpoint**: Watch receives time and music info immediately on connect ✅

---

## Phase 3.8: Persistent BLE Connection (Background Service) 🆕

**Goal**: Maintain reliable BLE connection when app is backgrounded per FR-089 to FR-092

**⚠️ CRITICAL**: This phase is essential for reliable notification forwarding and real-world usage. Must be implemented early.

**Independent Test**: Connect to watch → Background app → Wait 30 min → Verify still connected. Send notification while backgrounded → Verify received on watch.

### Android: Foreground Service

- [ ] T045r [P] Create ForegroundServiceManager in android/app/src/main/kotlin/.../ForegroundServiceManager.kt
  - Create persistent notification (FR-092)
  - Indicate "Maintaining watch connection" status
  - Handle service start/stop

- [ ] T045s Create BleConnectionForegroundService in android/app/src/main/kotlin/.../
  - Foreground service for background BLE (FR-050, FR-089)
  - Start when connected, stop when disconnected
  - Persist connection even when UI not active

- [ ] T045t Update AndroidManifest.xml with foreground service declaration
  - Add FOREGROUND_SERVICE permission
  - Declare service with proper type (connectedDevice)

- [ ] T045u Create foreground_service.dart Flutter wrapper in lib/services/background/
  - MethodChannel to start/stop foreground service
  - Query service status

### iOS: Background Modes

- [ ] T045v Verify Info.plist has bluetooth-central background mode (FR-051)
  - Already configured in Phase 1, verify still present

- [ ] T045w Implement iOS background connection handling
  - Use CoreBluetooth state restoration
  - Handle reconnection on iOS wake

### Integration

- [ ] T045x Update watch_service.dart to manage background connection
  - Start foreground service on connect (Android)
  - Stop foreground service on disconnect
  - Maintain connection across app lifecycle

- [ ] T045y Update notification and media services for background operation
  - Verify notifications forward when backgrounded (FR-090)
  - Verify music info sends when backgrounded

- [ ] T045z Add background connection setting in settings_screen.dart
  - Toggle to enable/disable persistent connection
  - Warning about battery impact

**Checkpoint**: BLE connection stable for 8+ hours when backgrounded (SC-021)

---

## Phase 4: User Story 2 - Firmware Update (Priority: P2) ✅ COMPLETE

**Goal**: User can update watch firmware via MCUmgr/SMP

**Independent Test**: Connect to watch → Navigate to Firmware Update → Select firmware from GitHub → Upload → Verify new version after reboot

### Models

- [X] T046 [P] [US2] Create FirmwareImage model in lib/data/models/firmware_image.dart
  - Includes ReleaseAsset model for GitHub release assets
  - Supports manifest.json parsing for image_index (slot) mapping
  - Board detection from manifest for proper image type classification
- [X] T047 [P] [US2] Create DfuState enum in lib/data/models/dfu_state.dart

### Services

- [X] T048 [US2] Create DFU service wrapping mcumgr_flutter in lib/services/dfu/dfu_service.dart
  - Uses FirmwareUpgradeMode.confirmOnly for proper image confirmation
  - Handles multi-image uploads with correct slot mapping from manifest
  - Speed calculation and progress tracking
- [X] T049 [US2] Create firmware manager for GitHub API in lib/services/dfu/firmware_manager.dart
  - Fetches releases with all available firmware assets (multiple HW variants)
  - Fetches CI builds from GitHub Actions
- [X] T050 [US2] Implement firmware download from GitHub artifacts
  - GitHub releases: Downloads outer zip, extracts dfu_application.zip
  - GitHub Actions: Opens in browser (requires auth for direct download)
- [X] T051 [US2] Implement zip extraction for multi-image firmware files
  - Parses manifest.json for image_index mapping
  - Extracts all .bin files referenced in manifest
  - Sorts images by slot for correct upload order
- [X] T052 [US2] Implement single .bin file handling

### Providers

- [X] T053 [US2] Create DFU providers in lib/providers/dfu_providers.dart
  - Manual fetch for releases and CI builds (avoids rate limiting)
  - Download progress tracking
  - DFU operation state management

### UI

- [X] T054 [US2] Create firmware update screen in lib/ui/screens/firmware/firmware_update_screen.dart
- [X] T055 [US2] Add prebuilt firmware list (branches from GitHub)
  - Shows all releases with expandable asset selection dialog
  - User selects hardware variant (watchdk, zswatch_legacy, etc.)
  - CI builds section with branch grouping
- [X] T056 [US2] Add local file picker for .zip
  - Uses file_picker package
  - Supports dfu_application.zip files
- [X] T057 [US2] Add upload progress UI with percentage, speed, stage
  - Real-time speed calculation
  - Remaining time estimate
  - Multi-image progress tracking
- [X] T058 [US2] Add battery level display (informational)
- [X] T059 [US2] Handle navigation lock during critical upload phase
  - PopScope prevents back navigation during critical DFU states
  - Warning dialog if user attempts to leave
- [X] T060 [US2] Implement reconnection after watch reboot
  - Fixed reconnection loop issue with _isSettingUp guard

**Checkpoint**: User can update firmware from GitHub releases or local file with full progress visibility ✅

---

## Phase 4.5: Filesystem Upload via MCUmgr (US2 Extension) ✅ COMPLETE

**Goal**: User can upload filesystem images (lvgl_resources_raw.bin) via MCUmgr filesystem commands

**Independent Test**: Download release → See filesystem option → Upload filesystem → Verify progress → Confirm upload completes

**Note**: This extends User Story 2 (Firmware Update) to support filesystem images found in the same release zip

**Note**: The file lvgl_resources_raw.bin is part of the downloaded firmware zip from github. In the same zip as we find dfu_application.zip.

### Models

- [X] T060a [P] [US2] Create FilesystemImage model in lib/data/models/filesystem_image.dart
  - Target path on device (`/S/full_fs`)
  - Source file path (local)
  - File size
  - Upload status tracking

### Services

- [X] T060b [US2] Create filesystem upload service in lib/services/dfu/filesystem_upload_service.dart
  - Uses mcumgr_flutter FsManagerApi for upload
  - Subscribes to FsManagerEvents.getFileUploadEvents() for progress
  - Speed calculation and progress tracking
  - Error handling and retry logic
- [X] T060c [US2] Update firmware_manager.dart to detect lvgl_resources_raw.bin during zip extraction
  - Check for lvgl_resources_raw.bin alongside dfu_application.zip
  - Extract and store filesystem image when found
  - Return both firmware images and filesystem image availability

### Providers

- [X] T060d [US2] Create filesystem upload providers in lib/providers/filesystem_providers.dart
  - filesystemImageProvider - detected filesystem image from zip
  - filesystemUploadStateProvider - upload progress/status
  - filesystemUploadProgressProvider - percentage, speed, time remaining
- [X] T060e [US2] Update dfu_providers.dart to coordinate filesystem and firmware uploads
  - Track which update types are available (FW only, FS only, Both)
  - Orchestrate "Start Both" flow: filesystem first, then firmware
  - When a dfu_application.zip is selected, we also behind the scenes pick the lvgl_resources_raw.bin

### UI Updates

- [X] T060f [US2] Update firmware_update_screen.dart with three update options
  - "Start FW Update" button (existing, always shown when FW available)
  - "Start Filesystem Update" button (shown when lvgl_resources_raw.bin detected)
  - "Start Both" button (shown when both available)
  - Disable unavailable options with tooltip explanation
- [X] T060g [US2] Add filesystem upload progress UI
  - Reuse existing progress card pattern
  - Show percentage, speed (KB/s), time remaining
  - Show "Uploading filesystem..." status during upload
- [X] T060h [US2] Implement "Start Both" orchestration flow
  - Step 1: Upload filesystem with progress
  - Step 2: After filesystem completes, automatically start firmware upload
  - Combined progress indication (e.g., "Step 1/2: Filesystem" → "Step 2/2: Firmware")
  - Handle errors at each step with ability to retry
- [X] T060i [US2] Update zip selection to show filesystem detection status
  - Indicate when lvgl_resources_raw.bin was found in release
  - Show filesystem image size
  - Warning if filesystem not found in release (FW-only update)

### Constants

- [X] T060j [P] [US2] Add filesystem constants in lib/core/constants/filesystem_constants.dart
  - Target path: `/S/full_fs`
  - Expected filename: `lvgl_resources_raw.bin`

**Checkpoint**: User can upload filesystem images from GitHub releases or local files, with option to upload both filesystem and firmware in sequence ✅

---

## Phase 5: User Story 3 - Notification & Media Integration (Priority: P3) ✅ PARTIAL

**Goal**: User receives phone notifications and can control media on watch (platform-specific)

**Independent Test**:
- Android: Enable forwarding → Send test notification → Verify appears on watch
- iOS: Verify ANCS/AMS works between watch and iOS (app not involved)

### Models

- [X] T061 [P] [US3] Create Notification model in lib/data/models/notification.dart

### Android Native (Platform Channel)

- [X] T062 [US3] Create NotificationListenerServiceImpl in android/app/src/main/kotlin/.../NotificationListenerServiceImpl.kt
- [X] T063 [US3] Create MediaSessionBridge in android/app/src/main/kotlin/.../MediaSessionBridge.kt
- [X] T064 [US3] Register services in AndroidManifest.xml

### Flutter Services

- [X] T065 [US3] Create notification service with MethodChannel in lib/services/notification/notification_service.dart
- [X] T066 [US3] Create media service with MethodChannel in lib/services/media/media_service.dart
- [X] T067 [US3] Implement notification → Gadgetbridge protocol translation
- [X] T068 [US3] Implement music state/info → Gadgetbridge protocol translation

### Gadgetbridge Protocol Messages

- [X] T069 [US3] Implement notify message (`t:"notify"`) in gadgetbridge_protocol.dart
- [X] T070 [US3] Implement musicstate message (`t:"musicstate"`) in gadgetbridge_protocol.dart
- [X] T071 [US3] Implement musicinfo message (`t:"musicinfo"`) in gadgetbridge_protocol.dart
- [X] T072 [US3] Implement music control responses (`t:"music"`) from watch

### UI

- [X] T073 [US3] Create notification settings screen in lib/ui/screens/notifications/notification_settings_screen.dart
- [X] T074 [US3] Add app filter list for notification sources (Android)
- [X] T075 [US3] Add NotificationListenerService permission flow (Android)

**Checkpoint**: Notifications forwarded (Android) or ANCS configured (iOS). Media control works. ✅

---

## Phase 5.5: Notification Stable IDs & Dismiss Sync (US3 Extension) 🆕

**Goal**: Implement bi-directional notification dismiss sync per FR-075 to FR-078

**Independent Test**: Send notification → Dismiss on watch → Verify removed from phone. Send notification → Dismiss on phone → Verify removed from watch.

### Models

- [ ] T075a [P] [US3] Update Notification model with stableId, dismissedOnPhone, dismissedOnWatch fields in lib/data/models/notification.dart

### Services

- [ ] T075b [US3] Create notification_sync_service.dart in lib/services/notification/
  - Generate stable unique notification IDs (FR-075)
  - Handle dismiss callback from watch (FR-076)
  - Send dismiss command to watch on phone dismiss (FR-077)
  - Track pending dismiss sync for offline queuing

- [ ] T075c [US3] Update notification_service.dart to use stable IDs
  - Generate stable ID per notification
  - Include stable ID in Gadgetbridge notify message
  - Listen for notification removal on phone

### Gadgetbridge Protocol

- [ ] T075d [US3] Implement dismiss callback handling in gadgetbridge_protocol.dart
  - Parse dismiss message from watch with notification ID
  - Trigger phone notification removal via NotificationService

- [ ] T075e [US3] Implement dismiss command with "-" prefix in gadgetbridge_protocol.dart
  - Format: notify with "-" + stableId
  - Send when phone notification is dismissed

### Android Native

- [ ] T075f [US3] Update NotificationListenerServiceImpl to track stable IDs
  - Map system notification key to stable ID
  - Expose cancelNotification(stableId) method
  - Report notification dismissal with stable ID

- [ ] T075g [US3] Handle notification removal callback in Android
  - Detect when user dismisses notification on phone
  - Notify Flutter via MethodChannel with stable ID

### Integration

- [ ] T075h [US3] Wire dismiss sync in watch_service.dart or dedicated provider
  - On watch dismiss: remove phone notification
  - On phone dismiss: send dismiss to watch
  - Queue dismiss commands if disconnected, send on reconnect

**Checkpoint**: Notification dismissals sync bi-directionally between phone and watch

---

## Phase 5.6: Music Control Integration Enhancement (US3 Extension) 🆕

**Goal**: Enhanced music control per FR-079 to FR-083

**Independent Test**: Play music → Connect watch → Verify immediate music info. Change track → Verify update on watch. Tap play/pause on watch → Verify phone responds.

### Services

- [ ] T075i [US3] Update media_service.dart for enhanced music control
  - Listen for media control commands from watch (FR-079)
  - Forward commands to MediaController (play/pause/next/previous)
  - Immediate update on track change (FR-080)
  - Immediate update on playback state change (FR-081)
  - Periodic updates while playing (FR-082)

- [ ] T075j [US3] Create MediaState model in lib/data/models/media_state.dart
  - title, artist, album, playbackState, position, duration
  - timestamp for last update

### Android Native

- [ ] T075k [US3] Update MediaSessionBridge for control commands
  - Receive control commands from Flutter
  - Execute on active MediaSession (play, pause, next, previous, etc.)
  - Detect track changes and notify Flutter immediately
  - Detect playback state changes and notify Flutter immediately

### Protocol

- [ ] T075l [US3] Implement music control command parsing in gadgetbridge_protocol.dart
  - Parse `t:"music"` with action (play, pause, next, prev, volumeup, volumedown)
  - Forward to media_service

### Integration

- [ ] T075m [US3] Update initial_sync_service to include music state
  - Query current music state on connect
  - Send immediately if playing or paused (FR-083)

- [ ] T075n [US3] Implement periodic music updates in media_service.dart
  - Send updates every 30 seconds while playing (configurable)
  - Stop periodic updates when paused/stopped

**Checkpoint**: Full bi-directional music control with immediate and periodic updates

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

**Goal**: Developer enables Developer Mode and accesses diagnostics, logs, shell, sensor streaming, notification/music debug tools

**Independent Test**: Enable Developer Mode → View live logs → Send shell command → Stream raw sensor data → Send debug notification → Send sample music metadata → View comm log

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

### Notification Debug Tools (FR-093 to FR-097) 🆕

- [ ] T113a [P] [US6] Create notification_debug_section.dart widget in lib/ui/widgets/developer/
  - App name dropdown/selector (FR-094)
  - Notification text input field (FR-095)
  - "Send Debug Notification" button (FR-096)

- [ ] T113b [US6] Implement debug notification service in lib/services/notification/debug_notification_service.dart
  - Create test notification on phone (FR-097)
  - Send notification to watch via Gadgetbridge protocol
  - Use stable ID for bi-directional dismiss testing

- [ ] T113c [US6] Add notification debug section to notification_settings_screen.dart
  - Only visible when Developer Mode enabled
  - Show debug section below main settings

### Music Debug Tools (FR-098) 🆕

- [ ] T113d [P] [US6] Create music_debug_section.dart widget in lib/ui/widgets/developer/
  - Buttons for sample track 1, 2, 3
  - Each sends different static metadata (title, artist, album)
  - Play/Pause state toggle

- [ ] T113e [US6] Implement debug music service in lib/services/media/debug_music_service.dart
  - Send static sample "now playing" metadata to watch
  - Predefined test tracks with different metadata
  - Useful for testing music display without actual playback

- [ ] T113f [US6] Add music debug section to developer_screen.dart or notification_settings_screen.dart

**Checkpoint**: Full developer diagnostics available when Developer Mode enabled, including notification and music debug tools

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

**Goal**: User configures app-specific settings (not watch settings), including watch rename

**Independent Test**: Open Settings → Change a preference → Restart app → Verify persisted. Rename a watch → Verify custom name shows throughout app.

### Repository

- [ ] T120 [US8] Create settings repository in lib/data/repositories/settings_repository.dart (SharedPreferences)

### UI

- [ ] T121 [US8] Create settings screen in lib/ui/screens/settings/settings_screen.dart
- [ ] T122 [US8] Add notification filter preferences (Android)
- [ ] T123 [US8] Add Developer Mode toggle (reference T113)
- [ ] T124 [US8] Add About section (app version, links)

### Watch Rename Feature (FR-099 to FR-102) 🆕

- [ ] T124a [US8] Update Watch model with customName field (nullable)
  - Store user-defined name alongside default name
  - Display customName if set, otherwise default name (FR-102)

- [ ] T124b [US8] Create watch_management_screen.dart in lib/ui/screens/settings/
  - List all paired/bonded watches (FR-100)
  - Show current name (custom or default)
  - Edit button per watch to rename

- [ ] T124c [US8] Create rename_watch_dialog.dart in lib/ui/widgets/
  - Text input for custom name
  - Save/Cancel buttons
  - Validate name not empty

- [ ] T124d [US8] Update watch_repository.dart with renameWatch method
  - Persist customName to database (FR-101)
  - Emit update to notify UI

- [ ] T124e [US8] Update all UI components to use displayName getter
  - stored_watch_card.dart
  - dashboard_screen.dart
  - device_list_screen.dart
  - Any other places showing watch name

- [ ] T124f [US8] Add "Manage Watches" navigation from settings_screen.dart
  - Links to watch_management_screen

**Checkpoint**: App settings persist across sessions, watches can be renamed

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

## Phase 11.5: GPS Location Support (Gadgetbridge GPSPower) 🆕

*Note: Persistent BLE Connection moved to Phase 3.8 for earlier implementation*

**Goal**: Handle GPS location requests from watch per FR-103 to FR-107

**Independent Test**: Connect to watch → Watch requests GPS → Phone obtains location → Watch receives coordinates

### Models

- [ ] T133j [P] Create GPSLocation model in lib/data/models/gps_location.dart
  - latitude, longitude, accuracy, altitude, timestamp

### Services

- [ ] T133k Create gps_service.dart in lib/services/location/
  - Request location permission (FR-105)
  - Obtain current location from phone
  - Handle permission denial gracefully (FR-107)
  - Return fresh location (not stale)

### Gadgetbridge Protocol

- [ ] T133l Implement GPSPower command handling in gadgetbridge_protocol.dart
  - Parse GPS request from watch (FR-103)
  - Format: `t:"gps"` or similar Gadgetbridge GPS message

- [ ] T133m Implement GPS response in gadgetbridge_protocol.dart
  - Send location in Gadgetbridge-compatible format (FR-106)
  - Include lat, lon, accuracy, speed, bearing

### Integration

- [ ] T133n Create gps_handler.dart in lib/services/location/
  - Listen for GPS requests from protocol service
  - Call gps_service to obtain location
  - Send response via protocol service

- [ ] T133o Add location permission request in permission_handler
  - Request ACCESS_FINE_LOCATION on Android
  - Request location when-in-use on iOS
  - Handle permission denied with error response to watch

### Dependencies

- [ ] T133p Add geolocator package to pubspec.yaml
  - Or use location package for cross-platform GPS

**Checkpoint**: Watch can request and receive phone GPS location

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
│       │
│       ├──► Phase 3.5: Gap Tasks (connection completion)
│       │
│       ├──► Phase 3.6: Start Page & Auto-Reconnect 🆕
│       │
│       └──► Phase 3.7: Initial Sync on Connect 🆕
│       │
│       └──► Phase 3.8: Persistent BLE Connection 🆕 ⚠️ CRITICAL
│
├──► Phase 4: US2 - Firmware (P2)
│       │
│       └──► Phase 4.5: Filesystem Upload (extends US2)
│
├──► Phase 5: US3 - Notifications (P3)
│       │
│       ├──► Phase 5.5: Notification Dismiss Sync 🆕
│       │
│       └──► Phase 5.6: Music Control Enhancement 🆕
│
├──► Phase 6: US4 - Dashboard (P4)
├──► Phase 7: US5 - Health (P5)
├──► Phase 8: US6 - Developer Tools (P6)
│       │
│       └──► (includes Notification/Music Debug Tools 🆕)
│
├──► Phase 9: US7 - Multi-Watch (P7)
├──► Phase 10: US8 - Settings (P8)
│       │
│       └──► (includes Watch Rename 🆕)
│
├──► Phase 11: US9 - Analytics (P9)
├──► Phase 11.5: GPS Support 🆕
├──► Phase 12: US10 - Voice [STUB] (P10)
│
└──► Phase 13: Polish (after desired stories complete)
```

### User Story Dependencies

| Story | Depends On | Can Parallel With | New Tasks |
|-------|------------|-------------------|-----------|
| US1 (Connect) | Foundational | None - MVP foundation | Start Page, Auto-Reconnect, Initial Sync, Persistent BLE |
| US2 (Firmware) | US1 (needs connection) | US3, US4, US5, US6 | - |
| US2 Filesystem Extension | US2 (needs DFU infrastructure) | US3, US4, US5, US6 | - |
| US3 (Notifications) | US1 (needs connection) | US2, US4, US5, US6 | Dismiss Sync, Music Control |
| US4 (Dashboard) | US1 (needs connection) | US2, US3, US5, US6 | - |
| US5 (Health) | US1 (needs connection) | US2, US3, US4, US6 | - |
| US6 (Developer) | US1 (needs connection) | US2, US3, US4, US5 | Debug Tools |
| US7 (Multi-Watch) | US1 (needs watch model) | US2-US6 | - |
| US8 (Settings) | Foundational | All stories | Watch Rename |
| US9 (Analytics) | US1 (needs connection) | US2-US8 | - |
| GPS Support | US1 (needs connection) | All stories | Gadgetbridge GPS |
| US10 (Voice) | US1 (stub only) | All stories | - |

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

**Phase 3.6 (Start Page) 🆕**:
```
Parallel: T045g (model update)
Sequential: T045h → T045i → T045j (services, repo, providers)
Parallel: T045k, T045l (UI components after services)
```

**Phase 4.5 (Filesystem)**:
```
Parallel: T060a, T060j (model and constants)
Sequential: T060b → T060c → T060d → T060e (service → detection → providers)
Parallel: T060f, T060g, T060h, T060i (UI updates after services ready)
```

**Phase 5.5 (Dismiss Sync) 🆕**:
```
Parallel: T075a (model update)
Sequential: T075b → T075c → T075d → T075e (service chain)
Parallel: T075f, T075g (Android native)
```

**Phase 3.8 (Persistent BLE) 🆕**:
```
Parallel: T045r, T045v (Android/iOS can be parallel)
Sequential: T045s → T045t → T045u (Android service chain)
```

**Phase 11.5 (GPS) 🆕**:
```
Parallel: T133j, T133p (model and dependency)
Sequential: T133k → T133l → T133m → T133n (service → protocol → integration)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational ⚠️ CRITICAL
3. Complete Phase 3: User Story 1 (Connect to Watch)
4. Complete Phase 3.5: Gap Tasks (dashboard, navigation)
5. Complete Phase 3.6: Start Page & Auto-Reconnect 🆕
6. Complete Phase 3.7: Initial Sync on Connect 🆕
7. Complete Phase 3.8: Persistent BLE Connection 🆕 ⚠️ CRITICAL
8. **STOP AND VALIDATE**: Test connection flow end-to-end
8. Deploy/demo the MVP

### Recommended Build Order

| Order | Story | Rationale | New Work |
|-------|-------|-----------|----------|
| 1 | US1 (Connect) | Foundation for everything | Start Page, Auto-Reconnect, Initial Sync, Persistent BLE |
| 2 | US4 (Dashboard) | Provides navigation hub | - |
| 3 | US2 (Firmware) | High user value, critical | - |
| 4 | US3 (Notifications) | Core smartwatch feature | Dismiss Sync, Music Control |
| 5 | US5 (Health) | Key value proposition | - |
| 6 | US8 (Settings) | Enhances UX | Watch Rename |
| 7 | US7 (Multi-Watch) | Convenience feature | - |
| 8 | US9 (Analytics) | Power user feature | - |
| 9 | US6 (Developer) | Developer-focused | Debug Tools |
| 10 | GPS Support | Watch feature | Gadgetbridge GPS |
| 11 | US10 (Voice) | Future placeholder | - |

### Parallel Team Strategy

With 2+ developers after Foundational phase:
- **Developer A**: US1 (+ Start Page + Auto-Reconnect + Initial Sync + Persistent BLE) → US2 → US5
- **Developer B**: US4 → US3 (+ Dismiss Sync + Music Control) → US6 (+ Debug Tools) → GPS Support

### New Feature Priority

Based on user value and dependencies:

1. **High Priority (Core Experience)**:
   - Start Page with Stored Watches (US1)
   - Auto-Reconnect (US1)
   - Initial Sync (US1)
   - Notification Dismiss Sync (US3)
   - Persistent BLE Connection (Background)

2. **Medium Priority (Enhanced Features)**:
   - Music Control Enhancement (US3)
   - Watch Rename (US8)
   - GPS Support

3. **Lower Priority (Developer/Debug)**:
   - Notification Debug Tools (US6)
   - Music Debug Tools (US6)

---

## Task Summary

| Phase | Task Count | Stories | New Tasks 🆕 |
|-------|------------|---------|--------------|
| Phase 1: Setup | 7 | - | - |
| Phase 2: Foundational | 22 | - | - |
| Phase 3: US1 Connect | 16 | P1 MVP | - |
| Phase 3.5: Gap Tasks | 6 | P1 | - |
| Phase 3.6: Start Page & Auto-Reconnect 🆕 | 8 | P1 | 8 |
| Phase 3.7: Initial Sync 🆕 | 3 | P1 | 3 |
| Phase 3.8: Persistent BLE 🆕 | 9 | P1 | 9 |
| Phase 4: US2 Firmware | 15 | P2 | - |
| Phase 4.5: Filesystem | 10 | P2 | - |
| Phase 5: US3 Notifications | 15 | P3 | - |
| Phase 5.5: Dismiss Sync 🆕 | 8 | P3 | 8 |
| Phase 5.6: Music Control 🆕 | 6 | P3 | 6 |
| Phase 6: US4 Dashboard | 5 | P4 | - |
| Phase 7: US5 Health | 14 | P5 | - |
| Phase 8: US6 Developer | 25 | P6 | 6 (debug tools) |
| Phase 9: US7 Multi-Watch | 6 | P7 | - |
| Phase 10: US8 Settings | 11 | P8 | 6 (rename) |
| Phase 11: US9 Analytics | 9 | P9 | - |
| Phase 11.5: GPS Support 🆕 | 7 | - | 7 |
| Phase 12: US10 Voice | 4 | P10 | - |
| Phase 13: Polish | 9 | - | - |
| **Total** | **~205** | 10 stories | **~53 new** |

### New Requirements Coverage

| Requirement | Phase | Tasks |
|-------------|-------|-------|
| Start Page: Stored Watches (FR-067-070) | 3.6 | T045g-T045n |
| Auto-Reconnect (FR-071-074) | 3.6 | T045h, T045j, T045n |
| Initial Sync (FR-084-088) | 3.7 | T045o-T045q |
| Notification Stable IDs (FR-075-078) | 5.5 | T075a-T075h |
| Music Control Enhancement (FR-079-083) | 5.6 | T075i-T075n |
| Notification Debug Tools (FR-093-097) | 8 | T113a-T113c |
| Music Debug Tools (FR-098) | 8 | T113d-T113f |
| Watch Rename (FR-099-102) | 10 | T124a-T124f |
| Persistent BLE (FR-089-092) | 3.8 | T045r-T045z |
| GPS Support (FR-103-107) | 11.5 | T133j-T133p |

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- 🆕 marks new tasks added for 2025-11-27 requirements
- Each user story should be independently testable after completion
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Voice Recording (US10) is a placeholder stub - full implementation depends on firmware

