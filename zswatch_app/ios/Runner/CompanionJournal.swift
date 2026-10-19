import Foundation
import CoreFoundation

enum CompanionFailure: LocalizedError {
  case invalid(String), unavailable(String), storage(String)
  var errorDescription: String? {
    switch self {
    case .invalid(let message), .unavailable(let message), .storage(let message): return message
    }
  }
}

/// Native control/receipts only. Flutter remains the sole writer of its Drift DB.
/// The coordinator serializes access; files retain normal first-unlock protection.
final class CompanionJournal {
  let url: URL
  private(set) var fields: [String: Any]
  private(set) var loadError: String?

  init(url: URL) {
    self.url = url
    fields = ["generation": 0, "event_cursor": 0, "address": "",
              "desired_running": false, "phase": "stopped", "events": [], "acked_cursor": 0,
              "recordings": [:], "voice_jobs": [], "forgotten_watches": [:],
              "journal_id": UUID().uuidString, "telemetry": [], "telemetry_sequence": 0,
              "telemetry_acked": 0, "telemetry_dropped": 0,
              "http_enabled": true, "gps_enabled": false, "recording_sync_enabled": true]
    if FileManager.default.fileExists(atPath: url.path) {
      do {
        let value = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        guard let saved = value as? [String: Any],
              let generation = saved["generation"] as? NSNumber,
              CFGetTypeID(generation) != CFBooleanGetTypeID(), generation.intValue >= 0,
              generation.doubleValue == Double(generation.intValue),
              let intent = saved["desired_running"] as? NSNumber,
              CFGetTypeID(intent) == CFBooleanGetTypeID(),
              let address = saved["address"] as? String,
              (!intent.boolValue || UUID(uuidString: address)?.uuidString == address) else {
          throw CompanionFailure.storage("Invalid companion journal")
        }
        fields.merge(saved) { _, saved in saved }
      } catch {
        // Do not overwrite an unreadable/protected/corrupt journal or restore intent by guess.
        loadError = "Companion storage unavailable"
      }
    }
  }

  var generation: Int { fields["generation"] as? Int ?? 0 }
  var cursor: Int { fields["event_cursor"] as? Int ?? 0 }
  var address: String { fields["address"] as? String ?? "" }
  var desired: Bool { fields["desired_running"] as? Bool == true && loadError == nil }

  func update(_ event: String, _ changes: [String: Any] = [:]) throws {
    guard loadError == nil else { throw CompanionFailure.storage(loadError!) }
    var next = fields
    next.merge(changes) { _, new in new }
    let cursor = self.cursor + 1
    next["event_cursor"] = cursor
    var events = next["events"] as? [[String: Any]] ?? []
    events.append(["seq": cursor, "kind": event, "utc_ms": Self.now,
                   "generation": next["generation"] ?? generation])
    next["events"] = Array(events.suffix(128))
    let data = try JSONSerialization.data(withJSONObject: next, options: [.sortedKeys])
    do {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      #if os(iOS)
      try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
      #else
      try data.write(to: url, options: .atomic)
      #endif
      fields = next
    } catch {
      loadError = "Companion storage unavailable"
      throw error
    }
  }

  @discardableResult func start(_ id: String) throws -> Int {
    guard let uuid = UUID(uuidString: id) else { throw CompanionFailure.invalid("Expected an iOS peripheral UUID") }
    if desired {
      guard address == uuid.uuidString else { throw CompanionFailure.unavailable("Stop before choosing another watch") }
      return generation
    }
    try update("start", ["address": uuid.uuidString, "desired_running": true,
                         "generation": generation + 1, "phase": "connecting", "last_error": NSNull()])
    return generation
  }

  func stop() throws {
    try update("stop", ["desired_running": false, "generation": generation + 1,
                        "phase": "stopped", "last_error": NSNull()])
  }

  func forget(_ id: String) throws {
    guard let uuid = UUID(uuidString: id) else { throw CompanionFailure.invalid("Expected an iOS peripheral UUID") }
    let id = uuid.uuidString
    if address == id {
      try stop()
      try update("selection_forgotten", ["address": "", "watch_info": NSNull(), "last_ready": NSNull(),
        "telemetry": (fields["telemetry"] as? [[String: Any]] ?? []).filter { $0["address"] as? String != id }])
    }
    var forgotten = fields["forgotten_watches"] as? [String: Int] ?? [:]
    forgotten[id] = generation
    try update("forget", ["forgotten_watches": forgotten,
      "telemetry": (fields["telemetry"] as? [[String: Any]] ?? []).filter { $0["address"] as? String != id },
      "forget_receipt": ["address": id, "generation": generation, "selection_removed": true,
                         "association_removed": false, "system_unpair_required": true]])
  }

  func telemetryChanges(kind: String, payload: [String: Any]) -> [String: Any] {
    let sequence = (fields["telemetry_sequence"] as? Int ?? 0) + 1
    var pending = fields["telemetry"] as? [[String: Any]] ?? []
    pending.append(["sequence": sequence, "kind": kind, "address": address,
                    "generation": generation, "utc_ms": Self.now, "payload": payload])
    let dropped = max(0, pending.count - 8192)
    return ["telemetry": Array(pending.suffix(8192)), "telemetry_sequence": sequence,
            "telemetry_dropped": (fields["telemetry_dropped"] as? Int ?? 0) + dropped]
  }

  func ackTelemetry(_ sequence: Int) throws {
    guard sequence >= (fields["telemetry_acked"] as? Int ?? 0),
          sequence <= (fields["telemetry_sequence"] as? Int ?? 0) else {
      throw CompanionFailure.invalid("Invalid telemetry acknowledgement")
    }
    let pending = fields["telemetry"] as? [[String: Any]] ?? []
    try update("telemetry_projected", ["telemetry_acked": sequence,
      "telemetry": pending.filter { ($0["sequence"] as? Int ?? 0) > sequence }])
  }

  func owns(_ generation: Int, _ id: String) -> Bool {
    desired && self.generation == generation && address == id
  }
  static var now: Int { Int(Date().timeIntervalSince1970 * 1000) }
}
