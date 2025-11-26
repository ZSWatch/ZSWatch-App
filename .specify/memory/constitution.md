<!--
SYNC IMPACT REPORT
==================
Version change: 2.0.0 → 2.1.0
Modified principles: None
Added sections:
  - Platform-Specific Constraints (Notifications & Media)
    - iOS: ANCS/AMS watch-direct communication
    - Android: App bridge via NotificationListenerService/MediaSession
Removed sections: None
Templates requiring updates:
  - .specify/templates/plan-template.md ⚠️ (needs constitution check update)
Follow-up TODOs: None
-->

# ZSWatch App Constitution

## Core Principles

### I. Flutter-First

The application MUST be implemented in Flutter/Dart. Only Flutter/Dart code is allowed at the top-level.

- Target platforms: **iOS and Android only**
- No web, desktop, watchOS, or WearOS support is in scope
- Native Android/iOS code is allowed **only** for:
  - Bluetooth Low Energy (BLE) interoperability
  - Firmware update (MCUmgr transport)
  - System-permission or background-mode integration

**Project Initialization Rules**:
- The Flutter project MUST be created using the official command: `flutter create <project_name>`
- No custom scaffolding, third-party templates, or AI-generated directory trees allowed
- AI assistants MUST NOT generate Flutter project structure from scratch
- AI assistants MUST assume the base project already exists (created by human via `flutter create`)

**Rationale**: Flutter enables cross-platform development with a single codebase while allowing native escape hatches for hardware-specific functionality. Using `flutter create` ensures consistent, officially-supported project structure.

### II. BLE Abstraction Layer

All BLE and DFU operations MUST be abstracted behind stable interfaces. UI code MUST NOT directly perform GATT operations or DFU commands.

- MUST implement a BLE abstraction layer isolating: Scanning, Connecting, GATT discovery, Characteristic read/write, Notifications/indications
- MUST maintain stable BLE connection when app is in foreground
- MUST maintain or restore BLE connection when backgrounded (within OS limitations)
- MUST handle automatic reconnection with explicit timeout and retry logic
- Connection state transitions MUST be explicit and observable

**Rationale**: Abstracting BLE allows testable business logic and enables future transport changes without rewriting the app.

### III. Privacy by Default

All data is stored locally on the user's device. No cloud services, user accounts, or telemetry.

- No cloud backend is allowed in scope
- No user accounts or external sync services
- The app MUST NOT transmit telemetry or analytics
- Watch data models MUST be deterministic, documented, and serializable

**Rationale**: Users trust the app with personal health and device data; privacy is non-negotiable for an open-source project.

### IV. Modular Architecture

The app MUST use modular architecture with clearly separated layers and predictable state management.

- **Layers** (top to bottom):
  - UI layer
  - Feature modules (settings, notifications, health, firmware update, etc.)
  - Device communication/services
  - BLE layer
- **State management**: Riverpod (preferred) or Bloc
- All modules SHOULD be designed so they can be replaced or extended without rewriting the entire app

**Rationale**: Clear separation enables independent testing, parallel development, and future extensibility.

## Technical Constraints

| Constraint | Requirement |
|------------|-------------|
| **Language** | Dart (Flutter) |
| **iOS** | 13.0+ |
| **Android** | API 19+ (minSdkVersion) |
| **BLE Library** | `flutter_blue_plus` |
| **DFU Library** | [`mcumgr_flutter`](https://github.com/NordicSemiconductor/Flutter-nRF-Connect-Device-Manager) (nRF Connect Device Manager) |
| **State Management** | Riverpod (preferred) or Bloc |
| **Local Storage** | Platform-native or SQLite equivalent |

## Protocol Constraints (MCUmgr/SMP)

ZSWatch uses MCUmgr / SMP (Zephyr/Nordic DFU protocol). The DFU implementation MUST adhere to:

- MCUmgr/SMP procedure ordering
- Image upload chunking rules
- Metadata and image state commands
- Integrity and hash checks
- Proper confirmation and reboot sequence

All BLE/DFU operations MUST have explicit timeout and retry logic.

## Platform-Specific Constraints (Notifications & Media)

Notification and media handling MUST be platform-specific. The implementations MUST NOT be unified on the phone side.

### iOS (ANCS / AMS - Watch-Direct)

On iOS, the **watch** communicates directly with iOS using Apple-defined GATT services:
- **ANCS** (Apple Notification Center Service) for notifications
- **AMS** (Apple Media Service) for media metadata and controls

The iOS companion app:
- MUST NOT intermediate, replace, or emulate ANCS/AMS
- MUST NOT attempt to replicate notification/media data flow
- May only provide: configuration UI, non-ANCS features (settings, DFU, health sync, developer tools)

### Android (App Bridge)

On Android, **no OS-equivalent** of ANCS/AMS exists. The app MUST act as the bridge:
- MUST use `NotificationListenerService` to access notifications
- MUST use `MediaSession` / `MediaController` APIs for media
- MUST translate notifications/media into ZSWatch GATT protocol
- MUST send data to watch via BLE (this is entirely app-driven)

**Rationale**: iOS provides exclusive accessory-side GATT interfaces that cannot be replicated by apps. Android requires app-level bridging as no system service exists.

## UX Requirements

- The app MUST be simple, predictable, and minimal with a modern sleek look
- Device connection state MUST always be visible when relevant
- Firmware update progress MUST always be visible during updates
- Debugging tools for developers are allowed in a dedicated "Developer Mode"

## Governance

This constitution supersedes all other development practices for ZSWatch App. Amendments require:

1. **Proposal**: Document proposed change with rationale
2. **Review**: Maintainer review required
3. **Versioning**: Semantic versioning (MAJOR.MINOR.PATCH)

All pull requests MUST verify compliance with Core Principles.

**Version**: 2.1.0 | **Ratified**: 2025-11-26 | **Last Amended**: 2025-11-26
