import Foundation

/// The native journal owns job attempts; the shared Dart processor owns inference.
final class CompanionVoiceJobs {
  struct Claim { let id: String; let fence: Int; let spec: [String: Any] }
  let journal: CompanionJournal
  private(set) var jobs: [String: [String: Any]]
  init(journal: CompanionJournal) throws {
    self.journal = journal
    guard journal.fields["jobs"] == nil || journal.fields["jobs"] is [String: [String: Any]] else { throw CompanionFailure.storage("Invalid voice journal") }
    jobs = journal.fields["jobs"] as? [String: [String: Any]] ?? [:]
    for (id, item) in jobs {
      guard let spec = item["spec"] as? [String: Any], Self.sha(try Self.canonical(spec)) == id,
            item["state"] is String, CompanionRecordingFiles.integer(item["fence"]) != nil else { throw CompanionFailure.storage("Invalid voice job") }
    }
  }
  static func canonical(_ value: Any) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed])
    return String(data: data, encoding: .utf8)!
  }
  static func sha(_ text: String) -> String { CompanionRecordingFiles.sha(Data(text.utf8)) }
  static let cloudPrefix = "openrouter:"
  static func isCloud(_ model: String) -> Bool { model.hasPrefix(cloudPrefix) }
  /// Jobs whose models run on OpenRouter; the key is passed per execution.
  static func isCloudJob(_ spec: [String: Any]?) -> Bool { spec?["backend"] as? String == "openrouter" }
  static func configuration(_ stt: String, _ llm: String, _ correct: Bool, analyze: Bool = true) throws -> [String: Any] {
    guard stt.range(of: "^([A-Za-z0-9_]{1,128}|openrouter:[A-Za-z0-9._:/-]{1,200})$", options: .regularExpression) != nil,
          !llm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, llm.utf8.count <= 256, !llm.contains("|") else {
      throw CompanionFailure.invalid("Invalid local model configuration")
    }
    return ["transcription_model": stt, "analysis_model": llm, "correct_transcription": correct, "analysis_enabled": analyze]
  }
  private func commit(_ event: String, _ next: [String: [String: Any]]) throws {
    try journal.update(event, ["jobs": next, "voice_jobs": Self.summary(next)])
    jobs = next
  }
  static func summary(_ jobs: [String: [String: Any]]) -> [[String: Any]] {
    jobs.sorted(by: { $0.key < $1.key }).compactMap { id, item in
      guard let spec = item["spec"] as? [String: Any] else { return nil }
      var result = spec
      result["job_id"] = id; result["state"] = item["state"]; result["selected"] = item["selected"] ?? false
      result["processing"] = item["lease_until"] is Int; result["transcript_saved"] = item["transcript"] is String
      if let body = item["result"] as? [String: Any] {
        result["category"] = body["category"] ?? ""
        result["action_types"] = (body["actions"] as? [[String: Any]] ?? []).compactMap { $0["type"] as? String }
      }
      for key in ["attempts", "deferred_attempts", "next_attempt", "last_error", "action_revision", "undo_until"] { result[key] = item[key] ?? NSNull() }
      result["undone"] = item["undone"] as? Bool ?? false; result["auto_created"] = item["auto_created"] as? Bool ?? false
      return result
    }
  }
  func recover() throws {
    var next = jobs
    for (id, var item) in next where item["lease_until"] is NSNumber {
      item["fence"] = (item["fence"] as? Int ?? 0) + 1; item["lease_until"] = NSNull()
      if item["state"] as? String == "ready" { item["last_error"] = "execution_interrupted" }
      next[id] = item
    }
    // iOS has no local LLM: local analysis jobs from older builds can never run.
    for (id, item) in next where ["ready", "blocked"].contains(item["state"] as? String ?? "") &&
      (item["spec"] as? [String: Any])?["pipeline_revision"] as? String == "voice-v1" && !Self.isCloudJob(item["spec"] as? [String: Any]) {
      next[id]?["state"] = "failed"; next[id]?["last_error"] = "analysis_unavailable"
      next[id]?["fence"] = (item["fence"] as? Int ?? 0) + 1
    }
    try commit("voice_process_recovered", next)
  }
  func start(identity: String, receipt: [String: Any], stt: String, llm: String, correct: Bool, operation: String) throws -> String {
    let transcribeOnly = ["transcribe", "retranscribe"].contains(operation)
    guard transcribeOnly || (["process", "reanalyze"].contains(operation) && Self.isCloud(llm)) else {
      throw CompanionFailure.unavailable("On-device analysis is not available on iOS")
    }
    guard receipt["state"] as? String == "downloaded", let hash = receipt["sha256"] as? String,
          let address = receipt["address"] as? String else { throw CompanionFailure.invalid("Verified recording receipt required") }
    _ = try Self.configuration(stt, llm, correct)
    let model = "\(stt)|\(llm)|\(correct)"; let revision = transcribeOnly ? "transcribe-v1" : "voice-v1"
    let cloud = Self.isCloud(stt) || Self.isCloud(llm)
    let prior = jobs.filter { ($0.value["spec"] as? [String: Any])?["recording_id"] as? String == identity }
    let selected = prior.values.first(where: { $0["selected"] as? Bool == true }) ?? prior.values.max(by: {
      (($0["spec"] as? [String: Any])?["generation"] as? Int ?? 0) < (($1["spec"] as? [String: Any])?["generation"] as? Int ?? 0)
    })
    let transcript = (selected?["result"] as? [String: Any])?["transcript"] as? String ?? selected?["transcript"] as? String
    let reuseTranscript = operation == "reanalyze" || (operation == "process" &&
      (selected?["spec"] as? [String: Any])?["pipeline_revision"] as? String == "transcript-edit-v1")
    guard operation != "reanalyze" || transcript?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { throw CompanionFailure.unavailable("Transcribe this recording first") }
    var next = jobs
    func select(_ id: String) { for key in prior.keys { next[key]?["selected"] = key == id } }
    if !["retranscribe", "reanalyze"].contains(operation), !reuseTranscript, let existing = prior.first(where: {
      let spec = $0.value["spec"] as? [String: Any]
      return spec?["model"] as? String == model && spec?["pipeline_revision"] as? String == revision &&
        spec?["input_sha256"] as? String == hash && !["failed", "cancelled"].contains($0.value["state"] as? String ?? "")
    }) {
      select(existing.key)
      if next[existing.key]?["state"] as? String == "blocked" { next[existing.key]?["state"] = "ready"; next[existing.key]?["last_error"] = NSNull(); next[existing.key]?["attempts"] = 0; next[existing.key]?["deferred_attempts"] = 0 }
      try commit("voice_job_selected", next); return existing.key
    }
    Self.pruneSuperseded(&next, incoming: identity)
    guard Self.hasRoom(next) else { throw CompanionFailure.unavailable("Voice job capacity reached") }
    let generation = (prior.values.map { ($0["spec"] as? [String: Any])?["generation"] as? Int ?? 0 }.max() ?? 0) + 1
    let spec: [String: Any] = ["version": 1, "watch_id": address, "recording_id": identity, "input_sha256": hash,
      "backend": cloud ? "openrouter" : "local", "provider": "dart-voice-v1", "model": model, "pipeline_revision": revision,
      "generation": generation, "upload_authorized": cloud]
    let id = Self.sha(try Self.canonical(spec))
    for key in prior.keys {
      next[key]?["selected"] = false
      if next[key]?["state"] as? String != "delivered" {
        next[key]?["state"] = "cancelled"; next[key]?["fence"] = (jobs[key]?["fence"] as? Int ?? 0) + 1; next[key]?["lease_until"] = NSNull()
      }
    }
    var item: [String: Any] = ["spec": spec, "state": "ready", "fence": 0, "lease_until": NSNull(),
      "attempts": 0, "deferred_attempts": 0, "next_attempt": 0, "last_error": NSNull(), "remote_id": NSNull(), "selected": true]
    if reuseTranscript { item["transcript"] = transcript }
    next[id] = item; try commit("voice_job_created", next); return id
  }
  // Finished jobs hold the user's transcripts and results; only pending work
  // is bounded, plus a generous total journal bound.
  private static let activeLimit = 100, totalLimit = 2000
  private static func recording(_ item: [String: Any]) -> String { (item["spec"] as? [String: Any])?["recording_id"] as? String ?? "" }
  private static func generation(_ item: [String: Any]) -> Int { (item["spec"] as? [String: Any])?["generation"] as? Int ?? 0 }
  private static func hasRoom(_ jobs: [String: [String: Any]]) -> Bool {
    jobs.values.filter { ["ready", "blocked"].contains($0["state"] as? String ?? "") }.count < activeLimit && jobs.count < totalLimit
  }
  /// Drop failed/cancelled jobs without a result that a newer generation of the
  /// same recording replaced. The incoming job is newer than every job of its recording.
  private static func pruneSuperseded(_ jobs: inout [String: [String: Any]], incoming identity: String) {
    var latest: [String: Int] = [:]
    for item in jobs.values { latest[recording(item)] = max(latest[recording(item)] ?? 0, generation(item)) }
    latest[identity] = Int.max
    for (id, item) in jobs where ["failed", "cancelled"].contains(item["state"] as? String ?? "") && item["result"] == nil &&
      (item["selected"] as? Bool != true || recording(item) == identity) && generation(item) < latest[recording(item)] ?? 0 {
      jobs.removeValue(forKey: id)
    }
  }
  func claim(_ id: String) throws -> Claim? {
    guard var item = jobs[id], item["state"] as? String == "ready", (item["lease_until"] as? Int ?? 0) <= CompanionJournal.now,
          (CompanionRecordingFiles.integer(item["next_attempt"]) ?? 0) <= CompanionJournal.now,
          let spec = item["spec"] as? [String: Any] else { return nil }
    let attempts = (item["attempts"] as? Int ?? 0) + 1
    // Deliberate lifecycle pauses fence/cancel work but are not inference
    // failures. Keep total claim telemetry while bounding unclean restarts.
    let deferred = min(CompanionRecordingFiles.integer(item["deferred_attempts"]) ?? 0, attempts - 1)
    guard attempts - deferred <= 5 else { try fail(id, code: "execution_attempt_limit"); return nil }
    let fence = (item["fence"] as? Int ?? 0) + 1
    item["fence"] = fence; item["attempts"] = attempts; item["lease_until"] = CompanionJournal.now + 900000; item["last_error"] = NSNull()
    var next = jobs; next[id] = item; try commit("voice_job_claimed", next)
    return Claim(id: id, fence: fence, spec: spec)
  }
  func owns(_ claim: Claim) -> Bool {
    guard let item = jobs[claim.id] else { return false }
    return item["fence"] as? Int == claim.fence && item["state"] as? String == "ready" &&
      (item["lease_until"] as? Int ?? 0) > CompanionJournal.now
  }
  func checkpoint(_ claim: Claim, transcript: String) throws -> Bool {
    guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, transcript.utf8.count <= 65536 else { throw CompanionFailure.invalid("Invalid transcript checkpoint") }
    guard owns(claim) else { return false }
    if let saved = jobs[claim.id]?["transcript"] as? String, saved != transcript { throw CompanionFailure.invalid("Transcript checkpoint changed") }
    var next = jobs; next[claim.id]?["transcript"] = transcript; try commit("voice_transcript_committed", next); return true
  }
  func deferClaim(_ claim: Claim, code: String, delayMs: Int = 0) throws {
    guard jobs[claim.id]?["state"] as? String == "ready", jobs[claim.id]?["fence"] as? Int == claim.fence else { return }
    var next = jobs; next[claim.id]?["fence"] = claim.fence + 1; next[claim.id]?["lease_until"] = NSNull(); next[claim.id]?["last_error"] = code
    next[claim.id]?["next_attempt"] = delayMs > 0 ? CompanionJournal.now + delayMs : 0
    next[claim.id]?["deferred_attempts"] = (jobs[claim.id]?["deferred_attempts"] as? Int ?? 0) + 1
    try commit("voice_execution_deferred", next)
  }
  func fail(_ id: String, code: String, blocked: Bool = false) throws {
    guard jobs[id] != nil else { throw CompanionFailure.invalid("Unknown voice job") }
    var next = jobs; next[id]?["state"] = blocked ? "blocked" : "failed"; next[id]?["lease_until"] = NSNull(); next[id]?["last_error"] = code
    next[id]?["fence"] = (jobs[id]?["fence"] as? Int ?? 0) + 1
    try commit("voice_job_failed", next)
  }
  /// A new key or top-up: queue every job that waited for it.
  @discardableResult func unblockCloud() throws -> Bool {
    var next = jobs; var changed = false
    for (id, item) in jobs where item["state"] as? String == "blocked" && (item["last_error"] as? String ?? "").hasPrefix("cloud_") {
      next[id]?["state"] = "ready"; next[id]?["last_error"] = NSNull(); next[id]?["attempts"] = 0
      next[id]?["deferred_attempts"] = 0; next[id]?["next_attempt"] = 0; changed = true
    }
    if changed { try commit("voice_cloud_unblocked", next) }
    return changed
  }
  /// Earliest time a deferred ready job may run again.
  var nextAttempt: Int? {
    jobs.values.filter { $0["state"] as? String == "ready" }.compactMap { CompanionRecordingFiles.integer($0["next_attempt"]) }
      .filter { $0 > CompanionJournal.now }.min()
  }
  func cancel(_ id: String) throws {
    guard jobs[id] != nil else { throw CompanionFailure.invalid("Unknown voice job") }
    var next = jobs; next[id]?["state"] = "cancelled"; next[id]?["fence"] = (jobs[id]?["fence"] as? Int ?? 0) + 1; next[id]?["lease_until"] = NSNull()
    try commit("voice_job_cancelled", next)
  }
  func cancelRecordings(_ identities: Set<String>) throws {
    var next = jobs
    for (id, item) in jobs where identities.contains((item["spec"] as? [String: Any])?["recording_id"] as? String ?? "") {
      next[id]?["fence"] = (item["fence"] as? Int ?? 0) + 1
      next[id]?["lease_until"] = NSNull()
      // Retain completed results and action receipts for Recently deleted/undo.
      if ["ready", "blocked", "result_ready"].contains(item["state"] as? String ?? "") {
        next[id]?["state"] = "cancelled"
      }
    }
    try commit("voice_recordings_removed", next)
  }
  func purgeRecordings(_ identities: Set<String>) throws {
    let next = jobs.filter { !identities.contains(($0.value["spec"] as? [String: Any])?["recording_id"] as? String ?? "") }
    if next.count != jobs.count { try commit("voice_recordings_purged", next) }
  }
  func editTranscript(_ id: String, transcript: String) throws -> String {
    guard let original = jobs[id], original["selected"] as? Bool == true,
          let spec = original["spec"] as? [String: Any], let identity = spec["recording_id"] as? String,
          (original["result"] as? [String: Any])?["transcript"] is String || original["transcript"] is String,
          !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          transcript.utf8.count <= 64000 else { throw CompanionFailure.invalid("Current saved transcript required (maximum 64 KB)") }
    let prior = jobs.filter { ($0.value["spec"] as? [String: Any])?["recording_id"] as? String == identity }
    var changedSpec = spec
    changedSpec["pipeline_revision"] = "transcript-edit-v1"
    changedSpec["transcript_sha256"] = Self.sha(transcript)
    changedSpec["generation"] = (prior.values.map { ($0["spec"] as? [String: Any])?["generation"] as? Int ?? 0 }.max() ?? 0) + 1
    let editedID = Self.sha(try Self.canonical(changedSpec))
    var next = jobs
    Self.pruneSuperseded(&next, incoming: identity)
    guard Self.hasRoom(next) else { throw CompanionFailure.unavailable("Voice job capacity reached") }
    for (key, item) in prior {
      next[key]?["selected"] = false
      next[key]?["fence"] = (item["fence"] as? Int ?? 0) + 1; next[key]?["lease_until"] = NSNull()
      if ["ready", "blocked", "result_ready"].contains(item["state"] as? String ?? "") { next[key]?["state"] = "cancelled" }
    }
    next[editedID] = ["spec": changedSpec, "state": "transcribed", "selected": true, "fence": 0,
      "lease_until": NSNull(), "attempts": 0, "deferred_attempts": 0, "next_attempt": 0, "last_error": NSNull(),
      "transcript": transcript, "result": ["version": 1, "transcript": transcript, "summary": "", "category": "", "actions": [[String: Any]]()]]
    try commit("voice_transcript_edited", next); return editedID
  }
  func search(_ query: String) -> Set<String> {
    var matches = Set<String>()
    for item in jobs.values where item["selected"] as? Bool == true {
      guard let identity = (item["spec"] as? [String: Any])?["recording_id"] as? String else { continue }
      let body = item["result"] as? [String: Any]
      var texts = [item["transcript"] as? String ?? "", body?["transcript"] as? String ?? "", body?["summary"] as? String ?? ""]
      for action in body?["actions"] as? [[String: Any]] ?? [] { texts += action.values.compactMap { $0 as? String } }
      if texts.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { matches.insert(identity) }
    }
    return matches
  }
  static func validate(_ result: [String: Any], transcriptionOnly: Bool) throws {
    guard Set(result.keys) == ["version", "transcript", "summary", "category", "actions"],
          CompanionRecordingFiles.integer(result["version"]) == 1,
          let transcript = result["transcript"] as? String, let summary = result["summary"] as? String,
          let category = result["category"] as? String, let actions = result["actions"] as? [[String: Any]], actions.count <= 64,
          // An Ask AI answer to silence or a setup problem has no transcript.
          category == "ask_ai" || !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          transcriptionOnly ? summary.isEmpty && category.isEmpty && actions.isEmpty : !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          (try canonical(result)).utf8.count <= 65536 else { throw CompanionFailure.invalid("Invalid voice result") }
    for action in actions {
      guard let type = action["type"] as? String, ["task", "calendar_event", "reminder", "timer", "alarm"].contains(type),
            let title = action["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            Set(action.keys).isSubset(of: ["type", "title", "due_date", "start_time", "notes", "location", "duration_seconds"]) else { throw CompanionFailure.invalid("Invalid action draft") }
      for key in ["due_date", "start_time", "notes", "location"] where action[key] != nil { guard action[key] is String else { throw CompanionFailure.invalid("Invalid action field") } }
      if action["duration_seconds"] != nil { guard let seconds = CompanionRecordingFiles.integer(action["duration_seconds"]), seconds > 0 else { throw CompanionFailure.invalid("Invalid action duration") } }
    }
  }
  func complete(_ claim: Claim, result: [String: Any]) throws -> Bool {
    guard owns(claim) else { return false }
    let only = claim.spec["pipeline_revision"] as? String == "transcribe-v1"
    try Self.validate(result, transcriptionOnly: only)
    var next = jobs; next[claim.id]?["result"] = result; next[claim.id]?["lease_until"] = NSNull(); next[claim.id]?["last_error"] = NSNull()
    next[claim.id]?["state"] = only ? "transcribed" : "result_ready"
    if !only { next[claim.id]?["undo_until"] = CompanionJournal.now + Self.undoWindowMs }
    if only { next[claim.id]?["transcript"] = result["transcript"] }
    try commit("voice_result_committed", next); return true
  }
  private func actionItem(_ id: String, index: Int) throws -> [String: Any] {
    guard let item = jobs[id],
          let actions = (item["result"] as? [String: Any])?["actions"] as? [[String: Any]], actions.indices.contains(index) else {
      throw CompanionFailure.invalid("Accepted action draft required")
    }
    return item
  }
  private func saveAction(_ id: String, index: Int, state: [String: Any]?, event: String) throws {
    var next = jobs
    var states = next[id]?["action_states"] as? [String: [String: Any]] ?? [:]
    states[String(index)] = state
    next[id]?["action_states"] = states
    next[id]?["action_revision"] = (jobs[id]?["action_revision"] as? Int ?? 0) + 1
    try commit(event, next)
  }
  func beginAction(_ id: String, index: Int, draft: [String: Any]) throws -> [String: Any] {
    let item = try actionItem(id, index: index)
    guard ["result_ready", "delivered"].contains(item["state"] as? String ?? "") else { throw CompanionFailure.invalid("Accepted action draft required") }
    let actions = (item["result"] as! [String: Any])["actions"] as! [[String: Any]]
    guard draft["actionType"] as? String == actions[index]["type"] as? String,
          let title = draft["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          title.utf8.count <= 4096, (try Self.canonical(draft)).utf8.count <= 32768 else { throw CompanionFailure.invalid("Invalid confirmed action") }
    if let previous = (item["action_states"] as? [String: [String: Any]])?[String(index)] {
      guard previous["state"] as? String == "creating" else { throw CompanionFailure.unavailable("Action already handled") }
      return previous
    }
    var action: [String: Any] = ["state": "creating", "draft": draft]
    if draft["actionType"] as? String == "timer" {
      guard let duration = CompanionRecordingFiles.integer(draft["durationSeconds"]), (1...604800).contains(duration) else { throw CompanionFailure.invalid("Invalid timer duration") }
      action["fire_utc_ms"] = CompanionJournal.now + duration * 1000
    }
    try saveAction(id, index: index, state: action, event: "voice_action_confirmed"); return action
  }
  func admitAction(_ id: String, index: Int) throws {
    let item = try actionItem(id, index: index)
    guard var action = (item["action_states"] as? [String: [String: Any]])?[String(index)], action["state"] as? String == "creating" else { throw CompanionFailure.invalid("Action confirmation expired") }
    action["effect_admitted"] = true
    try saveAction(id, index: index, state: action, event: "voice_action_admitted")
  }
  func finishAction(_ id: String, index: Int, response: [String: Any]) throws {
    let item = try actionItem(id, index: index)
    guard var action = (item["action_states"] as? [String: [String: Any]])?[String(index)], action["state"] as? String == "creating" else { throw CompanionFailure.invalid("Action confirmation expired") }
    let type = (action["draft"] as? [String: Any])?["actionType"] as? String ?? ""
    action["state"] = ["timer", "alarm"].contains(type) ? "dispatched" : "created"; action["response"] = response
    try saveAction(id, index: index, state: action, event: "voice_action_created")
  }
  func releaseAction(_ id: String, index: Int) throws {
    let item = try actionItem(id, index: index)
    guard (item["action_states"] as? [String: [String: Any]])?[String(index)]?["state"] as? String == "creating" else { return }
    try saveAction(id, index: index, state: nil, event: "voice_action_not_created")
  }
  func dismissAction(_ id: String, index: Int) throws {
    let item = try actionItem(id, index: index)
    guard (item["action_states"] as? [String: [String: Any]])?[String(index)] == nil else { throw CompanionFailure.unavailable("Action already handled") }
    try saveAction(id, index: index, state: ["state": "dismissed"], event: "voice_action_dismissed")
  }
  func beginUndo(_ id: String, index: Int) throws -> [String: Any] {
    let item = try actionItem(id, index: index)
    guard var action = (item["action_states"] as? [String: [String: Any]])?[String(index)],
          ["created", "undoing"].contains(action["state"] as? String ?? "") else { throw CompanionFailure.invalid("Created action required") }
    action["state"] = "undoing"; try saveAction(id, index: index, state: action, event: "voice_action_undo_started"); return action
  }
  func finishUndo(_ id: String, index: Int) throws {
    let item = try actionItem(id, index: index)
    guard var action = (item["action_states"] as? [String: [String: Any]])?[String(index)], action["state"] as? String == "undoing" else { throw CompanionFailure.invalid("Undo attempt expired") }
    action["state"] = "undone"; try saveAction(id, index: index, state: action, event: "voice_action_undone")
  }
  func deliveryPacket(_ id: String, filename: String) throws -> [String: Any] {
    guard let item = jobs[id], item["state"] as? String == "result_ready", item["undone"] as? Bool != true,
          let spec = item["spec"] as? [String: Any],
          let result = item["result"] as? [String: Any], let summary = result["summary"] as? String,
          let generation = spec["generation"] as? Int, (1...0xffffffff).contains(generation),
          let identity = spec["recording_id"] as? String,
          filename.range(of: "^[A-Za-z0-9_-]{1,31}$", options: .regularExpression) != nil else { throw CompanionFailure.invalid("Invalid voice delivery") }
    let first = (result["actions"] as? [[String: Any]])?.first
    // Ask AI answers use the watch's larger answer buffer.
    let answer = result["category"] as? String == "ask_ai"
    func bounded(_ text: String, _ size: Int) -> String {
      var value = ""
      for char in text { if (value + String(char)).utf8.count > size { break }; value.append(char) }
      return value
    }
    return ["t": "voice_memo", "action": "result", "version": 1,
      "result_id": Self.sha("result-v1:" + id), "recording_key": Self.sha(identity),
      "result_sha256": Self.sha(try Self.canonical(result)), "generation": generation, "filename": filename,
      "text": bounded(summary, answer ? 1023 : 127), "action_type": answer ? "ask_ai" : first?["type"] as? String ?? "",
      "datetime": bounded(first?["start_time"] as? String ?? first?["due_date"] as? String ?? "", 31)]
  }
  func acknowledge(_ id: String, ack: [String: Any], filename: String) throws -> Bool {
    guard ack["t"] as? String == "voice_memo", ack["action"] as? String == "result_ack",
          CompanionRecordingFiles.integer(ack["version"]) == 1, ack["status"] as? String == "accepted" else { return false }
    let packet = try deliveryPacket(id, filename: filename)
    for key in ["result_id", "recording_key", "result_sha256"] {
      guard let value = ack[key] as? String, value == packet[key] as? String else { return false }
    }
    guard CompanionRecordingFiles.integer(ack["generation"]) == packet["generation"] as? Int else { return false }
    var next = jobs; next[id]?["state"] = "delivered"
    // The watch shows its Undo from now on; give it the whole window.
    if let until = next[id]?["undo_until"] as? Int { next[id]?["undo_until"] = max(until, CompanionJournal.now + Self.undoWindowMs) }
    try commit("voice_delivery_acked", next); return true
  }
  /// Matches the watch popup's auto-dismiss (AUTO_DISMISS_MS).
  static let undoWindowMs = 20_000
  /// Undo from the watch or phone: nothing from this result is created and the watch is not told again.
  func undo(_ id: String) throws -> Bool {
    guard var item = jobs[id], ["result_ready", "delivered"].contains(item["state"] as? String ?? ""), item["undo_until"] is Int,
          item["undone"] as? Bool != true, item["auto_created"] as? Bool != true,
          let actions = (item["result"] as? [String: Any])?["actions"] as? [[String: Any]] else { return false }
    var states = item["action_states"] as? [String: [String: Any]] ?? [:]
    for index in actions.indices where states[String(index)] == nil { states[String(index)] = ["state": "dismissed"] }
    item["action_states"] = states; item["undone"] = true
    item["action_revision"] = (item["action_revision"] as? Int ?? 0) + 1
    var next = jobs; next[id] = item; try commit("voice_result_undone", next); return true
  }
  /// Selected results whose undo window has ended and that were neither undone nor auto-created.
  func undoPending() -> [(id: String, until: Int)] {
    jobs.compactMap { id, item in
      guard ["result_ready", "delivered"].contains(item["state"] as? String ?? ""), item["selected"] as? Bool == true,
            let until = item["undo_until"] as? Int, item["undone"] as? Bool != true, item["auto_created"] as? Bool != true else { return nil }
      return (id, until)
    }
  }
  func markAutoCreated(_ id: String) throws {
    var next = jobs; next[id]?["auto_created"] = true; try commit("voice_result_auto_created", next)
  }
  func detail(_ id: String) throws -> [String: Any] {
    guard var item = jobs[id] else { throw CompanionFailure.invalid("Unknown voice job") }
    item["processing"] = item["lease_until"] is NSNumber; item["transcript_saved"] = item["transcript"] is String
    return item
  }
}
