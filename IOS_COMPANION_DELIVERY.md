# Native iOS companion delivery checkpoint

2026-10-15. The normal Flutter app uses the Swift-owned iOS companion and the
shared Dart voice processor. Implementation and the physical resource recovery
are committed locally on `codex/ios-companion`. First-install Bluetooth denial, Settings recovery and new watch selection now
pass on the phone. Untested variants remain explicit below; this checkpoint is
not a claim that every physical acceptance case has passed.

## Source and installable artifact

| Component | Revision / location |
| --- | --- |
| Signed app executable | App `cea2517`; subsequent commits document acceptance |
| Nordic fork | `06644b17bec8202605afba2065ba8b5f7ef00fcb` |
| fllama fork | `115e7991e78de446ed44858ebe0a8dbc82769d8e` |
| Installed WatchDK firmware | `26c59c8a`, nested `ZSWatch/`, branch `codex/ios-companion` |
| Signed development app | `.companion-hil-runs/20261015-ios-companion/signed-permission-recovery/Runner.app` |
| Local evidence | `.companion-hil-runs/20261015-ios-companion/` |

The app is signed for team `28L8XH4G9T` and the connected iPhone 11, iOS 26.1.
It is a development-signed installation, not an App Store package. Raw evidence,
recordings, model weights and build artifacts are intentionally ignored by Git.
No PR, push or publication is included.

## What is verified

- Native BLE ownership, encrypted Ready, ordinary reconnect/watch reboot,
  Bluetooth off/on recovery, durable Stop and actual OS background relaunch after
  an injected process kill plus a new watch recording. The last method is not
  evidence for a user force-quit or spontaneous jetsam.
- All six normal routes; native GPS/weather/HTTP including offline error and
  recovery; ANCS receipt; CTS timestamps/timezone; AMS metadata and remote media
  controls; sensor subscriptions and cleanup; shell/filesystem/log tools;
  watchface selection, Photos/crop/upload and original restoration; isolated Demo.
- Verified BLE recording publication, playback/seek/export, search/edit/copy,
  archive/delete/restore, offline batch controls and selected-only permanent phone
  purge. A real background-expired download retained a verified 421,950-byte prefix
  and resumed to the exact 620,412-byte source.
- Real local transcription and analysis with saved results/watch ACK, automatic
  transcription without analysis, model import/delete/selection, calendar/reminder
  Create/Undo and local-notification timer behavior. Background AI deferral and a
  fresh fenced retry preserve the saved transcript.
- Firmware upload/retry/cancel, acknowledged throughput 33.5166 KiB/s for the
  measured 836,204-byte image, short Home pause/resume, real boot and active hashes.
- Resource upload after a ten-second Home pause and server-requested restart:
  all 5,919,608 bytes compared before and after reboot, Ready 182, UI test 861.387 s.
  A 26-second Home interval correctly expires to unknown outcome, requiring explicit
  Reset/reselection. The SDK repairs cover paused ACKs and server offset rewind.
- Final independent USB checks: 33 original recordings / 673,009 bytes, every hash
  unchanged; original 115,212-byte watchface hash unchanged; full resource image
  SHA256 `5b060daa49707f1f621a4d6ba1817d6f1032fd1def2fb18e38c5abade388d1a0`.
  Both installed firmware image hashes are active/confirmed. Final Ready 189 on app cea2517 has
  all 33 recordings downloaded, no error, GPS/logs off and automatic processing off.

Firmware 26c59c8a fixes the shared system-workqueue/ATT buffer deadlock using a
separate RX queue and measured stack budgets. Read-only captures show RX 4936/9504
and system work 4848/6144 bytes used, with CPU not halted before/after. The failed
4 KiB RX candidate is explicitly rejected. WatchDK heart-rate values are existing
firmware simulation; chart acceptance does not establish physiological accuracy.

## Validation and reproducibility

All 347 Flutter tests pass and full Flutter analysis is clean. Native core,
recording purge, voice-job and firmware-contract host checks pass. Actual Nordic
SDK fake-transport tests pass encoded ACK pause/drain/resume, offset rewind,
parameter cancellation/reuse, late replies and terminal self-retention.
The signed Release build and deep/strict signature verification pass. Android
native compilation is unverified on this Mac because Android SDK/JDK are absent;
shared Dart changes are covered by the Flutter suite.

See `IOS_MAC_BASELINE.md` for the isolated build workspace used to avoid the Mac's
Documents-folder tooling restriction. From its `zswatch_app/`, run ordinary
`flutter pub get` and `flutter build ios --release --no-pub`. Keep the exact
submodule pins, CocoaPods path-vendored Nordic SDK and signing team. For a signed
build use `build/ios/Release-iphoneos/Runner.app`; the generic output directory can
retain a previous Debug build. `HANDOFF_TO_MAC.md` and the HIL README document
USB/DTR bootstrap, explicit probe selection and one reader per serial port.

## Remaining physical acceptance and iOS limits

The first-launch installation used separate app storage and the same release
executable. After XCTest accepted the phone authentication, normal UI passed:
Connect your watch → Add watch → Find watch, explicit OS Bluetooth denial and
Settings recovery (9.257s), grant and native scan (19.617s), then first selection
and encrypted Ready (24.620s). Independent receipts prove no scan/Start on denial,
scan/discovery/stop after the grant, and fresh Ready generation 2. The existing iOS
system bond was retained; no new system pairing/unpair is claimed. The owned test
installation was stopped and removed. Original Ready 186 and all 33 saved recording
hash/size receipts are unchanged.

Actual user force-quit also passed through the app switcher: the focused card
was swiped away, an independent process snapshot found the app absent, twelve
seconds stayed notRunning, and explicit reopening recovered fresh Ready 189 with
all33 original downloaded receipts unchanged. The whole UI check passed in 27.890 seconds.
This is separate evidence from the injected-kill OS restoration check.

Other unverified variants stay explicit in `IOS_FEATURE_PARITY.md`: first unlock
after phone reboot, literal out-of-range recovery, denied
location/EventKit permissions, manual DST changes, interruption inside STT, and
system-scheduled AI execution. These must not be inferred from ordinary relaunch,
a short Home interval or host tests. Long endurance testing is left to the user.

CoreBluetooth restoration needs an eligible BLE event; it is not a periodic
restart service. User force-quit requires opening the app again. AI waits when iOS
has not granted execution; no permanent background process or immediate locked
phone inference is promised. Phone Clock alarms are not created: actions use
local notifications. The existing firmware has local notification dismissal,
not ANCS phone-action dispatch. Earlier-app recordings remain readable/exportable;
editing or processing those separate legacy rows has no migration path. New
native recordings have the full editing and processing controls.

App storage, the original stash and the Mac handoff backup are preserved. Owned
watch fixtures and native fixture receipts have been removed; cleanup journal
maintenance is distinguished from normal product acceptance in the progress log.
Some explicitly owned test downloads may remain in Files/Safari until UI access
is available. No user files are scheduled for deletion.
