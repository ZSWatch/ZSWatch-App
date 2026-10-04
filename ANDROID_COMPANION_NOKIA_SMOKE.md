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

## Native receipt status in the existing Voice Notes screen — 2026-10-03

Artifacts: `.companion-hil-runs/20261003-native-recording-view/`.
Installed/tested frozen APK SHA-256:
`5be6de5d63f5ade5c059a79f29f9e125f612c35f6c7f171b87f891b88e4c8dd9`.
This build opens a native receipt view through the existing `VoiceMemosScreen`
behind the prototype flag, bypassing legacy auto-sync/repository/transcription
startup. There is no synthetic DB row ID, audio import, playback or inference.

After install/explicit service Start, the first foreground observation still
showed Android Settings. MainActivity was explicitly reopened; this initial UI
launch behavior was not isolated as a recovery result. The bounded recording
test starts from observed Ready (PID 8347, generation 117).

The actual screen showed nine recording records: seven earlier saved receipts
and two earlier failed transfers. No new audio was downloaded. It also showed
the watch's fresh list count of nine and paused downloads. Screen navigation
retained PID/generation and shared the existing native observer.

Pressing Refresh returned a real BLE `voice_memo/list_result`; the native
`recording_list.observed_ms` advanced, count remained nine and generation stayed
117. Comparing complete recording dictionaries before/after confirmed that all
receipt metadata/states were unchanged and `recording_sync_enabled=false`.
The two failures were not retried or investigated. Logs include
`legacy_bridges_skipped modelsNotLoaded=true`, with no Dart sync-service,
WatchService creation or Dart worker execution observed.

Explicit app-UID Stop reached generation 118 with the service absent. The open
Voice Notes screen retained the nine records, displayed disconnected/saved
status, removed the current watch-list count and disabled Refresh. USB SMP status
confirmed watchface, no active recording and all nine watch originals. No reset,
flash, AI, upload or recording deletion occurred. The existing one synthetic
remote job/result outbox remained preserved; the local fixture was not enabled.

67 JVM tests and 53 selected Flutter tests pass; focused analysis is clean and
both normal/prototype debug builds compile. Native coverage includes repeated and
empty list observations preserving failures/receipts and paused policy. Flutter
coverage includes receipt identity/state validation, watch separation, ordinary
screen bypass of legacy/AI services and existing voice-memo recovery/sync tests.
These results do not establish new audio transfer, decoded-audio integrity,
Drift migration, real local/remote processing, watch-result application ACK,
modern-Android endurance or iOS behavior.

## Native notification settings in the existing Flutter screen — 2026-10-03

Artifacts: `.companion-hil-runs/20261003-native-notification-settings/`.
Installed/tested frozen APK SHA-256:
`e11425942a8c587eb6bc0b1a53d43168f8f0c898de2d3aac4502d3dd5cc6bfc4`.
The debug native branch of `NotificationSettingsScreen` controls the existing
service policy rather than creating Dart notification/WatchService instances.
Its catalogue shows active-notification apps, saved selections and ZSWatch;
permission grant and actual listener binding are distinct observations.

Opening settings retained stopped generation 118/PID 12018. The screen correctly
showed permission granted, listener connected and watch disconnected. Through
the actual controls, forwarding was disabled, only the ZSWatch selection was
removed/restored, and forwarding was re-enabled. Journal captures confirm the
allowlist went from `[com.zswatch.app]` to empty and back, without changing
running intent, generation or paused recording downloads. Other catalogue apps
were never selected. An enabled policy alone did not start BLE.

An explicit service Start then reached Ready at generation 119, with the same
PID. Refreshing the catalogue retained Ready, PID/generation and the synthetic-only
policy. Explicit Stop released the service at generation 120. All nine phone
receipt dictionaries were unchanged; the existing synthetic remote job and its
pending result remained preserved. The separate job journal had no enabled
local fixture. Persisted lifecycle events include
`legacy_bridges_skipped modelsNotLoaded=true`. USB status confirmed watchface,
no active recording and nine watch originals. No AI worker, model, new transfer,
reset, flash, upload or deletion ran.

The final build additionally disposes the status read when the screen closes,
so reopening re-reads current permission/catalogue metadata. Its installed frozen
APK SHA-256 is
`9d4c57ab30152dae0b16f958b50d4790d866864502e65de0fa91e7751fee4ea6`;
the complete policy-edit/live-refresh sequence above used the first APK.
The final APK was installed and its settings screen opened separately: PID
12939, generation 120, owner absent, permission/listener connected, only ZSWatch
selected and recording downloads still paused. This final open did not start BLE.

67 native tests and 60 selected Flutter tests pass; focused analysis is clean and
both normal/prototype APKs compile. New coverage checks versioned status decoding,
legacy-service guards, stopped-service edits, delayed native event delivery,
permission revocation/resume/reopening, settings-launch errors and preservation of selected
packages by the developer toggle. This is settings integration evidence; it does
not expand prior notification delivery or process-recovery acceptance, prove
personal-app notification filtering, migrate the legacy blocklist or activate
the full ordinary app navigation/startup tree.

## Existing Flutter app shell with native ownership — 2026-10-03

Artifacts: `.companion-hil-runs/20261003-native-app-shell/`.
Frozen installed APK SHA-256:
`6d81df629bde29549ea07bd67017f7254604f44920e73c063729c4b5f2cea254`.
The opt-in native build now opens `ZSWatchApp` with its existing theme and
dashboard, plus restricted native branches of start/settings. Flutter remains
the UI; the developer screen is reachable through Connection setup/Developer.
Normal debug/profile/release routing and eager service startup remain unchanged.

Cold app open retained the explicit Stop at generation 120, PID 14077, paused
downloads and the synthetic-only notification policy. Pressing the real home
Connect button started native BLE; an intermediate screenshot showed service
discovery, then the existing dashboard displayed Connected, MTU 247, firmware
0.8.1 and battery 87% at Ready generation 121. Notifications and Voice shortcuts
opened their native-backed screens without changing PID/generation. Voice Notes
showed all nine records, seven saved receipts, two earlier failed transfers and
paused downloads. No transfer was attempted.

Through the developer diagnostic, `Close UI and test in 15s` finished/removed the
Activity/task. Persisted events show task removal, UI detachment and Activity
destruction before the native notification write. After the timer, the service
was still Ready at PID 14077/generation 121 and the synthetic notice's delivered
revision/generation and transport write timestamp advanced. Android Settings was
foreground. This confirms native write completion with Flutter UI gone, not an
application receipt ACK or an OS process-death/Doze acceptance test.

Reopening the shell displayed the same session. The real dashboard Disconnect
then released the service and persisted Stop at generation 122. Closing and
reopening again retained stopped intent and did not issue Start. All nine phone
receipt dictionaries were unchanged, the synthetic job/outbox was preserved and
the separate job journal had no enabled local fixture. USB status confirmed nine
watch originals and no active recording; the synthetic popup was closed with
the existing `touch` command. An initial `input touch` command was rejected with
usage text and did not mutate recordings. No reset, flash, AI, new download,
upload or deletion ran.

40 selected Flutter tests pass, including five actual-app-shell integration
tests, existing native provider/client/settings/receipt tests and theme checks.
Guarded legacy BLE/reconnect/foreground/chat/AI/database providers were never
created during native startup, safe routing or resume. Tests cover permission
denial, Start acceptance versus Ready, Cancel/Disconnect, observer failure and
blocking unmigrated deep links. Focused analysis and both APK builds pass.
The previously passing 67 native tests cover unchanged native core sources;
they were not rerun for this Flutter-only change. Saved-watch DB/custom names,
scan/bonding, legacy preference migration, recording playback/import/processing,
media/GPS/HTTP/health/analytics/DFU and iOS remain outside this app-shell subset.

## Saved-watch metadata in the existing Flutter UI — 2026-10-03

Artifacts: `.companion-hil-runs/20261003-native-saved-watches/`.
Installed native APK SHA-256:
`c0d52c3430d4c019c0bf692c4784532cc3f6e722136cc4902da7b2f37dcf6311`.
The start screen reuses the ordinary saved-watch tile and rename dialog.
Names come from Drift; connection and live battery remain native observations.
Native database opening skips legacy unfinished-memo recovery. Schema 6 and
ordinary-build recovery behavior are unchanged. Rename writes only custom_name;
Forget/unpair is withheld. Saved Android MAC selection requires an explicit tap,
requests permission and cannot switch an active native owner.

Before install, the phone had no Flutter database. Opening the new native UI
created an empty schema-6 catalogue and retained Stop generation 122, PID 22568.
The real Connect button reached Ready generation 123 with the existing dashboard,
MTU 247, firmware 0.8.1 and battery 87%. Dashboard Disconnect persisted Stop
124. The already-stopped app was then force-stopped to close its database and
relaunched; new PID 23079 retained Stop 124 without starting BLE. This is a
stopped-app relaunch check, not recovery from process death during active BLE.

Private SQLite snapshots had identical logical contents before Connect and after
Stop (all watch/voice/action/chat tables empty). All nine native recording
records were unchanged, as was the separate synthetic job/result outbox;
local fixtures remained disabled, recording downloads paused and notification
selection limited to ZSWatch. USB status confirmed nine watch originals, no
active recording and the watchface. No model, audio transfer, reset, flash or
recording deletion ran.

73 targeted Flutter tests pass, including five new saved-watch checks: a real
file-backed schema-6 reopen preserving unfinished voice state while ordinary
recovery still works, column-only renaming and reactive metadata, alias ambiguity,
existing tile/dialog selection through the versioned bridge, and Android address
validation. Widget tests inject the saved catalogue; real SQLite preservation
and rename tests exercise Drift separately. Existing UI-shell tests inject an
empty catalogue and continue guarding against legacy BLE/AI startup. Focused
analysis and both debug APK builds pass; native Kotlin sources are unchanged.
Physical renamed/saved-row migration remains untested because this phone had no
old rows. Automatic saving of newly connected watches, discovery, coordinated
forget/unpair and recording import/playback/processing remain separate work.

## Automatic watch saving and ordinary saved-watch controls — 2026-10-03

Artifacts: `.companion-hil-runs/20261003-native-watch-autosave/`.
Installed native APK SHA-256:
`44b5fd0e14cab174a2f7b6040a64b70ed1d5848dddd2369d58b2da5a98cb88a7`.
The service commits optional `last_ready` address/generation/time metadata;
Flutter's app-lifetime projection saves it without acquiring BLE, changing
primary selection or invoking models. This selected-watch history survives Stop.
Old journals lacking it are not inferred from cached phase/version information.

Initial app open kept Stop 124, PID 23772, and the empty schema-6 watch catalogue.
The home Connect button reached Ready 125. SQLite showed one auto-saved row for
the test watch with firmware 0.8.1, hardware watchdk@1/nrf5340/cpuapp, cached
battery 87%, default name ZSWatch, no custom name, non-primary selection and
creation/last-connection times from native Ready. The real dashboard Disconnect
persisted Stop 126; the ordinary saved-watch tile then appeared.

The existing rename dialog had no Forget action. Saving temporary
CompanionLabWatch changed only custom_name in SQLite and retained Stop 126.
The already-stopped app was force-stopped and reopened, PID 24515: both start
header and saved tile showed that name while native intent remained stopped.
Selecting the saved tile explicitly reached Ready 127. Automatic persistence
kept the same ID, custom name, default name, primary flag, creation time and
capability flag; it advanced last_connected_at without inserting another row.
Dashboard Disconnect persisted Stop 128. The temporary name was restored through
the same dialog to ZSWatch (custom_name null) before the final relaunch.
Final PID 24884 retained Stop 128, one watch row and identical logical SQLite
contents across that reattachment.

These force-stops closed already-stopped apps for consistent SQLite snapshots;
they do not test OS recovery during active BLE. On every Ready the ordinary
dashboard displayed Connected, MTU 247, firmware 0.8.1 and battery 87%. Physical
SQLite integrity checks passed. Nine native recording dictionaries and the
separate synthetic job/result outbox were preserved, downloads stayed paused,
local fixtures disabled and notification selection limited to ZSWatch. USB status
confirmed nine originals, no active recording, unchanged free space and watchface.
No audio/model work, reset, flash, new upload or recording deletion ran.

82 targeted Flutter tests include eight new catalogue checks plus app-shell
historical-Ready integration. Real SQLite tests cover idempotence through actual
file reopen, no-op SQL updates, legacy-column/voice-state preservation, alias
ambiguity and stale observations. Serial-writer tests cover repeated events,
coalescing, retry and disposal; malformed/old Ready records cannot create rows.
69 native tests pass, including Ready-record persistence through Stop/reopen,
duplicate callback stability, generation fencing and new session/watch changes.
Focused analysis and both debug APK builds pass. This advances Android metadata
and UI integration only; it does not establish long-duration/modern-Android/iOS
acceptance or enable recording import/playback/processing, discovery or unpairing.


## Explicit offline recording import and playback — 2026-10-03

Artifacts: `.companion-hil-runs/20261003-native-recording-playback/`.
Final installed native APK SHA-256:
`795c626c417692a76acb2f5970f64740d9e2585e92a9ef2414a63dbbaa47a0e4`.
Native owner remains Stop generation 128; no BLE Start or recording-list refresh
was sent. Voice Notes displayed nine retained records / seven saved on phone.
Only the smallest existing committed receipt, `20261002_200103` (14,129 raw
bytes, 3,840 ms), was explicitly prepared. No audio contents were inspected or
uploaded, and no model/headless AI worker ran on this phone.

The dedicated schema-1 ledger contains exactly one immutable import. Raw receipt
size/hash/container validation passed; the playback derivative hash agrees with
the ledger. The schema-6 main database has identical logical contents and passes
SQLite integrity checks. All nine native recording dictionaries, all seven raw
SHA-256 values and the synthetic job/result outbox are unchanged. Downloads
remain paused and local fixtures disabled. No command touched the watch or its
original recordings; no reset, flash, transfer or deletion was needed.

The existing Flutter sheet loaded the local Ogg with a roughly four-second
Android duration and no autoplay. Explicit Play progressed to 0:01, then
completion paused/reset to 0:00. Closing releases the player. The prepared row
survived replacement/reopening with the final build and repeated preparation;
other recordings remained unprepared. The final preparation indicator clears
before the playback sheet opens. These observations exercise local decoding for
one existing receipt, not audio-quality acceptance across every recording.

145 targeted Flutter regressions pass. Import tests use real file-backed Drift
and SIGKILL actual Flutter workers at staged, published and committed boundaries,
then retry/reopen to one import. Coverage also includes conflicting source hashes,
filename collisions across watches, malformed/truncated/dirty containers,
symlinks, corrupt retained derivatives, no-op SQL retry and player/view disposal.
The pending-load/player fixture is a host simulation, not Android hardware.
Focused analysis is clean and both ordinary/native debug APKs compile.

This is explicit local playback integration. The dedicated ledger avoids changing
legacy voice-row identity or schema, but does not yet connect recordings to
transcription/action jobs. Retained interrupted stages, concurrency between Dart
runtimes, storage pressure, longer recordings, newer-Android background survival
and iOS are separate acceptance work. Already-stopped app force-stops here only
provided consistent SQLite snapshots; they do not test active BLE OS recovery.

## Android HTTP and shared lifecycle — 2026-10-03

Artifacts: `.companion-hil-runs/20261003-native-http-lifecycle/`.
Final installed frozen APK: `native-final-mtu.apk`, SHA-256
`be742c418d110695af2c67f7e786d046270f85bb927b53d6beda281c4c40c287`.
AI/model/headless processing and iOS were deferred. Flutter remains the existing
UI. Physical checks started only the native owner; Flutter was absent throughout.
Downloads stayed paused. No firmware reset, flash, SMP transfer, new recording,
watch-file deletion or model execution ran.

| Final APK scenario | Observation and limit |
| --- | --- |
| Initial Ready | Generation 146, negotiated ATT payload 244, fresh time and watch status/version. |
| Synthetic notification | ID 1000011 queued → ATT completion in 1,140 ms. Watch touch caused Android cancellation and listener removal of that ID. One fixture, not P95 or personal-app coverage. |
| Injected Java crash | PID 3070 → 3688, Ready 146 → 147 without Flutter or explicit Start; fresh time. Sticky service, listener and presence were active, so no single mechanism is isolated. |
| HTTP after crash | Fresh Trivia request, current-generation `written`, zero pending count; admission → committed completion 4.397 s. No UART HTTP timeout. |
| Incomplete frame | One metadata-only discard during the post-crash request; subsequent status and HTTP completion continued. This exercises resynchronization but does not locate the packet loss. |
| Forced deep idle | Deep state `IDLE` both before/after HTTP; same PID 3688/generation 147. Fresh `written`, zero pending, 3.053 s and no watch timeout. USB remained physically attached; this is not unplugged endurance. |
| Bluetooth off/on | Persisted disconnected state, then automatic Ready 150 without UI/Start; fresh time. Subsequent Trivia HTTP completed in 1.078 s with no watch timeout. |
| Explicit Stop | Generation 151, desired_running false, stopped, native owner absent and native notification count zero. Listener process remained alive; it is not the BLE owner. |

HTTP durations above come from native admission/completion journal events, not
an independent watch display timestamp. `written` means ATT completion. Trivia's
UART showed no timeout/consumer parse error, but no independent watch screenshot
or application receipt ACK was captured. The three requests used the real watch
consumer and remote API, not an injected phone-only relay fixture.

Earlier builds had repeated watch HTTP timeouts with no native admission, and
one temporary diagnostic build completed a request at generation 135. A later
build again stalled. These failures remain in the private evidence; the later
passes do not establish that every intermittent receive failure is fixed.
Code inspection found a shared weakness: an incomplete compact JSON frame could
buffer later traffic indefinitely. Newline-boundary recovery is host-tested and
was exercised by the final APK's discard marker. Source-packet integrity and
long-duration receive reliability remain separate acceptance work.

Ordinary native commands now use negotiated MTU, like HTTP replies. Before this
change, notification ID 1000010 took 7,433 ms with 20-byte writes; afterward the
fresh fixture took 1,140 ms and still dismissed correctly. Earlier touches were
premature or occurred with Trivia active. The later checks waited for a fresh
current-generation write before touching the watch on its watchface.

82 native JVM tests and 27 selected Flutter bridge/provider/app-shell tests pass.
Tests cover exact firmware bare-key framing, duplicate/late completions,
watchdog cancellation, connection fencing, actual HTTP status/body bounds and
relative redirects, XPath/DTD rejection, unsupported URL schemes, expired queued
writes, journal reopen after interrupted HTTP, and truncated frames followed by
HTTP/time/status. Both final debug variants compile. Fresh release manifest
merging excludes companion presence service/permissions and the debug network
policy; ordinary debug retains its loopback-only fixture policy.

A temporary account usage limit prevented approval review and delayed final
installation. Work resumed after the usage window reset; final installation,
physical checks and cleanup above subsequently completed through normal review.

Final native recording dictionaries exactly match the baseline: nine entries,
seven saved downloads and two earlier failures. The separate job/outbox journal
also matches exactly, with local fixtures disabled. USB status confirms watchface,
no active recording, nine originals and unchanged 9964 KB free space. Battery/
idle simulation was restored (`ACTIVE`, USB power restored), Bluetooth enabled,
and the native owner explicitly stopped. No transfer/integrity or AI claim is
added by these checks.

Repeat through the existing USB shell helpers: `power wake`, then `app state` /
`app close` until watchface, allowing the asynchronous close timer to run. Launch
`app launch Trivia` and capture UART for at least twelve seconds. Compare HTTP
markers after a pre-request cursor and require the current generation, terminal
outcome and zero pending count; retained `last_http` from an older generation is
not success. Close Trivia before notification-popup tests and wait for fresh
notification write completion before `touch 200 95`. Always unforce device idle
and reset battery simulation in a `finally` path. Preserve data with replacement
installs and verify frozen APK identity using `native_runtime_probe.py`.

Remaining: longer idle/reconnect runs, current-Android hardware, production
acceptance, migration of remaining Flutter feature controls, and watch-side
HTTP error/late-callback correctness. Fresh error/oversize/deadline cases have
host contracts; their complete watch-consumer outcomes remain unverified.


## HTTP policy through the existing Flutter UI — 2026-10-03

Artifacts: `.companion-hil-runs/20261003-native-http-settings/`.
Frozen APK `native.apk`, SHA-256
`bb4b973e645873a65dad03bd84ca3caee94abf8cd34fb50375e189f5e7a8f3a5`.
The existing Flutter Settings screen shows **Watch internet requests**, current
connection/pending state and the current-generation last outcome.

At Stop 153, Off and On persisted while running intent stayed false and the
native service stayed absent. Off survived force-stop/reopening of the already
stopped app. At Ready 154, a fresh Trivia request while Off completed as
`error_written` without UART timeout. After confirming the native policy was On,
a fresh request completed as `written` in 2.902 s, zero pending, no UART timeout.
An earlier attempted On tap used the stopped-layout position after the connected
layout expanded; the policy stayed Off and that request returned another error.
This retained observation is not an enabled-policy success.

The existing developer diagnostic **Close UI and test in 15s** then finished and
removed the Flutter Activity. Synthetic notification 1000012 completed in native
state with Flutter absent. A 15-minute forced deep-idle observation was started;
its outcome will be recorded separately after teardown. Downloads remain paused;
no AI, recording processing, SMP transfer or firmware change is involved.

84 native JVM, 41 selected Flutter and 42 companion harness tests pass; focused
Dart analysis is clean and both debug variants compile. The initial full harness
run lacked sandbox socket access; rerunning with loopback access passed. Updated
`native_runtime_probe.py` verifies the frozen installed APK and reports selected
current-generation status/HTTP metadata without content, retaining `NOT_RUN` as
its acceptance value.


## Fifteen-minute native-only deep-idle observation — 2026-10-03

Same HTTP-settings artifact as above: hash `bb4b973e…f3a5`, PID 7962, Ready 154.
The diagnostic finished/removed Flutter's Activity before forced idle. Across 31
samples at 30-second intervals (900.4 s), the live native service stayed Ready,
PID/generation stayed fixed, no Flutter Activity was present, and deep state was
`IDLE`. Selected current-generation watch status continued; its maximum sampled
age was 6306 ms. These are periodic watch events, not a silent BLE interval.

Delayed notification 1000012 completed after UI removal. A new fixture 1000013
queued/completed during idle in 896 ms. Touching the watch did not confirm its
cancellation in this run; do not inherit the previous shorter test's dismissal
pass. The final fresh Trivia request was admitted and got the relay's **Request
timed out** error at `error_written` (6.867 s), zero pending. UART confirmed the
error arrived without the watch's own HTTP timeout. Remote fetching therefore
did not pass this longer idle case. The installed firmware's error callback
limitation also remains. Android idle/battery simulation was restored afterward;
subsequent active-state HTTP after package replacement succeeded in 2.887 s.

The app was observed on the user Doze whitelist. This timeout does not alone
establish that Doze blocked the network: DNS/API latency and connectivity still
need controlled comparisons. Compare active/idle requests against a controlled
endpoint and verify network policy before changing permissions or exemptions.
USB stayed physically attached, so this is not unplugged/overnight battery or
modern-Android acceptance. No model, recording processing, transfer or firmware
change ran. All raw evidence stays private under the HTTP-settings artifact dir.


## Native boot and package-replacement recovery — 2026-10-03

Artifacts: `.companion-hil-runs/20261003-native-system-recovery/`.
Frozen final `native.apk`, SHA-256
`ff7846f385c5274d782779cfbb256c3d075a449602cc95ad30b33b6218ea213d`.
87 native JVM tests pass; both final ordinary/native debug variants compile.
No Flutter Activity or explicit Start was used in automatic recovery checks.

| Scenario | Observation and practical limit |
| --- | --- |
| Replacement while running | PID 7962 → 9371, Ready 154 → 155. Retained lifecycle events confirm actual `MY_PACKAGE_REPLACED` requested `RESTORE_SYSTEM` and the service accepted it. Fresh time/status followed. |
| HTTP after replacement | Fresh Trivia `written`, zero pending, 2.887 s, no UART HTTP timeout. Android power simulation was restored before this test. |
| Physical phone reboot | USB ADB exceeded the initial 120-second wait before returning. The normal secure PIN screen was unlocked, enabling credential storage. The first 60-second automatic-recovery window failed; a later bounded observation succeeded. Neither failed window is overwritten by the later pass. |
| Ordered boot delivery | Android enqueued BOOT at 20:37:29.269 local, dispatched at 20:37:29.753, finished at 20:39:11.008 (+1m41.255s). At the failed observation it was still in flight; the companion receiver was listed. Native retained events later confirm real `BOOT_COMPLETED` requested/accepted restoration. This demonstrates a substantial OS delivery delay on this phone. |
| Post-unlock Ready | New PID 4369, Ready 156, fresh time and current-generation watch status, Flutter absent. Native restoration happened automatically. This is eventual recovery, not immediate coverage during reboot/first unlock. |
| HTTP after reboot | Fresh Trivia `written`, zero pending, 3.429 s, no UART HTTP timeout. |
| Explicit Stop then replacement | Stop 157 remained unchanged after another replacement install. Handler logged `system_restore_skipped`; native BLE owner absent, native notification count zero, no UI/Start. Listener process remained alive. |

The package-replacement evidence script initially asserted markers from the last
500 logcat lines; that window had missed them. The automatic Ready had already
occurred. The bounded retained lifecycle journal proved request/acceptance; no
manual trigger or retry was substituted for the observed recovery.

Final native recording dictionaries and job/outbox journal exactly match the
pre-replacement baseline. Downloads remain paused and local fixture processing
stays disabled. USB confirms watchface, no active recording, nine originals and
9964 KB free space. Phone deep state is ACTIVE, power simulation restored,
Bluetooth enabled, and native owner deliberately stopped. No firmware reset,
flash, transfer, new recording or AI execution occurred.

Keep physical reboot, package replacement, framework crash and force-stop as
separate scenarios. The receiver is not direct-boot aware and does not access
credential storage before first unlock. Current-Android startup rules, repeated
recovery latency, OEM restrictions and longer unplugged endurance remain open.
The longer idle HTTP timeout above remains a separate failed remote-fetch case;
these later active-state passes do not resolve its cause.


## Native discovery and existing Flutter Add Watch — 2026-10-03

Private artifacts: `.companion-hil-runs/20261003-native-discovery/`.
Final installed `native-cancel-fix.apk`, SHA-256
`9b55cd388412ab88f438ea4f01807e5e4c021c30b7efc2e161cd0e92cc37fe2f`.
93 native JVM tests, 52 selected Flutter UI/client regressions and focused analysis
pass; both final ordinary/native debug APKs compile. Ordinary APK was not installed.

| Check | Observation |
| --- | --- |
| Initial native route | Opening Add Watch preserved Stop 157 and no owner. Android picker listed ZSWatch while CONNECT was granted and SCAN denied. |
| First cancellation | Predecessor `native.apk` (`42b0bb18…96da1`) preserved Stop but incorrectly displayed a generic error. An intermediate cancellation fix (`native-final.apk`, `f3a49b59…acd45`) still displayed that error in a prompt retest. Neither failure is replaced by the final pass. |
| Stop during picker | Predecessor picker opened from 157; explicit native Stop advanced to 158. Choosing the visible watch afterward stayed Stop 158, with no owner. Fresh selection subsequently reached Ready 159 and the existing Flutter dashboard. |
| Final cancellation fix | Android 12's ambiguous callback failure now briefly awaits the Activity cancellation result. Prompt Don't Allow on final APK returned quietly to Add Watch; Stop 160 unchanged, no owner, zero native notifications. |
| Final fresh selection | Explicit Find watch/system row selection reached live native Ready 161 without developer Start. Retained lifecycle confirms START_DISCOVERED accepted. Dashboard showed MTU 247, firmware 0.8.1 and battery 87%; fresh time/status followed. SCAN stayed denied. |
| Real HTTP | Fresh watch Trivia request was `written`, zero pending, about 2.8 s from admitted request to completion; UART reported no watch HTTP timeout. This active-state pass does not resolve the earlier long-idle remote-fetch timeout. |
| Flutter Disconnect | Existing dashboard Disconnect advanced to Stop 162; native owner absent, durable running intent false, notifications zero. |
| Preservation | Exact nine recording dictionaries and separate synthetic job/outbox journal match pre-test baseline. Downloads remain paused. USB confirms watchface, no recording, nine originals, 9964 KB free. No AI, transfer, firmware change or bond/association deletion ran. |

The Nokia already had its bond/OS association. Discovery proves explicit system
selection and native-owner handoff on API 31; it does not establish fresh bonding,
unpair, multiple-watch behavior or physical API 33+ callback compatibility.
Read-only probes report NOT_RUN for broad background acceptance: the bounded
observations above are not an overnight or current-Android production pass.

## Coordinated Forget contract — 2026-10-04

The native Android owner now accepts `forgetWatch` from the existing Flutter
settings dialog. For the selected watch it stops the owner and presence observer,
removes the public Android CompanionDeviceManager association and clears the
selected address/Ready projections. An old saved watch can be forgotten while
another watch stays connected. Durable per-address generation markers and a
command-specific receipt fence stale metadata and interrupted deletion/retry;
Flutter waits for any in-flight save and deletes the original Drift key/history.
Delayed presence events and pending pickers are fenced by the stopped intent
and generation. The public API
does not safely remove the Bluetooth bond across the supported Android range, so
the bond remains and can be reused by a later explicit pairing flow.

The Nokia association was deliberately preserved; no physical Forget action was
run. 108 native JVM and 105 companion Flutter tests pass; focused analysis is
clean and both debug APK variants compile. Native tests cover selected and other
watches, OS failure/retry and journal reopen; Flutter tests cover lowercase keys,
voice preservation and delayed-save/reattachment races.

Artifacts: `.companion-hil-runs/20261004-native-forget/`.
Native APK SHA-256 `372c736400feb48778380b7e4fe61759052a75cf4830d282776f83df626027a1`;
ordinary debug APK `b1777cb3da98d9dfe7837217d10e64dfe317bb38a1362e7b2433e4207d38bf31`.
The first UI dump immediately after launch returned no root; a later dump of the
same launched app succeeded. This was observation timing, not an install failure.

Physical Nokia/API 31 cancellation check: the existing saved-watch settings
opens the Forget confirmation with explicit companion-association removal,
saved-history deletion and Bluetooth-pairing preservation wording. Cancel then
closing settings returned to the saved watch without a command. Stop generation
170, nine native recording dictionaries, the complete separate job/outbox journal
and OS association entries match the baseline; no `watch_forgotten` event exists.
The frozen installed APK hash matches. The read-only probe confirms no native
service and stopped intent, with downloads still paused. Actual OS removal and
re-pairing were not performed; no recording transfer, model or firmware action ran.


## Service-owned Android media — 2026-10-03

Private evidence: `.companion-hil-runs/20261003-native-media/`.
Final installed `native-complete.apk`, SHA-256
`501e04623aafd58b7bfa7cb92116c6e7bffa3d4e6b31dc2d206e2b05088d5f92`.
102 native JVM, 53 selected Flutter and 44 harness tests pass; both final debug
variants compile and analysis is clean. Release manifest excludes the synthetic
service and debug media-playback permission. The first default-sandbox harness
run could not open localhost sockets; the authorized rerun passed all 44.

| Check | Evidence and limit |
| --- | --- |
| Predecessor native-only session | `native.apk` (`abe9dc1d…ff7e4`) Ready 163, Flutter Activity finished/removed through existing diagnostic. Real debug MediaSession produced native write completion. Watch center/next/previous touches produced fixture `watch_play`, `watch_pause`, `watch_next`, `watch_previous`. No audio was played. |
| Intermediate safeguard build | `native-final.apk` (`bc1a7c5a…f8368`) automatically restored Ready 164 after replacement without Flutter/Start and published current media. All four watch controls reached fixture callbacks. Stop 165 followed by a late watch tap left fixture sequence and native media write unchanged. |
| Complete build | Replacement while stopped retained Stop 165. Explicit lab Start reached Ready 166; same-track album change produced a fresh media write without Flutter. The final metadata callback includes album/duration changes despite legacy title/artist deduplication. |
| Radio workflow interruption | Nokia killed `svc bluetooth disable` with 137 after radio changed to enabled=false/BLE_ON and native 168/disconnected. The script ended before its planned offline metadata mutation. `svc bluetooth enable` also exited 137; later authoritative state was enabled=true/ON and Ready 169 with current-generation media write. Do not describe the unexecuted offline mutation as passed. |
| After radio recovery | Final watch play/pause produced corresponding real fixture callbacks and accepted native controls at generation 169 with Flutter absent. |
| Permission loss/restoration | Temporary notification-listener revocation blocked a watch control: fixture unchanged, accepted=false, BLE remained Ready 169. Access was restored in finally; a later watch pause reached the fixture and accepted=true. |
| Other shared work | Fresh Trivia HTTP after media/radio recovery completed `written`, zero pending, about 4.0 s, no UART watch HTTP timeout. This active-state pass does not resolve the earlier long-idle timeout. Fresh watch status/time remained visible in the native-only probe. |
| Cleanup | Fixture explicitly stopped/released, native Stop 170, no owner and zero native notifications. Current probe hides historical media receipts while stopped. Notification access restored and Bluetooth ON. Watchface, no recording, nine originals and 9964 KB free. Exact nine recording dictionaries and separate job/outbox journal match baseline; downloads paused and local fixture disabled. No media titles appear in the native journal. |

Reproduce using the opt-in native debug APK and the existing Flutter Connect
control, or an explicitly labelled lab Start. The private fixture component is
`com.zswatch.app/dev.zswatch.app.companion.CompanionMediaFixtureService`.
Use `adb shell run-as com.zswatch.app /system/bin/am start-foreground-service --user 0
-n <component> -a START`; subsequent `startservice` actions are PLAY, PAUSE, NEXT,
PREVIOUS, METADATA and STOP. METADATA changes only the synthetic album; journal
`files/companion-media-fixture/state-v1.json` carries fixed synthetic state/callback
counters. Always STOP/release it after the bounded test. It is not a player or
background acceptance scheduler and introduces no local AI.

Use USB shell `power wake`, close any prior app until `app state` reports watchface,
then `app launch Music`. On this installed 240×240 firmware, `touch 120 120` is
play/pause, `touch 185 120` next and `touch 55 120` previous. These positions were
confirmed by the real fixture callbacks; source layouts or successful shell
returns alone do not prove an action. The USB shell helpers use the existing SMP
client in `watch_file_probe.py`; calling its full `probe` would write a file and
is unnecessary here. No firmware instrumentation/flash is needed for this check.

Native `last_media_write` proves ATT completion, not track rendering or a watch
application ACK. Control acceptance means Android dispatched to the controller;
the synthetic callback provides separate evidence of receipt. Third-party music
apps, volume effects, session selection, display details, modern Android and
longer unplugged operation remain separate acceptance work.


## Native GPS request and permission boundary — 2026-10-04

Private evidence: `.companion-hil-runs/20261004-native-gps/`.
Initial `native.apk` SHA-256
`48d54cb0cd6006794fff38904b5262f5c1c701a1a66cb6a9e9f9715f28a06d94`.
Final installed `native-final.apk` (accessible switch label) SHA-256
`68e723c92e7cc6590324f7200f9fa23d13d1baff11e7668a72432a5101afcf13`.
Final ordinary APK SHA-256
`4e5acd037e7f98cb4b4930d976e2fe989785dfd2f087df2923cf99a96fb46ddf`.
118 native JVM / 111 companion Flutter tests pass, focused analysis clean and both
final debug variants compile. Ten native GPS tests include foreground rejection,
synchronous-source cleanup, late callbacks and queue/fix deadlines. Six Flutter
tests cover opt-in cancellation, permission denial, committed policy and no legacy
BLE/location ownership.

| Check | Observation and limit |
| --- | --- |
| Existing Flutter Settings | Watch location defaults off. Disclosure Cancel kept Stop 170 and sharing absent/off, with no permission grant or Start. |
| OS permission flow | Explicit Continue requested Android foreground access, then opened the all-time location page. Approximate was selected: coarse/background granted, fine denied. The permission activity was missing from UIAutomator's tree; focused activity plus screenshot confirmed the actual prompt. No plugin-stall conclusion is warranted. |
| Policy only | The accepted switch showed waiting for a request; journal sharing=true while Stop 170 and desired_running=false remained. Permission/policy do not Start BLE. |
| Existing Connect | Explicit Flutter Connect reached Ready 171. Downloads remained paused. |
| Periodic watch request | Existing periodic firmware behavior sent a request while connected. Journal recorded acquiring followed by location_unavailable about ten seconds later. No last_gps_write was created; no fresh position was delivered. This is first-fix failure/release evidence, not Weather success. |
| Sharing off / UI closed | Flutter switch committed sharing=false/disabled while Ready 171 continued. Existing diagnostic finished/removed the Flutter Activity; read-only APK-matched probe retained Ready and current watch status with launcher resumed. Synthetic delayed notification forwarded separately. |
| Real Weather launch | Not executed. Automatic approval review rejected the combined launch/capture command because real phone location would go to the watch and Open-Meteo endpoint without explicit destination-specific authorization. The user question is pending. No bypass or synthetic-as-real acceptance was used. |
| Cleanup/final APK | Native Stop 172 persisted, no owner/notifications, sharing off, all phone location grants revoked to the original baseline, downloads paused. Final APK replacement retained Stop. All nine recording dictionaries and the full separate job/outbox journal exactly equal the baseline. `last_gps_write` remains absent. Watch stayed on watchface and no recording/transfer/AI/firmware action ran. |

For later real acceptance, get explicit approval to transmit location, enable
sharing through Flutter and grant approximate or precise plus all-time access.
Use explicit Connect, finish/remove Flutter through the existing diagnostic, then
USB `power wake`, confirm `app state` is watchface and `app launch Weather`.
Capture native acquiring/write/release and HTTP outcome together with watch UART
consumer logs; keep coordinate-bearing logs private. The controller and watchdog
may time out indoors. A fresh fix reaching the actual consumer and a successful
Weather response are separate assertions; cached watch weather, ATT completion or
pure synthetic fixes do not establish them. Always close Weather, disable sharing,
Stop and restore temporary phone settings afterward.


## Service-owned Find Watch — 2026-10-04

Private evidence: `.companion-hil-runs/20261004-native-find/`.
Installed native APK SHA-256
`fb3211a329410c78ae530e6fb6dc15f9143b9cd1b430d116be2c1b1efac2346d`;
ordinary APK `f8d556b57894f35c3b397105e720dacae297513a412867a066268b20c8129e62`.
127 native JVM and 115 companion Flutter tests pass; analysis clean, both builds
compile. Source uses the existing Boolean `find` protocol; no SMP, model or
firmware change is involved.

Replaced the stopped native APK preserving Stop 172/data, then explicit existing
Flutter Connect reached Ready 173. The existing dashboard exposed Find watch.
Tapped it at the observed button coordinates and immediately sent the phone to
Home. The watch UART independently logged `find=true` at watch uptime
26:18:50.699 and `find=false` at 26:18:53.670. Native acceptance/start-written/
stop-written events were recorded at the same generation. Start-written to
stop-written was about 2.95 s: the timer is two seconds plus BLE/queue delivery,
not an exact two-second motor-duration promise. Final native state was
stop_written/Ready and Android's launcher was resumed. This demonstrates watch
parser consumption; no tactile motor measurement was made. The Flutter Activity
was backgrounded, not destroyed, for this physical burst. Widget disposal and
stale callbacks have separate deterministic tests.

Only after false consumption did cleanup issue native Stop. The immediate stopped
probe raced asynchronous Android service teardown and rejected its first read;
the later identical read-only check verified Stop 174 with no service/notifications
and the installed hash. Sharing remains off, all location grants remain denied,
downloads remain paused, all nine recording dictionaries and the full job/outbox
journal exactly equal baseline. Watch is on watchface, no recording and 9964 KB
free. No watch data was created/deleted.

The firmware has no Find disconnect or maximum-duration failsafe. Physical crash,
radio loss or Stop mid-burst were deliberately not claimed/tested. Add the firmware
safeguard and verify those paths before rollout. Recovery false is best effort and
only for a matching unfinished prior find receipt; normal reconnect does not stop
unrelated watch vibration. Real Weather/location acceptance still awaits the
separate explicit location-transmission approval.


Final timer/artifact follow-up: stop/watchdog scheduling was moved before
optional diagnostic observations; a new failure-injection test brings native
coverage to 127. An early copy accidentally installed the ordinary artifact.
A later candidate (`2e3ba559…56f01`) had native Flutter UI with compiled Android
flag=false/no bridge, producing a loading screen and MissingPluginException.
It was rejected; journal Stop 174 and all recordings/jobs stayed unchanged.
The native gate discrepancy beyond the first copy mistake was not diagnosed to
a specific compiler/cache cause. Do not label that candidate a passed native build.

A fresh frozen `native-flag-check.apk`/corrected `native-final.apk`, SHA-256
`f987b6fe4540ca4c5f2cee0f29325c2d2c2f080d06d71e8c1ecc2e724e070977`, has
compiled flag=true and native MainActivity bridge construction. Final ordinary
APK SHA-256 `30164352bce267b64ef77bc8a178dc7e7d9232cf3bc67f62dddab5b79009f37f`
has flag=false/no bridge. The new read-only APK verifier independently passes
both intended modes and rejects the retained mismatched artifact. Corrected native
replacement opens the existing disconnected Flutter view, installed hash matches,
no service and Stop 174 remain, and exact recordings/jobs/policies still match
baseline. The physical burst above used the earlier `fb3211a3…2346d` artifact;
the final safeguard has host tests plus physical owner/UI/retention verification,
not a repeated physical burst. Capture evidence is retained privately, including
the rejected candidate, rather than replacing failure evidence with a pass.

## Watch-side Find protection and interrupted bursts — 2026-10-04

Firmware source change: ZSWatch commit `d404e5d7`. Private evidence is under
`.companion-hil-runs/20261004-find-firmware/`. Nokia keeps the verified final
native APK `f987b6fe…070977`; no new app build was needed for this firmware work.
The complete pairing-enforced WatchDK revision 1 build passed, as did the host
Find controller and existing clock/timezone tests. Signed application HEX SHA-256:
`07a3bca1b9eaa0783dfc974ab44b961bb1e2ff9a7965f3207b15dd4c9aeb2689`;
ELF SHA-256:
`93cfc6041a267791c15e2069f9bda053420bd1d21ca8a6780db394041cbc6680`.

Before flash, nine recordings and `/lvgl_lfs/coredump.txt` were backed up through
the existing serial SMP library. Read-only image metadata matched hash TLVs in
the debugger-read rollback images. The archived config/layout matched the prior
WatchDK build. Exact debugger 51022722 programmed/verified only signed app ranges:
internal `[0x10000,0xdbfc8)` and mapped QSPI `[0x10120000,0x101959e8)`, rounding
erase to 4 KiB within their application partitions. No bootloader/network/settings
or user-storage erase ran. The full merged HEX was not used. The current firmware
checkout also includes the previous UTC/timezone changes and unrelated existing
source state; archived source/diff/submodule metadata makes that build scope clear.

The initial USB keepalive failed during startup; a separate authorized reset
reached SMP and the normal watchface. This is retained as a failed initial probe.
An unnecessary full QSPI backup read was cancelled and replaced with a bounded
read through offset 0x220000. Nordic BIN output included a large padded tail;
only explicitly read code/register/application bytes were kept. These backup
operations did not erase flash. Final verification used another reset after the
native owner was stopped and retained USB across its twenty-second boot guard.

| Check | Observation and limit |
| --- | --- |
| Pairing and ordinary Find | Existing Flutter Connect reached Ready 175 without re-pairing. Normal true/false worked with the phone on Home. |
| App suspended before false | UART true at watch uptime 00:02:24.826110; SIGSTOP suspended the app's existing PID 31292. Watch-owned maximum-duration stop at 00:02:34.826110, exactly 10.000 s. SIGCONT after twelve seconds allowed delayed false at 00:02:38.190429. Same PID/generation stayed Ready. This is suspension, not process death or recovery. |
| Disconnect mid-burst | True at 00:02:55.021270; explicit Flutter Disconnect produced BLE disconnect at 00:02:57.495941 and Find stop at 00:02:57.495971. No false consumer preceded that stop in this capture. |
| Fresh burst after recovery | Explicit reconnect reached Ready 177. True 00:04:06.302734 → false 00:04:09.272338, about 2.970 s. Both the watch consumer and current native stop receipt are present. |
| Notification after cleanup | Existing Close UI/test diagnostic finished and removed Flutter Activity. Delayed synthetic notification 1000016 reached the watch notification manager and native delivered revision 1/generation 177. Read-only probe retained Ready and launcher resumed. Physical haptic/display effects were not measured. |
| Final baseline | Explicit Stop 178, no native owner/notifications, sharing off and downloads paused. Nine originals, 9964 KB free, no recording and watchface after final reset. All nine original file hashes and the preexisting crash file hash exactly match their preflash backups. Separate job/outbox remains structurally consistent. |

To reproduce interrupted Find, first verify the installed native APK, Ready,
paused downloads and sharing off. Capture UART exclusively at 115200 with DTR/RTS
false. Tap the actual dashboard Find control; wait for the watch's true log before
SIGSTOP of that exact app PID. Always SIGCONT in finally, wait for delayed false,
then observe Ready. For the disconnect case, tap the real Flutter Disconnect
after true, verify the watch's disconnect/stop logs, reconnect and run a normal
burst. Restore Stop afterward. Do not use transfer instrumentation or count a
successful command/ATT write as the watch stop. Direct motor measurement remains
a separate acceptance gate; broad background probes retain `NOT_RUN`.

## Fixed HTTP active/idle comparison — 2026-10-04

Private artifacts: `.companion-hil-runs/20261004-native-http-comparison/`.
The installed native APK remained `f987b6fe…070977`; Ready 179/PID 31292.
The pairing-enforced WatchDK build adds a default-off `ZSW_COMPANION_HTTP_PROBE`
flag and fixed `http_probe loopback|remote` shell control using the existing
HTTP relay. Only signed application ranges were programmed/verified on exact
debugger 51022722. Bootloader/network/settings/storage were excluded; source,
config/layout/images and the prior Find rollback artifact are archived.

| Scenario | Result |
| --- | --- |
| Foreground and Flutter-removed active loopback | Both fixed 35-byte replies reached the watch callback; native `written`, zero pending. |
| Initial remote request | Active and background errors occurred with Wi-Fi off and no default network. These are not evidence of background-service failure. |
| Wi-Fi-enabled active remote | Watch callback status OK/220 bytes about 9.585 s after admission, while the native journal records `delivery_expired`. Retain both facts; this is not a native delivery pass. |
| Initial forced deep idle loopback | Watch callback OK/35 bytes about 2.116 s; native `written`. |
| Fifteen-minute idle window | 900.000 s, 31 read-only samples, same Ready/PID/generation, Flutter Activity absent, deep state IDLE. Watch status continued periodically; no process restart or fully silent link was exercised. |
| Final idle loopback | Watch callback OK/35 bytes about 2.373 s; native `written`, zero pending. |
| Final idle remote | Native `error_written`; watch received request-timeout error about 8.878 s after admission. No success callback is claimed. Owner stayed Ready, zero pending. |

The fixture recorded four local responses and stopped cleanly. ADB reverse was
removed; Wi-Fi was restored to its original disabled state, simulated battery
unplug was reset and forced idle was released. Downloads stayed paused and
location sharing off. Subsequent read-only observation at 07:09 UTC still found
the same live Ready 179/PID 31292, but Flutter had been reopened: this later
observation is not a continuously monitored seven-hour background soak. Explicit
debug cleanup then verified Stop 180 before the next APK installation.

This isolates working local relay/BLE in the bounded idle case from remote
network/deadline failure. USB stayed attached, ADB reverse bypasses external
network access and an active Wi-Fi reply was already late. The old idle timeout,
modern Android/unplugged operation and firmware HTTP error/late-result consumers
remain open. Do not extend HTTP microdiagnosis at the expense of feature migration.

## Existing Flutter Shell through the native Nordic owner — 2026-10-04

Private artifacts: `.companion-hil-runs/20261004-native-shell/`.
145 native JVM / 123 companion Flutter tests pass, focused analysis is clean,
and both final debug APKs compile and pass compiled-owner checks. No source or
working changes in the user's Flutter/Nordic fork were altered. Shell uses the
same Nordic 2.7.2 transport factory as existing native recording work and the
existing fork's ShellManager exec contract. No custom SMP protocol was added.

| Check | Observation and limit |
| --- | --- |
| Initial cold enable | First APK `ee052aa2…24f2` reached Ready 181. Watch SMP enable changed services, existing native recovery cancelled the command and reached Ready 182. Explicit retry returned real Power Status. Retain this failed first-command behavior. |
| Preparation/UI trials | Preparation permits one recovery before accepting a command. An earlier UI removed its Quick Action during disconnect; a real-widget regression now retains it. NUS-service-list readiness in `8814b6fa…c137` timed out despite watch SMP enable/Ready 192; it was replaced with Nordic SDK readiness. These trials are not overwritten by the final pass. |
| Nordic cold command | APK `f11b77c3ab6fef1d9a7f4a205d112763dd3f5f6665496bce47e185ffbd12876c` starts Ready 195 with watch BLE FOTA/SMP independently verified disabled via USB. One Power Status tap completed preparation/recovery to Ready 196, then displayed actual Power Status/uptime 28219 seconds. No manual command retry. |
| CPU after expiry | A subsequent CPU tap started after idle cleanup on Ready 197 and recovered to 198. The app was on Home during part of preparation, reopened while still loading, and later showed `CPU frequency profile: slow`. This does not prove execution completed with Flutter absent. |
| Timed command burst/Home | Fresh Power Status returned uptime 28700 seconds. Immediate CPU reused the SDK lease; read-only state remained Ready 200 before/after. The launcher was resumed during the five-second Home window, and CPU output was visible after reopening. There is no native completion timestamp here: claim foreground absence and retained result, not physical engine destruction or precise reply-arrival time. |
| Idle cleanup | Later USB `ble_fota status` independently verified disabled. Read-only state verified live Ready 201, same installed SDK APK, fresh watch status/time and paused downloads. Native recovery after dynamic service removal remained functional. The short UART lease capture contained only two bytes and provides no additional cleanup evidence. |
| Stop/preservation | Explicit app-UID debug Stop verified generation 202, no service/native notifications and desired intent=false. All nine originals plus the existing crash file match the pre-HTTP firmware backup hashes. Jobs/outbox remain structurally consistent. |
| Final installed build | `native-lease-final.apk`, SHA-256 `6c839a74a3fab378a1253560b58d49e1595ca2c9d130a92cea7043c4636d772f`, adds the idle guard for active preparation. Its native tests/build/owner check pass; replacement and UI opening preserve Stop 202 and installed hash. Cold/burst runs above used the immediately preceding SDK APK, not this final guard. Ordinary final APK `8dfcc613b35a0b8d31506dde6996608cab691778e53693e1d6ddb987b8feacf7` retains Flutter ownership. |

To reproduce, verify the frozen APK's compiled/installed owner and current Ready.
Keep downloads paused and sharing off. Open Developer → Shell → Quick Actions;
verify watch BLE FOTA/SMP disabled through the separate USB control path before
one read-only Power Status tap. Wait for the actual UI reply, not merely Ready.
For the command-burst scenario, invoke CPU promptly after Power completion;
record generations and foreground Activity. Source recordings remain untouched.
Use a fresh exclusive UART collector for the whole scenario; absence of UART
bytes is not a pass. After twenty seconds of inactivity, verify actual watch SMP
status and live native recovery, then restore and independently verify Stop.

Physical Flutter engine destruction, SDK failures during preparation/idle cleanup,
large monitor replies and simultaneous file/DFU operations remain acceptance work.
The final cleanup guard prevents an expired lease from releasing an SDK connection
while preparation is active. Real Weather still requires the separate location
approval; AI/iOS and transfer-corruption investigation remain deferred.
