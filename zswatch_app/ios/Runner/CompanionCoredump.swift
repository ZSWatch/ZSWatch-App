import Foundation

struct CompanionCoredump {
  static func summary(_ output: String, code: Int) throws -> [String: Any] {
    guard output.utf8.count <= 8192 else { throw CompanionFailure.invalid("Coredump summary too large") }
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    if code == -2 && trimmed == "Failed to read summary (-2)" || code == 0 && trimmed == "No stored coredumps" {
      return ["available": false]
    }
    guard code == 0 else { throw CompanionFailure.unavailable("Coredump summary command failed") }
    func field(_ key: String) throws -> String {
      let matches = output.components(separatedBy: .newlines).compactMap { line -> String? in
        let line = line.trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix(key + ":") else { return nil }
        return String(line.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
      }
      guard matches.count == 1 else { throw CompanionFailure.invalid("Invalid coredump \(key)") }
      return matches[0]
    }
    guard let count = Int(try field("Stored coredumps")), (1...32).contains(count),
          let line = Int(try field("Line")), line >= 0 else { throw CompanionFailure.invalid("Invalid coredump count or line") }
    let file = try field("File"); let time = try field("Timestamp")
    guard file.utf8.count <= 512, !time.isEmpty, time.utf8.count <= 80 else { throw CompanionFailure.invalid("Invalid coredump metadata") }
    return ["available": true, "file": file, "line": line, "time": time]
  }
}
