import Foundation

/// Metadata/state and resource-format validation only. Nordic encodes SMP and
/// parses MCUboot images; no transfer payload is persisted in the journal.
enum CompanionFirmwareContract {
  static let maxBytes = 8 * 1024 * 1024
  static let active: Set<String> = ["validating", "resource_uploading", "resource_verifying", "uploading", "applying", "rebooting", "reconnecting", "verifying"]
  struct Target {
    let index: Int
    let bytes: Int
    let hash: String
    var metadata: [String: Any] { ["index": index, "bytes": bytes, "hash": hash] }
  }
  struct Report { let index: Int; let hash: String; let active: Bool }
  static func targets(_ values: [Target], resources: Data?) throws {
    guard (!values.isEmpty || resources != nil), values.count <= 3,
          Set(values.map(\.index)).count == values.count,
          values.allSatisfy({ (0...2).contains($0.index) && (1...maxBytes).contains($0.bytes) &&
            $0.hash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil }) else {
      throw CompanionFailure.invalid("One to three distinct SDK firmware images required")
    }
  }
  static func checkActive(_ targets: [Target], reports: [Report]) throws {
    guard targets.allSatisfy({ target in reports.contains { $0.index == target.index } }) else {
      throw CompanionFailure.unavailable("boot_check_unavailable")
    }
    guard targets.allSatisfy({ target in reports.contains { $0.index == target.index && $0.active && $0.hash == target.hash } }) else {
      throw CompanionFailure.unavailable("boot_check_failed")
    }
  }
  static func resources(_ bytes: Data, hardware: String) throws {
    guard hardware.range(of: "^(watchdk@1|zswatch@(1|4|5))(/nrf5340/cpuapp)?$", options: .regularExpression) != nil else {
      throw CompanionFailure.invalid("Resource partition size is unknown for this watch")
    }
    try resourceTable(bytes)
  }
  static func resourceTable(_ bytes: Data) throws {
    guard (20...maxBytes).contains(bytes.count), bytes.count % 4 == 0 else { throw CompanionFailure.invalid("Invalid resource size") }
    func u32(_ at: Int) -> Int {
      (0..<4).reduce(0) { $0 | Int(bytes[at + $1]) << (8 * $1) }
    }
    let count = u32(12), header = u32(4), size = u32(8)
    guard u32(0) == 0x0a0a0a0a, u32(bytes.count - 4) == 0x0a0a0a0a,
          size == bytes.count, (1...800).contains(count), header == 16 + 40 * count,
          header <= size - 4 else { throw CompanionFailure.invalid("Invalid resource table envelope") }
    var names = Set<String>(); var spans: [(Int, Int)] = []
    for index in 0..<count {
      let at = 16 + 40 * index
      let raw = bytes.subdata(in: at..<at + 32)
      let end = raw.firstIndex(of: 0) ?? raw.count
      guard let name = String(data: raw.prefix(end), encoding: .utf8), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            ![".", ".."].contains(name), !name.contains("/"), !name.contains("\\"),
            !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }), names.insert(name).inserted else {
        throw CompanionFailure.invalid("Invalid or duplicate resource name")
      }
      let offset = u32(at + 32), length = u32(at + 36), available = size - header - 4
      guard offset <= available, length <= available - offset else { throw CompanionFailure.invalid("Resource file exceeds payload") }
      if length > 0 { spans.append((offset, offset + length)) }
    }
    spans.sort { $0.0 < $1.0 }
    for pair in zip(spans, spans.dropFirst()) where pair.0.1 > pair.1.0 { throw CompanionFailure.invalid("Resource files overlap") }
  }
}

final class CompanionFirmwareOperation {
  let journal: CompanionJournal
  private(set) var state: [String: Any]?
  init(journal: CompanionJournal) { self.journal = journal; state = journal.fields["firmware_operation"] as? [String: Any] }
  var busy: Bool { CompanionFirmwareContract.active.contains(state?["phase"] as? String ?? "") }
  var id: String? { state?["id"] as? String }
  func recover() throws {
    if busy { try terminal("failed", error: "interrupted", unknown: state?["effect_admitted"] as? Bool == true) }
  }
  private func commit(_ event: String, _ next: [String: Any]) throws {
    try journal.update(event, ["firmware_operation": next]); state = next
  }
  func begin(address: String, generation: Int, targets: [CompanionFirmwareContract.Target], resources: Data?) throws -> String {
    guard !busy, UUID(uuidString: address)?.uuidString == address, generation > 0 else { throw CompanionFailure.unavailable("Firmware operation already active or session invalid") }
    try CompanionFirmwareContract.targets(targets, resources: resources)
    let id = UUID().uuidString
    var next: [String: Any] = ["id": id, "address": address, "generation": generation, "phase": "validating",
      "current": 0, "total": targets.first?.bytes ?? resources?.count ?? 0, "targets": targets.map(\.metadata),
      "resource_verified": false, "images_verified": false, "result_unknown": false, "cancel_requested": false, "error": NSNull(),
      "effect_admitted": false, "started_utc_ms": CompanionJournal.now, "progress_scope": "current_image"]
    if let resources { next["resource"] = ["bytes": resources.count, "hash": CompanionRecordingFiles.sha(resources)] }
    try commit("firmware_accepted", next); return id
  }
  func phase(_ phase: String) throws {
    guard busy, CompanionFirmwareContract.active.contains(phase), var next = state else { throw CompanionFailure.invalid("Firmware phase expired") }
    next["phase"] = phase; next["current"] = 0
    try commit("firmware_phase", next)
  }
  func admitted() throws {
    guard busy, var next = state else { throw CompanionFailure.invalid("Firmware operation expired") }
    next["effect_admitted"] = true; try commit("firmware_effect_admitted", next)
  }
  func progress(_ current: Int, total: Int) throws {
    guard busy, (0...CompanionFirmwareContract.maxBytes).contains(total), (0...total).contains(current), var next = state else {
      throw CompanionFailure.invalid("Invalid SDK progress")
    }
    // Nordic reports the current image, without an image index. A new image
    // can reset progress even when both selected images have the same size.
    next["current"] = current; next["total"] = total; try commit("firmware_progress", next)
  }
  func verifiedResource() throws {
    guard busy, state?["resource"] is [String: Any], var next = state else { throw CompanionFailure.invalid("Resource operation expired") }
    next["resource_verified"] = true; try commit("resource_verified", next)
  }
  func verifiedImages(_ targets: [CompanionFirmwareContract.Target], reports: [CompanionFirmwareContract.Report]) throws {
    guard busy, var next = state else { throw CompanionFailure.invalid("Firmware operation expired") }
    guard let expected = next["targets"] as? [[String: Any]], expected.count == targets.count,
          zip(expected, targets).allSatisfy({ raw, target in
            CompanionRecordingFiles.integer(raw["index"]) == target.index &&
            CompanionRecordingFiles.integer(raw["bytes"]) == target.bytes && raw["hash"] as? String == target.hash
          }) else {
      throw CompanionFailure.invalid("Firmware verification targets changed")
    }
    try CompanionFirmwareContract.checkActive(targets, reports: reports)
    next["images_verified"] = true; try commit("active_images_verified", next)
  }
  func requestCancel() throws {
    guard busy, state?["phase"] as? String == "uploading", state?["resource"] == nil, var next = state else {
      throw CompanionFailure.unavailable("Cancellation is available during a firmware-only upload")
    }
    next["cancel_requested"] = true; try commit("firmware_cancel_requested", next)
  }
  func terminal(_ phase: String, error: String? = nil, unknown: Bool = false) throws {
    guard busy, ["completed", "failed", "cancelled"].contains(phase), var next = state else { return }
    guard phase != "completed" || (error == nil && !unknown && next["images_verified"] as? Bool == true &&
      (next["resource"] == nil || next["resource_verified"] as? Bool == true)) else {
      throw CompanionFailure.invalid("Unverified firmware operation cannot complete")
    }
    next["phase"] = phase; next["error"] = error.map { $0 as Any } ?? NSNull(); next["result_unknown"] = unknown
    next["finished_utc_ms"] = CompanionJournal.now
    if phase == "completed" { next["current"] = next["total"] }
    try commit("firmware_terminal", next)
  }
}
