# Android companion completion — 2026-10-08

The fixed local Android checklist is complete. Remote/hybrid AI, iOS and long
endurance remain outside this milestone. Earlier accepted functionality and
its precise limits are preserved in [the acceptance history](ANDROID_COMPANION_ACCEPTANCE_HISTORY.md).

## Final onboarding result

OnePlus NE2213, Android 16, started with ZSWatch data cleared through ordinary
Android settings (the phone denies ADB's data-clear command). App storage showed
zero data/cache and the app showed no saved watches. Nearby-device and notification
permissions were granted through normal dialogs.

This exposed one actual blocker: Android's existing HID/system GATT connection
kept the bonded watch connected, so it was not advertising and the scan-only
companion picker could not find it. Runtime commit `c617e7a` lets the existing
picker confirm the exact address of a single connected, bonded ZSWatch. Multiple
connected watches are not selected arbitrarily; ordinary discovery remains the
path when no unique connected watch exists. Android's normal access confirmation,
generation checks and the single native BLE owner remain in use.

The corrected release reaches Connected with MTU 247 without watch reset or
manual unpairing. With the Flutter task absent, one actual firmware HTTP request
receives a successful 35-byte loopback fixture response in 1,098 ms. The native
connected-device foreground service remains active, PID 1529 remains unchanged,
and reopening Flutter attaches to that same owner. The first observer checked
task removal before Android's transition completed; the continuation observed
the settled removal without requesting it again or repeating the HTTP request.

Evidence: [final physical observation](.companion-hil-runs/20261008-oneplus-final-onboarding/observation.json)
and [artifact identity](.companion-hil-runs/20261008-oneplus-final-onboarding/artifact.json).
Seven affected association/discovery unit tests pass and the release build passes.
The earlier 243-test native pass and unchanged voice/AI, feature, recovery and
update evidence remain the accepted baseline; these were not rerun wholesale.

## Deliverables

Runtime source: `c617e7a673de46efa20cec18f327df7d692ca600`.

- [Production release APK](.companion-hil-runs/20261008-oneplus-final-onboarding/app-release.apk)
  SHA-256: `e2ffdac4281bab765cb00aa7b6e143e58f4c7aa866589b8f83748ffe7fbd23b3`.
- [Installed lab-signed release copy](.companion-hil-runs/20261008-oneplus-final-onboarding/app-release-lab.apk)
  SHA-256: `2e28103214a4bb2661931b62821aafc7e20cf1cd7c21b75c7973b7d3011c6b18`.
  It is not debuggable; runtime ZIP entries match production. The installed phone
  APK hash is verified. Re-signing uses the existing lab certificate only.
- Firmware remains the already flashed `098977c4` fix. No firmware change or
  flash was needed today. Its exact image/build identity is in the acceptance history.

## Remaining limits and cleanup

No demonstrated blocker remains in this checklist. The interrupted custom-photo
observer did not reach selection/crop/upload; that variant remains unverified
and deferred. The old owned phone photo and temporary UI dump are removed. The
test HTTP server, UART collector and ADB reverse are stopped. Watch originals and
unrelated repository/library changes are preserved; no new watch files were created.

Clearing app data removed downloaded models and app preferences. Local models
must be downloaded/configured again for everyday use, and optional notification
forwarding/location settings can be enabled normally. The accepted local AI
inference and delivery evidence predates this intentional reset; it is not a
claim that models remain installed after clearing data.

Long unplugged/OEM endurance is user-owned. The other deferred cases listed in
[the finish checklist](ANDROID_COMPANION_FINISH_PLAN.md) remain deferred and are
not claimed to have passed. There is no further agent-run acceptance queue.
