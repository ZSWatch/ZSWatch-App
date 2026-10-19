# Service-owned Dart processing worker

2026-10-03. A small headless Flutter worker is implemented behind the existing
Android debug prototype flag. Its purpose is to evaluate reusing Dart processing
code while Android owns the companion connection and job journal. It does not
replace the native BLE owner or start the normal app UI/provider graph.

The service's `PrototypeLocalFixture` claims a local job from the same durable
`PrototypeJobs` contract used by the remote adapter. It creates a `FlutterEngine`
on Android's main thread and executes `companionWorkerMain`, without attaching an
Activity or rendering surface. Only the existing path-provider plugin is
registered. The worker returns a deterministic fixture result after 15 seconds;
native code checks the job identity/lease, validates the result and commits the
result/outbox. Native ownership also handles timeout, Stop and engine destruction.
Process interruption leaves the saved claim available for reclamation after its
60-second lease. A completed fixture remains pending watch delivery, as with the
remote fixture; it never implies an application receipt ACK.

The entry point does not create `WatchService`, a BLE plugin, Riverpod providers,
Drift, Whisper, an LLM or external actions. Local and remote jobs have separate
providers and recording identities; local jobs are not routed to the HTTP driver.
`startLocalFixture` is an explicit bridge/developer UI command and non-exported
app-UID service action. Mere service startup does not create an engine. The normal
app and profile/release continue to use their existing runtime selection.

This is an execution seam and fixture, **not integration of the existing STT/LLM
models yet**. Three host Dart contract tests pass and the Android integration
compiles. Actual headless-engine/plugin execution, process-interruption behavior,
model initialization, memory/thermal impact and inference remain unverified. At
the user's request, this worker and AI inference were not run on the old Nokia.
Use a suitable newer phone for those tests. Additional model/plugin adapters and
a service-safe configuration/input boundary are required before real recordings
can be processed here. iOS needs its own execution-window design and physical
verification; an Android service-owned engine does not establish iOS behavior.

The [Flutter embedding documentation](https://api.flutter.dev/javadoc/io/flutter/embedding/engine/FlutterEngine.html)
supports data-only engines without a rendering surface. That API capability does
not guarantee OS lifetime, plugin compatibility or acceptable model resource use.

Host checks:

```bash
cd zswatch_app
flutter test --no-pub test/companion_dart_worker_test.dart \
  test/companion_prototype_client_test.dart
flutter build apk --debug --no-pub --dart-define=COMPANION_RUNTIME_PROTOTYPE=true
```

For later physical worker testing, explicitly start the native runtime on the
selected newer phone, preserve a fresh synthetic job journal, then use the
developer UI's `Start Dart worker fixture (no model)`. Test the fixture with the
UI absent before enabling any real model. A lease/result event alone does not
prove watch delivery or inference. The Nokia BLE run leaves
`local_fixture_enabled=false` and never invokes this command.
