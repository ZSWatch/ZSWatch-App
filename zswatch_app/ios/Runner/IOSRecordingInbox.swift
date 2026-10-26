import Foundation

/// Session-independent source receipts; active transfers belong to a Ready generation.
final class IOSRecordingInbox {
  private weak var owner: IOSCompanionCoordinator?
  private let files: CompanionRecordingFiles
  private let lease = CompanionBackgroundLease()
  private var active: UUID?
  private var foreground = false
  private var pausedBackground = false
  init(owner: IOSCompanionCoordinator, root: URL) { self.owner = owner; files = CompanionRecordingFiles(root: root) }
  private var records: [String: [String: Any]] { owner?.journal.fields["recordings"] as? [String: [String: Any]] ?? [:] }
  private func put(_ key: String, _ record: [String: Any]) throws {
    guard let owner else { return }
    var next = records; next[key] = record
    try owner.publish("recording_receipt", ["recordings": next])
    owner.voice?.receiptChanged()
  }
  func recover() {
    for (key, metadata) in records {
      do {
        if metadata["state"] as? String == "deleted" {
          if metadata["purged"] as? Bool == true { try finishPurge(key); continue }
          try owner?.voice?.removeRecordings([key])
          try files.removeLocal(key, metadata: metadata)
          continue
        }
        if let recovered = try files.recover(key, metadata: metadata) { try put(key, recovered) }
        else if ["downloading", "downloaded"].contains(metadata["state"] as? String ?? "") {
          var next = metadata; next["state"] = "pending"; next.removeValue(forKey: "local_path"); next.removeValue(forKey: "sha256"); try put(key, next)
        }
      } catch {
        var failed = metadata
        // Never turn a durable deletion tombstone back into a sync candidate.
        if metadata["state"] as? String != "deleted" { failed["state"] = "failed" }
        if metadata["purged"] as? Bool == true { failed["purge_pending"] = true }
        failed["error"] = "receipt_unavailable"; try? put(key, failed)
      }
    }
  }
  func update(_ identity: String, title: String?, archived: Bool?) throws {
    guard var record = records[identity], record["purged"] as? Bool != true, title != nil || archived != nil,
          title == nil || (title!.utf8.count <= 256 && !title!.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })) else {
      throw CompanionFailure.invalid("Recording title/archive change required")
    }
    if let title { record["title"] = title.trimmingCharacters(in: .whitespacesAndNewlines) }
    if let archived { record["archived"] = archived }
    try put(identity, record)
  }
  func remove(_ identities: [String]) throws {
    let selected = Set(identities)
    guard !selected.isEmpty, selected.count == identities.count, selected.count <= 100,
          selected.allSatisfy({ records[$0]?["purged"] as? Bool != true && ["downloaded", "deleted"].contains(records[$0]?["state"] as? String ?? "") }), let owner else {
      throw CompanionFailure.invalid("Select up to 100 saved recordings")
    }
    try owner.voice?.removeRecordings(selected)
    var next = records
    for key in selected {
      next[key]?["state"] = "deleted"; next[key]?["deleted_at"] = CompanionJournal.now
      next[key]?.removeValue(forKey: "processing_request")
    }
    try owner.publish("recordings_removed_locally", ["recordings": next])
    // A lost process after the durable tombstone is repaired by recover().
    for key in selected { try files.removeLocal(key, metadata: next[key]!) }
  }
  func purge(_ identities: [String]) throws {
    let selected = Set(identities)
    guard !selected.isEmpty, selected.count == identities.count, selected.count <= 100,
          selected.allSatisfy({ records[$0]?["state"] as? String == "deleted" }), let owner else {
      throw CompanionFailure.invalid("Select up to 100 Recently deleted recordings")
    }
    // Durable intent first. Startup retries cleanup; the recording can never be
    // restored, automatically imported or downloaded after this confirmation.
    var next = records
    for key in selected {
      next[key]?["purged"] = true; next[key]?["purge_pending"] = true
      next[key]?.removeValue(forKey: "title"); next[key]?.removeValue(forKey: "processing_request")
      next[key]?.removeValue(forKey: "local_path")
    }
    try owner.publish("recordings_purge_requested", ["recordings": next])
    for key in selected { try finishPurge(key) }
  }
  private func finishPurge(_ identity: String) throws {
    guard var record = records[identity] else { return }
    guard let voice = owner?.voice else { throw CompanionFailure.unavailable("Voice job storage required for permanent deletion") }
    try voice.purgeRecordings([identity])
    try files.purgeLocal(identity, metadata: record)
    if record["purge_pending"] as? Bool == true || record["error"] != nil {
      record["purge_pending"] = false; record.removeValue(forKey: "error")
      try put(identity, record)
    }
  }
  func restore(_ identity: String) throws {
    guard let record = records[identity], record["state"] as? String == "deleted", record["purged"] as? Bool != true else { throw CompanionFailure.invalid("Deleted recording required") }
    var restored = try files.restoreLocal(identity, metadata: record)
    restored.removeValue(forKey: "deleted_at")
    try put(identity, restored)
    try owner?.voice?.restoreRecordings([identity])
  }
  @discardableResult func receive(_ message: [String: Any]) -> Bool {
    guard let owner, message["t"] as? String == "voice_memo" else { return false }
    if message["action"] as? String == "new" {
      // Firmware's new-event timestamp is stop time. Fetch header/list metadata.
      pausedBackground = false
      try? owner.send("GB({\"t\":\"voice_memo\",\"action\":\"list\"})")
    } else if message["action"] as? String == "list_result", let list = message["recordings"] as? [[String: Any]], list.count <= 512 {
      var next = records
      var deleted = 0
      for raw in list {
        guard let (key, original) = CompanionRecordingFiles.metadata(raw, address: owner.journal.address) else { continue }
        if var existing = next[key] {
          switch existing["state"] as? String {
          case "downloaded", "deleted":
            // Already on the phone (or removed there); the watch copy only fills its list.
            let attempts = CompanionRecordingFiles.integer(existing["watch_delete_attempts"]) ?? 0
            if attempts < Self.maxListRetries, let name = existing["filename"] as? String {
              existing["watch_delete_attempts"] = attempts + 1; next[key] = existing
              deleteOnWatch(name); deleted += 1
            }
          case "failed":
            // Retry a few times while the watch still has the file, so a failed
            // oldest entry does not hide newer recordings forever.
            let retries = CompanionRecordingFiles.integer(existing["list_retries"]) ?? 0
            if retries < Self.maxListRetries {
              existing["state"] = "pending"; existing.removeValue(forKey: "error"); existing["list_retries"] = retries + 1
              next[key] = existing
            }
          default: break
          }
        } else if next.count < 4096 {
          var metadata = original
          // The watch's Chat questions are always answered, even with memo processing off.
          let name = original["filename"] as? String ?? ""
          let question = name.hasPrefix("chat_") || name.hasPrefix("chatr_")
          // Processing preferences apply to every watch; the request keeps its source identity.
          if var policy = owner.journal.fields["voice_processing_policy"] as? [String: Any],
             question || policy["enabled"] as? Bool == true {
            policy["watch_id"] = owner.journal.address
            if question {
              policy["analysis_enabled"] = true
            }
            metadata["processing_request"] = policy
          }
          next[key] = metadata
        }
      }
      let more = message["more"] as? Bool == true
      try? owner.publish("recording_list_received", ["recordings": next,
        "recording_list": ["address": owner.journal.address, "generation": owner.journal.generation,
          "observed_ms": CompanionJournal.now, "count": list.count,
          "result_ack_version": CompanionRecordingFiles.integer(message["result_ack_version"]) == 1 ? 1 : 0,
          "more": more]])
      // The watch lists only its oldest recordings; ask for the next page after deletions.
      if deleted > 0 && more { requestList() }
      downloadNext()
    }
    return true
  }
  private static let maxListRetries = 3
  private func deleteOnWatch(_ name: String) {
    guard let owner, let data = try? JSONSerialization.data(withJSONObject: ["t": "voice_memo", "action": "delete", "filename": name]),
          let json = String(data: data, encoding: .utf8) else { return }
    try? owner.send("GB(\(json))")
  }
  private func requestList() { try? owner?.send("GB({\"t\":\"voice_memo\",\"action\":\"list\"})") }
  func foregrounded() { foreground = true; pausedBackground = false; downloadNext() }
  func backgrounded() {
    foreground = false
    if let token = active { expireAfterWindow(token) }
  }
  func closed() { active = nil; lease.end() }
  private func expireAfterWindow(_ token: UUID) {
    owner?.queue.asyncAfter(deadline: .now() + 20) { [weak self] in
      guard let self, !self.foreground, self.active == token else { return }
      self.expire(token)
    }
  }
  private func expire(_ token: UUID) {
    guard active == token else { return }
    pausedBackground = true
    owner?.smp.cancelActive("Recording download paused when background time expired")
  }
  func resumeSync() { pausedBackground = false; downloadNext() }
  func pauseSync() {
    if active != nil { pausedBackground = true; owner?.smp.cancelActive("Recording sync disabled") }
  }
  func retryFailed() throws {
    guard let owner else { return }
    var next = records
    for (key, var record) in next where record["address"] as? String == owner.journal.address && record["state"] as? String == "failed" {
      record["state"] = "pending"; record.removeValue(forKey: "error"); next[key] = record
    }
    try owner.publish("recording_retry", ["recordings": next]); pausedBackground = false; downloadNext()
  }
  func downloadNext() {
    guard let owner, active == nil, !pausedBackground, owner.journal.fields["recording_sync_enabled"] as? Bool != false,
          owner.isReadySession(owner.journal.generation), owner.smp.isIdle,
          let (key, metadata) = records.sorted(by: { $0.key < $1.key }).first(where: {
            $0.value["address"] as? String == owner.journal.address && $0.value["state"] as? String == "pending"
          }), let size = CompanionRecordingFiles.integer(metadata["size_bytes"]), let name = metadata["filename"] as? String else { return }
    let token = UUID(); active = token
    func finish(_ error: Error?, interrupted: Bool = false, verified: Bool = false) {
      guard self.active == token else { return }
      self.active = nil; self.lease.end()
      do {
        let metadata = self.records[key] ?? metadata
        if let error {
          var next = metadata; next["state"] = interrupted ? "pending" : "failed"
          next["error"] = String(error.localizedDescription.prefix(160)); try self.put(key, next)
        } else {
          try self.put(key, self.files.publish(key, metadata: metadata))
          // Delete the watch copy only when the phone copy matches the watch's hash.
          if verified { self.deleteOnWatch(name) }
          let list = owner.journal.fields["recording_list"] as? [String: Any]
          let pending = self.records.values.contains { $0["address"] as? String == owner.journal.address && $0["state"] as? String == "pending" }
          if list?["more"] as? Bool == true && !pending { self.requestList() }
        }
      } catch { var next = metadata; next["state"] = "failed"; next["error"] = "receipt_publish_failed"; try? self.put(key, next) }
      owner.queue.asyncAfter(deadline: .now() + 0.5) { self.downloadNext() }
    }
    do {
      if let receipt = try files.recover(key, metadata: metadata) { try put(key, receipt); active = nil; downloadNext(); return }
      let prefix = try files.prefix(key, expected: size)
      var next = metadata; next["state"] = "downloading"; try put(key, next)
      lease.hold("ZSWatch recording download") { [weak self] in owner.queue.async { self?.expire(token) } }
      if !foreground { expireAfterWindow(token) }
      try owner.smp.prepare(owner.journal.generation) { result in
        guard self.active == token else { return }
        do {
          guard let generation = try result.get()["generation"] as? Int else { throw CompanionFailure.invalid("Invalid recording session") }
          try owner.smp.downloadRecording(generation, path: "/user/recordings/\(name).zsw_opus", expected: size, prefix: prefix,
            append: { offset, bytes in try self.files.append(key, offset: offset, bytes: bytes, expected: size) },
            complete: { result in
              switch result {
              case .success(let value):
                let local = (try? Data(contentsOf: self.files.partial(key))).map(CompanionRecordingFiles.sha)
                guard let watch = value["watch_sha256"] as? String else { finish(nil); break } // Older firmware: keep the watch copy.
                if watch == local { finish(nil, verified: true) }
                else {
                  // Corrupted transfer: start over from byte 0 and keep the watch copy (bounded).
                  try? FileManager.default.removeItem(at: self.files.partial(key))
                  var record = self.records[key] ?? metadata
                  let retries = CompanionRecordingFiles.integer(record["verify_retries"]) ?? 0
                  record["verify_retries"] = retries + 1; try? self.put(key, record)
                  finish(CompanionFailure.invalid("Recording hash differs from the watch"), interrupted: retries < 2)
                }
              case .failure(let error): finish(error, interrupted: !owner.isReadySession(generation) || self.pausedBackground)
              }
            })
        } catch { finish(error, interrupted: !owner.journal.desired || self.pausedBackground) }
      }
    } catch { finish(error) }
  }
}
