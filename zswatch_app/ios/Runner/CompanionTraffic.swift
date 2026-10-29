import Foundation

/// Process-local NUS history owned by the companion queue, independent of Flutter.
/// Payloads are bounded and never written to the journal.
final class CompanionTraffic {
  private var history: [[String: Any]] = []
  private var totalBytes = 0
  var replay: [[String: Any]] { history }

  @discardableResult
  func append(_ event: [String: Any]) -> Bool {
    guard let bytes = event["size_bytes"] as? Int, (1...65536).contains(bytes) else { return false }
    while !history.isEmpty && (history.count >= 5000 || totalBytes + bytes > 5 * 1024 * 1024) {
      totalBytes -= history.removeFirst()["size_bytes"] as! Int
    }
    history.append(event); totalBytes += bytes
    return true
  }

  func clear() { history.removeAll(); totalBytes = 0 }
}
