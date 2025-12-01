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

- [X] T045r [P] Create ForegroundServiceManager in android/app/src/main/kotlin/.../ForegroundServiceManager.kt
  - Create persistent notification (FR-092)
  - Update notification text based on state:
    - "Connected to [Watch Name]" when connected
    - "Reconnecting to [Watch Name]..." when disconnected/reconnecting
  - Handle service start/stop
  - Notification actions: Disconnect button (stops service and disconnects)
  - **Note**: Combined with T045s into BleConnectionForegroundService.kt

- [X] T045r2 [P] Create notification channel for foreground service (Android 8+)
  - Channel ID: "ble_connection"
  - Channel name: "Watch Connection"
  - Low importance (minimize intrusiveness)
  - Create channel on app startup in MainActivity

- [X] T045s Create BleConnectionForegroundService in android/app/src/main/kotlin/.../
  - Foreground service for background BLE (FR-050, FR-089)
  - Persist connection even when UI not active
  - Service stays alive until explicitly stopped (not tied to connection state)

- [X] T045t Update AndroidManifest.xml with foreground service declaration
  - Add FOREGROUND_SERVICE permission
  - Declare service with proper type (connectedDevice)

- [X] T045u Create foreground_service.dart Flutter wrapper in lib/services/background/
  - MethodChannel to start/stop foreground service
  - Method to update notification text (for connection state changes)
  - Query service status (running/stopped)

### iOS: Background Modes

- [X] T045v Verify Info.plist has bluetooth-central background mode (FR-051)
  - Already configured in Phase 1, verified still present

- [X] T045w Implement iOS background connection handling
  - Use CoreBluetooth state restoration (handled by flutter_blue_plus)
  - Handle reconnection on iOS wake (handled by flutter_blue_plus autoConnect)
  - **Note**: iOS background BLE handled natively via bluetooth-central background mode

### Integration

- [X] T045x Update watch_service.dart to manage background connection
  - Start foreground service when user initiates connection (Android)
  - Keep foreground service running on unexpected disconnect (enables auto-reconnect)
  - Stop foreground service only on explicit user disconnect or setting disabled
  - Maintain connection across app lifecycle
  - Listen to connection state changes and update notification text accordingly
  - **Note**: Implemented via ForegroundServiceNotifier in foreground_service_providers.dart

- [X] T045x2 Integrate auto_reconnect_service with foreground service
  - When running in background and watch disconnects, trigger auto-reconnect
  - Auto-reconnect must work when app UI is not active
  - Use flutter_blue_plus autoConnect feature for system-level reconnect
  - **Note**: ForegroundServiceNotifier updates notification to "Reconnecting..." state

- [X] T045y Update notification and media services for background operation
  - Verify notifications forward when backgrounded (FR-090)
  - Verify music info sends when backgrounded
  - **Note**: Existing notification/media services work when app backgrounded with foreground service

- [X] T045z Add background connection setting in settings_screen.dart
  - Toggle to enable/disable persistent connection (default: enabled)
  - Warning about battery impact
  - When disabled while connected: stop foreground service but keep current connection
  - When enabled while connected: start foreground service

- [X] T045z2 [P] Add battery optimization guidance (Android)
  - Detect if app is battery-optimized (affects background reliability)
  - Show info dialog explaining battery optimization impact
  - Provide button to open battery optimization settings
  - Note: Don't auto-request exemption, let user decide

**Checkpoint**: BLE connection stable for 8+ hours when backgrounded (SC-021) ✅

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

## Phase 5.5: Notification Stable IDs & Dismiss Sync (US3 Extension) 🆕 ✅ COMPLETE

**Goal**: Implement bi-directional notification dismiss sync per FR-075 to FR-078

**Independent Test**: Send notification → Dismiss on watch → Verify removed from phone. Send notification → Dismiss on phone → Verify removed from watch.

### Models

- [X] T075a [P] [US3] Update Notification model with stableId, dismissedOnPhone, dismissedOnWatch fields in lib/data/models/notification.dart
  - Uses Android sbn.id (converted to unsigned) as stable ID
  - Uses sbn.key for Android dismissal API

### Services

- [X] T075b [US3] Create notification_sync_service.dart in lib/services/notification/
  - Generate stable unique notification IDs (FR-075)
  - Handle dismiss callback from watch (FR-076)
  - Send dismiss command to watch on phone dismiss (FR-077)
  - Track pending dismiss sync for offline queuing
  - **Note**: Implemented in notification_providers.dart with _notificationIdToKey mapping

- [X] T075c [US3] Update notification_service.dart to use stable IDs
  - Generate stable ID per notification
  - Include stable ID in Gadgetbridge notify message
  - Listen for notification removal on phone
  - **Note**: notificationRemoved stream emits IDs, dismissNotification(key) method exists

### Gadgetbridge Protocol

- [X] T075d [US3] Implement dismiss callback handling in gadgetbridge_protocol.dart
  - Parse dismiss message from watch with notification ID
  - Trigger phone notification removal via NotificationService
  - **Note**: Handled in notification_providers.dart _handleWatchMessage

- [X] T075e [US3] Implement dismiss command with "-" prefix in gadgetbridge_protocol.dart
  - Format: notify with "-" + stableId
  - Send when phone notification is dismissed
  - **Note**: watch_service.dart removeNotification sends {"t":"notify-","id":...}

### Android Native

- [X] T075f [US3] Update NotificationListenerServiceImpl to track stable IDs
  - Map system notification key to stable ID
  - Expose cancelNotification(stableId) method
  - Report notification dismissal with stable ID
  - **Note**: Uses unsigned sbn.id, dismissNotification(key) method exists

- [X] T075g [US3] Handle notification removal callback in Android
  - Detect when user dismisses notification on phone
  - Notify Flutter via MethodChannel with stable ID
  - **Note**: onNotificationRemoved notifies Flutter via callback

### Integration

- [X] T075h [US3] Wire dismiss sync in watch_service.dart or dedicated provider
  - On watch dismiss: remove phone notification
  - On phone dismiss: send dismiss to watch
  - Queue dismiss commands if disconnected, send on reconnect
  - **Note**: Implemented in notification_providers.dart with _handleWatchMessage and _handleNotificationRemoved

**Checkpoint**: Notification dismissals sync bi-directionally between phone and watch ✅

---

## Phase 5.6: Music Control Integration Enhancement (US3 Extension) 🆕 ✅ COMPLETE

**Goal**: Enhanced music control per FR-079 to FR-083

**Independent Test**: Play music → Connect watch → Verify immediate music info. Change track → Verify update on watch. Tap play/pause on watch → Verify phone responds.

### Services

- [X] T075i [US3] Update media_service.dart for enhanced music control
  - Listen for media control commands from watch (FR-079) - in MediaControlNotifier._handleWatchMessage()
  - Forward commands to MediaController (play/pause/next/previous) - calls MediaService methods
  - Immediate update on track change (FR-080) - via _metadataSubscription stream
  - Immediate update on playback state change (FR-081) - via _playbackSubscription stream
  - Periodic updates while playing (FR-082) - via _periodicUpdateTimer (30s interval)

- [X] T075j [US3] Create MediaState model in lib/data/models/media_state.dart
  - Not needed: Existing MediaPlaybackState, MediaMetadata (media_service.dart), and MediaControlState (notification_providers.dart) cover all fields
  - title, artist, album, playbackState, position, duration all present in existing classes

### Android Native

- [X] T075k [US3] Update MediaSessionBridge for control commands
  - Receive control commands from Flutter - play(), pause(), next(), previous(), volumeUp(), volumeDown(), seekTo()
  - Execute on active MediaSession (play, pause, next, previous, etc.) - via transportControls
  - Detect track changes and notify Flutter immediately - via controllerCallback.onMetadataChanged()
  - Detect playback state changes and notify Flutter immediately - via controllerCallback.onPlaybackStateChanged()

### Protocol

- [X] T075l [US3] Implement music control command parsing in gadgetbridge_protocol.dart
  - Parse `t:"music"` with action (play, pause, next, prev, volumeup, volumedown) - in _parseMessage() case 'music'
  - Forward to media_service - via MusicControlMessage handled by MediaControlNotifier

### Integration

- [X] T075m [US3] Update initial_sync_service to include music state
  - Query current music state on connect - in InitialSyncService._syncMusicState()
  - Send immediately if playing or paused (FR-083) - checks isPlaying || isPaused

- [X] T075n [US3] Implement periodic music updates in media_service.dart
  - Send updates every 30 seconds while playing (configurable) - _periodicUpdateTimer in MediaControlNotifier
  - Stop periodic updates when paused/stopped - _updatePeriodicTimer() stops timer when !isPlaying

**Checkpoint**: Full bi-directional music control with immediate and periodic updates ✅

---

## Phase 6: User Story 4 - Dashboard & Device Info (Priority: P4) ✅ COMPLETE

**Goal**: User sees at-a-glance watch info and navigates to all features

**Independent Test**: Connect to watch → See dashboard with connection status, battery, firmware version → Tap through to each section

### UI

- [X] T076 [US4] Create dashboard screen in lib/ui/screens/dashboard/dashboard_screen.dart
- [X] T077 [US4] Add watch status card (name, battery ring, firmware version)
- [X] T078 [US4] Add connection status display with real-time updates
- [X] T079 [US4] Add navigation tiles to: Settings, Notifications, Health, Firmware, Developer

**Checkpoint**: Dashboard provides complete overview and navigation hub ✅

---

## Phase 7: User Story 5 - Health & Activity Data (Priority: P5) ✅ COMPLETE

**Goal**: User views step counts, heart rate history, and live HR streaming

**Independent Test**: Connect → View Health → See today's steps (hourly breakdown) → Open HR view → See live plot

### Models

- [X] T081 [P] [US5] Create HealthSample model in lib/data/models/health_sample.dart
- [X] T082 [P] [US5] Create HealthType and Granularity enums

### Repository

- [X] T083 [US5] Create health repository in lib/data/repositories/health_repository.dart
- [X] T084 [US5] Implement 60-day data cleanup query

### Services

- [X] T085 [US5] Create health sync service in lib/services/health/health_sync_service.dart
- [X] T087 [US5] Implement HR GATT service subscription (standard 0x180D)
- [X] T086 [US5] Implement Gadgetbridge activity messages (`t:"act"`, `t:"actfetch"`). NOTE: Not implemented on watch firmware yet. HR Service sends HR every second or so, this is live mode for now.

### Providers

- [X] T088 [US5] Create health providers in lib/providers/health_providers.dart

### UI

- [X] T089 [US5] Create health screen in lib/ui/screens/health/health_screen.dart
- [X] T090 [US5] Add daily step summary with hourly breakdown chart
- [X] T091 [US5] Add daily/weekly/monthly history tabs
- [X] T092 [US5] Create heart rate screen in lib/ui/screens/health/heart_rate_screen.dart
- [X] T093 [US5] Add real-time HR chart widget using fl_chart
- [X] T094 [US5] Create RealTimeChart widget in lib/ui/widgets/real_time_chart.dart

**Checkpoint**: Health data syncs, persists, and displays with live HR streaming ✅

---

## Phase 8: User Story 6 - Developer Tools (Priority: P6)

**Goal**: Developer enables Developer Mode and accesses diagnostics, logs, shell, sensor streaming, notification/music debug tools

**Independent Test**: Enable Developer Mode → View live logs → Send shell command → Stream raw sensor data → Send debug notification → Send sample music metadata → View comm log

### Models

- [X] T095 [P] [US6] Create LogEntry model in lib/data/models/log_entry.dart
- [X] T096 [P] [US6] Create CommLogEntry model in lib/data/models/comm_log_entry.dart
- [ ] T097 [P] [US6] Create ShellCommand model in lib/data/models/shell_command.dart
- [X] T098 [P] [US6] Create SensorReading model (in-memory) in lib/data/models/sensor_reading.dart
- [X] T098a [P] [US6] Create LogFilter enum/model in lib/data/models/log_filter.dart
  - Filter types: All, LogsOnly, Notifications, Music, Activity, Health, Other

### Services

- [ ] T099 [US6] Create Extended API protocol in lib/services/protocol/extended_protocol.dart
- [X] T100 [US6] Implement log streaming via BLE NUS in gadgetbridge_protocol.dart
  - All incoming BLE NUS data is captured for log viewer
  - Log messages identified by `<BLELOG>...</BLELOG>` wrapper
  - Supports multi-packet log messages
- [X] T100a [US6] Implement log enable/disable command in gadgetbridge_protocol.dart
  - Send `{"t":"log","status":true}` to enable watch logging
  - Send `{"t":"log","status":false}` to disable watch logging
  - Handle watch-initiated logs (may arrive without app request)
- [ ] T101 [US6] Implement shell command messages (Extended API `shell`)
- [X] T102 [US6] Create sensor GATT service client in lib/services/ble/sensor_gatt_service.dart
- [X] T103 [US6] Implement comm log recording in protocol service

### Repository

- [X] T104 [US6] Create comm log repository with rotation (5000 entries / 5MB)

### Providers

- [X] T105 [US6] Create developer providers in lib/providers/developer_providers.dart
- [X] T105a [US6] Create log viewer providers in lib/providers/developer_providers.dart
  - rawBleDataStreamProvider - stream of all incoming BLE NUS data
  - logFilterProvider - currently selected filter
  - filteredLogEntriesProvider - applies filter to raw stream
  - logEnabledProvider - whether logging is enabled on watch

### UI

- [X] T106 [US6] Create developer screen (hub) in lib/ui/screens/developer/developer_screen.dart
- [X] T107 [US6] Add BLE diagnostics display (MTU, PHY, RSSI, reconnection count)
- [X] T108 [US6] Create log viewer screen in lib/ui/screens/developer/log_viewer_screen.dart
  - Display ALL incoming BLE NUS log data (BLELOG wrapped messages only)
  - Timestamp and direction for each entry
  - Auto-scroll with pause option
  - Clear log button
- [X] T108a [US6] ~~Add log filter dropdown/chips to log viewer screen~~ REMOVED - Filter moved to comm log for TX/RX filtering
- [X] T108b [US6] Add log enable/disable toggle button to log viewer screen
  - Shows current log streaming state
  - Sends enable/disable command to watch
  - Note: logs may still arrive if watch has logging enabled independently
- [ ] T109 [US6] Create shell terminal screen in lib/ui/screens/developer/shell_terminal_screen.dart
- [X] T110 [US6] Create sensor debug screen in lib/ui/screens/developer/sensor_debug_screen.dart
- [X] T111 [US6] Add real-time sensor charts (accel, gyro, mag, temp, humidity, pressure, light)
- [X] T112 [US6] Create comm log screen in lib/ui/screens/developer/comm_log_screen.dart

### Notification Debug Tools (FR-093 to FR-097) 🆕

- [X] T113a [P] [US6] Create notification_debug_section.dart widget in lib/ui/widgets/developer/
  - App name dropdown/selector (FR-094)
  - Notification text input field (FR-095)
  - "Send Debug Notification" button (FR-096)

- [X] T113b [US6] Implement debug notification service in lib/services/notification/debug_notification_service.dart
  - Create test notification on phone (FR-097)
  - Send notification to watch via Gadgetbridge protocol
  - Use stable ID for bi-directional dismiss testing
  - **Note**: Implemented directly in notification_debug_section.dart using WatchService.sendNotification

- [X] T113c [US6] Add notification debug section to notification_settings_screen.dart
  - Only visible when Developer Mode enabled
  - Show debug section below main settings
  - **Note**: Added to developer_screen.dart under "Debug Tools" section

### Music Debug Tools (FR-098) 🆕

- [X] T113d [P] [US6] Create music_debug_section.dart widget in lib/ui/widgets/developer/
  - Buttons for sample track 1, 2, 3
  - Each sends different static metadata (title, artist, album)
  - Play/Pause state toggle

- [X] T113e [US6] Implement debug music service in lib/services/media/debug_music_service.dart
  - Send static sample "now playing" metadata to watch
  - Predefined test tracks with different metadata
  - Useful for testing music display without actual playback
  - **Note**: Implemented directly in music_debug_section.dart using WatchService.sendMusicInfo/sendMusicState

- [X] T113f [US6] Add music debug section to developer_screen.dart or notification_settings_screen.dart
  - **Note**: Added to developer_screen.dart under "Debug Tools" section

**Checkpoint**: Full developer diagnostics available when Developer Mode enabled, including notification and music debug tools

---

## Phase 8.5: User Story 12 - IMU Sensor Fusion Viewer (Priority: P6) 🆕 ✅ COMPLETE

**Goal**: User visualizes watch orientation in real-time via Euler angles and 3D axis visualization that mirrors physical watch rotation

**Independent Test**: Connect to watch → Open Sensor Debug → Enable Sensor Fusion → Rotate watch → 3D axis rotates correspondingly → Euler angles update in real-time

**Technical Details**:
- Watch firmware performs sensor fusion onboard using Madgwick/Mahony algorithm
- Watch outputs quaternion (w, x, y, z) via GATT characteristic `ADAFRUIT_CHAR_3D` (UUID: `ADAF0D01-C332-42A8-93BD-25E905756CB8`)
- Service UUID: `ADAFRUIT_SERVICE_3D` (`ADAF0D00-C332-42A8-93BD-25E905756CB8`)
- Data format: 4 floats (16 bytes) - quaternion w, x, y, z
- Update rate: 5Hz (200ms interval) when subscribed
- Magnetometer is optional; without it, yaw drift occurs over time

### Models

- [X] T168 [P] [US12] Create SensorFusionData model in lib/data/models/sensor_fusion_data.dart
  - Quaternion: w, x, y, z (floats)
  - Timestamp
  - Factory constructor to parse from BLE notification (16 bytes → 4 floats)
  - Method to compute Euler angles (roll, pitch, yaw) from quaternion
  - Quaternion math: conjugate, inverse, multiply, applyOffset

### Constants

- [X] T169 [P] [US12] Add sensor fusion GATT UUIDs to lib/core/constants/ble_constants.dart
  - sensorFusionService: `ADAF0D00-C332-42A8-93BD-25E905756CB8`
  - sensorFusionChar: `ADAF0D01-C332-42A8-93BD-25E905756CB8`

### Services

- [X] T170 [US12] Update sensor_gatt_service.dart to support sensor fusion characteristic
  - Added _fusionChar, _fusionSubscription, _fusionController
  - startSensorFusion() / stopSensorFusion() methods
  - hasSensorFusion getter for availability check
  - sensorFusionStream for UI consumption
  - Parses 16-byte notification into SensorFusionData

### UI Integration (Sensor Debug Screen)

- [X] T175 [US12] Add Sensor Fusion card to sensor_debug_screen.dart
  - Moved to top of sensor list for prominence
  - Toggle switch to enable/disable sensor fusion streaming
  - Shows quaternion values (W, X, Y, Z) with 3 decimal places
  - Shows Euler angles (Roll, Pitch, Yaw) in degrees
  - 3D axis visualization that rotates based on orientation

- [X] T176 [US12] Add "Reset Orientation" button
  - Stores current quaternion as reference offset
  - Applies inverse offset to subsequent readings: q_corrected = q_raw * q_offset^-1
  - "Clear offset" button to remove correction
  - Visual indicator when offset is active

- [X] T177 [US12] Add 3D axis visualization (_AxisPainter)
  - X-axis (red), Y-axis (green), Z-axis (blue) with arrowheads and labels
  - Rotates based on roll, pitch, yaw using ZXY Euler order
  - Depth sorting so front axes drawn on top
  - Circle background for visual context

- [X] T177a [US12] Add Euler angle display with axis colors
  - Roll (red), Pitch (green), Yaw (blue) color-coded
  - Displayed alongside 3D axis visualization
  - Updates in real-time as watch orientation changes

### Lifecycle Management

- [X] T178 [US12] Handle sensor fusion subscription lifecycle
  - CCCD notification enable/disable controls watch streaming
  - Unsubscribe when leaving sensor debug screen
  - Toggle disabled and shows "Not available" if characteristic not found

**Checkpoint**: Sensor Fusion card in Sensor Debug Screen shows quaternion, Euler angles, and 3D axis visualization that rotates in real-time mirroring physical watch orientation ✅

---

## Phase 9: User Story 7 - Multiple Watch Management (Priority: P7) ✅ COMPLETE

**Goal**: User manages multiple paired ZSWatch devices via the Start Screen

**Independent Test**: Pair two watches → See both on Start Screen → Tap config on one → Rename it → Verify name shows → Tap config → Forget watch → Verify removed and unbonded

**Note**: The Start Screen (from Phase 3.6) already shows all paired watches. This phase adds management actions (rename, forget) via a config button on each watch card. The "active" watch is simply the last one the user tapped to connect.

### Repository Updates

- [X] T114 [US7] Add `renameWatch(watchId, customName)` method to watch_repository.dart
- [X] T115 [US7] Add `forgetWatch(watchId)` method to watch_repository.dart
  - Delete watch from database
  - Unbond/unpair device via BLE (FlutterBluePlus removeBond)

### UI: Start Screen Enhancements

- [X] T116 [US7] Add config/settings icon button to each watch card in start_page_screen.dart
  - Gear icon or three-dot menu on each paired watch tile
  - Opens watch management bottom sheet or dialog

- [X] T117 [US7] Create watch_config_dialog.dart in lib/ui/widgets/
  - Shows watch name (editable text field)
  - "Rename" button to save custom name
  - "Forget Watch" button with red styling
  - Cancel button

- [X] T118 [US7] Implement forget watch flow with confirmation
  - Show confirmation dialog: "Forget [Watch Name]? This will remove the watch and unpair it."
  - On confirm: call forgetWatch() which deletes from DB and unbonds BLE
  - Refresh Start Screen to remove the watch

- [X] T119 [US7] Implement rename watch flow
  - Text field pre-populated with current name (custom or default)
  - Save persists customName to database
  - Start Screen updates to show new name immediately

### Model Updates

- [X] T120 [US7] Ensure Watch model supports customName field (may already exist from Phase 3.6)
  - Display customName if set, otherwise use default advertised name

**Checkpoint**: User can rename and forget watches directly from Start Screen ✅

---

## Phase 10: User Story 8 - App Settings (Priority: P8)

**Goal**: User configures app-specific settings (not watch settings)

**Independent Test**: Open Settings → Change a preference → Restart app → Verify persisted

**Note**: Watch rename functionality moved to Phase 9 (Start Screen management)

### Repository

- [X] T121 [US8] Create settings repository in lib/data/repositories/settings_repository.dart (SharedPreferences)

### UI

- [X] T122 [US8] Create settings screen in lib/ui/screens/settings/settings_screen.dart
- [X] T125 [US8] Add About section (app version, links)

**Checkpoint**: App settings persist across sessions ✅

---

## Phase 11: User Story 9 - Battery & Connection Analytics (Priority: P9) ✅ COMPLETE

**Goal**: User analyzes battery drain and connection quality over time

**Independent Test**: Connect watch → View Analytics → See 24h battery drain graph → View weekly trend → See connection uptime stats

### Models

- [X] T125 [P] [US9] Create BatteryReading model in lib/data/models/battery_reading.dart
  - Note: Using `BatteryReadingEntity` generated by Drift from `battery_readings_table.dart`
- [X] T125a [P] [US9] Create ConnectionEvent model in lib/data/models/connection_event.dart
  - Event type (connected, disconnected, reconnect_attempt, reconnect_failed)
  - Timestamp, watchId, reason (for disconnects)

### Database

- [X] T125b [US9] Create ConnectionEvents table in lib/data/database/tables/connection_events_table.dart
- [X] T125c [US9] Add ConnectionEvents to app_database.dart and regenerate

### Repository

- [X] T126 [US9] Create battery repository in lib/data/repositories/battery_repository.dart
- [X] T126a [US9] Create connection_analytics_repository.dart in lib/data/repositories/
  - Insert connection events
  - Query uptime percentage for period
  - Query disconnection count and reasons
  - Get average session duration
- [X] T127 [US9] Implement battery sampling (every 5 min when connected)

### Services

- [X] T127a [US9] Create connection_analytics_service.dart in lib/services/analytics/
  - Listen to connection state changes from WatchService
  - Record connect/disconnect events with timestamps
  - Track reconnection attempts and outcomes

### Providers

- [X] T129 [US9] Create analytics providers in lib/providers/analytics_providers.dart
  - batteryAnalyticsProvider - battery readings for charts
  - connectionUptimeProvider - uptime % for 24h, 7d
  - disconnectionEventsProvider - list of recent disconnects
  - connectionStatsProvider - combined stats (uptime, avg session, reconnect rate)

### UI

- [X] T130 [US9] Create analytics screen in lib/ui/screens/analytics/analytics_screen.dart
  - Tab bar: Battery | Connection
- [X] T131 [US9] Add 24-hour battery drain chart
- [X] T132 [US9] Add 7-day battery trend chart
- [X] T132a [US9] Create connection analytics tab in analytics_screen.dart
  - Connection uptime percentage (24h, 7d)
  - Total connected time today
  - Disconnection count with reasons
  - Average session duration
  - RSSI history chart (optional)

**Checkpoint**: Battery and connection analytics visualized over time ✅

---

## Phase 11.5: GPS Location Support (Gadgetbridge GPSPower) 🆕 ✅ COMPLETE

*Note: Persistent BLE Connection moved to Phase 3.8 for earlier implementation*

**Goal**: Handle GPS location requests from watch per FR-103 to FR-107

**Independent Test**: Connect to watch → Watch requests GPS → Phone obtains location → Watch receives coordinates

### Models

- [X] T133j [P] Create GPSLocation model in lib/data/models/gps_location.dart
  - latitude, longitude, accuracy, altitude, timestamp
  - **Note**: Using geolocator's Position class directly

### Services

- [X] T133k Create gps_service.dart in lib/services/location/
  - Request location permission (FR-105)
  - Obtain current location from phone
  - Handle permission denial gracefully (FR-107)
  - Return fresh location (not stale)
  - Added openAppSettings() and openLocationSettings() for permission management

### Gadgetbridge Protocol

- [X] T133l Implement GPSPower command handling in gadgetbridge_protocol.dart
  - Parse GPS request from watch (FR-103)
  - Format: `t:"gps_power"` with status boolean

- [X] T133m Implement GPS response in gadgetbridge_protocol.dart
  - Send location in Gadgetbridge-compatible format (FR-106)
  - Include lat, lon, alt, speed, course, time, hdop, gpsSource

### Integration

- [X] T133n Create gps_handler.dart in lib/providers/gps_providers.dart
  - GpsNotifier listens for GPS requests from watch service
  - Calls gps_service to obtain location
  - Sends response via watch service
  - Periodic updates (5 seconds) when GPS active

- [X] T133o Add location permission request in settings
  - GPS permission tile in Settings screen
  - Shows current permission status
  - Button to enable or open app settings
  - Info dialog explaining GPS feature

### Dependencies

- [X] T133p Add geolocator package to pubspec.yaml
  - geolocator: ^13.0.2

**Checkpoint**: Watch can request and receive phone GPS location ✅

---

## Phase 11.6: User Story 11 - HTTP Relay (Priority: P4) 🆕 ✅ COMPLETE

**Goal**: Phone performs HTTP/HTTPS (with optional XPath) on behalf of the watch via Gadgetbridge `t:"http"` and returns `resp`/`err` with the integer `id` echoed.

**Independent Test**: From developer console send `{"t":"http","url":"https://pur3.co.uk/hello.txt","id":1}` → phone replies `{"t":"http","resp":"hello","id":1}`; repeat with `xpath` and `insecure:true` against a host with an invalid cert to verify TLS override path.

### Models

- [X] T147 [P] [US11] Create HttpRequest model in lib/data/models/http_request.dart (url, xpath?, insecure?, id:int?, resp?, err?, timestamps)

### Services

- [X] T148 [US11] Create http_relay_service.dart in lib/services/http/ to perform requests, optional XPath evaluation, and per-request insecure TLS override

### Protocol Integration

- [X] T149 [US11] Handle inbound `t:"http"` in gadgetbridge_protocol.dart, invoke http_relay_service, and send `{"t":"http","resp"/"err",...,"id"}` back to watch (support concurrent requests)
  - Note: Gadgetbridge protocol already parses `t:"http"` messages
  - Added sendHttpResponse/sendHttpError methods to watch_service.dart

### Providers / Wiring

- [X] T150 [US11] Wire HTTP relay into watch service/providers (e.g., http_providers.dart) and ensure comm log captures request/response entries
  - Created http_providers.dart with HttpRelayNotifier
  - Listens to incomingMessages stream for t:"http" requests
  - Performs requests via HttpRelayService
  - Sends responses back via WatchService.sendHttpResponse/sendHttpError
  - Tracks pending and recent requests for debugging

**Checkpoint**: Watch-initiated HTTP relay works end-to-end with XPath and insecure TLS override. ✅

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

## Phase 13: Permission Onboarding (First Launch Experience) 🆕

**Purpose**: Centralized permission handling on first launch to ensure all permissions are requested upfront, avoiding missed permission dialogs when app runs in background

**Problem**: Currently permissions are requested on-demand when features are used. Since the watch connection runs in background, users may miss permission dialogs (e.g., notification listener, location for GPS, POST_NOTIFICATIONS). This leads to broken features without clear indication why.

**Solution**: Request all necessary permissions during first app launch with clear explanations. If user denies, show a banner/indicator on relevant screens with link to re-enable in Settings.

### Permission Onboarding Screen

- [ ] T151 [US1] Create PermissionOnboardingScreen in lib/ui/screens/onboarding/permission_onboarding_screen.dart
- [ ] T152 [P] Create permission state model in lib/data/models/permission_state.dart (tracks granted/denied for each permission)
- [ ] T153 [P] Create permission providers in lib/providers/permission_providers.dart (centralized permission state management)
- [ ] T154 [US1] Implement permission request flow for Bluetooth (BLUETOOTH_SCAN, BLUETOOTH_CONNECT) on Android
- [ ] T155 [US1] Implement permission request flow for Notification Listener Service (Android) with explanation
- [ ] T156 [US1] Implement permission request flow for POST_NOTIFICATIONS (Android 13+) for foreground service notification
- [ ] T157 [US1] Implement permission request flow for Location (for GPS relay feature) with explanation
- [ ] T158 [US1] Implement permission request flow for Battery Optimization exemption with explanation
- [ ] T159 [US1] Show first-launch onboarding flow before navigating to main app
- [ ] T160 [US1] Persist onboarding completion state in SharedPreferences

### Permission Status Indicators

- [ ] T161 [P] Create PermissionStatusBanner widget in lib/ui/widgets/permission_status_banner.dart
- [ ] T162 [US1] Show permission denied banner on Settings screen with link to system settings
- [ ] T163 [US3] Show notification permission banner on Notifications screen if not granted
- [ ] T164 [US1] Show location permission banner on GPS-related screens if not granted
- [ ] T165 [P] Add "Re-request permissions" option in Settings screen

### Permission Re-check on Resume

- [ ] T166 [US1] Re-check permission status when app resumes from background (user may have changed in system settings)
- [ ] T167 [US1] Update permission providers automatically when returning from system settings

**Checkpoint**: Users are guided through permissions on first launch; denied permissions are clearly indicated with paths to re-enable

---

## Phase 14: Polish & Cross-Cutting Concerns

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
│       ├──► (includes Notification/Music Debug Tools 🆕)
│       │
│       └──► Phase 8.5: US12 - IMU Sensor Fusion Viewer 🆕
│
├──► Phase 9: US7 - Multi-Watch (P7)
├──► Phase 10: US8 - Settings (P8)
│       │
│       └──► (includes Watch Rename 🆕)
│
├──► Phase 11: US9 - Analytics (P9)
├──► Phase 11.5: GPS Support 🆕
├──► Phase 11.6: US11 - HTTP Relay 🆕
├──► Phase 12: US10 - Voice [STUB] (P10)
│
├──► Phase 13: Permission Onboarding 🆕 (first launch experience)
│
└──► Phase 14: Polish (after desired stories complete)
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
| US12 (IMU Viewer) | US6 (extends Developer Tools) | US7-US11 | 3D orientation viewer 🆕 |
| US7 (Multi-Watch) | US1 (Start Page) | US2-US6 | Rename, Forget via Start Screen |
| US8 (Settings) | Foundational | All stories | - |
| US9 (Analytics) | US1 (needs connection) | US2-US8 | - |
| GPS Support | US1 (needs connection) | All stories | Gadgetbridge GPS |
| US11 (HTTP Relay) | US1 (needs connection) | All stories | HTTP relay |
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

**Phase 8.5 (IMU Viewer) 🆕**:
```
Parallel: T168, T169, T172, T173 (model, constants, dependency, 3D asset)
Sequential: T170 → T171 → T174 → T175 (service → providers → widget → screen)
Sequential: T176, T177 (features after screen exists)
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
| 11 | US11 (HTTP Relay) | Needed for watch-initiated internet access | HTTP relay |
| 12 | US10 (Voice) | Future placeholder | - |

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
| Phase 8.5: US12 IMU Viewer 🆕 | 11 | P6 | 11 |
| Phase 9: US7 Multi-Watch | 7 | P7 | 7 (Start Screen mgmt) |
| Phase 10: US8 Settings | 5 | P8 | - |
| Phase 11: US9 Analytics | 9 | P9 | - |
| Phase 11.5: GPS Support 🆕 | 7 | - | 7 |
| Phase 11.6: US11 HTTP Relay 🆕 | 4 | P4 | 4 |
| Phase 12: US10 Voice | 4 | P10 | - |
| Phase 13: Permission Onboarding 🆕 | 17 | - | 17 |
| Phase 14: Polish | 9 | - | - |
| **Total** | **~227** | 12 stories | **~86 new** |

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
| Watch Rename (FR-099-102) | 9 | T114, T117, T119, T120 |
| Watch Forget/Unbond | 9 | T115, T116, T118 |
| Persistent BLE (FR-089-092) | 3.8 | T045r-T045z |
| GPS Support (FR-103-107) | 11.5 | T133j-T133p |
| HTTP Relay (FR-117-122) | 11.6 | T147-T150 |
| IMU Sensor Fusion Viewer (FR-131-144) | 8.5 | T168-T179 |
| Permission Onboarding (FR-123-130) | 13 | T151-T167 |

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- 🆕 marks new tasks added for 2025-11-27 requirements
- Each user story should be independently testable after completion
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Voice Recording (US10) is a placeholder stub - full implementation depends on firmware
