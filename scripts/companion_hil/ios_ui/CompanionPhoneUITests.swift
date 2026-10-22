import XCTest

/// Reusable UI regression flows for the installed ZSWatch companion app on a
/// real iPhone. The bundle drives the normal app through public XCUITest APIs;
/// it never installs the app and only touches pairing in `testPairWatch`.
///
/// Configuration comes from the test runner environment. With xcodebuild, pass
/// `TEST_RUNNER_<NAME>=value` and the runner sees `<NAME>` (see README.md).
///
/// The Flutter UI exposes no `Semantics(identifier:)` values today, so the
/// flows query by visible label or tooltip. Places that would benefit from an
/// identifier are marked `MISSING-ID`.
final class CompanionPhoneUITests: XCTestCase {
    private enum Config {
        static let env = ProcessInfo.processInfo.environment
        static func value(_ key: String, _ fallback: String) -> String {
            guard let value = env[key], !value.isEmpty else { return fallback }
            return value
        }
        static func required(_ key: String) throws -> String {
            guard let value = env[key], !value.isEmpty else {
                throw XCTSkip("Set TEST_RUNNER_\(key) to run this flow")
            }
            return value
        }
        static var bundleId: String { value("ZSW_BUNDLE_ID", "dev.zswatch.companion") }
        static var watchName: String { value("ZSW_WATCH_NAME", "ZSWatch") }
        /// Document picker root that holds the Downloads folder.
        static var pickerLocation: String { value("ZSW_PICKER_LOCATION", "On My iPhone") }
        static var pickerFolder: String { value("ZSW_PICKER_FOLDER", "Downloads") }
        static var background: String { value("ZSW_BACKGROUND", "Aurora") }
        static var speechModel: String { value("ZSW_SPEECH_MODEL", "Whisper Small (English)") }
        static var backgroundSeconds: TimeInterval { TimeInterval(value("ZSW_BACKGROUND_SECONDS", "20")) ?? 20 }
    }

    private let routes: [(entry: String, heading: String)] = [
        ("Health", "Health"), ("Notifications", "Notifications"), ("Analytics", "Analytics"),
        ("Watchface", "Watchface Background"), ("Developer", "Developer Tools"), ("Voice", "Voice Notes"),
    ]

    private lazy var app = XCUIApplication(bundleIdentifier: Config.bundleId)
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private let settingsApp = XCUIApplication(bundleIdentifier: "com.apple.Preferences")

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private struct FlowError: Error, CustomStringConvertible {
        let description: String
    }

    private func fail(_ message: String, capture name: String? = nil) -> FlowError {
        if let name { screenshot(name) }
        return FlowError(description: message)
    }

    private func require(_ condition: Bool, _ message: String, capture name: String? = nil) throws {
        if !condition { throw fail(message, capture: name) }
    }

    private func screenshot(_ name: String, _ target: XCUIApplication? = nil) {
        let attachment = XCTAttachment(screenshot: (target ?? app).screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func any(_ format: String, _ args: Any..., in root: XCUIApplication? = nil) -> XCUIElement {
        (root ?? app).descendants(matching: .any)
            .matching(NSPredicate(format: format, argumentArray: args)).firstMatch
    }

    private func exact(_ label: String, in root: XCUIApplication? = nil) -> XCUIElement {
        any("label == %@", label, in: root)
    }

    private func prefix(_ label: String, in root: XCUIApplication? = nil) -> XCUIElement {
        any("label BEGINSWITH %@", label, in: root)
    }

    private func containing(_ text: String) -> XCUIElement {
        any("label CONTAINS %@ OR value CONTAINS %@", text, text)
    }

    private func tap(_ element: XCUIElement, _ what: String, timeout: TimeInterval = 10) throws {
        try require(element.waitForExistence(timeout: timeout), "Missing \(what)", capture: "missing-\(what)")
        element.tap()
    }

    /// Scrolls with short drags until `element` is hittable. Flutter lists do
    /// not always respond to `swipeUp()` near the bottom inset.
    @discardableResult
    private func reveal(_ element: XCUIElement, _ what: String, attempts: Int = 12) throws -> XCUIElement {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return element }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
            Thread.sleep(forTimeInterval: 0.5)
        }
        throw fail("Could not scroll to \(what)", capture: "reveal-\(what)")
    }

    /// The switch on the same row as `label`. MISSING-ID: sensor, Demo Mode
    /// and voice-policy switches carry no label or identifier of their own.
    private func switchOnRow(_ label: String) throws -> XCUIElement {
        let title = try reveal(prefix(label), label)
        let candidates = app.switches.allElementsBoundByIndex.filter {
            $0.isHittable && abs($0.frame.midY - title.frame.midY) < 40
        }
        try require(candidates.count == 1, "Expected one switch on row \(label)", capture: "switch-\(label)")
        return candidates[0]
    }

    private func isOn(_ toggle: XCUIElement) -> Bool { toggle.value as? String == "1" }

    /// Flutter switch tiles route taps on the label to the tile; tap the knob side.
    private func flip(_ toggle: XCUIElement, to on: Bool, timeout: TimeInterval = 15) throws {
        if isOn(toggle) == on { return }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let done = expectation(for: NSPredicate(format: "value == %@", on ? "1" : "0"), evaluatedWith: toggle)
        wait(for: [done], timeout: timeout)
    }

    private var connectedHomeVisible: Bool {
        let disconnect = app.buttons["Disconnect"]
        return disconnect.exists && disconnect.isHittable
    }

    /// Returns to the dashboard (connected) or start page (stopped).
    private func home() throws {
        app.activate()
        Thread.sleep(forTimeInterval: 1)
        for _ in 0..<6 {
            if connectedHomeVisible { return }
            if app.buttons["Connect"].exists && app.buttons["Settings"].exists { return }
            if app.buttons["Close"].exists { app.buttons["Close"].tap() }
            else if app.buttons["Back"].exists { app.buttons["Back"].tap() }
            else if app.buttons["Cancel"].exists { app.buttons["Cancel"].firstMatch.tap() }
            else if app.buttons["Disconnect"].waitForExistence(timeout: 10) { return }
            else { break }
            Thread.sleep(forTimeInterval: 1)
        }
        throw fail("Could not return to Home", capture: "home-not-reached")
    }

    private func connectedHome() throws {
        try home()
        try require(connectedHomeVisible, "Connect the watch in the normal app before this flow", capture: "not-connected")
    }

    private func openRoute(_ entry: String, heading: String) throws {
        try connectedHome()
        try tap(exact(entry), "\(entry) entry")
        try require(exact(heading).waitForExistence(timeout: 10), "Missing \(heading) screen", capture: "route-\(entry)")
    }

    private func openSettings() throws {
        try home()
        try tap(app.buttons["Settings"], "Settings")
    }

    private func openVoiceModels() throws {
        try openSettings()
        let screen = prefix("Experimental: on-device processing")
        // A tap during the reveal scroll's settle can be dropped; tap again.
        for _ in 0..<2 where !screen.exists {
            try reveal(prefix("Voice memo models"), "Voice memo models").tap()
            _ = screen.waitForExistence(timeout: 5)
        }
        try require(screen.waitForExistence(timeout: 5), "Missing model settings", capture: "models")
    }

    /// Local model pickers are behind the experimental on-device switch.
    private func openOnDeviceModels() throws {
        try openVoiceModels()
        try flip(try switchOnRow("Experimental: on-device processing"), to: true)
        try require(prefix("Select model").waitForExistence(timeout: 10), "Missing local model settings", capture: "models")
    }

    private func openDeveloperRoute(_ menu: String, heading: String) throws {
        try openRoute("Developer", heading: "Developer Tools")
        try tap(try reveal(prefix(menu), menu), menu)
        try require(exact(heading).waitForExistence(timeout: 10), "Missing \(heading)", capture: "developer-\(menu)")
    }

    /// Opens Voice and filters the list down to `search`.
    private func searchRecordings(_ search: String) throws -> XCUIElement {
        try openRoute("Voice", heading: "Voice Notes")
        let field = app.textFields.firstMatch
        try require(field.waitForExistence(timeout: 10), "Missing recording search")
        field.tap()
        field.typeText(search)
        for key in ["Done", "Return", "Search"] where app.keyboards.buttons[key].exists {
            app.keyboards.buttons[key].tap()
            break
        }
        let row = prefix(search)
        try require(row.waitForExistence(timeout: 10), "No recording matches the search", capture: "recording-search")
        return row
    }

    /// Exactly one recording must match so destructive actions hit only it.
    private func singleRecording() throws -> XCUIElement {
        let row = try searchRecordings(try Config.required("ZSW_RECORDING"))
        try require(app.buttons.matching(identifier: "Transcription actions").count == 1,
                    "ZSW_RECORDING must match exactly one recording", capture: "recording-not-unique")
        return row
    }

    private func recordingAction(_ action: String) throws {
        try tap(app.buttons["Transcription actions"], "Transcription actions")
        try tap(exact(action), action)
    }

    private func shell(_ command: String, expect reply: String, timeout: TimeInterval = 20) throws {
        let input = app.textFields.firstMatch
        try require(input.waitForExistence(timeout: 10), "Missing shell input")
        input.tap()
        input.typeText(command)
        try tap(app.keyboards.buttons["Send"], "keyboard Send", timeout: 5)
        try require(containing(reply).waitForExistence(timeout: timeout),
                    "No watch reply to '\(command)'", capture: "shell-\(command)")
    }

    /// Picks `prefixName` from the configured Files location via the system
    /// document picker opened by the app. Walks back to the location list first.
    private func pickDocument(_ prefixName: String) throws {
        try tap(app.buttons["Browse"].firstMatch, "picker Browse tab")
        let location = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", Config.pickerLocation)).firstMatch
        for _ in 0..<5 where !location.exists {
            let back = app.navigationBars.buttons.firstMatch
            try require(back.exists && back.label != "Cancel", "No picker location \(Config.pickerLocation)", capture: "picker-root")
            back.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
        try tap(location, Config.pickerLocation)
        try tap(app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", Config.pickerFolder)).firstMatch, Config.pickerFolder)
        try tap(app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", prefixName)).firstMatch, prefixName)
    }

    private func openFirmwareSelection() throws {
        try connectedHome()
        try tap(app.buttons["Update Firmware"], "Update Firmware")
        // Clear a finished or cancelled previous run.
        if app.buttons["Done"].exists { app.buttons["Done"].tap(); Thread.sleep(forTimeInterval: 1) }
        if app.buttons["Update Firmware"].exists { app.buttons["Update Firmware"].tap() }
        if app.buttons["Reset"].exists && app.buttons["Reset"].isEnabled { app.buttons["Reset"].tap() }
        try tap(prefix("Select .zip or .bin file"), "firmware file selector")
    }

    private func selectFirmwarePackage() throws -> String {
        let package = try Config.required("ZSW_FW_PACKAGE")
        try openFirmwareSelection()
        try pickDocument(package)
        try require(app.buttons["FW Update"].waitForExistence(timeout: 10), "FW Update not offered", capture: "fw-selected")
        return package
    }

    private func startFirmwareUpload() throws {
        let start = app.buttons["FW Update"]
        try require(start.exists && start.isEnabled, "FW Update not ready", capture: "fw-not-ready")
        start.tap()
        let cancel = app.buttons["Cancel"]
        try require(cancel.waitForExistence(timeout: 30) && cancel.isEnabled, "Upload did not start", capture: "fw-not-started")
    }

    private func waitForFirmwareComplete(timeout: TimeInterval = 600) throws {
        try require(exact("Update Complete!").waitForExistence(timeout: timeout),
                    "Firmware update did not complete", capture: "fw-not-complete")
        screenshot("fw-complete")
    }

    private func openWatchface() throws {
        try openRoute("Watchface", heading: "Watchface Background")
    }

    private func sendToBackground(for seconds: TimeInterval) throws {
        XCUIDevice.shared.press(.home)
        try require(app.wait(for: .runningBackground, timeout: 10), "App did not enter background")
        print("HIL_BACKGROUND_ENTERED")
        Thread.sleep(forTimeInterval: seconds)
        app.activate()
        print("HIL_FOREGROUND_RETURNED")
    }

    private func bluetoothSwitch() throws -> XCUIElement {
        settingsApp.activate()
        let radio = settingsApp.switches["Bluetooth"]
        for _ in 0..<6 where !radio.exists {
            let row = settingsApp.staticTexts["Bluetooth"]
            if row.exists && row.isHittable { row.tap() }
            else if let back = settingsApp.navigationBars.buttons.allElementsBoundByIndex.first { back.tap() }
            else { break }
            Thread.sleep(forTimeInterval: 0.7)
        }
        try require(radio.waitForExistence(timeout: 10), "Missing Bluetooth switch in Settings", capture: "settings-bluetooth")
        return radio
    }

    // MARK: - Pairing and connection

    /// Taps Connect and accepts the iOS pairing prompt for the watch.
    /// State: creates an iOS bond. Run only on a phone/watch you intend to pair.
    func testPairWatch() throws {
        app.activate()
        let connect = app.buttons["Connect"]
        if connect.waitForExistence(timeout: 10) && connect.isEnabled { connect.tap() }
        let deadline = Date().addingTimeInterval(150)
        while Date() < deadline {
            for owner in [springboard, app] {
                for alert in owner.alerts.allElementsBoundByIndex {
                    let text = ([alert.label] + alert.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: " ")
                    if text.localizedCaseInsensitiveContains(Config.watchName),
                       text.localizedCaseInsensitiveContains("pair"),
                       alert.buttons["Pair"].exists {
                        alert.buttons["Pair"].tap()
                        XCTAssertTrue(alert.waitForNonExistence(timeout: 10))
                        XCTAssertTrue(app.buttons["Disconnect"].waitForExistence(timeout: 60), "Did not reach connected Home")
                        return
                    }
                }
            }
            if connectedHomeVisible { return } // Already bonded.
            Thread.sleep(forTimeInterval: 1)
        }
        throw fail("No \(Config.watchName) pairing prompt within 150 s", capture: "no-pair-prompt")
    }

    /// Developer > Find watch makes the watch buzz.
    func testFindWatch() throws {
        try openRoute("Developer", heading: "Developer Tools")
        let find = app.buttons["Find watch"]
        try require(find.exists && find.isEnabled, "Find watch not ready", capture: "find-watch")
        find.tap()
        Thread.sleep(forTimeInterval: 5)
        screenshot("find-watch")
        try home()
    }

    /// Disconnect, relaunch the app process, verify it stays stopped, then Connect.
    /// State: briefly disconnects the watch.
    func testExplicitStopSurvivesRelaunch() throws {
        try connectedHome()
        app.buttons["Disconnect"].tap()
        try require(app.buttons["Connect"].waitForExistence(timeout: 15), "Disconnect did not stop")
        app.terminate()
        Thread.sleep(forTimeInterval: 2)
        app.activate()
        try require(app.buttons["Connect"].waitForExistence(timeout: 15), "Stop was not kept after relaunch")
        XCTAssertFalse(app.buttons["Disconnect"].exists)
        Thread.sleep(forTimeInterval: 5)
        try require(!app.buttons["Disconnect"].exists, "App reconnected on its own after explicit stop")
        app.buttons["Connect"].tap()
        try require(app.buttons["Disconnect"].waitForExistence(timeout: 45), "Connect did not return", capture: "reconnect")
    }

    // MARK: - Main routes and settings

    func testMainRoutes() throws {
        try connectedHome()
        for route in routes {
            try tap(exact(route.entry), "\(route.entry) entry")
            try require(app.buttons["Back"].waitForExistence(timeout: 10), "Missing Back on \(route.entry)")
            try require(exact(route.heading).exists, "Missing \(route.heading) screen", capture: "route-\(route.entry)")
            if route.entry == "Health" {
                for range in ["Week", "Month", "Today"] { try tap(prefix(range), "\(range) range"); Thread.sleep(forTimeInterval: 1) }
            }
            screenshot("route-\(route.entry)")
            app.buttons["Back"].tap()
            try require(app.buttons["Disconnect"].waitForExistence(timeout: 10), "Home not connected after \(route.entry)")
        }
    }

    /// Read-only walk through Settings: permissions, version, licenses, coredump server dialog.
    func testSettingsReadOnly() throws {
        try openSettings()
        try reveal(prefix("App Permissions"), "App Permissions").tap()
        for row in ["Bluetooth connection", "App notifications", "Location", "Background location"] {
            try reveal(prefix(row), row)
        }
        XCTAssertFalse(exact("Battery optimization").exists, "Android-only permission row on iOS")
        screenshot("settings-permissions")
        try reveal(prefix("App Version"), "App Version").tap()
        try require(exact("App Version").waitForExistence(timeout: 10), "Missing version dialog")
        if app.buttons["OK"].exists { app.buttons["OK"].firstMatch.tap() } else if app.buttons["Close"].exists { app.buttons["Close"].tap() }
        try reveal(prefix("Licenses"), "Licenses").tap()
        try require(exact("Licenses").waitForExistence(timeout: 10), "Missing Licenses")
        app.buttons["Back"].tap()
        try reveal(prefix("Coredump Server"), "Coredump Server").tap()
        try require(app.buttons["Cancel"].waitForExistence(timeout: 10), "Missing coredump dialog")
        app.buttons["Cancel"].tap()
        try home()
    }

    /// Turns Demo Mode on, walks the routes against the synthetic watch, turns it off
    /// and expects the real watch back. State: real watch disconnects during demo.
    func testDemoModeRoundTrip() throws {
        try connectedHome()
        try tap(app.buttons["Settings"], "Settings")
        let on = try switchOnRow("Demo Mode")
        try require(!isOn(on), "Demo Mode already on")
        try flip(on, to: true)
        try home()
        for route in routes {
            try tap(exact(route.entry), "\(route.entry) entry (demo)")
            try require(exact(route.heading).waitForExistence(timeout: 10), "Missing \(route.heading) in demo")
            app.buttons["Back"].tap()
        }
        screenshot("demo-mode")
        try tap(app.buttons["Settings"], "Settings")
        try flip(try switchOnRow("Demo Mode"), to: false)
        app.buttons["Back"].tap()
        try require(app.buttons["Disconnect"].waitForExistence(timeout: 45), "Real watch not restored after demo", capture: "demo-exit")
    }

    // MARK: - Firmware and resources

    /// Selects `ZSW_FW_PACKAGE` (file name prefix) from Files. No upload.
    func testFirmwareSelectPackage() throws {
        _ = try selectFirmwarePackage()
        screenshot("fw-selected")
    }

    /// Selects the package, starts the upload, cancels during upload, then
    /// clears the cancelled state with Reset. State: interrupts a DFU upload.
    func testFirmwareCancelDuringUpload() throws {
        _ = try selectFirmwarePackage()
        try startFirmwareUpload()
        Thread.sleep(forTimeInterval: 2)
        let cancel = app.buttons["Cancel"]
        try require(cancel.exists && cancel.isEnabled, "Upload phase ended before cancel")
        cancel.tap()
        let cancelled = any("label ==[c] %@", "Update cancelled")
        try require(cancelled.waitForExistence(timeout: 30), "No cancelled state", capture: "fw-cancel")
        screenshot("fw-cancelled")
        try tap(app.buttons["Reset"], "Reset")
        try require(prefix("Select .zip or .bin file").waitForExistence(timeout: 10), "Reset did not clear the selection")
    }

    /// Installs `ZSW_FW_PACKAGE` in the foreground. State: flashes and reboots the watch.
    func testFirmwareUpdateToCompletion() throws {
        _ = try selectFirmwarePackage()
        try startFirmwareUpload()
        try waitForFirmwareComplete()
    }

    /// Same as above but sends the app to the background for
    /// `ZSW_BACKGROUND_SECONDS` during upload. State: flashes and reboots the watch.
    func testFirmwareUpdateWithShortBackground() throws {
        _ = try selectFirmwarePackage()
        try startFirmwareUpload()
        try sendToBackground(for: min(Config.backgroundSeconds, 10))
        try waitForFirmwareComplete()
    }

    /// Retries a failed or cancelled update from the firmware screen.
    /// State: flashes and reboots the watch.
    func testFirmwareRetry() throws {
        app.activate()
        let retry = app.buttons["Retry"].exists ? app.buttons["Retry"] : app.buttons["FW Update"]
        try require(retry.waitForExistence(timeout: 15) && retry.isEnabled, "No Retry/FW Update on screen", capture: "fw-retry")
        retry.tap()
        try waitForFirmwareComplete()
    }

    /// Uploads `ZSW_RESOURCE_PACKAGE` (filesystem image) over SMP.
    /// State: overwrites watch resources (images/fonts).
    func testResourceUpload() throws {
        let package = try Config.required("ZSW_RESOURCE_PACKAGE")
        try openFirmwareSelection()
        try pickDocument(package)
        let start = app.buttons["FS Upload"]
        try require(start.waitForExistence(timeout: 10) && start.isEnabled, "FS Upload not ready", capture: "fs-not-ready")
        start.tap()
        let done = any("label == %@ OR label == %@", "Filesystem Upload Complete!", "Update Complete!")
        try require(done.waitForExistence(timeout: 1200), "Resource upload did not complete", capture: "fs-not-complete")
        screenshot("fs-complete")
    }

    // MARK: - Watchface background

    /// Applies the bundled background `ZSW_BACKGROUND`. State: changes the watchface.
    func testWatchfaceApplyBundledBackground() throws {
        try openWatchface()
        // MISSING-ID: tiles are images with a text label; tap the image centre.
        let tile = exact(Config.background)
        for _ in 0..<10 where !(tile.exists && tile.isHittable && tile.frame.midY < app.frame.height - 100) {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        try require(tile.exists && tile.isHittable, "Missing background \(Config.background)", capture: "bg-tile")
        let image = app.images[Config.background]
        (image.exists ? image : tile).tap()
        try require(exact("Background applied!").waitForExistence(timeout: 180), "Background not applied", capture: "bg-apply")
        screenshot("bg-applied")
    }

    /// Reset to Default. State: changes the watchface.
    func testWatchfaceResetToDefault() throws {
        try openWatchface()
        let reset = try reveal(app.buttons["Reset to Default"], "Reset to Default")
        try require(reset.isEnabled, "Reset to Default disabled")
        // The button's lower half overlaps the bottom inset gesture area.
        reset.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        try require(exact("Background reset to default").waitForExistence(timeout: 30), "No reset acknowledgement", capture: "bg-reset")
    }

    // MARK: - Recordings

    /// Plays `ZSW_RECORDING`, seeks with the slider, closes. Read-only.
    func testRecordingPlaybackSeek() throws {
        try singleRecording().tap()
        if app.buttons["Close"].exists && !app.buttons["Play recording"].exists { app.buttons["Close"].tap() }
        try tap(app.buttons["Play recording"].firstMatch, "Play recording")
        let slider = app.sliders.firstMatch
        try require(slider.waitForExistence(timeout: 15), "No playback slider", capture: "playback")
        let position = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+:[0-9]{2} / [0-9]+:[0-9]{2}$")).firstMatch
        slider.adjust(toNormalizedSliderPosition: 0.7)
        Thread.sleep(forTimeInterval: 1)
        try require(position.exists && !position.label.hasPrefix("0:00 /"), "Seek did not move playback", capture: "seek")
        screenshot("playback-seek")
        try home()
    }

    /// Archive, unarchive, delete from phone, restore from Recently deleted.
    /// State: ends where it started; touches only the `ZSW_RECORDING` match.
    func testRecordingArchiveDeleteRestore() throws {
        let row = try singleRecording()
        try recordingAction("Archive")
        try require(row.waitForNonExistence(timeout: 10), "Archived recording still in All")
        try tap(exact("Archived"), "Archived filter")
        try require(row.waitForExistence(timeout: 10), "Recording not in Archived")
        try recordingAction("Unarchive")
        try tap(exact("All"), "All filter")
        try require(row.waitForExistence(timeout: 10), "Recording not back in All")
        try recordingAction("Delete from phone")
        try tap(app.buttons["Delete from phone"], "delete confirmation")
        try require(row.waitForNonExistence(timeout: 10), "Deleted recording still listed")
        try tap(exact("Recently deleted"), "Recently deleted filter")
        try require(row.waitForExistence(timeout: 10) && app.buttons.matching(identifier: "Restore").count == 1,
                    "Expected only this recording in Recently deleted", capture: "recently-deleted")
        app.buttons["Restore"].tap()
        try tap(exact("All"), "All filter")
        try require(row.waitForExistence(timeout: 10), "Restored recording missing")
        try home()
    }

    /// Copies the transcript, appends text, saves, then saves the original text back.
    /// State: adds two transcript revisions; final text matches the original.
    func testTranscriptEditRestore() throws {
        try singleRecording().tap()
        try require(app.buttons["Edit transcript"].waitForExistence(timeout: 10), "Recording has no saved transcript")
        try tap(app.buttons["Copy transcript"], "Copy transcript")
        app.buttons["Edit transcript"].tap()
        func editor() throws -> XCUIElement {
            let fields = app.textViews.allElementsBoundByIndex + app.textFields.allElementsBoundByIndex
            guard let field = fields.first(where: { $0.isHittable }) else { throw fail("No transcript editor", capture: "editor") }
            return field
        }
        func replace(with text: String) throws {
            let field = try editor()
            let current = field.value as? String ?? ""
            field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 5))
            try require((try editor().value as? String)?.isEmpty == true, "Editor not cleared")
            try editor().typeText(text)
            app.buttons["Save"].tap()
        }
        guard let original = try editor().value as? String, original.count > 3 else { throw fail("Empty transcript") }
        try replace(with: original + " HIL edit check.")
        try require(containing("HIL edit check.").waitForExistence(timeout: 10), "Edited text not shown")
        app.buttons["Edit transcript"].tap()
        try replace(with: original)
        try require(exact(original).waitForExistence(timeout: 10), "Original text not restored", capture: "transcript-restore")
        try home()
    }

    // MARK: - Transcription, analysis, models

    /// Transcribe only on `ZSW_RECORDING`. State: saves a new transcript revision.
    func testTranscribeRecording() throws {
        _ = try singleRecording()
        try recordingAction("Transcribe only")
        try tap(app.buttons["Transcribe"], "Transcribe confirmation")
        try require(containing("Transcribed").waitForExistence(timeout: 300), "Transcription not saved", capture: "transcribe")
        screenshot("transcribed")
    }

    /// Re-analyze the transcript of `ZSW_RECORDING` and wait for watch acceptance
    /// or a reviewable action. State: sends the analysis result to the watch.
    func testAnalyzeTranscript() throws {
        _ = try singleRecording()
        try recordingAction("Re-analyze transcript")
        try tap(app.buttons["Process"], "Process confirmation")
        let result = any("label CONTAINS %@ OR label BEGINSWITH %@", "Accepted by watch", "Review & create")
        try require(result.waitForExistence(timeout: 300), "No analysis result", capture: "analysis")
        screenshot("analysis-result")
    }

    /// Selects `ZSW_SPEECH_MODEL` and downloads it if needed. State: changes
    /// the selected model and may download several hundred MB.
    func testSelectSpeechModel() throws {
        try openOnDeviceModels()
        let selector = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Select model")).firstMatch
        // MISSING-ID: the dropdown's tap target is the top line of the merged button.
        selector.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        try tap(any("label CONTAINS %@", Config.speechModel), Config.speechModel)
        Thread.sleep(forTimeInterval: 1)
        try require(selector.label.contains(Config.speechModel), "Selection not shown", capture: "model-select")
        let download = app.buttons["Download"].firstMatch
        if download.exists && download.isHittable {
            download.tap()
            try require(app.buttons["Delete"].firstMatch.waitForExistence(timeout: 900), "Model download did not finish", capture: "model-download")
        }
        screenshot("speech-model")
        try home()
    }

    /// Pastes `ZSW_OPENROUTER_KEY` (once) and turns on automatic OpenRouter processing.
    /// State: stores the key in the app and changes the voice policy.
    func testOpenRouterSetup() throws {
        let key = try Config.required("ZSW_OPENROUTER_KEY")
        try connectedHome()
        try openVoiceModels()
        try flip(try switchOnRow("Experimental: on-device processing"), to: false)
        if !prefix("OpenRouter key saved").waitForExistence(timeout: 3) {
            // Flutter exposes the obscured field as a secure or a plain text field.
            let field = app.descendants(matching: .any).matching(NSPredicate(format: "elementType == %d OR elementType == %d",
                XCUIElement.ElementType.secureTextField.rawValue, XCUIElement.ElementType.textField.rawValue)).firstMatch
            try tap(field, "API key field")
            field.typeText(key)
            try tap(exact("Verify and save"), "Verify and save")
            try require(prefix("OpenRouter key saved").waitForExistence(timeout: 30), "Key not accepted", capture: "openrouter-key")
        }
        let automatic = try switchOnRow("Automatically process new recordings")
        try flip(automatic, to: true)
        if exact("Apply").exists { try tap(exact("Apply"), "Apply") }
        Thread.sleep(forTimeInterval: 1)
        screenshot("openrouter-setup")
        try home()
    }

    /// Turns on automatic processing for the connected watch (it is per watch).
    /// State: changes the voice policy.
    func testAutoProcessOn() throws {
        try connectedHome()
        try openVoiceModels()
        try flip(try switchOnRow("Automatically process new recordings"), to: true)
        if exact("Apply").exists { try tap(exact("Apply"), "Apply") }
        Thread.sleep(forTimeInterval: 1)
        try home()
    }

    /// Cancels all queued on-device voice jobs from AI models settings.
    func testCancelLocalJobs() throws {
        try connectedHome()
        try openVoiceModels()
        let cancel = try reveal(exact("Cancel all"), "Cancel all")
        try tap(cancel, "Cancel all")
        try tap(app.buttons["Cancel jobs"].firstMatch, "Cancel jobs")
        try require(any("label CONTAINS 'on-device job'").waitForNonExistence(timeout: 60),
                    "On-device jobs still queued", capture: "cancel-local")
    }

    /// Records the Swedish timer memo from Shell → Quick Actions, then stays on
    /// the home screen for `ZSW_BACKGROUND_SECONDS` while it is processed.
    /// The native journal holds the timings.
    func testVoiceMemoBackground() throws {
        try connectedHome()
        try openDeveloperRoute("Shell", heading: "Shell")
        try tap(containing("Quick Actions"), "Quick Actions")
        let card = try reveal(containing("Voice Memo Test: Swedish timer"), "Swedish timer")
        try tap(card, "Swedish timer")
        print("HIL_MEMO_STARTED")
        try require(containing("Recorded: ").waitForExistence(timeout: 60), "Memo was not recorded", capture: "memo")
        print("HIL_MEMO_RECORDED")
        try sendToBackground(for: Config.backgroundSeconds)
    }

    /// Asks the watch's Chat app a spoken question and waits for the answer.
    /// Needs an OpenRouter key in the app.
    func testChat() throws {
        try recordQuestion("Chat Test (phone speaks)")
    }

    /// Follow-up to `testChat` within its conversation window.
    func testChatReply() throws {
        try recordQuestion("Chat Reply Test (phone speaks)")
    }

    /// Records a question as an ordinary memo; OpenRouter should answer it.
    func testMemoQuestionRouting() throws {
        try recordQuestion("Voice Memo Test: question")
    }

    private func recordQuestion(_ action: String) throws {
        try connectedHome()
        try openDeveloperRoute("Shell", heading: "Shell")
        try tap(containing("Quick Actions"), "Quick Actions")
        try tap(try reveal(containing(action), action), action)
        try require(containing("Recorded: ").waitForExistence(timeout: 60), "Question was not recorded", capture: "chat")
        print("HIL_ASK_RECORDED")
        // The answer is checked on the watch (`chat state`) or in the native journal.
        Thread.sleep(forTimeInterval: Config.backgroundSeconds)
    }

    // MARK: - Background and radio recovery

    /// Home for `ZSW_BACKGROUND_SECONDS`, reopen, expect connected Home.
    /// UI-level only; native receipts prove background data collection.
    func testBackgroundReturn() throws {
        try connectedHome()
        try sendToBackground(for: Config.backgroundSeconds)
        try require(app.buttons["Disconnect"].waitForExistence(timeout: 20), "Connected Home did not return", capture: "bg-return")
        try require(exact("Voice").exists, "Dashboard incomplete after return")
    }

    /// Turns phone Bluetooth off then on in Settings and expects reconnection.
    /// State: toggles the phone's Bluetooth radio (restored on exit).
    func testBluetoothOffOnRecovery() throws {
        let radio = try bluetoothSwitch()
        try require(isOn(radio), "Bluetooth must start on")
        defer {
            settingsApp.activate()
            // The radio can take a while to report on; tapping before that turns it off again.
            let settled = NSPredicate(format: "value == %@", "1")
            if radio.exists && XCTWaiter.wait(for: [expectation(for: settled, evaluatedWith: radio)], timeout: 20) != .completed {
                radio.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
            app.activate()
        }
        try flip(radio, to: false, timeout: 30)
        app.activate()
        try require(containing("Bluetooth is off").waitForExistence(timeout: 10), "App did not report Bluetooth off", capture: "bt-off")
        Thread.sleep(forTimeInterval: 8)
        settingsApp.activate()
        try flip(radio, to: true, timeout: 30)
        app.activate()
        try require(app.buttons["Disconnect"].waitForExistence(timeout: 45), "No reconnection after Bluetooth on", capture: "bt-on")
    }

    // MARK: - Developer tools

    /// Runs the read-only `app state` command over the BLE shell.
    func testShellAppState() throws {
        try openDeveloperRoute("Shell", heading: "Shell")
        try shell("app state", expect: "UI state:")
        screenshot("shell")
        try home()
    }

    /// Crash Reports, File System and Comm Log screens load real data. Read-only.
    func testDeveloperReadOnlyRoutes() throws {
        try openDeveloperRoute("Crash Reports", heading: "Crash Reports")
        try require(any("label BEGINSWITH %@ OR label == %@", "Crash Summary", "No active crash").waitForExistence(timeout: 20),
                    "No crash summary", capture: "crash")
        try openDeveloperRoute("File System", heading: "File System")
        try tap(prefix("Files"), "Files tab", timeout: 20)
        screenshot("filesystem")
        try openDeveloperRoute("Comm Log", heading: "Communication Log")
        try require(any("label MATCHES %@", "[1-9][0-9]*").waitForExistence(timeout: 30), "No communication entries", capture: "comm-log")
        try home()
    }

    /// Enables watch log streaming, waits for entries, disables it again.
    /// State: ends with streaming off.
    func testLogStreaming() throws {
        try openDeveloperRoute("Log Viewer", heading: "Log Viewer")
        // MISSING-ID: the only switch on this screen.
        let stream = app.switches.firstMatch
        try require(stream.waitForExistence(timeout: 15), "No log streaming switch")
        wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: stream)], timeout: 15)
        try flip(stream, to: false)
        try flip(stream, to: true)
        try require(any("label MATCHES %@", "[1-9][0-9]* entries").waitForExistence(timeout: 30), "No log entries", capture: "logs")
        try flip(stream, to: false)
        try home()
    }

    /// Developer > Sync Time. State: sets the watch clock.
    func testSyncTime() throws {
        try openRoute("Developer", heading: "Developer Tools")
        try tap(exact("Sync Time"), "Sync Time")
        screenshot("time-sync")
        try home()
    }

    /// Starts each sensor stream, waits for samples, leaves the screen and
    /// checks the stream stopped. State: ends with every sensor off.
    func testSensorsStartStop() throws {
        let sensors = Config.value("ZSW_SENSORS", "Accelerometer,Sensor Fusion,Gyroscope,Magnetometer,Temperature,Humidity,Pressure,Ambient Light")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for name in sensors {
            try openDeveloperRoute("Sensors", heading: "Sensor Debug")
            let toggle = try switchOnRow(name)
            try require(toggle.isEnabled && !isOn(toggle), "\(name) not available or already on", capture: "sensor-\(name)")
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            let samples = name == "Sensor Fusion"
                ? app.buttons["Reset Orientation"]
                : any("label MATCHES %@", "(?s).*[1-9][0-9]* total samples received.*")
            try require(samples.waitForExistence(timeout: 20), "No samples from \(name)", capture: "sensor-samples-\(name)")
            app.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 1)
            try tap(prefix("Sensors"), "Sensors entry")
            try require(prefix("0 sensors streaming").waitForExistence(timeout: 10), "\(name) kept streaming after close", capture: "sensor-stop-\(name)")
            try home()
        }
    }

    /// Dashboard Restart Watch and wait for the reconnect. State: reboots the watch.
    func testRestartWatch() throws {
        try connectedHome()
        try tap(app.buttons["Restart Watch"], "Restart Watch")
        try tap(app.buttons["Restart"], "Restart confirmation")
        // The dashboard is replaced by the start page as soon as the link drops,
        // often before its snackbar is shown; either proves the restart started.
        let disconnect = app.buttons["Disconnect"]
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline && !exact("Restart command sent to watch").exists && disconnect.exists {
            Thread.sleep(forTimeInterval: 0.25)
        }
        try require(Date() < deadline, "No restart acknowledgement", capture: "restart-ack")
        Thread.sleep(forTimeInterval: 8)
        try require(app.buttons["Disconnect"].waitForExistence(timeout: 90), "Watch did not reconnect", capture: "restart")
    }
}
