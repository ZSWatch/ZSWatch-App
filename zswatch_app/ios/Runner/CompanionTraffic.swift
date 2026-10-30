import Foundation

/// Process-local NUS history owned by the companion queue, independent of Flutter.
/// Payloads are bounded and never written to the journal.
final class CompanionTraffic {
  private var history: [[String: Any]] = []
  private var totalBytes = 0
  private var sequence = 0
  var replay: [[String: Any]] { history }

  /// Retain valid traffic with a monotonically increasing delivery identity.
  @discardableResult
  func append(_ event: [String: Any]) -> [String: Any]? {
    guard let bytes = event["size_bytes"] as? Int, (1...65536).contains(bytes) else { return nil }
    while !history.isEmpty && (history.count >= 5000 || totalBytes + bytes > 5 * 1024 * 1024) {
      totalBytes -= history.removeFirst()["size_bytes"] as! Int
    }
    sequence += 1
    var captured = event; captured["sequence"] = sequence
    history.append(captured); totalBytes += bytes
    return captured
  }

  /// Return a cutoff for queued events without reusing IDs after Clear.
  @discardableResult
  func clear() -> Int { history.removeAll(); totalBytes = 0; return sequence }
}
