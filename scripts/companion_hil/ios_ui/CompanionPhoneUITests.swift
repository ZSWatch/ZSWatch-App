import XCTest

/// Drives the installed normal app. It does not install an app or change pairing.
final class CompanionPhoneUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "dev.zswatch.companion")
    private func element(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
    private func require(_ value: Bool, _ message: String) throws {
        guard value else { XCTFail(message); throw NSError(domain: "ZSWatchPhoneAcceptance", code: 1) }
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func connectedHome() throws {
        app.activate(); Thread.sleep(forTimeInterval: 1)
        for _ in 0..<5 {
            if app.buttons["Disconnect"].exists && app.buttons["Disconnect"].isHittable { return }
            if app.buttons["Close"].exists { app.buttons["Close"].tap() }
            else if app.buttons["Back"].exists { app.buttons["Back"].tap() }
            else { break }
            Thread.sleep(forTimeInterval: 1)
        }
        try require(false, "Connect the selected watch in the normal app before this check")
    }
    func testConnectedRoutes() throws {
        try connectedHome()
        for (name, heading) in [("Health", "Health"), ("Notifications", "Notifications"),
                                ("Analytics", "Analytics"), ("Watchface", "Watchface Background"),
                                ("Developer", "Developer Tools"), ("Voice", "Voice Notes")] {
            let entry = element(name)
            try require(entry.waitForExistence(timeout: 10), "Missing \(name) entry"); entry.tap()
            try require(app.buttons["Back"].waitForExistence(timeout: 10), "Missing \(name) Back")
            try require(element(heading).exists, "Missing \(heading) screen")
            if name == "Health" {
                for label in ["Week", "Month", "Today"] {
                    let tab = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
                    try require(tab.exists, "Missing \(label) range"); tab.tap(); Thread.sleep(forTimeInterval: 1)
                }
            }
            screenshot("route-\(name)"); app.buttons["Back"].tap(); Thread.sleep(forTimeInterval: 1)
            try require(app.buttons["Disconnect"].waitForExistence(timeout: 10), "Home no longer connected after \(name)")
        }
    }
    func testReadOnlyShell() throws {
        try connectedHome(); element("Developer").tap()
        let shell = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Shell")).firstMatch
        try require(shell.waitForExistence(timeout: 10), "Missing Shell entry"); shell.tap()
        let input = app.textFields.firstMatch
        try require(input.waitForExistence(timeout: 10), "Missing shell input")
        input.tap(); input.typeText("app state")
        let send = app.keyboards.buttons["Send"]
        try require(send.waitForExistence(timeout: 5), "Missing keyboard Send"); send.tap()
        let reply = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "UI state:", "UI state:")).firstMatch
        try require(reply.waitForExistence(timeout: 20), "No actual watch response")
        screenshot("read-only-shell"); try connectedHome()
    }
    func testBackgroundReturn() throws {
        try connectedHome()
        XCUIDevice.shared.press(.home)
        try require(app.wait(for: .runningBackground, timeout: 10), "App did not enter background")
        print("HIL_COMPANION_BACKGROUND_ENTERED")
        Thread.sleep(forTimeInterval: 20)
        app.activate()
        try require(app.buttons["Disconnect"].waitForExistence(timeout: 20), "Connected Home did not return")
        screenshot("background-return")
    }

}
