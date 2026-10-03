# Native Android job recovery prototype

2026-10-03. The debug companion service now has a mobile adapter for the shared
[remote-job contract](REMOTE_JOB_RECOVERY_CONTRACT.md). It is a synthetic
metadata/results experiment. It does not open, upload, transcribe or delete any
recording, initialize a model, execute actions, or change the normal Flutter/Drift
voice-memo pipeline. The service-owned BLE experiment remains behind
`COMPANION_RUNTIME_PROTOTYPE=true`.

## Ownership and durability

`PrototypeJobs` uses a separate private journal under
`files/companion-prototype/jobs/state-v1.json`. Claims, lease deadlines, fencing
tokens, backend/generation and remote IDs persist. Result and delivery outbox
share one flushed temporary-file rename. A callback checks its current fence and
lease at response time; cancellation/new generation invalidate older callbacks
and pending outboxes. Matching watch/result application ACK is required for
Delivered. ATT completion and UI event ACK never imply delivery.

The job journal uses the existing native serialized worker and atomic-file store,
not the Python reference's SQLite or the app's Drift DB. Its concurrency guarantee
is one app process/serialized owner, not arbitrary processes sharing a file. The
prototype bounds jobs at 100, result JSON at 64 KiB and response bodies at 128 KiB.
Flushed rename proves the tested process-interruption boundary, not full device
power-loss durability. Committed JSON is reparsed to prevent caller-owned mutable
JSON from changing authoritative in-memory state without a commit.

The native adapter uses a separate network executor, 3-second connect/read
timeouts and a 5-second in-process service tick. Persisted poll/retry deadlines,
30-second claims, five-failure budget, bounded backoff and numeric Retry-After
are applied. Server `running` responses do not consume failure budget. HTTP
401/403 block for explicit credential refresh; local jobs are never silently sent
to the remote driver. Core local jobs use the same result/outbox shape but no
local inference is implemented here. Job/request content is excluded from new logs
and UI snapshots. Corrupt/unsupported job data disables that fixture worker and
preserves BLE; it is not reset or silently discarded.

This tick requires the process/service to be executing. It is not an OS wakeup
guarantee, iOS scheduler, Doze exemption or durable HTTP-transfer registration.
Explicit Stop pauses fixture work and closes network/BLE handles; pending job
results remain for a later intentional runtime start. UTC deadlines still need
controlled rebasing for large system clock adjustments before production. Native
integers are signed 64-bit; the fixture envelopes fit that bound.

## Synthetic backend boundary

The driver accepts only the bundled `job-v1.json`, provider `loopback-fixture`,
remote backend and its explicit synthetic authorization flag. Its endpoint is
fixed to `http://127.0.0.1:8765`; redirects are disabled. Cleartext is enabled for
that IP only in the debug network-security configuration. Release/profile disable
the runtime and release has no fixture assets/network policy/presence components.
No credentials or arbitrary backend URL are accepted by the bridge.

`startRemoteFixture` creates/resumes the same synthetic generation; repeated
starts do not create a new backend job. The development UI displays state-only
job summaries. A non-exported debug service action supports explicit app-UID lab
launches with the phone locked; those launches are not autonomous wakeup evidence.

There is no real watch delivery from this fixture. Its watch ID is `fixture-watch`,
and the current firmware lacks the required versioned result receipt ACK and
persistent deduplication. A result stays `result_ready` with an outbox entry. The
JVM golden trace uses a fake persisted receiver for lost-ACK testing; that receiver
is not evidence about current firmware. Real recording import, provider-specific
idempotency, upload authorization/revocation, OS workers/background URLSession,
models, firmware negotiation, retention and action execution remain later work.

## Verified behavior

- Eight native job tests include the shared 13-step trace, cross-language Unicode
  identities, lease reclamation, late response rejection, cancel/new generation,
  credential blocking, local/remote separation, ACK identity, mutable JSON aliases
  and malformed collection rejection. The trace's server/receiver are fakes.
- Physical Nokia/API 31 against the existing Python loopback server: accept then
  drop response produced persisted transport backoff; retry reunited with one
  server job and saved its remote ID. Flutter was never launched.
- Injected Java crash while waiting changed PID 29923 to 30758. The fixture server
  completed during that interruption, before native service recreation. The
  service recovered and atomically published the golden result/outbox without UI.
- A second crash changed PID to 30976. Job journal/cursor 17 and canonical result
  payload remained byte-for-byte equivalent; the server still held one job.
- A separate final APK injected an unsupported version into the backed-up
  synthetic journal. The native job worker failed closed while BLE remained Ready
  at generation 106. The original result/outbox was restored, the runtime stopped
  at generation 107, and the installed hash was checked.

This is USB-attached Android process/service recovery using injected crashes,
not low-memory termination, force-stop, unplugged Doze, actual audio upload, LLM
execution, physical watch ACK or iOS acceptance. Notification-listener, sticky
service and CDM were active; one recovery mechanism is not isolated.

57 native tests, 16 Flutter bridge/UI tests and 40 HIL/reference/probe tests pass.
Focused analysis, normal/prototype debug APK builds and release-manifest isolation
checks pass. Evidence is private/ignored under
`.companion-hil-runs/20261003-native-remote-jobs/`. Initial HTTP/crash APK SHA-256:
`33b3a0870c5928be85f8789eceec7ed9a324ba528926cd6430bf847dda6f0b11`;
final isolation APK:
`8d3999fe6494ad8f2288f365c49a8b5ebbc930381ae3e0fc500baf675e7328cd`.
The final source additionally has an indentation-only cleanup. No watch firmware
was flashed and all nine recordings remain. The fixture server is stopped and
the temporary ADB reverse mapping removed.

## Reproduce

Use a new fixture-server state directory and a frozen prototype APK. Existing
synthetic terminal results require a fresh isolated lab job journal for a new
scenario; back up evidence first and do not clear any production/app database.

```bash
PYTHONPATH=scripts/companion_hil python3 -m remote_jobs.server \
  --state-dir /tmp/new-zswatch-fixture-server --port 8765
adb -s A00000V791290707484 reverse tcp:8765 tcp:8765
```

Start the debug runtime through the foreground UI with recording downloads paused.
Choose `Start synthetic remote job`. The fixed job can also be explicitly started
from the app UID after that runtime is running:

```bash
adb -s A00000V791290707484 shell run-as com.zswatch.app /system/bin/am \
  startservice --user 0 -n com.zswatch.app/dev.zswatch.app.companion.CompanionPrototypeService \
  -a dev.zswatch.app.companion.START_REMOTE_FIXTURE
python3 scripts/companion_hil/native_runtime_probe.py \
  --adb /home/jakkra/Android/Sdk/platform-tools/adb \
  --android-serial A00000V791290707484 --jobs \
  --output /tmp/new-native-job-observation.json
```

The reference server's documented fault/complete controls drive metadata-only
scenarios. Observe committed native deadlines/results, correlate process/UI
lifecycle and preserve exact APK provenance. Finish with explicit Stop, verify
it, remove `adb reverse --remove tcp:8765`, and stop the fixture server.
