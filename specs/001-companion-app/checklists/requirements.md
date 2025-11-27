# Specification Quality Checklist: ZSWatch Companion App

**Purpose**: Validate specification completeness and quality before proceeding to planning  
**Created**: 2025-11-26  
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Validation Results

### Passed Items

| Check | Status | Notes |
|-------|--------|-------|
| No implementation details | ✅ Pass | Spec avoids mentioning Flutter, Riverpod, specific libraries |
| User value focus | ✅ Pass | All stories focus on user outcomes |
| Non-technical language | ✅ Pass | Readable by stakeholders |
| Mandatory sections | ✅ Pass | User Stories, Requirements, Success Criteria all present |
| No clarifications needed | ✅ Pass | All requirements are concrete |
| Testable requirements | ✅ Pass | Each FR has verifiable criteria |
| Measurable success criteria | ✅ Pass | SC-001 through SC-010 have specific metrics |
| Technology-agnostic criteria | ✅ Pass | No framework/library mentions in SC |
| Acceptance scenarios | ✅ Pass | All user stories have Given/When/Then scenarios |
| Edge cases | ✅ Pass | 5 edge cases identified |
| Scope bounded | ✅ Pass | Non-goals clear in constitution; scope defined |
| Dependencies identified | ✅ Pass | Assumptions section documents dependencies |

## Notes

- Specification is complete and ready for `/speckit.plan`
- Constitution provides technical constraints (Flutter, flutter_blue_plus, mcumgr_flutter)
- BLE protocol details from firmware code inform communication requirements
- Firmware update flow matches existing website implementation patterns
- **Updated**: Added dual-protocol architecture (Gadgetbridge API + Extended ZSWatch API)
- **Updated**: Added high MTU, DLE, and 2M PHY requirements for optimal BLE throughput
- **Updated**: Added comprehensive developer tools (sensor streaming, comm logs, battery analytics)
- **Updated**: Added detailed health/activity history (hourly steps, live HR plot)
- **Updated**: Added voice recording placeholder for future firmware support
- **Updated**: Added time/timezone sync requirements
- **Updated**: Added background behavior requirements (Foreground Service, iOS BG modes)
- **Updated**: Added comprehensive UI/UX requirements (dark theme, ZSWatch colors, typography, animations, navigation)
- **Updated 2025-11-27**: Added Start Page with stored watches and "Connect new watch" button (FR-067 to FR-070)
- **Updated 2025-11-27**: Added Auto-Reconnect behavior (FR-071 to FR-074)
- **Updated 2025-11-27**: Added Notification Stable IDs and bi-directional dismiss sync (FR-075 to FR-078)
- **Updated 2025-11-27**: Added Music Control Integration with media commands and updates (FR-079 to FR-083)
- **Updated 2025-11-27**: Added Initial Sync on Connect for time and media state (FR-084 to FR-088)
- **Updated 2025-11-27**: Enhanced Persistent BLE Connection requirements (FR-089 to FR-092)
- **Updated 2025-11-27**: Added Notification Debug Tools (FR-093 to FR-097)
- **Updated 2025-11-27**: Added Music Debug Tools (FR-098)
- **Updated 2025-11-27**: Added Watch Rename feature (FR-099 to FR-102)
- **Updated 2025-11-27**: Added Gadgetbridge GPS Support (FR-103 to FR-107)
- **Updated 2025-11-27**: Added new success criteria (SC-015 to SC-021)

## Summary Statistics

- **User Stories**: 10
- **Functional Requirements**: 107 (expanded from 66)
- **UI/UX Requirements**: 28
- **Success Criteria**: 21 (expanded from 14)
- **Edge Cases**: 17 (expanded from 10)
- **Key Entities**: 14 (expanded from 12)

## Platform-Specific Notes

- **iOS**: Notifications/media via ANCS/AMS (watch-direct, app not involved in data flow)
- **Android**: Notifications/media via app bridge (NotificationListenerService, MediaSession APIs)

## Clarifications Resolved (2025-11-26)

- BLE Security: Bonding/pairing REQUIRED, encrypted connections mandatory
- Data Retention: 60 days with automatic cleanup
- DFU Battery Check: Informational only (not blocking)
- Developer Mode: Visible toggle in Settings (not hidden)
- Log Rotation: 5,000 entries or 5MB with oldest-first rotation

## Scope Clarifications

- **Watch settings**: Configured on watch directly (NOT synced from app)
- **Sensor streaming**: Uses existing `zsw_gatt_sensor_server.c` GATT service
- **Device info**: Uses Gadgetbridge `t:"ver"` message (no custom protocol)
- **Extended API**: Minimal - only for bulk health sync, logs, shell, voice memos

## Implementation Progress

| User Story | Status | Notes |
|------------|--------|-------|
| US1 - Connect to Watch | ✅ Complete | Scan, connect, bond, dashboard, reconnection, start page, auto-reconnect |
| US2 - Firmware Update | ✅ Complete | GitHub releases (multi-variant), CI builds, local files, MCUmgr DFU |
| US3 - Notifications | ✅ Complete | Android NotificationListener, MediaSession, Gadgetbridge protocol, initial sync |
| US4 - Dashboard | ✅ Complete | Connection status, battery ring, firmware version, feature navigation tiles |
| US5 - Health | ✅ Complete | Health screen with step charts, heart rate screen with live streaming, 60-day retention |
| US6 - Developer Tools | 🔲 Not Started | |
| US7 - Multi-Watch | 🔲 Not Started | |
| US8 - App Settings | 🔲 Not Started | |
| US9 - Analytics | 🔲 Not Started | |
| US10 - Voice Recording | 🔲 Placeholder | |

### Phase 3.6: Start Page & Auto-Reconnect (2025-11-27)

**Completed Requirements:**
- FR-067: Start page displays list of stored watches ✅
- FR-068: Each watch shows connection status indicator ✅
- FR-069: "Connect new watch" button navigates to scan ✅
- FR-070: Tapping stored watch initiates connection ✅
- FR-071: Auto-reconnect attempts on app launch ✅
- FR-072: Uses platform auto-connect (flutter_blue_plus autoConnect: true) ✅
- FR-073: User can cancel auto-reconnect and select different watch ✅
- FR-074: Automatic navigation to connected screen on success ✅
- FR-084: Time sync on connection ✅
- FR-085: Media state sync on connection (Android) ✅
- FR-099: Custom name field added to Watch model ✅

**Implementation Details:**
- `StartPageScreen`: New screen showing stored watches with status, "Add Watch" FAB
- `AutoReconnectService`: Simplified to leverage flutter_blue_plus's native autoConnect feature
- Database schema v2: Added customName column with migration
- `MediaControlNotifier`: Listens to connection stream and syncs media state on connect

### Phase 3.7: Initial Sync on Connect (2025-11-27)

**Completed Requirements:**
- FR-084: Initial sync performed immediately after BLE connection ✅
- FR-085: Time sync (via Gadgetbridge setTime command) ✅
- FR-086: Music state sync on connect (Android, via MediaControlNotifier) ✅
- FR-087: Other relevant state synced (device info request) ✅
- FR-088: Connection marked "connected" only after sync completes ✅

**Implementation Details:**
- `InitialSyncService`: New service to orchestrate sync operations (time, music, future state)
- `WatchConnectionState.syncing`: New state between negotiating and connected
- `ConnectionStatusPill`: Updated to show "Syncing..." during sync phase
- `WatchService._setupAfterConnect`: Transitions through syncing state, performs sync, then connected

## Firmware Update Implementation Details

- **GitHub Releases**: Fetches all releases with multiple hardware variants (watchdk, zswatch_legacy)
- **Asset Selection**: User selects which variant to download via dialog
- **Nested Extraction**: Downloads outer zip → extracts dfu_application.zip → parses manifest.json
- **Manifest Parsing**: Uses `image_index` from manifest.json for correct MCUmgr slot mapping
- **Multi-Image DFU**: Uploads each .bin to correct slot (0=app.internal, 1=ipc_radio, 2=app.external)
- **CI Builds**: Opens in browser (GitHub Actions artifacts require authentication)
- **Local Files**: Supports dfu_application.zip selection via file picker
- **Progress**: Real-time speed, percentage, time remaining, multi-image tracking
- **Confirmation**: Uses FirmwareUpgradeMode.confirmOnly for MCUboot image confirmation

