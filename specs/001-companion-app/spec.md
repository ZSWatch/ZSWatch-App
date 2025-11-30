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

A user opens the app for the first time and wants to connect to their ZSWatch. The start page ("Connect to your watch") displays all previously paired/stored watches prominently. The user can select a stored watch to reconnect, or tap "Connect new watch" to scan for and pair a watch not already stored. When a watch is selected or discovered, the app pairs and connects, displaying basic device info (name, firmware version, battery level). Upon successful connection (manual or automatic), the app navigates to the connected dashboard screen.

**Why this priority**: Connection is the foundation; no other feature works without it. This is the absolute minimum viable product.

**Independent Test**: Can be fully tested by scanning for a powered-on ZSWatch, connecting to it, and verifying device info appears. Delivers immediate value by proving BLE connectivity works.

**Acceptance Scenarios**:

1. **Given** the app is open on the start page, **When** user views the screen, **Then** all previously paired/stored watches are displayed prominently
2. **Given** stored watches are displayed, **When** user taps on a stored watch, **Then** app attempts to connect to that specific watch
3. **Given** the app is open and Bluetooth is enabled, **When** user taps "Connect new watch" button, **Then** app requests necessary permissions and begins scanning for ZSWatch devices not already stored
4. **Given** a ZSWatch is powered on and in range, **When** scanning completes, **Then** the device appears in the list with its advertised name
5. **Given** a device is shown in the list, **When** user taps on it, **Then** app connects and displays connection progress
6. **Given** connection succeeds, **When** the dashboard loads, **Then** user sees watch name, firmware version, battery level, and "Connected" status
7. **Given** the watch goes out of range or disconnects, **When** connection is lost, **Then** app shows "Disconnected" and attempts automatic reconnection
8. **Given** a watch is already connected to the phone, **When** user opens scan screen, **Then** the connected device appears in the list with "Connected" indicator
9. **Given** a watch was previously paired and saved in the app, **When** user opens scan screen but watch is not advertising, **Then** device shows as "Saved • Out of range"
10. **Given** a watch was previously paired and is now advertising, **When** user opens scan screen, **Then** device shows as "Saved" with current RSSI
11. **Given** a connection is established (manual or auto-connect), **When** connection completes, **Then** app automatically navigates to the connected dashboard screen

---

### User Story 2 - Firmware Update (Priority: P2) ✅ IMPLEMENTED

A user wants to update their ZSWatch firmware. They navigate to the Firmware Update screen, see current firmware version, and can either select a prebuilt firmware from GitHub releases (choosing their hardware variant), open CI builds in browser, or upload a local dfu_application.zip file. The app uploads the firmware via MCUmgr/SMP, shows progress, and confirms success after reboot.

**Why this priority**: Firmware updates are critical for watch functionality and security. Users need a reliable way to update without web tools.

**Independent Test**: Can be tested by downloading a firmware from GitHub, uploading to watch, verifying progress display, and confirming new version after reboot.

**Implementation Notes**:
- GitHub releases contain multiple hardware variants (watchdk, zswatch_legacy) - user selects which to download
- Release zip contains dfu_application.zip which is extracted automatically
- dfu_application.zip contains manifest.json with image_index for each .bin file
- Multi-image DFU uploads each image to correct slot based on manifest
- CI builds require authentication - app opens in browser for manual download
- Uses FirmwareUpgradeMode.confirmOnly for proper MCUboot image confirmation
- Release zip also contains lvgl_resources_raw.bin - a filesystem image that can be uploaded via MCUmgr filesystem commands
- When dfu_application.zip is selected/extracted, app automatically locates lvgl_resources_raw.bin from the same zip
- User is presented with three update options: "Start FW Update", "Start Filesystem Update", or "Start Both"
- When "Start Both" is selected, filesystem upload MUST complete first, then firmware images are uploaded
- Filesystem upload uses MCUmgr filesystem upload command (not image upload)

**Acceptance Scenarios**:

1. **Given** the watch is connected, **When** user navigates to Firmware Update, **Then** current firmware version is displayed ✅
2. **Given** user has internet access, **When** they tap refresh on releases, **Then** app fetches available releases from GitHub with all firmware variants ✅
3. **Given** releases are displayed, **When** user taps a release, **Then** dialog shows available hardware variants to choose from ✅
4. **Given** user selects a variant, **When** download completes, **Then** app extracts dfu_application.zip from the release zip ✅
5. **Given** user prefers local file, **When** they tap "Select .zip firmware file", **Then** file picker opens allowing .zip selection ✅
6. **Given** file is selected, **When** user taps "Start Update", **Then** upload begins with progress percentage, speed, and time remaining displayed ✅
7. **Given** upload completes, **When** watch reboots, **Then** app handles reconnection (fixed loop issue) ✅
8. **Given** user wants CI builds, **When** they tap "Open" on an artifact, **Then** browser opens GitHub download page ✅
9. **Given** a release zip is downloaded/selected, **When** dfu_application.zip is extracted, **Then** app also locates lvgl_resources_raw.bin from the same zip (if present)
10. **Given** both firmware and filesystem images are available, **When** user views update options, **Then** three choices are presented: "Start FW Update", "Start Filesystem Update", "Start Both"
11. **Given** user selects "Start Filesystem Update", **When** upload begins, **Then** lvgl_resources_raw.bin is uploaded via MCUmgr filesystem commands with progress displayed
12. **Given** user selects "Start Both", **When** update begins, **Then** filesystem upload completes first, followed by firmware image upload
13. **Given** only dfu_application.zip is available (no lvgl_resources_raw.bin), **When** user views update options, **Then** only "Start FW Update" option is available

---

### User Story 3 - Notification & Media Integration (Priority: P3)

A user wants to receive phone notifications and control media on their watch. The behavior differs by platform:
- **iOS**: Watch uses native ANCS/AMS services directly with iOS. App provides configuration only.
- **Android**: App acts as bridge, forwarding notifications and media via BLE to watch.

All notifications sent from the app include a stable unique notification ID to enable bi-directional dismiss synchronization. When a notification is dismissed on the watch, the watch sends the ID back to the app, and the app removes the corresponding notification on the phone. Conversely, when a notification is dismissed on the phone, the app sends a notify command prefixed with "-" plus the notification ID to the watch, so the watch can dismiss the matching notification.

For music control, the app listens for media control commands from the watch (next/previous/play/pause/etc.) and forwards these commands to control the phone's media playback. The app sends updated music information to the watch periodically and immediately whenever the track or playback state changes. After connecting to a watch, the app immediately sends the current "now playing" info if something is playing or paused.

**Why this priority**: Notifications and media control are core smartwatch features providing ongoing value.

**Independent Test**: 
- Android: Enable notification forwarding, send test notification, verify it appears on watch. Dismiss on watch, verify phone notification is removed. Dismiss on phone, verify watch notification is removed.
- iOS: Verify ANCS/AMS connection works between watch and iOS (app not involved in data flow).
- Music: Play media on phone, verify metadata appears on watch. Send play/pause command from watch, verify phone media responds.

**Acceptance Scenarios**:

##### Android-Specific
1. **Given** Android device with app installed, **When** user enables notification forwarding, **Then** app requests NotificationListenerService permission
2. **Given** permission is granted on Android, **When** a phone notification arrives, **Then** app forwards it to watch via BLE within 2 seconds with a stable unique notification ID
3. **Given** Android user wants to filter notifications, **When** they access filter settings, **Then** they can enable/disable specific apps
4. **Given** Android user plays media, **When** media state changes, **Then** app forwards metadata to watch via BLE

##### Notification Dismiss Sync (Android)
5. **Given** a notification was forwarded to the watch with a stable ID, **When** the watch dismisses the notification and sends the ID back, **Then** app removes the corresponding notification on the phone
6. **Given** a notification exists on both phone and watch, **When** the notification is dismissed on the phone, **Then** app sends a notify command with "-" prefix plus the notification ID to the watch
7. **Given** the watch receives a dismiss command with "-" prefix, **When** the ID matches an existing notification, **Then** the watch dismisses the matching notification

##### iOS-Specific
8. **Given** iOS device with watch paired, **When** notification arrives, **Then** iOS sends it directly to watch via ANCS (app not involved)
9. **Given** iOS device with watch paired, **When** media plays, **Then** iOS provides metadata via AMS directly to watch
10. **Given** iOS user opens app, **When** they access notification settings, **Then** app shows configuration for watch-side ANCS behavior

##### Music Control Integration
11. **Given** the watch is connected, **When** the watch sends a media control command (play/pause/next/previous/etc.), **Then** app forwards the command to control the phone's media playback
12. **Given** media is playing on the phone, **When** the track changes, **Then** app immediately sends updated music information (title, artist, album) to the watch
13. **Given** media playback state changes (play/pause), **When** the change occurs, **Then** app sends updated playback state to the watch
14. **Given** media is playing or paused, **When** the app connects to the watch, **Then** app immediately sends current "now playing" info to the watch
15. **Given** music information updates are enabled, **When** connected and media is playing, **Then** app sends periodic music updates to keep watch in sync

##### Common
16. **Given** notification permission is revoked (Android), **When** app detects this, **Then** user is informed and prompted to re-enable

---

### User Story 4 - Dashboard & Device Info (Priority: P4)

A user wants to see at-a-glance information about their connected watch. The dashboard shows connection status, battery level, firmware version, and provides navigation to all app features.

**Why this priority**: Central hub for all app functionality; enhances discoverability and user experience.

**Independent Test**: Connect to watch, verify dashboard displays all expected information, tap through to each feature section.

**Acceptance Scenarios**:

1. **Given** the app opens with a paired watch, **When** connection is established, **Then** dashboard shows watch name, battery %, firmware version, hardware version, RSSI, and MTU
2. **Given** connection state changes, **When** watch disconnects/reconnects, **Then** status indicator updates immediately
3. **Given** user wants to access features, **When** they tap Settings/Notifications/Health/Firmware/Developer, **Then** navigation works correctly and back button returns to dashboard
4. **Given** user wants to disconnect, **When** they tap "Disconnect", **Then** app disconnects from watch and returns to welcome screen

---

### User Story 5 - Health & Activity Data (Priority: P5)

A user wants to view detailed health and activity data from the watch. The app displays step count (hourly breakdown, daily/weekly/monthly history), live heart rate streaming with real-time plot, activity state breakdown showing time spent in each activity (walking, running, still, not worn, sleep states, etc.), and historical summaries. Data is stored locally and persisted across sessions.

Heart rate data comes from activity messages sent by the watch via Gadgetbridge protocol (`t:"act"` with `hrm` field), not from the standard BLE Heart Rate GATT service. Activity messages may include an optional `ts` timestamp field (milliseconds since 1970) to support historical/cached data from when the phone was not connected.

**Why this priority**: Health data is a key smartwatch value proposition but depends on firmware implementation status.

**Independent Test**: Connect to watch, view today's steps with hourly breakdown, see live HR values, view activity breakdown pie chart, verify historical data displays correctly.

**Acceptance Scenarios**:

1. **Given** watch is connected, **When** user navigates to Health, **Then** today's step count is displayed with hourly breakdown graph
2. **Given** watch sends activity messages with HR data, **When** user opens heart rate view, **Then** live HR values plot in real-time
3. **Given** historical data exists, **When** user views daily history, **Then** step counts per day are shown
4. **Given** user switches to weekly view, **When** data loads, **Then** weekly aggregates are displayed
5. **Given** user switches to monthly view, **When** data loads, **Then** monthly trends are displayed
6. **Given** new health data arrives, **When** sync completes, **Then** data is persisted locally
7. **Given** app restarts, **When** Health screen loads, **Then** previously synced data is still available
8. **Given** watch sends activity state updates, **When** user views Health screen, **Then** activity breakdown pie chart shows time spent in each state (walking, running, still, not worn, etc.)
9. **Given** watch sends activity messages with `ts` timestamp, **When** app processes message, **Then** data is stored with the provided timestamp (not current time)
10. **Given** watch was disconnected and cached activity data, **When** watch reconnects and sends historical data, **Then** app correctly stores and displays backdated samples

---

### User Story 6 - Developer Tools (Priority: P6)

A developer or power user enables Developer Mode and accesses comprehensive diagnostic tools including: live logs, shell terminal, BLE diagnostics (signal history, MTU, PHY mode, reconnection stats), raw sensor streaming via existing GATT service, full communication logging, and notification/music debug tools.

The notification debug section allows selecting an app name, entering notification text, and sending a debug notification to the watch. Debug notifications are also created on the phone itself to test dismissal syncing in both directions. Music debug tools provide buttons to send static sample "now playing" metadata (title, artist, album) to the watch.

**Log Streaming Architecture**: Logs are transmitted from the watch over the BLE NUS (Nordic UART Service) characteristic - the same channel used for all Gadgetbridge protocol messages. The Log Viewer displays ALL incoming data over BLE NUS, which includes both watch logs and regular protocol data (notifications, music info, etc.). Pre-defined filters allow filtering the log view to show only specific message types. The app can dynamically enable/disable log streaming on the watch by sending `{"t":"log","status":true/false}`. Note that the watch may also have its own setting to enable logs, so logs may be received even if the app hasn't explicitly requested them.

**Why this priority**: Essential for debugging and development but not needed by typical end users.

**Independent Test**: Enable Developer Mode, view live logs, send a shell command, stream raw sensor data, send debug notification, verify all diagnostics display correctly. Open Log Viewer, verify all incoming BLE data is shown, apply filter, verify filtered view shows only selected message types.

**Acceptance Scenarios**:

1. **Given** Developer Mode is disabled, **When** user enables it in settings, **Then** Developer Tools section appears in navigation
2. **Given** watch is connected, **When** user opens Log Viewer, **Then** live logs from watch stream to screen
3. **Given** Shell Terminal is open, **When** user sends a command, **Then** command is sent and response is displayed
4. **Given** connection diagnostics are open, **When** user views BLE stats, **Then** current MTU, PHY mode (1M/2M), signal strength history, and reconnection frequency are displayed
5. **Given** sensor debug mode is enabled, **When** app subscribes to zsw_gatt_sensor_server characteristics, **Then** accelerometer/gyro/PPG/temperature values graph in real-time
6. **Given** communication log is open, **When** any message is sent/received, **Then** it appears in the log with timestamp and direction
7. **Given** notification debug section is open, **When** user selects an app name and enters notification text, **Then** a debug notification can be sent to the watch
8. **Given** user sends a debug notification, **When** it is sent to the watch, **Then** a corresponding notification is also created on the phone to test bi-directional dismiss sync
9. **Given** music debug section is open, **When** user taps send sample metadata button, **Then** static sample "now playing" metadata (title, artist, album) is sent to the watch
10. **Given** Log Viewer is open, **When** any data arrives over BLE NUS, **Then** it appears in the log (including both logs and protocol messages)
11. **Given** Log Viewer shows all incoming data, **When** user selects a filter (e.g., "Logs only", "Notifications", "Music"), **Then** view filters to show only matching messages
12. **Given** user wants to enable watch logging, **When** they tap "Enable Logs" button, **Then** app sends `{"t":"log","status":true}` to watch
13. **Given** user wants to disable watch logging, **When** they tap "Disable Logs" button, **Then** app sends `{"t":"log","status":false}` to watch
14. **Given** watch has logging enabled in its own settings, **When** app connects, **Then** logs may arrive even without app requesting them

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

A user wants to configure app-specific settings (not watch settings). Watch settings are configured directly on the watch itself. Users can also rename previously paired/bonded watches for easier identification within the Settings section.

**Why this priority**: App configuration enhances user experience.

**Independent Test**: Change an app setting, verify it persists after restart. Rename a bonded watch, verify the custom name displays throughout the app.

**Acceptance Scenarios**:

1. **Given** user opens App Settings, **When** screen loads, **Then** app preferences are displayed (notification filters, developer mode toggle, etc.)
2. **Given** user changes an app setting, **When** they save, **Then** setting is persisted locally
3. **Given** app restarts, **When** Settings screen loads, **Then** previous settings are retained
4. **Given** user has paired watches, **When** they access watch management in Settings, **Then** they can see all paired/bonded watches with option to rename
5. **Given** user wants to rename a watch, **When** they edit the name and save, **Then** the custom name is persisted and displayed throughout the app

**Note**: Watch-specific settings (display timeout, vibration, etc.) are configured on the watch directly. The app does not sync or modify watch settings.

**Note**: Rename bonded watches feature is part of the requirements list but not needed for initial implementation.

---

### User Story 11 - HTTP Relay (Priority: P4)

The watch needs phone-assisted network access. It sends `t:"http"` Gadgetbridge messages with a URL and optional `xpath`, `id` (integer), and `insecure` fields. The app performs the HTTP/HTTPS request, optionally evaluates the XPath on XML content, and returns either the body or an error to the watch, echoing the integer `id` so multiple requests can be in-flight.

**Why this priority**: Enables watch apps (weather/news/custom data) without adding a full network stack to firmware; required to meet Gadgetbridge compatibility for HTTP relay.

**Independent Test**: From Developer Tools or a BLE console, send `{"t":"http","url":"https://pur3.co.uk/hello.txt","id":1}` from the watch; verify the phone replies with `{"t":"http","resp":"hello","id":1}`. Repeat with `xpath` and with `insecure:true` targeting a test host with an invalid certificate to confirm TLS override behavior.

**Acceptance Scenarios**:

1. **Given** the watch sends `{"t":"http","url":"https://pur3.co.uk/hello.txt"}`, **When** the request succeeds, **Then** the app replies over BLE with `{"t":"http","resp":<body>}`
2. **Given** the watch includes an `xpath` in the request, **When** the document is fetched, **Then** the app parses as XML and returns the XPath result in `resp`
3. **Given** the watch supplies an integer `id`, **When** the app responds, **Then** the response (or error) echoes the same `id` so concurrent requests can be matched
4. **Given** no `insecure` flag is provided, **When** the app performs HTTPS, **Then** TLS validation is enforced; **When** `insecure:true` is provided, **Then** the request bypasses certificate validation for that call only
5. **Given** the HTTP request fails (network error, TLS failure, XML/XPath parse failure), **When** the app responds, **Then** it returns `{"t":"http","err":<message>}` including `id` if supplied
6. **Given** several `t:"http"` requests are issued with different `id` values, **When** responses are delivered, **Then** each response includes the originating `id` regardless of completion order

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
- What happens when user navigates to sub-screens and presses system back button? App navigates back to previous screen (not exit)
- What happens when opening scan screen while a watch is already connected? Connected device appears in list with "Connected" badge
- What happens when a previously saved watch is not advertising? Device shows in list as "Saved • Out of range" with MAC address
- What happens when scanning shows multiple devices? Devices are sorted by signal strength (strongest first)
- What happens when the app is backgrounded while playing music? App continues sending music updates via background BLE connection
- What happens when notification dismiss sync fails due to connection loss? App queues dismiss commands and sends when reconnected
- What happens when auto-reconnect attempts exhaust platform limits? App stops attempts and informs user; manual reconnect available
- What happens when GPS location permission is denied when watch requests location? App sends error response to watch indicating location unavailable
- What happens when GPS location is stale? App obtains fresh location before sending to watch
- What happens when app is reopened after being closed? App automatically attempts to reconnect to last connected watch
- What happens when initial sync data is incomplete (e.g., no media playing)? App sends available data; omits unavailable data gracefully

## Requirements *(mandatory)*

### Functional Requirements

#### Connection & Communication
- **FR-001**: App MUST scan for BLE devices advertising ZSWatch service UUIDs
- **FR-002**: App MUST support pairing and connecting to ZSWatch devices
- **FR-003**: App MUST maintain stable BLE connection when in foreground
- **FR-004**: App MUST attempt automatic reconnection when connection is lost
- **FR-005**: App MUST persist paired watch information across app restarts
- **FR-005a**: App MUST display already-connected devices in the scan list with "Connected" indicator
- **FR-005b**: App MUST display saved (previously paired) devices in scan list even when not advertising
- **FR-005c**: Saved devices not currently advertising MUST show as "Out of range"
- **FR-005d**: Scan list MUST always show MAC address for device identification
- **FR-006**: App MUST support multiple saved watches with ability to switch between them
- **FR-007**: App MUST request and use high MTU (Maximum Transmission Unit) on connection
- **FR-008**: App MUST enable Data Length Extension (DLE) for optimal throughput

#### Start Page & Stored Watches
- **FR-067**: Start page ("Connect to your watch") MUST display all previously paired/stored watches prominently
- **FR-068**: Start page MUST include a dedicated "Connect new watch" button for pairing watches not already stored
- **FR-069**: Stored watches on start page MUST allow direct selection to initiate connection
- **FR-070**: Upon successful connection (manual or automatic), app MUST navigate to the connected dashboard screen

#### Auto-Reconnect Behavior
- **FR-071**: When app is reopened after being closed, app MUST automatically attempt to reconnect to the last connected watch
- **FR-072**: Auto-connect attempts MUST run periodically and indefinitely (within platform limits) until connection established or user chooses different watch
- **FR-073**: Auto-reconnect MUST NOT block user from manually selecting a different watch
- **FR-074**: When connection is established (manual or auto), app MUST navigate to connected screen

#### BLE Security (Mandatory)
- **FR-059**: App MUST require BLE bonding/pairing for all connections (encrypted link mandatory)
- **FR-060**: App MUST NOT allow unencrypted BLE connections to ZSWatch
- **FR-061**: App MUST store bonding keys securely using platform keychain/keystore
- **FR-062**: App MUST handle bonding failures gracefully with clear user guidance

#### BLE Protocol Architecture
- **FR-009**: App MUST implement Gadgetbridge API as primary protocol for watch communication
- **FR-010**: Gadgetbridge API MUST support: notifications, weather, music, GPS, HTTP relay, activity data (steps, heart rate, activity state), device version/status
- **FR-011**: Extended ZSWatch API used only for: bulk health sync, log streaming, shell commands, voice memos (future)
- **FR-012**: Sensor streaming MUST use existing zsw_gatt_sensor_server GATT service (not custom protocol)
- **FR-013**: Device info (firmware/hardware version) MUST use Gadgetbridge `t:"ver"` message (no custom API)
- **FR-013a**: Health data (steps, heart rate, activity state) MUST be received via Gadgetbridge `t:"act"` messages

#### Firmware Update
- **FR-014**: App MUST support firmware upload via MCUmgr/SMP protocol
- **FR-015**: App MUST support zip files containing multiple firmware images (app core, net core, filesystem)
- **FR-016**: App MUST support single .bin firmware files
- **FR-017**: App MUST display upload progress percentage and estimated time
- **FR-018**: App MUST fetch prebuilt firmwares from ZSWatch GitHub repository
- **FR-019**: App MUST support filesystem image upload via MCUmgr filesystem commands (lvgl_resources_raw.bin)
- **FR-019a**: App MUST automatically detect lvgl_resources_raw.bin when extracting release zip alongside dfu_application.zip
- **FR-019b**: App MUST present update options (FW only, Filesystem only, Both) based on available images
- **FR-019c**: When updating both, filesystem upload MUST complete before firmware upload begins
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

#### Notification Stable IDs & Dismiss Sync (Android)
- **FR-075**: All notifications sent from the app MUST include a stable unique notification ID
- **FR-076**: When watch dismisses a notification and sends ID back, app MUST remove the corresponding notification on the phone
- **FR-077**: When notification is dismissed on phone, app MUST send notify command prefixed with "-" plus the notification ID to watch
- **FR-078**: Watch MUST dismiss matching notification when receiving dismiss command with "-" prefix

#### Music Control Integration (Android)
- **FR-079**: App MUST listen for music control commands from watch (next/previous/play/pause/etc.) and forward to control phone's media playback
- **FR-080**: App MUST send updated music information (title, artist, album) to watch immediately when track changes
- **FR-081**: App MUST send updated music information to watch immediately when playback state changes (play/pause)
- **FR-082**: App MUST send music information to watch periodically while media is playing
- **FR-083**: After connecting to watch, app MUST immediately send current "now playing" info if media is playing or paused

#### Initial Sync on Connect
- **FR-084**: Upon connection (including auto-connect and manual connect), app MUST immediately send critical state data to watch
- **FR-085**: Initial sync MUST include current time
- **FR-086**: Initial sync MUST include current music/"now playing" information if any media is playing or paused
- **FR-087**: Initial sync SHOULD include any other key state relevant for watch UI (e.g., notification summary, weather if available)
- **FR-088**: Initial sync MUST complete before app considers connection fully established

#### Health & Activity
- **FR-031**: App MUST receive and display step count data from watch (via Gadgetbridge `t:"act"` messages)
- **FR-032**: App MUST receive heart rate data from Gadgetbridge activity messages (`t:"act"` with `hrm` field)
- **FR-032a**: Heart rate values MUST be displayed in real-time as they arrive from activity messages
- **FR-033**: App MUST persist health data locally on device
- **FR-034**: App MUST display today's summary and 7-day history

#### Activity State Tracking
- **FR-108**: App MUST receive and process activity state from Gadgetbridge `t:"act"` messages (`act` field)
- **FR-109**: App MUST support all Gadgetbridge ActivityKind values: UNKNOWN, NOT_WORN, DEEP_SLEEP, LIGHT_SLEEP, REM_SLEEP, ACTIVITY (still), RUNNING, WALKING, SWIMMING, CYCLING, EXERCISE
- **FR-110**: App MUST persist activity state changes to local database with timestamps
- **FR-111**: App MUST calculate and display activity breakdown showing time spent in each state
- **FR-112**: Activity breakdown MUST be calculated from persisted database records (not in-memory only)
- **FR-113**: Activity breakdown MUST show duration and percentage for each activity state
- **FR-114**: App MUST support optional `ts` timestamp field in activity messages (milliseconds since 1970)
- **FR-115**: When `ts` field is present, app MUST use provided timestamp instead of current time
- **FR-116**: Historical/cached activity data (with `ts` field) MUST be stored with correct timestamps for accurate breakdown calculation

#### Data Retention
- **FR-063**: App MUST retain health and analytics data for 60 days
- **FR-064**: App MUST automatically delete data older than 60 days
- **FR-065**: Data cleanup MUST run periodically without user intervention

#### Developer Tools
- **FR-035**: App MUST provide live log viewer receiving logs over BLE NUS (same channel as Gadgetbridge protocol)
- **FR-035a**: Log viewer MUST display ALL incoming data over BLE NUS, including both watch logs and protocol messages (notifications, music, etc.)
- **FR-035b**: Log viewer MUST provide pre-defined filters to filter messages by type (e.g., "Logs only", "Notifications", "Music", "Activity", "All")
- **FR-035c**: App MUST support sending `{"t":"log","status":true}` to dynamically enable log streaming on watch
- **FR-035d**: App MUST support sending `{"t":"log","status":false}` to dynamically disable log streaming on watch
- **FR-035e**: App MUST handle receiving logs even when not explicitly requested (watch may have logging enabled independently)
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

#### Notification Debug Tools
- **FR-093**: Developer tools MUST include notification debug section on notification page
- **FR-094**: Notification debug MUST allow selecting an app name for test notifications
- **FR-095**: Notification debug MUST allow entering custom notification text
- **FR-096**: Notification debug MUST provide button to send debug notification to watch
- **FR-097**: Debug notifications MUST also be created on phone to test bi-directional dismiss syncing

#### Music Debug Tools
- **FR-098**: Developer tools MUST include music debug section with buttons to send static sample "now playing" metadata (title, artist, album) to watch

#### Watch Management
- **FR-099**: Users MUST be able to rename each previously paired/bonded watch for easier identification
- **FR-100**: Watch rename feature MUST be accessible within App Settings section
- **FR-101**: Custom watch names MUST persist across app restarts
- **FR-102**: Custom watch names MUST display throughout app wherever watch is referenced

#### Battery & Analytics
- **FR-045**: App MUST track and graph battery drain over last 24 hours
- **FR-046**: App MUST track and graph battery drain over last 7 days
- **FR-047**: App MUST display steps per hour breakdown for current day

#### Time & Timezone
- **FR-048**: App MUST sync time to watch according to Gadgetbridge protocol (setTime + timezone)
- **FR-049**: App MUST handle timezone changes and update watch accordingly

#### Background Behavior
- **FR-050**: Android: App MUST use Foreground Service with persistent notification to maintain reliable BLE connection when UI is not active
- **FR-051**: iOS: App MUST enable Bluetooth background modes for connection maintenance
- **FR-052**: App MUST disconnect cleanly when user explicitly removes/forgets the device
- **FR-053**: App MUST throttle health-sync frequency to minimize battery impact

#### Persistent BLE Connection
- **FR-089**: App MUST maintain reliable BLE connection even when running in background or UI is not active
- **FR-090**: Persistent connection MUST support sending notifications, music info, and all other BLE features
- **FR-091**: Persistent connection MUST work on both Android and iOS within their respective background-execution rules
- **FR-092**: Android: Foreground service notification MUST clearly indicate app is maintaining watch connection
- **FR-092a**: Android: Foreground service MUST start when user initiates connection to a watch
- **FR-092b**: Android: Foreground service MUST remain running when watch disconnects unexpectedly (to enable auto-reconnect)
- **FR-092c**: Android: Foreground service MUST stop only when user explicitly disconnects, disables persistent connection setting, or forgets the watch
- **FR-092d**: Android: Foreground service notification MUST update to reflect current state ("Connected to [Watch]" vs "Reconnecting to [Watch]...")

#### Voice Recording (Placeholder)
- **FR-054**: App MUST be architecturally prepared for future voice memo/dictation sync from watch
- **FR-055**: App MUST support audio playback for received voice recordings (when firmware supports)

#### Data & Privacy
- **FR-056**: App MUST store all data locally on device only
- **FR-057**: App MUST NOT transmit telemetry, analytics, or user data
- **FR-058**: App MUST NOT require user accounts or cloud services

#### Gadgetbridge GPS Support
- **FR-103**: App MUST implement Gadgetbridge GPSPower command to handle GPS location requests from watch
- **FR-104**: When watch sends GPSPower (or equivalent GPS request) command, app MUST obtain current location from phone
- **FR-105**: App MUST respect OS location permissions and settings when obtaining GPS location
- **FR-106**: App MUST send current GPS location back to watch in Gadgetbridge-compatible format
- **FR-107**: App MUST handle GPS permission denial gracefully with error response to watch

#### Gadgetbridge HTTP Relay
- **FR-117**: App MUST handle Gadgetbridge `t:"http"` requests from the watch containing `url` and optional `xpath`, integer `id`, and `insecure` fields
- **FR-118**: App MUST perform HTTP/HTTPS requests for `t:"http"` messages; TLS certificate validation MUST be enabled by default and ONLY disabled when `insecure:true` is explicitly provided
- **FR-119**: When `xpath` is provided, app MUST parse the fetched document as XML and return the XPath evaluation result in the response (failing with error if parsing or evaluation fails)
- **FR-120**: App MUST return HTTP responses to the watch using `{"t":"http","resp":<body or xpath result>}` and MUST echo the integer `id` when provided to allow concurrent in-flight requests
- **FR-121**: App MUST return HTTP errors to the watch using `{"t":"http","err":<error message>}` and MUST echo the integer `id` when provided
- **FR-122**: App MUST support multiple concurrent HTTP relay requests and MUST NOT drop or reorder responses across different `id` values

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
- **UX-019a**: Sub-screens MUST use push navigation to preserve back stack (not replace)
- **UX-019b**: System back button/gesture MUST return to previous screen, not exit app
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

- **Watch**: Represents a ZSWatch device (identifier, name, customName, firmware version, battery level, paired status, supported protocols, lastConnected timestamp)
- **Connection**: BLE connection state and metadata (state, signal strength, MTU, PHY mode, DLE enabled, reconnection count, last seen, autoReconnectEnabled)
- **ProtocolMessage**: Base message type with protocol indicator (Gadgetbridge API or Extended ZSWatch API)
- **Notification**: Phone notification to be forwarded (stableId, source app, title, body, timestamp, icon, dismissedOnPhone, dismissedOnWatch)
- **FirmwareImage**: Firmware file for upload (name, version, size, hash, type: app/net/filesystem)
- **HealthSample**: Health data point (type: steps/heartrate/sleep/activity, value, timestamp, granularity: realtime/hour/day/week/month)
- **ActivityState**: Activity state enumeration (unknown, notWorn, deepSleep, lightSleep, remSleep, still, running, walking, swimming, cycling, exercise) with integer value for database storage
- **ActivityBreakdown**: Aggregated time spent in each activity state (durations map, currentState, lastUpdate timestamp)
- **BatteryReading**: Battery level sample (level, timestamp, charging status)
- **SensorReading**: Raw sensor data (type: accel/gyro/ppg/temp, x/y/z or value, timestamp)
- **LogEntry**: Debug log from watch (level, message, timestamp, source module)
- **CommLogEntry**: BLE communication log (direction: in/out, protocol, payload, timestamp)
- **ShellCommand**: Terminal command/response pair (command, response, timestamp)
- **VoiceMemo**: Voice recording from watch (id, duration, timestamp, audio data) [placeholder]
- **MediaState**: Current media playback state (title, artist, album, playbackState, timestamp)
- **GPSLocation**: GPS coordinates (latitude, longitude, accuracy, timestamp)
- **HttpRequest**: HTTP relay request from watch (url, xpath?, insecure?, id?:int, startedAt, completedAt, resp?, err?)

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
- **SC-015**: Start page displays stored watches within 1 second of app launch
- **SC-016**: Auto-reconnect begins within 5 seconds of app launch if last connected watch is available
- **SC-017**: Notification dismiss sync (phone to watch and watch to phone) completes within 2 seconds
- **SC-018**: Music metadata updates appear on watch within 1 second of track/state change
- **SC-019**: Initial sync completes within 3 seconds of connection establishment
- **SC-020**: GPS location response sent to watch within 5 seconds of request (subject to GPS acquisition time)
- **SC-021**: BLE connection remains stable for at least 8 hours when app is backgrounded (within OS limits)

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
- Watch firmware supports notification dismiss callback with stable notification ID
- Watch firmware supports Gadgetbridge-compatible GPS location format
- Android foreground service with persistent notification is acceptable for users who want reliable background connection
- Watch firmware sends music control commands using Gadgetbridge music control protocol
