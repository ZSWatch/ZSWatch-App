# First physical Android companion smoke test

2026-10-02. Nokia G100, Android 12/API 31, USB ADB, bonded ZSWatch.
This is a development smoke session, not companion acceptance or an overnight test.

The installed watch reported `v0.8.1-2d93427ba620`, Zephyr `4.3.99` and
SDK `3.3.0-preview1`; it is not the current watch source revision. No firmware
was flashed. One authorized setup reset kept USB SMP available: the host opened
it within 5.688 seconds and held DTR with status requests through the boot guard.
The phone remained USB powered. `mWakefulness=Dozing` below describes display
sleep; it does not prove Android Device Idle/Doze or unplugged battery behavior.

Raw evidence, phone identifiers, APKs, source patches, UART and Android logs are
local and ignored under `.companion-hil-runs/20261002-nokia-usb-first/`.
Logs from other phone apps must not be committed. No recording was deleted or
uploaded to an AI service. Microphone recordings were made with the normal
`voice_memo start/stop` commands over USB SMP; the phone received files over BLE.

## Observations

| Scenario | Result and limit |
| --- | --- |
| Paired connection | Native service reached Ready and subscribed to NUS. Initial subscription attempts timed out during bonding/MTU setup. |
| Clock | Time/timezone writes completed and new filenames reflected phone time. This is not independent clock accuracy or zero/fractional timezone validation. |
| First recording | Real recording was downloaded; raw phone/watch bytes and SHA-256 matched. The initial event was lost before the MTU fix; reconnect/list discovered it. |
| UI in background | A later recording was automatically discovered and downloaded with the prototype Activity stopped and Settings foreground. |
| Task removed from Recents | Activity/task was destroyed; the same process and service retained a Ready connection. Observer detach was logged. This alone does not establish a subsequent successful recording after task removal. |
| Display asleep | Recording events/list entries and download attempts occurred while the phone reported Dozing. The first trial completed after a manual wake, so full screen-off completion was not proved there. A later trial failed with `McuMgrDisconnectedException` within its 90-second budget. |
| File integrity | Four downloaded receipts were independently compared with USB reads of the watch: exact bytes, sizes and SHA-256 matched. All five watch copies remained. |
| Injected process crash | Two `adb shell am crash --user 0 com.zswatch.app` trials failed automatic transport restoration within 90 seconds. This is a Java process crash, not SIGKILL, low-memory reclamation or force-stop. |
| Explicit recovery | Relaunch/Connect restored the native connection and recovered the list. A previously failed fourth receipt downloaded after retries and matched the watch. |

The Nokia denied `run-as` signalling of the app process; no attempted SIGKILL
succeeded. An earlier framework low-memory exit was observed during initial app
startup, before the tested foreground service was running, and is not evidence
for background service recovery.

## Fixes and unresolved causes

The watch initiated MTU 247, then the prototype requested 64. Firmware retained
its larger cached send capacity and a 126-byte recording notification failed
with `No ATT channel for MTU 126`. Discovery now precedes a local request,
reuses observed peer capacity and requests 517 only if needed. Duplicate
CONNECTED/discovery callbacks are fenced. Recording events were delivered after
this change.

Enabling/disabling the firmware's SMP service causes GATT Service Changed. The
prototype now fences old handles and reconnects. This interrupts active work;
MCUmgr/NUS coexistence remains unstable. One valid watch file initially yielded
a different BLE hash and was rejected by container validation; other retries
timed out. The later valid receipt matched the source. Validation stays strict;
failure diagnostics retain size/hash and container header, without retaining
audio payloads in the journal. USB reads of prior receipts overlapped the last
screen-off scenario, so repeat that case without competing filesystem reads.

A successful transfer previously released its SDK transport and queued SMP
disable immediately before starting another pending file. The new batch change
retains one SDK connection/SMP lease across pending files. Physical validation of
that change was attempted after phone unlock and failed, as described below.
Successful reuse across multiple completed files remains unverified.
The updated prototype is installed. Both debug variants compile and the existing
28 JVM contract tests pass; these tests do not execute the Android transport.

For crash recovery, Android logged a scheduled sticky restart, a new process,
then `am_stop_idle_service` before `am_proc_bound`. The service was created and
destroyed without a start callback; the persisted Ready state was stale. A
foreground notification and a new PID therefore did not establish recovery.
Moving promotion to `onCreate` reproduced the same failure and was reverted.
No battery exemption or OS restriction was silently disabled to obtain a pass.
This is observed on this rig; it is not yet attributed to a Nokia customization.
Starting the service from the debug app UID while locked/backgrounded was also
rejected with `ForegroundServiceStartNotAllowedException`. That diagnostic
attempt was an explicit test start, not automatic recovery or a UI launch.

## Isolated repeat after phone unlock

The installed batch APK was unchanged (`43a09e0db53f4d9bdafb51e8055dc6c8d97c815bf1beffc75473ab549e651106`,
source commit `0d09a61a0010524340f7caea89b1893c5c37ef63`). The host made two more
short recordings with the service stopped, then used Connect and one Fetch
recordings action to queue those two and the prior failed receipt. The batch did
not complete within 120 seconds: two receipts timed out and one was rejected by
container validation. There were repeated GATT reconnects. No successful
multi-file batch was observed, so retaining the SDK lease is not a proven fix
for the transfer failures.

A subsequent new recording was made with the display asleep. Its event/list
entry arrived and download started, but the resulting container was rejected.
The 120-second trial ended with `mWakefulness=Dozing`, USB power and a Ready
connection; there was no intervening UI launch or manual wake. UART/phone logs
were captured throughout. No USB filesystem reads competed with either BLE trial.
This reproduces failure independently of the earlier overlapping USB reads.

After both trials ended, all four failed source recordings were read over USB.
Their exact sizes, canonical timestamps, closed frame counts, frame boundaries
and durations were valid. The two rejected BLE payloads had the same size and
32-byte header as their sources, but different SHA-256 values. This narrows the
problem to the BLE transfer/assembly path; the current evidence does not locate
the fault within firmware SMP delivery, the SDK or GATT ownership. No invalid
payload was accepted as a receipt. Audio was compared in memory without exporting
new audio copies. All eight source recordings remain on the watch; four have
previously verified phone receipts.

Evidence is in `unlocked-batch-validation.json`, `unlocked-screen-off.json`,
`isolated-failed-watch-files.json` and `capture-batch-validation/` under the local
evidence root. The prototype service remains foreground and connected after the
trials. The two prior crash-recovery failures remain unresolved and were not
reclassified or repeated in this session. No native code changed during this repeat.

## Chunk validation and timeout experiment

The app now checks the SDK's returned file offset, bounds, first-chunk length,
and complete container before publishing any receipt. Five JVM tests exercise
the actual SDK download assembler with injected responses; one confirms that
the unguarded SDK would silently zero-fill an offset gap. This prevents a bad
payload from being marked as received, but does not repair bytes lost earlier
in BLE delivery.

A debug-only instrumentation probe can start the native service while the
Nokia is locked, retry already-listed recordings, and return bounded state.
Because Android instrumentation changes process scheduling and can terminate
the target process, these trials diagnose transfers only; they do not establish
normal background recovery or kill recovery.

The pinned Nordic `FsManager` uses a 2.5 second timeout for every file chunk.
An experimental build raised that single-request timeout to 10 seconds. Two
previously failing recordings completed byte reception, but both failed the
container/hash check. In-memory comparison against USB reads found different
data in one of seven chunks for `20261002_195726` and the first chunk for
`20261002_195732`; the other 12 checked chunks matched. The third pending file
still timed out. Offsets were contiguous. Thus the short timeout contributes to
some failures but cannot account for the body corruption, which is already
present before the SDK copies the returned data into its receipt buffer. No
invalid receipt was accepted and no watch recording was deleted or exported.

Packet hashes and SMP headers were captured without packet bodies. During these
attempts Android also reported Service Changed callbacks and unregistered GATT
clients as the watch dynamically registered/unregistered SMP. This is a concrete
coexistence lead, not yet proof that it caused the altered bytes. The current
prototype uses separate NUS and Nordic MCUmgr GATT objects. The companion service
must coordinate their lifecycles; a single logical owner does not require
replacing Nordic's transport or sharing one BluetoothGatt object.

The experimental APK, source copies, native test log, probe output, UART/logcat
and hash-only comparison records are kept locally under
`.companion-hil-runs/20261002-native-chunk-trace/`,
`.companion-hil-runs/20261002-native-packet-trace/` and
`.companion-hil-runs/20261002-native-timeout-trial/`. Host test results are 34
passing native JVM tests. Transfer acceptance remains unmet.

## Withdrawn custom-transport experiment

A later diagnostic experiment replaced Nordic's GATT/SMP transport with a
shared-GATT adapter. That departed from the implementation plan and has been
removed. Nordic's `McuMgrBleTransport` and `FsManager` are restored. The added
firmware checksum configuration was also removed; it was never flashed.

The experiment introduced a separate timeout bug: requests kept sequence zero,
and a timer from a completed request could fail a later request. Its results
cannot establish that the Nordic library caused the original failures.
Byte-for-byte USB comparison found `20261002_195726` and `20261002_200103` exact,
but `20261002_195732` differed in the chunk starting at offset 9700 even though
the container passed validation and the prototype marked it downloaded.
A new `20261002_212304` recording differed at offset 12125 and was rejected by
the container check. Thus a diagnostic `ALL_RECEIPTS_DOWNLOADED` result does not
prove end-to-end integrity. All nine original recordings remain on the watch.
The locally captured experiment evidence is retained under
`.companion-hil-runs/20261002-single-gatt-*`; continuation-fragment byte samples
have been redacted from the diagnostic capture.

The restored Nordic build passes all 34 native JVM tests and has replaced the
experimental APK on the Nokia; the installed APK SHA-256 matches the built file.
The corrupted `20261002_195732` receipt is preserved in quarantine and its journal
entry is marked failed, so it cannot be reused as a successful cached download.
This verifies the rollback, not transfer integrity or background recovery.

## Existing Flutter baseline and presence foundation

The foreground diagnostic now invokes the existing Flutter `WatchService`,
`BleConnectionService` and `FileSystemService` without auto-sync, AI or watch
cleanup. The first harness attempt was invalid: it checked Connected immediately
after `connectById` returned, before asynchronous setup finished. That wait is
corrected and the diagnostic now requires its visible Run button.

The corrected Nokia run reached the app's Connected state, but service discovery
returned zero services. `WatchService` logged missing NUS and still reported
Connected; SMP-enable could not take effect, and the diagnostic stopped before
calling Nordic's file downloader. A subsequent native prototype connection also
reported `NUS service unavailable`. This is not a Nordic file-transfer result.
Four source files were hashed independently over USB before the run, with no USB
filesystem traffic during BLE. All nine watch originals remain. Metadata and
failed-run captures are under `.companion-hil-runs/20261002-flutter-nordic-baseline/`.

A debug-only CDM association/presence path is now implemented and the Nokia
reports the companion-device-setup feature. The system picker selects the exact
watch address. OS presence callbacks request restoration of the existing native
runtime without starting Flutter. Persisted intent/address/generation checks
protect Stop and watch changes; a matching event can retry an errored link.
The service/permissions are excluded from the merged release manifest.

37 native JVM tests and 12 Flutter bridge/widget tests pass, static analysis
passes, and the prototype/diagnostic APKs compile. Android’s system picker approved the
watch association, observation registration succeeded, and real appeared/
disappeared callbacks reached `PrototypePresenceService`. A callback issued
`RESTORE_PRESENCE`, which the runtime accepted; the NUS failure persisted.

With the association active and Settings foreground, an injected `am crash`
changed PID 17260 to 17863 and generation 81 to 82 without a UI launch. Android
delivered a null-intent sticky start, and the service registered observation
again. Unlike the earlier trials, a new native generation ran. The starting
link was already disconnected, and the restored generation still did not reach
Ready. This is evidence of process/service restart with association active,
not full connection/recording recovery or proof of which CDM privilege caused
the difference. It is not low-memory termination or a force-stop test.

Real presence callbacks also resumed after the crash. A subsequent explicit Stop
persisted `desired_running=false` and phase Stopped; generation stayed 89, the
native foreground service was absent, and the system association remained.
The phone is left with the prototype stopped rather than repeatedly retrying the
failed link. All nine watch recordings remain, and no firmware was flashed.
Evidence is under `.companion-hil-runs/20261002-presence-foundation/`.

The initial empty discovery was recovered in the follow-up below. Transport
integrity remains an open blocker. Setup and acceptance instructions are in
`scripts/companion_hil/README.md`.

## Existing discovery flow and SDK baseline after adapter restart

The existing Flutter SMP preparation already sends enable, waits two seconds,
then rediscovers instead of trusting `hasSmpService`; the diagnostic uses that
same path. Initial connection also closes any stale GATT handle. No replacement
cache recovery or SMP protocol was added.

Restarting the Nokia Bluetooth adapter retained the watch bond and changed the
unchanged diagnostic's discovery result from zero to 15 services. NUS subscription
and the existing enable/rediscovery flow succeeded. The Android enable log confirms
an adapter restart, although Google Play services also re-enabled Bluetooth during
the operation. This is an observed recovery, not proof of the exact root cause or
a requirement to restart Bluetooth on every connection.

The ordinary Flutter `FileSystemService` / Nordic 2.7.2 baseline then completed
four recordings in roughly 2.9–3.8 seconds each. All had the correct length but
all four SHA-256 hashes differed from independent USB reads of the watch originals.
The USB originals still matched the earlier references. In-memory comparison found
186–326 changed bytes per file, confined to a few regions. The diagnostic invokes
no AI, voice-sync commit, or watch deletion; its unverified receipts remain separate
from the normal voice-memo pipeline. Correct length alone is insufficient for
transfer acceptance. This reproduces corruption through the existing library path
and does not establish whether the fault is in firmware, Android, or the SDK.

Flutter protocol setup now propagates missing NUS service, missing notify/write
characteristic, and subscription failures to `BleConnectionService` instead of
allowing Connected. The owner's existing setup failure/reconnect path remains in
use. Battery remains optional. Six setup regression tests plus eleven existing
voice-sync tests pass, focused analysis is clean, and the diagnostic APK compiles.
The installed readiness APK's hash was verified. Its second physical run discovered
14 services initially, then 15 after the existing SMP enable/rediscovery flow,
and completed all four downloads. Two matched the USB references exactly and two
did not. This confirms intermittent corruption; the readiness change does not
claim to fix it. Background transfer acceptance remains unrun in these baselines.

A separate USB isolation attempt enabled BLE SMP without a concurrent BLE transfer.
USB disconnected during a subsequent read, and UART showed the watch had rebooted.
There was no active UART capture at the fault itself, so its cause is unconfirmed.
The stored coredump summary has an invalid-looking filename/line and is not a
usable source location. An authorized reset restored USB SMP; BLE SMP is disabled
and all nine recordings remain. No firmware was flashed or coredump erased.
Evidence: `.companion-hil-runs/20261002-existing-discovery-retry/`.

## Next physical work (updated 2026-10-03)

1. Finish the main native BLE/application integration: connection state, two-way
   notifications, watch data and native receipt/job/result integration. Keep the
   existing Nordic library and the ordinary app's cache fixes.
2. Repeat the basic BLE/lifecycle cases on a modern Android phone, then unplugged
   idle/Doze and a longer soak. Test permission/radio changes and genuine process
   reclamation separately from injected crashes and explicit lab starts.
3. Test the prepared service-owned Dart worker and actual local AI only on a
   suitable newer phone. The Nokia is for BLE/lifecycle; it is too old for useful
   AI validation. iOS background execution still needs a Mac and physical iPhone.
4. Keep file-integrity diagnosis as a separate deferred work item. Later transfer
   acceptance needs the failed batch/screen-off cases and byte-for-byte source
   checks. Preserve originals and earlier failures; never add custom SMP transport.

Transfer diagnosis remains a separate work item. It must not turn into a custom
protocol implementation or prevent work on native service ownership and recovery.

These results do not establish production migration readiness. The prototype
remains behind its debug flag; the Flutter UI is retained.

## Native notifications with paused downloads, 2026-10-03

The corrected debug prototype forwarded synthetic notifications after Activity/task
disposal and completed a write with the screen off. Bluetooth restart and an
injected process crash from Ready both recovered protocol readiness without a
Flutter UI launch, resynced time and replayed stable notification IDs. Explicit
Stop cleared content and released the service; radio restart did not undo it.
These tests have USB attached and demonstrate native ATT write completion, not
watch popup/application receipt or unplugged Doze. The firmware does not
expose an application notification ACK; that capture did not include watch-side
notification-manager logs. The later watch-control run below includes UART
receipt/removal evidence. Full process/service/receipt evidence and tested
APK hash are in `ANDROID_COMPANION_RUNTIME_PROTOTYPE.md` and
`.companion-hil-runs/20261003-native-notifications/`.

No recording downloads ran in this milestone, all nine watch recordings remain,
and neither firmware flashing nor AI/upload/delete occurred. The phone locked
after the screen-off test; the existing non-exported Stop action was invoked as
the debug app UID with explicit user 0. Notification access remains granted for
ZSWatch, its policy remains synthetic-only, downloads are paused, Bluetooth is on,
and the runtime is stopped.
## Native BLE watch state, dismissal and forced idle — 2026-10-03

Evidence: `.companion-hil-runs/20261003-native-watch-control/` (private/ignored).
The first tested APK SHA-256 was
`34a5d01ff09c5cd15771abeda28b807ae794d52539c02567dcc5d28bcd22b975`.
The subsequent APK with serialized initial Battery Service read was
`62637491e735ffa3782443772b0028e1425ff4458cf9c27a4b758834507577d4`.
Frozen APKs and raw state/log evidence are retained. Later source also validates
the unexecuted local-worker response and returns immediately when saved Stop
prevents restoration. The BLE paths were tested with the frozen battery APK;
these later changes were host-verified.

- Native service was explicitly launched from the debug app UID while Flutter
  was absent. Lock state was not recorded at entry; the later window-policy
  capture showed the phone awake/unlocked. This launch is lab control, not autonomous
  wakeup evidence. Recording downloads stayed disabled throughout.
- Generation 108 received requested firmware `0.8.1` and hardware
  `watchdk@1/nrf5340/cpuapp`. Its initial run did not populate battery status.
  A synthetic notice was received/stored by the watch's notification manager;
  touch removed ID 1000004, but Android dismissal was not observed on that run.
  An injected battery event likewise did not reach the native snapshot. The
  cause was not isolated, and these failures are retained rather than treated
  as a pass. No transport-corruption investigation or firmware flash followed.
- After native Stop/install/restart, generation 111 acquired battery 87% via
  the optional standard GATT read before NUS writes and subsequently received
  firmware plus unsolicited voltage/charging status. NUS version/time/notification
  writes still completed. The ordinary app's existing cache workaround was not
  changed and Nordic SMP remains unchanged.
- New synthetic notification ID 1000005: watch `touch 200 95` closed it, the
  native service recorded one Android cancellation request, the listener's removal
  callback cleared the saved entry and a watch removal write completed. Flutter
  was absent. This is physical bidirectional notification behavior for that
  fixture, not an application ACK for AI-result delivery.
- Forced deep idle: `dumpsys battery unplug` and `deviceidle force-idle deep`
  reported `IDLE`. Ten seconds later, USB SMP injected a battery event (73%,
  charging) on the watch; its BLE status reached the existing native owner.
  Deep state remained `IDLE` and PID stayed 4243. No service-start command, app UI
  launch or AI job was issued during this receive test. This is forced idle with
  USB physically attached, not unplugged endurance or remote-network acceptance.
- Android idle/battery simulation was restored. Watch event state was restored
  to its previously measured 87%/not-charging baseline. All nine recordings
  remained and no recording was active.
- A subsequent injected Java crash changed PID 4243 → 4718. Generation 112
  reached Ready and refreshed firmware and battery/status metadata without UI.
  Sticky service, notification listener and CDM were active, so no single recovery
  mechanism is isolated. This does not prove low-memory reclaim or force-stop.
- Flutter was subsequently opened and displayed Ready, generation 112, firmware
  `0.8.1`, hardware and battery 87% from the native snapshot. Opening and closing
  the UI retained PID 4718 and generation 112; the service remained Ready after
  Back returned to the launcher. `flutter-ui.png` and attached/detached probes
  record this observation. This verifies the developer UI, not migration of the
  ordinary app's providers or database.

66 native JVM tests and 21 selected Flutter tests pass; focused Dart analysis
is clean. The new Dart worker's deterministic result contract was tested only on
the host and its Android classes compiled. The local fixture was never enabled;
no headless Dart worker, Whisper or LLM was started on the Nokia, as requested.
Actual local AI/worker testing is deferred to a suitable newer phone. Normal app
provider/DB migration, modern-Android coverage, long soak and iOS remain open.

Final cleanup explicitly stopped the native runtime (generation 113, service
absent, notification journal empty). Downloads and the local fixture remain
disabled; the existing synthetic remote result/outbox was preserved. Bluetooth
is on, deep idle is `ACTIVE`, battery simulation was reset and no ADB reverse
tunnel remains. The phone still has the frozen battery prototype installed;
the final host build was not installed over the physically tested artifact.

## Existing Flutter providers backed by native BLE — 2026-10-03

The shared connection/phase, watch-info and battery providers now have native
branches behind the prototype flag, along with the existing watch command
notifier. The developer view uses those providers. One EventChannel observer
serves them all; legacy BLE creation is guarded. This does not activate the
ordinary app's navigation, DB migration, model or startup-service graph.

Physical artifacts: `.companion-hil-runs/20261003-native-provider-ui/`.
Installed frozen APK SHA-256:
`a4976a22f3fb662dba3c71cc9049e8605f80956ce379bf49b6fed9e96c94edbe`.
An explicit app-UID Start reached Ready with UI absent (PID 5926, generation 114).
Flutter then displayed firmware `0.8.1`, hardware and battery 87% through the
existing providers. Connect/recover was pressed while Ready; generation and PID
remained unchanged. Back disposed the Flutter view, a single native attach/detach
was logged and the service stayed Ready at the same generation. The logs include
`legacy_bridges_skipped modelsNotLoaded=true`; no Dart worker was created.

Downloads remained paused. The local fixture flag is absent in the persisted
journal, meaning not enabled; the existing one synthetic remote result/outbox
remained unchanged. USB SMP status confirmed watchface, no active recording and
all nine recordings. No reset, firmware flash, recording mutation, AI or upload
was performed. Final explicit Stop reached generation 115 with the service absent.

Thirty selected Flutter tests pass, including six existing legacy watch-setup
tests. Provider tests cover one shared subscription, native-only commands,
observer cancellation, stale generation/error handling and actual UI rendering.
Focused analysis is clean; both prototype and normal debug APK builds pass.
The normal APK was compiled but not installed over the frozen prototype.
After the physical check, the developer view was also changed to clear its
readiness diagnostics on an observer error. This guard is covered by the widget
test and final host compilation; the phone retains the preceding frozen APK.
