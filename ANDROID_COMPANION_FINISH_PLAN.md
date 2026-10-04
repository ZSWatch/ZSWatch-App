# Finish the Android companion refactor

Authoritative user direction, 2026-10-04. This short checklist supersedes earlier
staging, compatibility and work-order recommendations in the background plan and
progress review. Keep the existing Flutter UI; finish the native Android owner.
Continue on `codex/companion-background-foundation` and commit completed work.

## Revised goal wording

Finish the Android native companion refactor in the existing Flutter app. Make
native ownership the normal Android path in all build modes and remove the
legacy Android owner/selection flag. Choose the next work by actual dependencies
and remaining functional gaps. When completing updates, first make real Nordic
firmware uploads reliable and match the old app's reported 20 KB/s or better
speed before attempting larger filesystem and combined updates. A one-time app database/settings reset and
fresh permission setup are allowed instead of compatibility migration. Finish
the existing non-AI features and a practical consolidated background/recovery
check. Preserve the user's library fixes, unrelated work and watch originals.
Use the existing Nordic SDK, fix encountered watch-firmware bugs and verify them
with the available debugger/flash tools, defer iOS/AI, and avoid peripheral
investigations.

## Decisions already made

- This is one direct refactor for a small private user base. No staged rollout,
  legacy Android runtime fallback, dual-owner feature flag or backward-compatible
  database migration is required. Do not build those systems.
- Existing phone databases/settings may be reset on upgrade if that simplifies
  the implementation. Use a one-time reset only where needed, not a reset on each
  launch. A fresh permission/association setup is acceptable. Runtime durability
  after the refactor still matters; this does not authorize deleting watch audio
  or flashing over unrelated watch storage.
- Retain shared code still needed by Flutter UI or the deferred iOS path. Remove
  obsolete Android ownership paths; avoid unrelated mass renames or cleanup.
- The user's old-app firmware upload baseline is about 20 KB/s or better. This
  is an upload baseline, not a claimed filesystem download/readback speed.
- Fix encountered watch-firmware bugs as normal implementation work. The user
  authorizes building, flashing and debugging the connected watch; the known HTTP
  callback bug should be fixed, not merely documented. Use the verified board and
  existing targeted flashing tools, preserving unrelated watch storage. Firmware
  update throughput is a requirement for that feature, not a command to work on
  that feature next.
- No development freeze. Record the APK/firmware revision used for each relevant
  hardware result; continue editing and building normally.

## Work order for Sol

Use this order as a practical default; finish prerequisites and active changes
where that is more efficient. Firmware upload validation precedes large resource
tests, but firmware updates are not required to be the immediate next task.

1. **Complete the direct Android cutover.** Enable the native owner in normal
   debug/profile/release builds; remove `COMPANION_RUNTIME_PROTOTYPE` as a runtime
   choice and remove obsolete Android BLE/service startup paths. Move required
   permissions, receivers and service declarations into normal Android builds;
   keep lab instrumentation and synthetic fixture triggers out of normal release
   execution. Retain the existing Flutter screens and connect remaining real
   consumers. Use clean app storage/setup where needed instead of migration,
   shadow-storage compatibility or rollback machinery.

2. **Close the core functional work.** Notifications, time, HTTP, reconnect,
   saved-watch setup, media, location/weather policy and voice-note acquisition
   must use the native owner. Preserve already working implementations. Fix the
   small known HTTP error/empty/late-response callback contract in watch firmware,
   build and flash the matching target, and verify the real consumer. Apply the
   same approach to other firmware bugs encountered during the refactor. Keep recording
   integrity visible as a non-AI check; do not resume an open-ended corruption
   investigation on the Nokia. Actual local AI and iOS remain deferred. Retain
   local/remote processing integration points without building new AI features.

3. **Firmware updates and throughput.** Use the existing Flutter firmware
   screen, the user's Nordic fork settings/fixes and the native service owner.
   Select a valid, board-matching firmware artifact and verify that Nordic actually
   uploads it; an already-active-image shortcut is not a throughput result.
   Measure acknowledged payload bytes over the active upload interval, separately
   from preparation, reboot and reconnect. Check representative sustained speed
   against 20 KB/s before attempting large resource updates. If slow, compare the
   actual SDK MTU, upload window, connection priority, logging and handoff with
   the working old path. Reuse an existing baseline artifact or a separate old
   checkout if a same-phone comparison is necessary; do not retain a fallback
   owner in the refactored product. Confirm reboot and normal companion recovery,
   using the SDK's existing image evidence. Keep any unavailable image-index
   verification explicit. Do not write a new SMP implementation or hide slow
   transfer by increasing deadlines.

4. **Filesystem images and combined updates.** Preserve the already-written
   resource code; review/commit it without claiming a physical pass. Run the larger
   real resource test only after firmware upload performance is established.
   Check resource upload and verification rates separately. Simplify redundant
   full-image readbacks where justified: a normal update need not automatically
   download the entire multi-megabyte image twice. Keep a deliberate integrity
   check and the original resource backup for the lab test. Size alone is not
   an integrity check. Use measured rates for sensible deadlines. Combined
   resource-first/firmware-second work must remain service-owned when Flutter
   closes. Test the required reset/reconnect using the existing Nordic library.

5. **Validate the finished app, then stop expanding scope.** Run affected tests
   while implementing and one consolidated physical smoke/recovery pass covering
   core features with Flutter absent, UI reattachment, radio/process recovery,
   Stop intent and ordinary reconnects. Include a longer background/quiet-period
   run once the implementation works; it is not a gate before every feature or
   a reason to stop implementation now. Record real power/network conditions and
   device limitations. No repeating whole suites or rebuilding both legacy/native
   variants after the legacy owner is removed. Fix actual blockers, commit the
   result, and report any hardware-dependent acceptance still outstanding.

## Completion and working discipline

Done means the normal Android app uses one native companion owner with the
existing Flutter UI, real firmware/filesystem workflows have appropriate evidence,
firmware upload speed meets the agreed baseline or has a concrete documented
hardware limitation, and the consolidated core checks pass. Do not silently count
unverified transfers or deferred hardware tests as passed. Longer release-scale
soaks and newer-phone/iOS/AI validation are reported separately, not used to invent
new implementation work indefinitely.

Use targeted source reads and one short pass/fail/pending list. Preserve existing
evidence; stop duplicating checkpoint narratives into multiple long documents.
Ask for input only when required information or authorization actually blocks the
next useful step. Do not ask again about accepting a clean phone database/setup.

## Current checks (2026-10-04)

- Direct cutover implemented: normal debug/profile/release builds compile; 205 native
  and 158 companion Flutter tests pass. Ordinary debug APK on Nokia reaches Ready,
  remains connected with launcher visible, reattaches the same generation, and
  Flutter Disconnect settles Stop with the service absent. Evidence:
  `.companion-hil-runs/20261004-direct-native-cutover/`.
- Pending: firmware HTTP callback fix, measured firmware upload, physical resource/combined
  updates, and the final consolidated background/recovery pass.
