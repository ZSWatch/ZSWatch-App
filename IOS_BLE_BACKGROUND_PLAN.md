# iOS BLE Background and Restoration Plan

> Historical plan, superseded on 2026-10-12 by
> [IOS_COMPANION_IMPLEMENTATION_PLAN.md](IOS_COMPANION_IMPLEMENTATION_PLAN.md).
> Use [HANDOFF_TO_MAC.md](HANDOFF_TO_MAC.md) for branches, dependencies and tools.
> Do not reintroduce this document's staged legacy/native ownership strategy.

## Goal

Make the iOS app as resilient as possible when it is backgrounded, suspended, or relaunched by the system for BLE work, without rewriting the entire BLE stack at once.

## Current State

- The app already declares `bluetooth-central` in `zswatch_app/ios/Runner/Info.plist`.
- BLE ownership is still primarily in Dart via `flutter_blue_plus`.
- Android now has persisted lifecycle diagnostics and recovery scaffolding.
- iOS does not have an Android-style foreground service.
- If the user force-quits the app from the app switcher, iOS generally will not relaunch it for BLE until the user manually opens it again.

## What iOS Can and Cannot Do

### iOS can help with

- Keeping BLE activity alive for limited background scenarios through CoreBluetooth background modes.
- Waking or relaunching the app for BLE events when CoreBluetooth state restoration is configured correctly.
- Re-delivering restored peripherals and pending central-manager state after a system relaunch.

### iOS cannot guarantee

- Recovery after a user force-quit.
- A permanent always-running process equivalent to Android foreground service behavior.
- Reliable terminated-state restoration if BLE ownership stays entirely in Flutter/Dart with no explicit native restoration flow.

## Recommended Strategy

Use the same phased approach as Android, but with a different end state:

1. Add diagnostics first.
2. Add explicit iOS state-restoration hooks.
3. Move the minimal BLE ownership needed for restoration into native iOS code.
4. Keep higher-level protocol and app behavior in Dart where practical.

## Phase 0: iOS Diagnostics

### Objective

Make iOS lifecycle and restoration behavior observable before changing architecture.

### Tasks

- Add an iOS-native lifecycle diagnostics logger mirroring the Android ring buffer idea.
- Persist events in an iOS-owned store such as `UserDefaults`.
- Log:
  - app launch
  - app background/foreground transitions
  - scene transitions if scenes are used
  - CoreBluetooth manager creation
  - restoration callbacks
  - discovered/restored peripherals
  - connect/disconnect events
  - app termination notifications when available
- Bridge those stored events into Flutter and show them in Analytics -> Connection beside the Android diagnostics.
- Add a copy action on iOS too, using the same exported text format as Android.

### Outcome

We can inspect whether iOS is suspending, relaunching, restoring, or simply not reviving the app for a given case.

## Phase 1: Enable Explicit CoreBluetooth State Restoration

### Objective

Use CoreBluetooth state restoration deliberately instead of depending on plugin defaults or assumptions.

### Tasks

- Audit how `flutter_blue_plus_darwin` is initialized in app startup.
- Confirm whether `restore_state` is actually enabled from app code.
- If not enabled, wire it on explicitly during early startup.
- Verify restoration identifier usage stays stable across launches.
- Add startup logic that checks for a restored Bluetooth manager before normal connection flow begins.
- Record whether restored peripherals are present on relaunch.

### Validation

- Connect to the watch.
- Background the app.
- Let iOS suspend it naturally.
- Trigger BLE activity from the watch if possible.
- Relaunch and inspect whether restoration callbacks occurred.

### Outcome

We know whether the existing plugin path is enough for restoration or whether native takeover is required.

## Phase 2: Native iOS BLE Recovery Shim

### Objective

Move only the minimum BLE ownership required for restoration into iOS native code while keeping most application logic in Dart.

### Tasks

- Create an iOS native BLE coordinator around `CBCentralManager`.
- Give it stable restoration identifiers.
- Let it own:
  - central manager lifecycle
  - restoration callback handling
  - reconnect intent for the known watch
  - basic connection state persistence
- Expose a Flutter bridge for:
  - current connection state
  - restored peripheral identifiers
  - restoration events
  - reconnect requests
- Keep higher-level Gadgetbridge protocol logic in Dart initially.

### Constraints

- Do not rewrite the entire watch protocol layer in Swift unless Phase 2 proves that Dart ownership is still too fragile.
- Keep the native layer narrowly scoped to connection survival and restoration.

### Outcome

The app can be relaunched by iOS into a native BLE-aware state before Flutter fully comes up.

## Phase 3: Native Ownership of Critical GATT Session State

### Objective

If restoration is still unreliable, move the connection-critical GATT session pieces into native iOS code.

### Tasks

- Identify the minimum critical path needed before Flutter is ready:
  - reconnect to the known watch
  - rediscover required services and characteristics
  - re-enable required notifications
- Hold that state natively.
- Notify Flutter when the transport is usable again.
- Keep protocol parsing in Dart unless restoration timing forces a deeper move.

### Outcome

This is the point where iOS resilience approaches the practical maximum allowed by the platform.

## Analytics Additions

Add iOS-specific diagnostic fields to Analytics -> Connection export:

- app lifecycle transitions
- restoration callback count
- last restoration timestamp
- restored peripheral IDs
- last disconnect reason if known
- whether the previous stop looked like:
  - normal suspend
  - OS relaunch
  - crash
  - user force-quit inferred from missing restoration plus cold launch

## Validation Matrix

Use real-device validation only. Simulator is not enough.

### Scenario A: Foreground to background

- Launch app
- Connect watch
- Send app to background
- Verify whether connection survives for expected period

### Scenario B: Suspended and later revived

- Launch app
- Connect watch
- Let app sit in background long enough to suspend
- Trigger watch traffic
- Check whether iOS relaunches/restores app

### Scenario C: OS pressure / process eviction

- Launch app
- Connect watch
- Cause realistic memory pressure or wait for system eviction
- Relaunch app and inspect restoration trail

### Scenario D: User force-quit

- Launch app
- Connect watch
- Swipe app away
- Verify that reconnection does not happen automatically
- Confirm diagnostics make this limitation obvious

## Success Criteria

- Analytics clearly shows whether iOS suspended, restored, cold-launched, or likely force-quit the app.
- Background BLE behavior is measurable instead of anecdotal.
- State restoration is explicitly enabled and verified.
- After non-force-quit termination, the app can resume BLE work as far as iOS allows.
- Native code ownership is increased only where restoration actually requires it.

## Recommended Order

1. Implement Phase 0 diagnostics.
2. Verify plugin behavior and complete Phase 1 restoration setup.
3. Decide whether Phase 2 native recovery shim is needed.
4. Only do Phase 3 if real-device tests show Phase 2 is insufficient.

## Notes for Implementation

- Keep Android and iOS diagnostics conceptually aligned so Analytics -> Connection stays comparable across platforms.
- Reuse the same exported diagnostic text format where possible.
- Treat user force-quit as a hard platform boundary, not a bug to code around.
- Prefer small native shims over a full Swift BLE rewrite unless evidence forces it.
