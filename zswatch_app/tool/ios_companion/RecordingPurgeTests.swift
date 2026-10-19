import Foundation

// Only platform scheduling/BLE are replaced; the entire real Inbox, file store,
// durable journal and voice-job store compile and execute below.
final class CompanionBackgroundLease {
  func hold(_ name: String, expired: @escaping () -> Void) {}
  func end() {}
}
final class PurgeVoice {
  let jobs: CompanionVoiceJobs
  var failPurge = false
  init(_ journal: CompanionJournal) throws { jobs = try CompanionVoiceJobs(journal: journal) }
  func receiptChanged() {}
  func removeRecordings(_ identities: Set<String>) throws { try jobs.cancelRecordings(identities) }
  func purgeRecordings(_ identities: Set<String>) throws {
    if failPurge { throw CompanionFailure.storage("Injected interruption after durable purge intent") }
    try jobs.purgeRecordings(identities)
  }
}
final class PurgeSmp {
  var isIdle: Bool { true }
  func cancelActive(_ reason: String) { fatalError("Purge attempted SMP cancellation") }
  func prepare(_ generation: Int, _ complete: @escaping (Result<[String: Any], Error>) -> Void) throws { fatalError("Purge attempted SMP preparation") }
  func downloadRecording(_ generation: Int, path: String, expected: Int, prefix: Data,
    append: @escaping (Int, Data) throws -> Void, complete: @escaping (Result<Void, Error>) -> Void) throws { fatalError("Purge attempted watch download") }
}
final class IOSCompanionCoordinator {
  let journal: CompanionJournal
  let queue = DispatchQueue(label: "purge-host-owner")
  let smp = PurgeSmp()
  var voice: PurgeVoice?
  init(root: URL) throws {
    journal = CompanionJournal(url: root.appendingPathComponent("state.json"))
    voice = try PurgeVoice(journal)
  }
  func publish(_ name: String, _ changes: [String: Any]) throws { try journal.update(name, changes) }
  func isReadySession(_ generation: Int) -> Bool { false }
  func send(_ packet: String) throws { fatalError("Local purge attempted a watch command") }
}
@main struct RecordingPurgeTests {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let owner = try IOSCompanionCoordinator(root: root)
    let files = CompanionRecordingFiles(root: root)
    let address = "FE88C737-593F-DB9B-732D-E11FF4C463F5"
    var bytes = Data(repeating: 0, count: 36)
    func u(_ value: UInt32, _ offset: Int, _ count: Int) { for i in 0..<count { bytes[offset+i] = UInt8((value >> (8*i)) & 255) } }
    bytes.replaceSubrange(0..<4, with: Data("ZSWO".utf8)); u(1,4,2); u(16000,6,2); u(160,8,2); u(1000,16,4); u(1,20,4); u(10,24,4); u(2,32,2)
    var records: [String: [String: Any]] = [:]; var keys: [String] = []
    for name in ["selected", "untouched"] {
      let (key, metadata) = CompanionRecordingFiles.metadata(["filename": name, "timestamp":1000, "size_bytes":36, "duration_ms":10], address:address)!
      try files.append(key, offset:0, bytes:bytes, expected:36)
      let receipt = try files.recover(key, metadata:metadata)!
      records[key] = receipt; keys.append(key)
      let id = try owner.voice!.jobs.start(identity:key, receipt:receipt, stt:"whisperTinyEn", llm:"qwen", correct:false, operation:"transcribe")
      let claim = try owner.voice!.jobs.claim(id)!
      let saved = try owner.voice!.jobs.complete(claim, result:["version":1,"transcript":"Private saved speech", "summary":"", "category":"", "actions":[[String:Any]]()]); precondition(saved)
    }
    try owner.publish("fixture", ["recordings":records, "address":address, "desired_running":false])
    let inbox = IOSRecordingInbox(owner:owner, root:root)
    do { try inbox.purge([keys[0]]); fatalError("Live recording accepted for purge") } catch {}
    try inbox.remove([keys[0]])
    owner.voice!.failPurge = true
    do { try inbox.purge([keys[0]]); fatalError("Injected interruption did not occur") } catch {}
    let interrupted = (owner.journal.fields["recordings"] as! [String:[String:Any]])[keys[0]]!
    precondition(interrupted["purged"] as? Bool == true && interrupted["purge_pending"] as? Bool == true)
    // Unavailable job storage must not claim cleanup or destroy unrelated data.
    let absent = try IOSCompanionCoordinator(root:root); absent.voice = nil
    IOSRecordingInbox(owner:absent, root:root).recover()
    let waiting = (absent.journal.fields["recordings"] as! [String:[String:Any]])[keys[0]]!
    precondition(waiting["purge_pending"] as? Bool == true)
    precondition(FileManager.default.fileExists(atPath:files.destination(keys[1]).path))
    // Actual restart repairs the durable intent and removes all selected revisions.
    let restored = try IOSCompanionCoordinator(root:root)
    let recovered = IOSRecordingInbox(owner:restored, root:root); recovered.recover()
    let complete = (restored.journal.fields["recordings"] as! [String:[String:Any]])[keys[0]]!
    precondition(complete["purged"] as? Bool == true && complete["purge_pending"] as? Bool == false)
    precondition(!restored.voice!.jobs.jobs.values.contains { ($0["spec"] as? [String:Any])?["recording_id"] as? String == keys[0] })
    precondition(restored.voice!.jobs.jobs.count == 1)
    precondition(FileManager.default.fileExists(atPath:files.destination(keys[1]).path))
    do { try recovered.restore(keys[0]); fatalError("Purge was restored") } catch {}
    _ = recovered.receive(["t":"voice_memo", "action":"list_result", "recordings":[["filename":"selected", "timestamp":1000, "size_bytes":36, "duration_ms":10]]])
    let afterList = (restored.journal.fields["recordings"] as! [String:[String:Any]])[keys[0]]!
    precondition(afterList["state"] as? String == "deleted" && afterList["purged"] as? Bool == true)
    recovered.recover(); precondition(restored.voice!.jobs.jobs.count == 1)
    print("PASS: actual Inbox purge intent, interruption/unavailable-job recovery, selected-only cleanup and no watch redownload")
  }
}
