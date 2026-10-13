import Foundation
@main struct CoredumpTests {
  static func main() throws {
    let missing = try CompanionCoredump.summary("Failed to read summary (-2)\r\n", code: -2)
    precondition(missing["available"] as? Bool == false)
    let output = "Stored coredumps: 1\r\nFile: main.c\r\nLine: 42\r\nTimestamp: 2026-10-13T08:00:00Z\r\n"
    let stored = try CompanionCoredump.summary(output, code: 0)
    precondition(stored["file"] as? String == "main.c" && stored["line"] as? Int == 42)
    for (text, code) in [(output, -5), (output + "Line: 43\r\n", 0), ("No stored coredumps", -5), (output.replacingOccurrences(of: "Line: 42", with: "Line: -1"), 0)] {
      do { _ = try CompanionCoredump.summary(text, code: code); fatalError("Malformed/failed command was accepted") } catch {}
    }
    print("PASS: coredump absence, metadata, duplicate fields and failed shell exits")
  }
}
