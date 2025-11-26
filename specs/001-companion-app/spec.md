# Feature Specification: ZSWatch Companion App

**Feature Branch**: `001-companion-app`  
**Created**: 2025-11-26  
**Status**: Draft  
**Input**: Cross-platform Flutter companion app for ZSWatch smartwatch

## Clarifications

### Session 2025-11-26

- Q: What BLE pairing security mode should be used? → A: BLE bonding/pairing is REQUIRED (encrypted link mandatory, no unencrypted connections)
- Q: How long should health & analytics data be retained? → A: 60 days retention with automatic cleanup
- Q: Minimum battery level for firmware update? → A: No mandatory threshold; removed requirement (user responsibility)
- Q: How is Developer Mode activated? → A: Visible toggle in Settings (not hidden, just another screen)
- Q: Communication log size limit? → A: 5,000 entries or 5MB with rotation (oldest entries discarded)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Connect to Watch (Priority: P1)

A user opens the app for the first time and wants to connect to their ZSWatch. They tap "Add Watch", the app scans for nearby ZSWatch devices via BLE, displays found devices, and the user selects their watch. The app pairs and connects, displaying basic device info (name, firmware version, battery level).

**Why this priority**: Connection is the foundation; no other feature works without it. This is the absolute minimum viable product.

**Independent Test**: Can be fully tested by scanning for a powered-on ZSWatch, connecting to it, and verifying device info appears. Delivers immediate value by proving BLE connectivity works.

**Acceptance Scenarios**:

1. **Given** the app is open and Bluetooth is enabled, **When** user taps "Add Watch", **Then** app requests necessary permissions and begins scanning for ZSWatch devices
2. **Given** a ZSWatch is powered on and in range, **When** scanning completes, **Then** the device appears in the list with its advertised name
3. **Given** a device is shown in the list, **When** user taps on it, **Then** app connects and displays connection progress
4. **Given** connection succeeds, **When** the dashboard loads, **Then** user sees watch name, firmware version, battery level, and "Connected" status
5. **Given** the watch goes out of range or disconnects, **When** connection is lost, **Then** app shows "Disconnected" and attempts automatic reconnection

---

### User Story 2 - Firmware Update (Priority: P2)

A user wants to update their ZSWatch firmware. They navigate to the Firmware Update screen, see current firmware version, and can either select a prebuilt firmware from GitHub or upload a local file (zip containing multiple images, or single .bin). The app uploads the firmware via MCUmgr/SMP, shows progress, and confirms success after reboot.

**Why this priority**: Firmware updates are critical for watch functionality and security. Users need a reliable way to update without web tools.

**Independent Test**: Can be tested by downloading a firmware from GitHub, uploading to watch, verifying progress display, and confirming new version after reboot.

**Acceptance Scenarios**:

1. **Given** the watch is connected, **When** user navigates to Firmware Update, **Then** current firmware version is displayed
2. **Given** user has internet access, **When** they tap "Fetch Prebuilt Firmwares", **Then** app fetches available builds from GitHub and displays them organized by branch
3. **Given** firmwares are displayed, **When** user selects a build, **Then** app downloads the zip artifact and prepares for upload
4. **Given** user prefers local file, **When** they tap "Select File", **Then** file picker opens allowing .zip or .bin selection
5. **Given** file is selected and battery levels are acceptable, **When** user taps "Start Update", **Then** upload begins with progress percentage and speed displayed
6. **Given** upload completes, **When** watch reboots, **Then** app reconnects and displays new firmware version

---

### User Story 3 - Notification & Media Integration (Priority: P3)

A user wants to receive phone notifications and control media on their watch. The behavior differs by platform:
- **iOS**: Watch uses native ANCS/AMS services directly with iOS. App provides configuration only.
- **Android**: App acts as bridge, forwarding notifications and media via BLE to watch.

**Why this priority**: Notifications and media control are core smartwatch features providing ongoing value.

**Independent Test**: 
- Android: Enable notification forwarding, send test notification, verify it appears on watch.
- iOS: Verify ANCS/AMS connection works between watch and iOS (app not involved in data flow).

**Acceptance Scenarios**:

##### Android-Specific
1. **Given** Android device with app installed, **When** user enables notification forwarding, **Then** app requests NotificationListenerService permission
2. **Given** permission is granted on Android, **When** a phone notification arrives, **Then** app forwards it to watch via BLE within 2 seconds
3. **Given** Android user wants to filter notifications, **When** they access filter settings, **Then** they can enable/disable specific apps
4. **Given** Android user plays media, **When** media state changes, **Then** app forwards metadata to watch via BLE

##### iOS-Specific
5. **Given** iOS device with watch paired, **When** notification arrives, **Then** iOS sends it directly to watch via ANCS (app not involved)
6. **Given** iOS device with watch paired, **When** media plays, **Then** iOS provides metadata via AMS directly to watch
7. **Given** iOS user opens app, **When** they access notification settings, **Then** app shows configuration for watch-side ANCS behavior

##### Common
8. **Given** notification permission is revoked (Android), **When** app detects this, **Then** user is informed and prompted to re-enable

---

### User Story 4 - Dashboard & Device Info (Priority: P4)

A user wants to see at-a-glance information about their connected watch. The dashboard shows connection status, battery level, firmware version, and provides navigation to all app features.

**Why this priority**: Central hub for all app functionality; enhances discoverability and user experience.

**Independent Test**: Connect to watch, verify dashboard displays all expected information, tap through to each feature section.

**Acceptance Scenarios**:

1. **Given** the app opens with a paired watch, **When** connection is established, **Then** dashboard shows watch name, battery %, and firmware version
2. **Given** connection state changes, **When** watch disconnects/reconnects, **Then** status indicator updates immediately
3. **Given** user wants to access features, **When** they tap Settings/Notifications/Health/Firmware/Developer, **Then** navigation works correctly

---

### User Story 5 - Health & Activity Data (Priority: P5)

A user wants to view detailed health and activity data from the watch. The app displays step count (hourly breakdown, daily/weekly/monthly history), live heart rate streaming with real-time plot, and historical summaries. Data is stored locally and persisted across sessions.

**Why this priority**: Health data is a key smartwatch value proposition but depends on firmware implementation status.

**Independent Test**: Connect to watch, view today's steps with hourly breakdown, see live HR plot, verify historical data displays correctly.

**Acceptance Scenarios**:

1. **Given** watch is connected, **When** user navigates to Health, **Then** today's step count is displayed with hourly breakdown graph
2. **Given** HR streaming is supported, **When** user opens heart rate view, **Then** live HR values plot in real-time
3. **Given** historical data exists, **When** user views daily history, **Then** step counts per day are shown
4. **Given** user switches to weekly view, **When** data loads, **Then** weekly aggregates are displayed
5. **Given** user switches to monthly view, **When** data loads, **Then** monthly trends are displayed
6. **Given** new health data arrives, **When** sync completes, **Then** data is persisted locally
7. **Given** app restarts, **When** Health screen loads, **Then** previously synced data is still available

---

### User Story 6 - Developer Tools (Priority: P6)

A developer or power user enables Developer Mode and accesses comprehensive diagnostic tools including: live logs, shell terminal, BLE diagnostics (signal history, MTU, PHY mode, reconnection stats), raw sensor streaming via existing GATT service, and full communication logging.

**Why this priority**: Essential for debugging and development but not needed by typical end users.

**Independent Test**: Enable Developer Mode, view live logs, send a shell command, stream raw sensor data, verify all diagnostics display correctly.

**Acceptance Scenarios**:

1. **Given** Developer Mode is disabled, **When** user enables it in settings, **Then** Developer Tools section appears in navigation
2. **Given** watch is connected, **When** user opens Log Viewer, **Then** live logs from watch stream to screen
3. **Given** Shell Terminal is open, **When** user sends a command, **Then** command is sent and response is displayed
4. **Given** connection diagnostics are open, **When** user views BLE stats, **Then** current MTU, PHY mode (1M/2M), signal strength history, and reconnection frequency are displayed
5. **Given** sensor debug mode is enabled, **When** app subscribes to zsw_gatt_sensor_server characteristics, **Then** accelerometer/gyro/PPG/temperature values graph in real-time
6. **Given** communication log is open, **When** any message is sent/received, **Then** it appears in the log with timestamp and direction

---

### User Story 9 - Battery & Connection Analytics (Priority: P9)

A user or developer wants to analyze battery drain patterns and connection reliability. They can view battery drain graphs over 24 hours or a week, and see BLE connection quality metrics over time.

**Why this priority**: Useful for power users and debugging but not core functionality.

**Independent Test**: Connect watch, view battery graph showing drain over last 24h, view connection signal history.

**Acceptance Scenarios**:

1. **Given** watch has been connected, **When** user opens Battery Analytics, **Then** battery drain graph for last 24 hours is displayed
2. **Given** historical data exists, **When** user switches to weekly view, **Then** 7-day battery trend is shown
3. **Given** connection analytics is open, **When** user views signal history, **Then** BLE RSSI over time is graphed

---

### User Story 10 - Voice Recording Playback (Priority: P10) [PLACEHOLDER]

A user records a voice memo or dictation on their watch and wants to play it back on the phone. The app receives the audio data and allows playback.

**Why this priority**: Future feature placeholder - depends on firmware voice recording capability.

**Independent Test**: Record voice memo on watch, sync to app, play back audio.

**Acceptance Scenarios**:

1. **Given** watch has recorded a voice memo, **When** app syncs, **Then** memo appears in voice recordings list
2. **Given** memo is in the list, **When** user taps play, **Then** audio plays back
3. **Given** memo is playing, **When** user taps stop, **Then** playback stops

---

### User Story 7 - Multiple Watch Management (Priority: P7)

A user owns multiple ZSWatch devices and wants to switch between them. The app remembers all paired watches and allows selecting which one to connect to.

**Why this priority**: Multi-device support adds convenience but primary use case is single watch.

**Independent Test**: Pair two watches, disconnect from first, connect to second, switch back to first.

**Acceptance Scenarios**:

1. **Given** one watch is paired, **When** user adds another watch, **Then** both appear in saved devices list
2. **Given** multiple watches are saved, **When** user selects a different watch, **Then** app disconnects from current and connects to selected
3. **Given** user wants to remove a watch, **When** they tap "Forget", **Then** watch is removed from saved devices

---

### User Story 8 - App Settings (Priority: P8)

A user wants to configure app-specific settings (not watch settings). Watch settings are configured directly on the watch itself.

**Why this priority**: App configuration enhances user experience.

**Independent Test**: Change an app setting, verify it persists after restart.

**Acceptance Scenarios**:

1. **Given** user opens App Settings, **When** screen loads, **Then** app preferences are displayed (notification filters, developer mode toggle, etc.)
2. **Given** user changes an app setting, **When** they save, **Then** setting is persisted locally
3. **Given** app restarts, **When** Settings screen loads, **Then** previous settings are retained

**Note**: Watch-specific settings (display timeout, vibration, etc.) are configured on the watch directly. The app does not sync or modify watch settings.

---

### Edge Cases

- What happens when Bluetooth is disabled on the phone? App prompts user to enable Bluetooth
- What happens when watch battery is critically low during firmware update? App shows battery level; user proceeds at own risk
- How does app handle firmware update interrupted by connection loss? Update is resumable; app reconnects and offers to retry
- What happens when notification permission is revoked while app is running? App detects and prompts user to re-enable
- How does app behave when watch is in MCUBoot recovery mode? App detects recovery mode and offers direct firmware upload
- What happens when 2M PHY is not supported by phone? App falls back to 1M PHY gracefully
- How does app handle timezone changes while connected? App detects change and re-syncs time to watch
- What happens when raw sensor streaming causes high battery drain? App warns user and offers to reduce streaming frequency
- How does app handle very large communication logs? Logs are truncated/rotated to prevent memory issues
- What happens when app is killed by OS while firmware update is in progress? App saves state and offers to resume on restart

## Requirements *(mandatory)*

### Functional Requirements

#### Connection & Communication
- **FR-001**: App MUST scan for BLE devices advertising ZSWatch service UUIDs
- **FR-002**: App MUST support pairing and connecting to ZSWatch devices
- **FR-003**: App MUST maintain stable BLE connection when in foreground
- **FR-004**: App MUST attempt automatic reconnection when connection is lost
- **FR-005**: App MUST persist paired watch information across app restarts
- **FR-006**: App MUST support multiple saved watches with ability to switch between them
- **FR-007**: App MUST request and use high MTU (Maximum Transmission Unit) on connection
- **FR-008**: App MUST enable Data Length Extension (DLE) for optimal throughput

#### BLE Security (Mandatory)
- **FR-059**: App MUST require BLE bonding/pairing for all connections (encrypted link mandatory)
- **FR-060**: App MUST NOT allow unencrypted BLE connections to ZSWatch
- **FR-061**: App MUST store bonding keys securely using platform keychain/keystore
- **FR-062**: App MUST handle bonding failures gracefully with clear user guidance

#### BLE Protocol Architecture
- **FR-009**: App MUST implement Gadgetbridge API as primary protocol for watch communication
- **FR-010**: Gadgetbridge API MUST support: notifications, weather, music, GPS, HTTP relay, activity data, device version/status
- **FR-011**: Extended ZSWatch API used only for: bulk health sync, log streaming, shell commands, voice memos (future)
- **FR-012**: Sensor streaming MUST use existing zsw_gatt_sensor_server GATT service (not custom protocol)
- **FR-013**: Device info (firmware/hardware version) MUST use Gadgetbridge `t:"ver"` message (no custom API)

#### Firmware Update
- **FR-014**: App MUST support firmware upload via MCUmgr/SMP protocol
- **FR-015**: App MUST support zip files containing multiple firmware images (app core, net core, filesystem)
- **FR-016**: App MUST support single .bin firmware files
- **FR-017**: App MUST display upload progress percentage and estimated time
- **FR-018**: App MUST fetch prebuilt firmwares from ZSWatch GitHub repository
- **FR-020**: App MUST handle firmware confirmation and reboot sequence per MCUmgr specification

#### Notifications & Media (Platform-Specific)

**Critical Architecture Note**: Notification and media handling MUST be platform-specific. iOS and Android use fundamentally different mechanisms. The phone-side logic MUST differ per platform.

##### iOS Behavior (ANCS / AMS - Watch-Direct)
- **FR-021**: On iOS, the watch MUST communicate directly with iOS using Apple GATT services:
  - **ANCS** (Apple Notification Center Service) for notifications
  - **AMS** (Apple Media Service) for media metadata and controls
- **FR-022**: The iOS companion app MUST NOT intermediate, replace, or emulate ANCS/AMS
- **FR-023**: The iOS app provides only: configuration UI, non-ANCS features (settings, DFU, health sync, developer tools)

##### Android Behavior (App Bridge)
- **FR-024**: On Android, the app MUST act as the notification and media bridge (no OS-equivalent of ANCS/AMS exists)
- **FR-025**: Android app MUST use `NotificationListenerService` to access notifications
- **FR-026**: Android app MUST use `MediaSession` / `MediaController` APIs for media metadata and control
- **FR-027**: Android app MUST translate notifications into ZSWatch GATT protocol and send to watch
- **FR-028**: Android app MUST translate media updates into ZSWatch GATT protocol and send to watch

##### Common (Both Platforms)
- **FR-029**: App MUST allow user to filter notifications by source app (Android only - iOS uses watch-side ANCS filtering)
- **FR-030**: App MUST support notification actions where platform allows (dismiss, reply)

#### Health & Activity
- **FR-031**: App MUST receive and display step count data from watch (via Extended API when available)
- **FR-032**: App MUST access heart rate data via standard HR GATT service
- **FR-033**: App MUST persist health data locally on device
- **FR-034**: App MUST display today's summary and 7-day history

#### Data Retention
- **FR-063**: App MUST retain health and analytics data for 60 days
- **FR-064**: App MUST automatically delete data older than 60 days
- **FR-065**: Data cleanup MUST run periodically without user intervention

#### Developer Tools
- **FR-035**: App MUST provide live log viewer receiving logs over BLE (via Extended API)
- **FR-036**: App MUST provide shell terminal for sending commands to watch (via Extended API)
- **FR-037**: App MUST display BLE connection diagnostics: current MTU, PHY mode (1M/2M), signal strength (RSSI)
- **FR-038**: App MUST request 2M PHY mode if supported by device for improved throughput
- **FR-039**: App MUST track and display reconnection frequency statistics
- **FR-040**: App MUST provide BLE signal strength history graph
- **FR-041**: App MUST provide raw sensor streaming via existing zsw_gatt_sensor_server GATT characteristics
- **FR-042**: App MUST graph raw sensor data (accel/gyro/PPG/temp) in real-time by subscribing to GATT notifications
- **FR-043**: App MUST log all BLE communication between watch and app (viewable in developer mode)
- **FR-044**: Developer tools MUST be accessible via a visible Developer Mode toggle in Settings
- **FR-066**: Communication logs MUST rotate at 5,000 entries or 5MB (whichever first), discarding oldest entries

#### Battery & Analytics
- **FR-045**: App MUST track and graph battery drain over last 24 hours
- **FR-046**: App MUST track and graph battery drain over last 7 days
- **FR-047**: App MUST display steps per hour breakdown for current day

#### Time & Timezone
- **FR-048**: App MUST sync time to watch according to Gadgetbridge protocol (setTime + timezone)
- **FR-049**: App MUST handle timezone changes and update watch accordingly

#### Background Behavior
- **FR-050**: Android: App SHOULD support Foreground Service for persistent BLE connection
- **FR-051**: iOS: App MUST enable Bluetooth background modes for connection maintenance
- **FR-052**: App MUST disconnect cleanly when user explicitly removes/forgets the device
- **FR-053**: App MUST throttle health-sync frequency to minimize battery impact

#### Voice Recording (Placeholder)
- **FR-054**: App MUST be architecturally prepared for future voice memo/dictation sync from watch
- **FR-055**: App MUST support audio playback for received voice recordings (when firmware supports)

#### Data & Privacy
- **FR-056**: App MUST store all data locally on device only
- **FR-057**: App MUST NOT transmit telemetry, analytics, or user data
- **FR-058**: App MUST NOT require user accounts or cloud services

### UI/UX Requirements

#### Visual Theme
- **UX-001**: App SHOULD use dark theme only (no light mode)
- **UX-002**: App SHOULD use ZSWatch brand colors:
  - Primary: `#FFBAAF` (coral/salmon)
  - Secondary: `#9EC8F6` (light blue)
  - Dark: `#495060` (slate)
  - Darker: `#30343F` (charcoal)
- **UX-003**: App SHOULD use card-based layout with soft shadows and rounded corners

#### Status Indicators
- **UX-004**: Connected state MUST display as green indicator
- **UX-005**: Updating/reconnecting state MUST display as yellow/amber indicator
- **UX-006**: Error/disconnected state MUST display as red indicator
- **UX-007**: Connection status MUST be shown as a pill-shaped badge

#### Typography
- **UX-008**: Typography MUST follow platform defaults (Roboto on Android, San Francisco on iOS)
- **UX-009**: Headlines (page titles): 24–28sp, semi-bold
- **UX-010**: Section titles: 18–20sp, medium weight
- **UX-011**: Body text: 14–16sp, regular weight
- **UX-012**: Secondary text: 13–14sp with reduced opacity

#### Micro-animations
- **UX-013**: Transitions MUST be subtle and non-distracting
- **UX-014**: Page transitions MUST use fade or slide animations
- **UX-015**: Progress indicators MUST update smoothly
- **UX-016**: Buttons MUST provide tap feedback animation
- **UX-017**: Battery indicator SHOULD use smooth ring animation

#### Navigation
- **UX-018**: Navigation MUST be simple 2–3 level hierarchy maximum
- **UX-019**: Back navigation MUST always be predictable
- **UX-020**: No deep menu trees allowed

#### System Status Display
- **UX-021**: App MUST clearly show: Connected/Reconnecting/Disconnected status
- **UX-022**: App MUST clearly show battery level (visual + percentage)
- **UX-023**: App MUST clearly show firmware update states with progress
- **UX-024**: Errors MUST display with meaningful, actionable messages

#### Firmware Update UX (Fail-safe)
- **UX-026**: App MUST pre-check connection stability before allowing update
- **UX-027**: App MUST NOT allow navigating away during critical upload phase
- **UX-028**: App MUST show detailed progress (percentage, speed, stage)

#### Visual Pattern Guidelines
- Modern card-based layout with soft shadows and rounded corners
- Bold headline at the top of each screen
- Segmented sections separated by vertical spacing
- Monochrome battery ring with smooth animation
- Connection-status pill in green/red/amber
- Primary actions shown as full-width rounded buttons

### Key Entities

- **Watch**: Represents a ZSWatch device (identifier, name, firmware version, battery level, paired status, supported protocols)
- **Connection**: BLE connection state and metadata (state, signal strength, MTU, PHY mode, DLE enabled, reconnection count, last seen)
- **ProtocolMessage**: Base message type with protocol indicator (Gadgetbridge API or Extended ZSWatch API)
- **Notification**: Phone notification to be forwarded (id, source app, title, body, timestamp, icon)
- **FirmwareImage**: Firmware file for upload (name, version, size, hash, type: app/net/filesystem)
- **HealthSample**: Health data point (type: steps/heartrate/sleep, value, timestamp, granularity: hour/day/week/month)
- **BatteryReading**: Battery level sample (level, timestamp, charging status)
- **SensorReading**: Raw sensor data (type: accel/gyro/ppg/temp, x/y/z or value, timestamp)
- **LogEntry**: Debug log from watch (level, message, timestamp, source module)
- **CommLogEntry**: BLE communication log (direction: in/out, protocol, payload, timestamp)
- **ShellCommand**: Terminal command/response pair (command, response, timestamp)
- **VoiceMemo**: Voice recording from watch (id, duration, timestamp, audio data) [placeholder]

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can discover and connect to a ZSWatch within 30 seconds of opening the app
- **SC-002**: Firmware updates complete successfully in under 10 minutes over BLE (faster with 2M PHY/high MTU)
- **SC-003**: 95% of incoming phone notifications appear on watch within 3 seconds
- **SC-004**: App automatically reconnects to watch within 10 seconds of coming back in range
- **SC-005**: Health data persists across app restarts with no data loss
- **SC-006**: Connection state accurately reflects actual BLE state at all times
- **SC-007**: Users can complete primary tasks (connect, update, configure) without external documentation
- **SC-008**: App functions reliably after being backgrounded for extended periods (within OS limits)
- **SC-009**: Battery impact on phone is minimal during normal connected operation (less than 5% per hour)
- **SC-010**: All user-facing errors provide actionable guidance for resolution
- **SC-011**: Real-time sensor streaming displays data at minimum 10 Hz refresh rate
- **SC-012**: Live heart rate plot updates within 500ms of receiving new data
- **SC-013**: Battery analytics graph loads within 2 seconds with 7 days of data
- **SC-014**: Navigation between any two screens completes in under 300ms

## Assumptions

- ZSWatch firmware supports and maintains the Gadgetbridge BLE protocol
- ZSWatch firmware will be extended to support new Extended ZSWatch API
- MCUmgr/SMP is functional on the watch side and follows Zephyr/Nordic conventions
- HR GATT service follows standard Bluetooth Heart Rate Profile
- Raw sensor streaming uses zsw_gatt_sensor_server.c implementation
- GitHub API remains accessible for fetching prebuilt firmwares
- Users have basic familiarity with Bluetooth pairing concepts
- Target Android API level 21+ and iOS 13.0+ provide necessary BLE capabilities
- 2M PHY is supported on most modern smartphones (2017+)
- Voice recording feature depends on future firmware implementation
