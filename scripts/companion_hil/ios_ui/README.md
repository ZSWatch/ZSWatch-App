# Normal iPhone UI acceptance

This standalone XCTest bundle controls the installed `dev.zswatch.companion` app.
It uses public Xcode UI automation; there is no special product entrypoint or
injected companion command. It does not connect, pair, Stop, delete recordings,
select models or install firmware. Shell sends the read-only `app state` command.

Require an unlocked Mac/iPhone, trusted USB device, Developer Mode, signing team,
and a selected watch already connected through the normal app. Install the
normal signed app first. `xcodeproj` is provided by the CocoaPods Ruby environment.
Use fresh output/result directories and select the individual check explicitly:

```sh
export ZSW_IOS_TEAM=YOUR_TEAM
export ZSW_PHONE_UDID=YOUR_DEVICE_UDID
ruby scripts/companion_hil/ios_ui/create_project.rb /tmp/zswatch-phone-acceptance-NEW
xcodebuild build-for-testing \
  -project /tmp/zswatch-phone-acceptance-NEW/PhoneAcceptance.xcodeproj \
  -scheme PhoneAcceptance -destination "id=$ZSW_PHONE_UDID" \
  -derivedDataPath /tmp/zswatch-phone-acceptance-NEW/build \
  -allowProvisioningUpdates
xcodebuild test-without-building \
  -project /tmp/zswatch-phone-acceptance-NEW/PhoneAcceptance.xcodeproj \
  -scheme PhoneAcceptance -destination "id=$ZSW_PHONE_UDID" \
  -derivedDataPath /tmp/zswatch-phone-acceptance-NEW/build \
  -only-testing:PhoneAcceptance/CompanionPhoneUITests/testConnectedRoutes \
  -resultBundlePath /tmp/zswatch-phone-acceptance-NEW/routes.xcresult
```

Select `testReadOnlyShell` similarly, with a distinct result path.
`testBackgroundReturn` presses Home for 20 seconds, then reopens the app; it
checks the UI return only. Capture native journal receipts and database projection
separately to establish data collection while the app is in the background.
Neither check proves a locked-screen exchange or genuine OS restoration. Assertions stop
before subsequent UI actions on failure. Screenshots/results may contain private
recording names or diagnostic information; retain them in ignored local evidence,
not source control. No complete app hierarchy or transcript is printed.

Flutter release builds may need a temporary accessibility inspection session for
XCTest to see their semantics. Diagnose an empty hierarchy separately from app
functionality. Inspection is a test facility and must not become a release-mode
product requirement or a VoiceOver preference change. On this rig a temporary
pymobiledevice3 AccessibilityAudit session enabled inspection without changing
VoiceOver. This runner does not enable that session or bypass a locked device.

The original six-route phone check passed on iPhone 11 / iOS 26.1 with app
8ee84dd. The reusable runner's build and subsequent evidence are documented in
IOS_NATIVE_COMPANION_PROGRESS.md; shell response/navigation acceptance is separate
from the successful route check. Run tests sequentially against one phone.
