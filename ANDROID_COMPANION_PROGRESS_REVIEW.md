# Android companion progress review — 2026-10-04

**Subsequent user decision:** follow [the finish plan](ANDROID_COMPANION_FINISH_PLAN.md).
The user explicitly authorizes a direct Android cutover and one-time app-data
reset instead of backward compatibility. Firmware upload performance (old app:
about 20 KB/s+) must be established before large filesystem tests, but updates
are not mandated as the immediate next task. Encountered watch-firmware bugs
should be fixed and flashed using the available tools. The recommendations
below about candidate freeze, compatibility migration and background gates before
further implementation are superseded. The recorded gaps remain observations,
not added prerequisites to continuing the rewrite.

Scope: plan adherence, delivery process and the remaining-work estimate. Reviewed
HEAD `c3bd8a3`, the uncommitted resource-update implementation, selected native /
Flutter ownership paths, test reports, and samples of retained hardware evidence.
This is not an exhaustive code audit or a new hardware acceptance run. Development
and the existing goal remain paused at the user's request.

## Verdict

Keep the native-service architecture and existing implementation. Most work is
relevant and the recorded evidence is unusually careful about its limitations.
Change the order of remaining work: close the core background acceptance gate
before extending peripheral features or adding further robustness experiments.
“20–30% left” is plausible for a narrowly defined Android implementation milestone,
but is not established for a reliable, normally shipped companion.

## Findings

1. **High priority: broad migration advanced before the core acceptance gate.**
   The [plan](COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md#13-genomförandeetapper-och-beslutspunkter)
   requires an eight-hour Android prototype run including a quiet period before
   broad porting. Its release criteria also call for a twenty-cycle initial
   reconnect series. Later checkpoints implement media, discovery, GPS, Shell,
   logs, backgrounds and DFU while these gates remain open. The retained HTTP
   comparison shows 900 seconds of forced idle with periodic watch traffic and
   USB attached; the runbook explicitly rejects the later spot check as a
   seven-hour soak. No completed eight-hour/quiet-period or consolidated
   twenty-cycle acceptance report was found. This is the principal sequencing
   issue: more feature coverage does not close the original reliability question.

2. **High priority for completion reporting: the remaining milestone is undefined.**
   `android/app/build.gradle.kts:106–110` forces the native runtime off in profile
   and release. The service, fixtures and configuration still contain prototype
   boundaries. That isolation is appropriate during development, but moving to
   ordinary app use, checking existing-user settings/data, and validating supported
   Android versions are still distinct deliverables. Test totals or migrated
   screen counts cannot establish that only twenty percent of delivery effort
   remains. AI and iOS are explicitly deferred and should not inflate the current
   Android milestone; receipt/download integrity remains a non-AI acceptance item.

3. **Medium priority: one small, previously required core fix remains displaced.**
   Firmware `app/src/ble/ble_http.c:40–76` still cancels the timeout without invoking
   the consumer callback for error/empty responses and does not reject a matching
   late response using `request_pending`. The original review and revised plan
   identified this as a bounded correction. The latest local-relay test succeeds,
   but the remote idle request times out; loopback does not establish external
   network access. Close the callback contract with focused tests, then treat
   external network behavior as a separate acceptance result. Avoid another
   open-ended HTTP investigation.

4. **Medium priority: sanity-check the current resource test before launching it.**
   The uncommitted implementation uploads the resource image and reads it back in
   full both before and after reboot. The preserved image is 5,932,208 bytes.
   A recorded 115,212-byte background verification took 50.059 seconds, equivalent
   to about 2.3 KB/s. At that rate one resource read would take about 43 minutes,
   beyond the new 20-minute postflight deadline; two would exceed the 60-minute
   whole-operation deadline before counting upload. This is a throughput-based
   risk, not a reproduced resource failure: different file paths/runs may be
   faster. Establish a bounded read-only throughput estimate and make deadlines
   consistent before writing the full image. Do not remove integrity checks just
   to make the test pass, or turn this into another transport investigation.

## What is being done correctly

- Flutter remains the UI. Native startup creates the BLE owner and handlers;
  Flutter startup observes it and avoids the legacy BLE initialization path.
- Current SMP/DFU code uses Nordic 2.7.2. Direct native use bypasses the Flutter
  callback layer deliberately; existing upload settings are carried across.
  The earlier custom-GATT/SMP experiment was a plan deviation, documented and
  removed. It is not the current implementation.
- Persistent user Stop, generation fences, exclusive update ownership and durable
  receipt handling address real lifecycle problems. Sampled tests exercise
  meaningful stale-callback, interruption and stage-ordering cases.
- Physical recovery evidence exists for injected crashes, radio changes, package
  replacement and reboot. Sampled private reports support the runbook's bounded
  claims. Failed trials remain recorded; Home is distinguished from engine loss.
- Current native XML reports contain 205 passing tests; retained Flutter output
  reports 157 passing tests and clean targeted analysis. Those checks were
  inspected, not rerun in this review. Watch originals and local fork changes
  have been preserved; iOS and Nokia AI execution are appropriately deferred.

## Recommended next milestone

1. Review and commit the current resource patch with physical acceptance explicitly
   pending. Do not start another feature migration.
2. Freeze one candidate APK and run a consolidated core regression: notifications,
   time, HTTP, UI detach/reattach, Stop intent and repeated reconnect/recovery.
   Fix the bounded HTTP consumer issue. Keep the known recording-transfer issue
   visible and isolated; use suitable hardware for its eventual acceptance.
3. Complete the planned eight-hour background and quiet-period cases, with actual
   power/network conditions recorded. Avoid repeated UI/status poking that changes
   the conditions being tested. Retain first-failure evidence.
4. Use those results to decide the finite production-cutover work: build/manifest
   configuration, fixture separation, old settings/data, modern Android, and the
   remaining update/transfer acceptance. Keep one short pass/fail/pending matrix;
   preserve historical runbooks as evidence without duplicating every checkpoint
   into several documents.

Retain the current code and testing discipline. Tighten milestone control and
test batching. There is no evidence here that restarting the implementation,
rewriting the Flutter UI, or changing models is the necessary remedy.
