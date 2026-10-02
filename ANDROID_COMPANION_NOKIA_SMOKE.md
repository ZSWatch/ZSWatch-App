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
protocol uses two Android GATT owners (NUS and Nordic MCUmgr); a single-owner
transfer experiment and repeated byte comparisons are still needed.

The experimental APK, source copies, native test log, probe output, UART/logcat
and hash-only comparison records are kept locally under
`.companion-hil-runs/20261002-native-chunk-trace/`,
`.companion-hil-runs/20261002-native-packet-trace/` and
`.companion-hil-runs/20261002-native-timeout-trial/`. Host test results are 34
passing native JVM tests. Transfer acceptance remains unmet.

## Next physical work

1. Compare a single-owner GATT transport against Nordic MCUmgr, then repeat the
   failed files. Preserve hash-only traces and check whether returned packet
   hashes match contiguous source ranges; do not publish until whole-file hashes
   and containers pass. The 10-second chunk timeout fixes some waiting but not
   the observed body corruption.
2. Once transfers work, repeat the failed batch and isolated screen-off cases,
   then record after task removal. Require byte comparisons after completion;
   include multiple pending files and interrupted SMP. Keep the original failed
   trials as baseline evidence.
3. Investigate the idle-service stop against the running Android build. Evaluate
   the planned CompanionDeviceManager association/presence recovery path; repeat
   with a genuine process-reclamation scenario when a reliable kill mechanism is
   available. Keep injected crashes and explicit user recovery separately labelled.
4. Run the ordinary Flutter-app baseline, notification forwarding, Stop,
   permissions/radio changes and network jobs. Repeat unplugged idle/Doze and
   longer recordings before the planned soak tests. iOS still requires a Mac/iPhone.

Neither a foreground-service migration nor rewriting the UI in native code is
approved by these results. The prototype remains behind its debug flag.
