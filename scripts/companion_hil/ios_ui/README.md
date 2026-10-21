# iPhone UI regression flows

`CompanionPhoneUITests.swift` is a standalone XCUITest bundle that drives the
installed, normally signed companion app on a real iPhone through public UI
automation. It never installs the app. Each `test*` method is one flow; run
them one at a time, in order, against one phone.

## Prerequisites

- Mac with Xcode, unlocked iPhone on USB, trusted, Developer Mode on.
- The app installed (see `AGENTS.md`) and, for most flows, the watch already
  connected (dashboard shows **Disconnect**).
- An Apple signing team for the test runner.
- `xcodeproj` gem (comes with CocoaPods).

Flutter release builds may need an accessibility inspection session before
XCTest sees their semantics. An empty hierarchy is a tooling problem, not an
app failure. A pymobiledevice3 AccessibilityAudit session enabled inspection
without changing VoiceOver on our rig; this runner does not start one.

## Create the project

The project is generated, not committed. Use a fresh directory each time
(re-run after editing the Swift file, or edit the copy and open it in Xcode):

```sh
export ZSW_IOS_TEAM=YOUR_TEAM_ID
export OUT=.companion-hil-runs/phone-ui-$(date +%Y%m%d-%H%M%S)
LANG=en_US.UTF-8 ruby scripts/companion_hil/ios_ui/create_project.rb "$OUT"
open "$OUT/PhoneAcceptance.xcodeproj"   # optional, to run from Xcode
```

`ZSW_UITEST_BUNDLE_ID` overrides the runner's bundle id
(default `dev.zswatch.companion.hil.acceptance`).

Compile check without a phone or signing:

```sh
xcodebuild build-for-testing -project "$OUT/PhoneAcceptance.xcodeproj" -scheme PhoneAcceptance -destination 'generic/platform=iOS' -derivedDataPath "$OUT/build" CODE_SIGNING_ALLOWED=NO
```

## Select a device and run one flow

`xcrun devicectl list devices` lists device ids. Build once for the phone,
then run single flows with `-only-testing` and a distinct result bundle:

```sh
export ZSW_PHONE_UDID=YOUR_DEVICE_UDID
xcodebuild build-for-testing -project "$OUT/PhoneAcceptance.xcodeproj" -scheme PhoneAcceptance -destination "id=$ZSW_PHONE_UDID" -derivedDataPath "$OUT/build" -allowProvisioningUpdates
```

```sh
xcodebuild test-without-building -project "$OUT/PhoneAcceptance.xcodeproj" -scheme PhoneAcceptance -destination "id=$ZSW_PHONE_UDID" -derivedDataPath "$OUT/build" -only-testing:PhoneAcceptance/CompanionPhoneUITests/testMainRoutes -resultBundlePath "$OUT/main-routes.xcresult"
```

Keep `.xcresult` bundles in the gitignored `.companion-hil-runs/`: screenshots
can show recording names, transcripts and diagnostics.

### Configuration

Flows read environment variables. xcodebuild forwards `TEST_RUNNER_<NAME>` to
the runner as `<NAME>`, e.g.
`TEST_RUNNER_ZSW_RECORDING=hil_test_note xcodebuild test-without-building ...`.
A flow whose required variable is unset is skipped.

| Variable | Default | Used by |
| --- | --- | --- |
| `ZSW_BUNDLE_ID` | `dev.zswatch.companion` | all |
| `ZSW_WATCH_NAME` | `ZSWatch` | `testPairWatch` (pairing prompt text) |
| `ZSW_FW_PACKAGE` | required | firmware flows; file name prefix of a `dfu_application.zip` |
| `ZSW_RESOURCE_PACKAGE` | required | `testResourceUpload`; file name prefix of the resource image |
| `ZSW_PICKER_LOCATION` | `On My iPhone` | document picker root (`iCloud Drive` also works) |
| `ZSW_PICKER_FOLDER` | `Downloads` | folder under that root holding the packages |
| `ZSW_RECORDING` | required | recording/transcript flows; search text that must match exactly one recording |
| `ZSW_BACKGROUND` | `Aurora` | `testWatchfaceApplyBundledBackground` |
| `ZSW_SPEECH_MODEL` | `Whisper Small (English)` | `testSelectSpeechModel` |
| `ZSW_OPENROUTER_KEY` | required | `testOpenRouterSetup`; pass it from a file (`$(cat ~/.config/zswatch/openrouter_key)`), never commit it |
| `ZSW_SENSORS` | all sensors | `testSensorsStartStop`; comma-separated row labels |
| `ZSW_BACKGROUND_SECONDS` | `20` | `testBackgroundReturn`, `testVoiceMemoBackground` (firmware background caps at 10) |

Put firmware/resource packages into Files yourself first (Safari download,
AirDrop, Finder file sharing). The flows only pick them.

Without touching the phone, push a package into the app's own container
instead; the firmware screen then offers **Use pushed file: NAME** (shown only
while such files exist):

```sh
xcrun devicectl device copy to --device "$ZSW_PHONE_UDID" --domain-type appDataContainer \
  --domain-identifier "${ZSW_BUNDLE_ID:-dev.zswatch.companion}" --source dfu_application.zip \
  --destination "Library/Application Support/dev_drop/dfu_application.zip"
```

A local build with a changed boot banner (e.g. an extra conf with
`CONFIG_NCS_APPLICATION_BOOT_BANNER_STRING="ZSWatch DFU-TEST"`) shows on the
watch UART which image runs after the update.

## Hands-free voice memo

Developer > Shell > Quick Actions > **Voice Memo Test (phone speaks)** runs
`voice_memo start`, speaks a fixed reminder phrase through the phone speaker
(iOS or Android text-to-speech) and runs `voice_memo stop`. With the AI options on, the
recording then goes through sync, transcription, analysis and delivery to the
watch like a spoken memo. Keep the phone next to the watch with media volume up.
Playback has a bounded wait so a stalled speech engine still reaches the stop
attempt. A failed stop is reported; check the watch before retrying.

On Android, packages can be pushed into the release app's external files
directory without `run-as`:

```sh
adb -s "$ZSW_ANDROID_SERIAL" shell mkdir -p /sdcard/Android/data/com.zswatch.app/files/dev_drop
adb -s "$ZSW_ANDROID_SERIAL" push dfu_application.zip /sdcard/Android/data/com.zswatch.app/files/dev_drop/
```

The same **Use pushed file** control offers these packages. If a pushed file is
not readable by the app, use `adb shell chmod 666` on that lab package. Remove
the pushed package when testing is complete.

## Flows

**Read-only** (no watch or phone state change beyond navigation):

| Flow | Checks |
| --- | --- |
| `testMainRoutes` | Health (Today/Week/Month), Notifications, Analytics, Watchface, Developer, Voice open and Home stays connected |
| `testSettingsReadOnly` | iOS permission rows, App Version, Licenses, Coredump Server dialog (cancelled) |
| `testShellAppState` | BLE shell `app state` returns `UI state:` |
| `testDeveloperReadOnlyRoutes` | Crash Reports, File System, Comm Log load watch data |
| `testFirmwareSelectPackage` | picks `ZSW_FW_PACKAGE`; no upload |
| `testRecordingPlaybackSeek` | plays and seeks the `ZSW_RECORDING` audio |
| `testBackgroundReturn` | Home → wait → reopen, connected dashboard returns (UI only; native receipts prove background work) |

**Change watch state:**

| Flow | Effect |
| --- | --- |
| `testFindWatch` | watch buzzes |
| `testSyncTime` | sets the watch clock |
| `testLogStreaming` | toggles watch log streaming; ends off |
| `testSensorsStartStop` | starts/stops each sensor stream; ends all off |
| `testWatchfaceApplyBundledBackground` | changes the watchface background |
| `testWatchfaceResetToDefault` | resets the background to default |
| `testRestartWatch` | reboots the watch, waits for reconnect |
| `testResourceUpload` | overwrites watch filesystem resources |
| `testFirmwareCancelDuringUpload` | starts a DFU and cancels it during upload, then Reset |
| `testFirmwareUpdateToCompletion` | flashes `ZSW_FW_PACKAGE`, watch reboots |
| `testFirmwareUpdateWithShortBackground` | same, with ≤10 s in background during upload |
| `testFirmwareRetry` | retries a failed/cancelled update already on screen, to completion |
| `testAnalyzeTranscript` | sends an analysis result for `ZSW_RECORDING` to the watch |

Upload resources before firmware: the firmware reboot cuts a resource upload.

**Change phone/app state:**

| Flow | Effect |
| --- | --- |
| `testPairWatch` | taps Connect and accepts the iOS pairing prompt (creates a bond). Ask before running. |
| `testExplicitStopSurvivesRelaunch` | Disconnect, terminate and relaunch app, verify still stopped, Connect |
| `testDemoModeRoundTrip` | Demo Mode on (real watch disconnects), walks routes, Demo Mode off, real watch back |
| `testBluetoothOffOnRecovery` | turns phone Bluetooth off then on in Settings; restored on exit |
| `testSelectSpeechModel` | changes the selected speech model; may download hundreds of MB |
| `testTranscribeRecording` | saves a new transcript revision for `ZSW_RECORDING` |
| `testTranscriptEditRestore` | appends text, saves, restores the original (adds revisions) |
| `testRecordingArchiveDeleteRestore` | archive/unarchive, delete, restore; ends as it started |

Do not flash, reset or recover the watch while running background or
reconnection flows. Flows stop at the first failed check and attach a
screenshot named after the step.

## Missing accessibility identifiers

The Flutter UI sets no `Semantics(identifier:)`, so flows match labels and
tooltips. They break if those strings change. Spots marked `MISSING-ID` in
the Swift file would benefit most from identifiers: the switches on sensor,
Demo Mode and voice-policy rows (found by row position), the Log Viewer
streaming switch, the model selector dropdown (tapped at its top line),
watchface background tiles and the Reset to Default button.

## Owned AMS media fixture

`python3 scripts/companion_hil/ios_media_fixture.py <new-dir>` writes a page
with two quiet generated tones that publish unique track titles through
MediaSession. Serve its parent with `http_fixture.py`, open it in iPhone
Safari and tap Start owned audio. Watch Music controls should then log
`remote-play`, `remote-pause`, `remote-next` and `remote-previous` requests
(404 responses are expected; the request log records the callback). Check the
phone player and watch metadata, then stop the audio.

## What was dropped from the ad-hoc driver

The earlier `/tmp` driver had ~150 one-shot steps. Dropped: steps tied to
specific fixture files on one phone (named recordings, firmware zips,
imported GGUF models, reminder/calendar/timer fixtures, photos), Safari
download/Files navigation by screen coordinates, App Switcher force-quit by
coordinates, Airplane/Wi-Fi toggles, AccessorySetupKit migration steps,
first-launch permission checks against a separately signed copy, and
watch-specific shell probes (`kernel thread stacks`, `voice_memo status`).
