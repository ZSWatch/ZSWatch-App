# Release 2.0.0 checklist

Prepared overnight on 2026-10-23, on branch `jakkra_permissions_setup` (not pushed).
The live versions are App Store 1.1.0 (released 2026-02-18) and Play 1.1.0, which is still in closed testing.
There are 364 commits since 1.1.0.

## Done tonight

| Commit | What |
| --- | --- |
| `9b2ef8c` | `version: 2.0.0+3`, Android `targetSdk 36` (Play requires API 36 for updates since 31 Aug 2026) |
| `ccd193e` | `PrivacyInfo.xcprivacy` (SystemBootTime 35F9.1, FileTimestamp C617.1, no tracking) and a microphone string that matches real use |
| `1248191` | Ask for consent before voice audio and text go to OpenRouter (App Review guideline 5.1.2(i), Nov 2025) |
| `642c0c2` | Background location text in Play's prominent-disclosure wording |
| `a4439eb` | Removed `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (Play restricts it). The Settings row opens the system battery list instead. Also adds `scripts/store/feature_graphic.py` |
| `ad10230` | Settings shows the real app version (`package_info_plus`) instead of a hard-coded `1.0.0 (1)` |
| `092f2ad`, `caec337` | Demo Mode no longer shows key and history errors, and the key reloads after Demo Mode is turned off |
| `5cf5692` | XCUITest `testStoreScreenshots` and `scripts/store/frame_screenshots.py` |

Checks: `flutter analyze` is clean and all 381 tests pass. The release APK and AAB build (see the size below). The emulator ran Android 16 edge-to-edge without problems.

## Things to decide or do yourself

1. **Build numbers.** `+3` must be higher than every build already uploaded to App Store Connect and Play Console. If Play already has versionCode 3 or more, bump it.
2. **AAB size.** It is 161 MB. Play caps the compressed download of the base module at 200 MB, so this fits. The APK is 232 MB, so ship only the AAB.
3. **Play production access.** New personal developer accounts need closed testing with **12 testers for 14 continuous days** before they can apply for production (it used to be 20). Check that the counter in Play Console is running.
4. **Core dump server is down.** `zswatch-production.up.railway.app` answers "Application not found". The app now downloads the dump from the correct path (`/lvgl_lfs/coredump.txt`), but analysis fails until the server is back. Either redeploy the server or hide the Analyze button before release.
5. **App Review demo.** The app needs the watch. Demo Mode works but shows almost no data. Options, best first:
   - Upload a short demo video of the real watch and link it in Review Notes. Play's background-location and foreground-service forms ask for videos anyway.
   - Seed Demo Mode with sample data: memos, health, firmware info. This is a code task.
6. **Screenshots.** See the Screenshots section below.

## What's New

**App Store (≤4000 chars)**

```
ZSWatch 2.0 is a big update for the open-source smartwatch.

• Voice memos: record on the watch, then get a transcript, a summary and actions such as timers, alarms, reminders and calendar events. Run it on your phone or with your own OpenRouter key.
• Chat: ask questions from your watch and get the answer on your wrist.
• A rewritten connection that stays up in the background and comes back after the app has been closed.
• Faster and more reliable firmware updates, including resources and watchface backgrounds.
• Weather and GPS for the watch.
• A new permission setup after your first connection, with a clear explanation of each permission.
• Many fixes and stability improvements.
```

**Play (≤500 chars)**

```
ZSWatch 2.0
• Voice memos with transcripts, summaries and actions (timers, alarms, reminders, calendar)
• Chat from your watch
• New background connection that stays up reliably
• Faster firmware and resource updates, watchface backgrounds
• Weather and GPS for the watch
• Guided permission setup
• Many fixes
```

## Store description additions

Add to both listings:

- Voice memos with AI, on the phone (Whisper and Gemma) or through OpenRouter with your own key.
- Chat on the watch.
- Forward phone notifications (Android) and ANCS (iOS).
- Set alarms and timers from voice.
- Weather and GPS sent to the watch.
- Custom watchface backgrounds.
- The connection runs natively in the background.
- Firmware update over Bluetooth, plus a developer shell and logs.
- Open source, with links to the GitHub repos.

## Permissions review

### iOS (`Info.plist`)

| Key / mode | Use | Status |
| --- | --- | --- |
| `bluetooth-central` | Watch connection in the background | Needed |
| `location` + Always string | GPS relay and weather for the watch | Needed; App Review will ask for the user-facing reason. The setup screen explains it |
| `fetch`, `processing` | Voice jobs and sync (BGTaskScheduler) | Needed |
| Microphone | Sample recording in Voice Memo AI settings | String rewritten tonight |
| Calendars / Reminders (full access) | Create actions from voice memos | OK |
| Photo library read/add | `image_picker` (watchface backgrounds) | Update the strings: they still mention firmware files |
| `NSBluetoothPeripheralUsageDescription` | Deprecated | Harmless |
| `NSAllowsArbitraryLoads = true` | — | **Narrow it or justify it.** Only HTTP should need it (watch HTTP sensors / LAN?). Prefer `NSExceptionDomains` |
| AccessorySetupKit | Pairing | Do not add `.bluetoothPairingLE` (see AGENTS.md) |

### Android (merged release manifest)

- **Background location** (`ACCESS_BACKGROUND_LOCATION`, FGS `location`): Play Console asks for the declaration form, a video showing the prominent disclosure and the feature, and the core-feature justification ("weather and GPS on the watch").
- **Foreground-service types** `connectedDevice`, `dataSync`, `mediaProcessing` and `location`: Play Console needs one declaration per type, each with a short video.
  - Consider whether `dataSync` is required. Play is tightening rules for it, and `connectedDevice` may cover sync with the watch.
- `RECORD_AUDIO`, `READ/WRITE_CALENDAR`, `SET_ALARM`: covered by the features. Declare them in Data safety.
- **Notification listener service**: Play reviews it more closely. Its use (forward notifications to the watch) is clear.
- **Companion-device permissions** (`REQUEST_COMPANION_RUN_IN_BACKGROUND`, etc.): these give the app background exemptions. This is why the battery exemption permission is no longer needed.
- `BLUETOOTH_SCAN` with `neverForLocation`: OK.

## Privacy declarations

Update before you submit:

- **App Store App Privacy.** Audio data and user content (transcripts) are sent to OpenRouter when you add your own key. They are not linked to identity and not used for tracking. Precise location is used for app functionality: is it only sent to the weather API? If so, it still counts as collected if it leaves the device.
- **Play Data safety.** Same items. Also say that data is encrypted in transit and that the user can delete it (deleting memos in the app).
- **Privacy policy.** Mention OpenRouter as a third party (only after consent and with the user's own key), the weather provider, and on-device processing.
- **App Review notes.** Hardware is required. Give the Demo Mode path (Settings → Demo Mode) and the video link. Do not give reviewers a real OpenRouter key unless you create a low-credit key just for them.

## Screenshots

These are in `.companion-hil-runs/release/` (gitignored).

- **`store_ios/01..06`**, 1320×2868 (App Store 6.9", iPhone only, so no iPad set). Captured on the iPhone 11 with the real watch: Home, Voice memo detail, Voice AI, Firmware, Watchface, Developer. Ready to use as a draft.
  - Live-data flaws worth a retake with a charged watch and staged content: 0 steps, low watch battery, a low-battery banner on Firmware, recordings titled with timestamps, and a "milk" memo that is not processed.
  - The UI test also shows "Use pushed file: dfu_*.zip" rows. Delete those test files from the app container first.
  - To retake: run `testStoreScreenshots`, export the attachments, then `python scripts/store/frame_screenshots.py ios_pick/spec.json --font fonts/Inter.ttf --out store_ios`.
- **`store_play/01..06`**, 1080×1920, and `feature_graphic_1024x500.png`. These are **provisional**: iOS captures inside an Android frame. Retake them on the OnePlus. The iOS simulator cannot build (ggml simulator symbols), and the emulator has no watch.
- The font is Inter (OFL). Apple only licenses SF Pro for UI mockups, not marketing text.
- The current App Store screenshots are Android captures on white, saved in `appstore_current/`.

## Still to verify on the OnePlus

- The permission setup screen after the first connection, including the battery row opening the system list.
- The Android 16 target with the real watch: foreground service start from the background, notification listener, and edge-to-edge on screens with bottom actions.
- An install of the release AAB through internal testing.

## Sources

- Play target API: https://support.google.com/googleplay/android-developer/answer/11926878
- Play testing for new personal accounts: https://support.google.com/googleplay/android-developer/answer/14151465
- Play background location: https://support.google.com/googleplay/android-developer/answer/9799150
- Play foreground-service types: https://support.google.com/googleplay/android-developer/answer/13392821
- Play battery optimization policy: https://developer.android.com/training/monitoring-device-state/doze-standby#exemption-cases
- App Review Guidelines 5.1.2: https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing
- Privacy manifest required-reason APIs: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- App Store screenshot sizes: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- Play app size limits: https://support.google.com/googleplay/android-developer/answer/9859372
