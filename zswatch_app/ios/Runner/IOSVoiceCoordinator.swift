import BackgroundTasks
import Foundation
import UIKit
import UserNotifications

/// Scheduling policy is native; inference and local model selection stay Dart.
final class IOSVoiceCoordinator {
  static let backgroundID = "dev.zswatch.companion.voice.processing.v1"
  private weak var owner: IOSCompanionCoordinator?
  let jobs: CompanionVoiceJobs
  private let files: CompanionRecordingFiles
  private let worker: IOSDartVoiceWorker
  private var foreground = false
  private var scheduled = false
  private var background: BGProcessingTask?
  private var backgroundFailed = false
  private var deliveries: [String: (generation: Int, count: Int, token: UUID)] = [:]
  private var claim: CompanionVoiceJobs.Claim?
  private var executing = false
  private var undoTimer: DispatchWorkItem?
  private var undoBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  init(owner: IOSCompanionCoordinator, root: URL) throws {
    self.owner = owner; files = CompanionRecordingFiles(root: root)
    jobs = try CompanionVoiceJobs(journal: owner.journal); worker = IOSDartVoiceWorker(queue: owner.queue)
    try jobs.recover()
  }
  /// Diagnostic engine/plugin proof only: no audio, model or watch mutation.
  func verifyWorker(_ complete: @escaping (Result<[String: Any], Error>) -> Void) throws {
    guard !executing, foreground else { throw CompanionFailure.unavailable("Open the app with no processing job running") }
    executing = true
    let id = "ios-worker-proof-" + UUID().uuidString
    let spec: [String: Any] = ["version": 1, "backend": "local", "provider": "dart-fixture", "upload_authorized": false,
      "watch_id": "fixture-watch", "recording_id": "fixture-recording-local-001", "model": "deterministic-v1",
      "pipeline_revision": "voice-v1", "generation": 1,
      "input_sha256": "effa60b67bee0f4d8da64cc35755a07a1e7535b2ed0ced083ce34bdd7d22ff18"]
    worker.execute(id: id, spec: spec, input: [:], checkpoint: { _ in false }) { [weak self] result in
      self?.executing = false; complete(result); self?.advance()
    }
  }
  func configure(_ args: [String: Any]) throws {
    guard let watch = args["watch_id"] as? String, UUID(uuidString: watch)?.uuidString == watch,
          let enabled = args["enabled"] as? Bool, let stt = args["transcription_model"] as? String,
          let llm = args["analysis_model"] as? String, let correct = args["correct_transcription"] as? Bool,
          let analyze = args["analysis_enabled"] as? Bool, let owner else { throw CompanionFailure.invalid("Voice policy required") }
    var config = try CompanionVoiceJobs.configuration(stt, llm, correct, analyze: analyze)
    config["watch_id"] = watch; config["enabled"] = enabled
    try owner.publish("voice_processing_policy", ["voice_processing_policy": config])
  }
  func start(_ args: [String: Any]) throws -> String {
    guard let identity = args["identity"] as? String, let stt = args["transcription_model"] as? String,
          let llm = args["analysis_model"] as? String, let correct = args["correct_transcription"] as? Bool,
          let owner, let metadata = (owner.journal.fields["recordings"] as? [String: [String: Any]])?[identity], metadata["state"] as? String == "downloaded",
          let receipt = try files.recover(identity, metadata: metadata), receipt["sha256"] as? String == metadata["sha256"] as? String else {
      throw CompanionFailure.invalid("Verified local recording required")
    }
    let id = try jobs.start(identity: identity, receipt: receipt, stt: stt, llm: llm, correct: correct,
      operation: args["operation"] as? String ?? "process")
    fenceObsoleteWorker(); owner.journalChanged(); advance(); return id
  }
  func cancel(_ id: String) throws {
    try jobs.cancel(id); fenceObsoleteWorker(); owner?.journalChanged(); advance()
  }
  func removeRecordings(_ identities: Set<String>) throws {
    try jobs.cancelRecordings(identities); fenceObsoleteWorker(); owner?.journalChanged()
  }
  func purgeRecordings(_ identities: Set<String>) throws {
    try jobs.purgeRecordings(identities); fenceObsoleteWorker(); owner?.journalChanged()
  }
  func editTranscript(_ id: String, transcript: String) throws -> String {
    guard let identity = (jobs.jobs[id]?["spec"] as? [String: Any])?["recording_id"] as? String,
          let record = (owner?.journal.fields["recordings"] as? [String: [String: Any]])?[identity],
          record["state"] as? String != "deleted" else { throw CompanionFailure.invalid("Restore this recording before editing") }
    let next = try jobs.editTranscript(id, transcript: transcript)
    fenceObsoleteWorker(); owner?.journalChanged(); return next
  }
  private func fenceObsoleteWorker() {
    if let claim, !jobs.owns(claim) { self.claim = nil; worker.cancel(claim.id) }
  }
  func foregrounded() { foreground = true; advance() }
  func inactive() {
    foreground = false
    if background == nil { deferExecution("background_deferred") }
    schedule()
  }
  func stopped() { deferExecution("watch_session_stopped") }
  private func deferExecution(_ code: String) {
    guard let current = claim else { return }
    try? jobs.deferClaim(current, code: code); claim = nil
    owner?.journalChanged(); worker.cancel(current.id)
  }
  func grant(_ task: BGProcessingTask) {
    guard background == nil else { task.setTaskCompleted(success: false); return }
    scheduled = false; background = task; backgroundFailed = false
    task.expirationHandler = { [weak self, weak task] in
      guard let self, let task, let owner = self.owner else { return }
      owner.queue.async {
        guard self.background === task else { return }
        self.deferExecution("background_expired"); self.background = nil
        task.setTaskCompleted(success: false); self.schedule()
      }
    }
    try? owner?.publish("voice_background_granted", ["voice_execution": ["mode": "scheduled_cpu", "granted_utc_ms": CompanionJournal.now]])
    advance()
  }
  private func schedule() {
    guard !scheduled, jobs.jobs.values.contains(where: { $0["state"] as? String == "ready" }) else { return }
    let request = BGProcessingTaskRequest(identifier: Self.backgroundID)
    request.requiresExternalPower = false; request.requiresNetworkConnectivity = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(request); scheduled = true
      try? owner?.publish("voice_background_scheduled", ["voice_execution": ["mode": "waiting_for_ios", "scheduled": true]])
    } catch {
      try? owner?.publish("voice_background_unavailable", ["voice_execution": ["mode": "foreground_required", "scheduled": false]])
    }
  }
  func receiptChanged() { enqueueAutomatic(); advance(); deliverResults() }
  private func enqueueAutomatic() {
    guard let owner, let records = owner.journal.fields["recordings"] as? [String: [String: Any]] else { return }
    for (identity, receipt) in records where receipt["state"] as? String == "downloaded" {
      guard let request = receipt["processing_request"] as? [String: Any],
            let stt = request["transcription_model"] as? String, let llm = request["analysis_model"] as? String,
            let correct = request["correct_transcription"] as? Bool else { continue }
      let model = "\(stt)|\(llm)|\(correct)"; let revision = request["analysis_enabled"] as? Bool == false ? "transcribe-v1" : "voice-v1"
      if jobs.jobs.values.contains(where: {
        guard let spec = $0["spec"] as? [String: Any] else { return false }
        return spec["recording_id"] as? String == identity && spec["model"] as? String == model &&
          spec["pipeline_revision"] as? String == revision && spec["input_sha256"] as? String == receipt["sha256"] as? String
      }) { continue }
      do {
        _ = try jobs.start(identity: identity, receipt: receipt, stt: stt, llm: llm, correct: correct,
          operation: revision == "transcribe-v1" ? "transcribe" : "process")
        owner.journalChanged()
      } catch { /* Capacity/model errors leave the verified recording intact. */ }
    }
  }
  func sessionClosed() { deliveries.removeAll() }
  func deliverResults() {
    guard let owner, owner.isReadySession(owner.journal.generation),
          let list = owner.journal.fields["recording_list"] as? [String: Any],
          list["generation"] as? Int == owner.journal.generation, list["result_ack_version"] as? Int == 1 else { return }
    let generation = owner.journal.generation
    for (id, item) in jobs.jobs where item["state"] as? String == "result_ready" {
      guard let spec = item["spec"] as? [String: Any], spec["watch_id"] as? String == owner.journal.address,
            let identity = spec["recording_id"] as? String,
            let record = (owner.journal.fields["recordings"] as? [String: [String: Any]])?[identity], let name = record["filename"] as? String else { continue }
      let previous = deliveries[id]
      if previous?.generation == generation { continue }
      sendResult(id, name: name, generation: generation, attempt: 1)
    }
  }
  private func sendResult(_ id: String, name: String, generation: Int, attempt: Int) {
    guard let owner, owner.isReadySession(generation), jobs.jobs[id]?["state"] as? String == "result_ready" else { return }
    do {
      let packet = try jobs.deliveryPacket(id, filename: name)
      let command = "GB(\(try CompanionVoiceJobs.canonical(packet)))"
      guard command.utf8.count < 1900 else { return }
      let token = UUID(); deliveries[id] = (generation, attempt, token)
      try owner.send(command, admission: { [weak self] in
        self?.deliveries[id]?.token == token && self?.jobs.jobs[id]?["state"] as? String == "result_ready" && owner.isReadySession(generation)
      })
      owner.queue.asyncAfter(deadline: .now() + 8) { [weak self] in
        guard let self, self.deliveries[id]?.token == token, attempt < 3 else { return }
        self.sendResult(id, name: name, generation: generation, attempt: attempt + 1)
      }
    } catch { /* Pending result remains durable for the next Ready session. */ }
  }
  @discardableResult func receiveAck(_ message: [String: Any]) -> Bool {
    guard message["t"] as? String == "voice_memo", message["action"] as? String == "result_ack", let owner else { return false }
    for (id, item) in jobs.jobs where item["state"] as? String == "result_ready" {
      guard let spec = item["spec"] as? [String: Any], spec["watch_id"] as? String == owner.journal.address,
            let identity = spec["recording_id"] as? String,
            let filename = (owner.journal.fields["recordings"] as? [String: [String: Any]])?[identity]?["filename"] as? String else { continue }
      if (try? jobs.acknowledge(id, ack: message, filename: filename)) == true {
        deliveries.removeValue(forKey: id); owner.journalChanged(); resultReady(id); break
      }
    }
    return true
  }
  /// Undo on the watch popup for [filename].
  @discardableResult func receiveUndo(_ message: [String: Any]) -> Bool {
    guard message["t"] as? String == "voice_memo", message["action"] as? String == "undo_last", let owner else { return false }
    let filename = message["filename"] as? String
    let records = owner.journal.fields["recordings"] as? [String: [String: Any]] ?? [:]
    if let id = jobs.jobs.first(where: { _, item in
      guard item["selected"] as? Bool == true, let spec = item["spec"] as? [String: Any],
            spec["watch_id"] as? String == owner.journal.address, let identity = spec["recording_id"] as? String else { return false }
      return records[identity]?["filename"] as? String == filename
    })?.key { undo(id) }
    return true
  }
  @discardableResult func undo(_ id: String) -> Bool {
    let undone = (try? jobs.undo(id)) == true
    if undone { VoiceUndoNotification.remove(id); owner?.journalChanged(); scheduleUndo() }
    return undone
  }
  /// A result is ready or the watch received it: (re)start the phone Undo and the creation timer.
  func resultReady(_ id: String) {
    guard let item = jobs.jobs[id], let result = item["result"] as? [String: Any], let until = item["undo_until"] as? Int,
          item["selected"] as? Bool == true, item["undone"] as? Bool != true, item["auto_created"] as? Bool != true else { scheduleUndo(); return }
    let actions = result["actions"] as? [[String: Any]] ?? []
    if autoCreateEnabled, actions.contains(where: { IOSCompanionActions.autoDraft($0) != nil }) {
      VoiceUndoNotification.show(id, result: result, until: until)
    }
    scheduleUndo()
  }
  private var autoCreateEnabled: Bool {
    (owner?.journal.fields["voice_actions"] as? [String: Any])?["auto_create"] as? Bool != false
  }
  /// Runs createExpired when the next window ends; background time keeps a suspended app alive for it.
  func scheduleUndo() {
    undoTimer?.cancel(); undoTimer = nil
    guard let next = jobs.undoPending().map(\.until).min() else { endUndoBackgroundTask(); return }
    if undoBackgroundTask == .invalid {
      DispatchQueue.main.async {
        guard self.undoBackgroundTask == .invalid else { return }
        self.undoBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "voice-undo-window") { [weak self] in
          self?.endUndoBackgroundTask()
        }
      }
    }
    let work = DispatchWorkItem { [weak self] in self?.createExpired(); self?.scheduleUndo() }
    undoTimer = work
    owner?.queue.asyncAfter(deadline: .now() + .milliseconds(max(0, next - CompanionJournal.now)), execute: work)
  }
  private func endUndoBackgroundTask() {
    DispatchQueue.main.async {
      guard self.undoBackgroundTask != .invalid else { return }
      UIApplication.shared.endBackgroundTask(self.undoBackgroundTask); self.undoBackgroundTask = .invalid
    }
  }
  /// Creates every schedulable action of results whose undo window ended.
  func createExpired() {
    guard let owner else { return }
    for (id, until) in jobs.undoPending() where until <= CompanionJournal.now {
      VoiceUndoNotification.remove(id)
      let item = jobs.jobs[id] ?? [:]
      let actions = (item["result"] as? [String: Any])?["actions"] as? [[String: Any]] ?? []
      let handled = item["action_states"] as? [String: Any] ?? [:]
      try? jobs.markAutoCreated(id)
      // Off: the result stays for Review & create in the app.
      guard autoCreateEnabled else { continue }
      for (index, action) in actions.enumerated() where handled[String(index)] == nil {
        guard let draft = IOSCompanionActions.autoDraft(action) else { continue }
        owner.actions?.autoCreate(id, index: index, draft: draft)
      }
    }
    owner.journalChanged()
  }
  func advance() {
    guard let owner, owner.journal.loadError == nil, !executing else { return }
    enqueueAutomatic()
    guard foreground || background != nil else { schedule(); return }
    guard let id = jobs.jobs.sorted(by: { $0.key < $1.key }).first(where: { $0.value["state"] as? String == "ready" && ($0.value["lease_until"] as? Int ?? 0) <= CompanionJournal.now })?.key else {
      if let background { self.background = nil; background.setTaskCompleted(success: !backgroundFailed) }
      return
    }
    do {
      guard let claimed = try jobs.claim(id) else { owner.journalChanged(); owner.queue.async { self.advance() }; return }
      guard let identity = claimed.spec["recording_id"] as? String,
            let metadata = (owner.journal.fields["recordings"] as? [String: [String: Any]])?[identity] else { throw CompanionFailure.invalid("Recording input unavailable") }
      claim = claimed; executing = true; owner.journalChanged()
      var input: [String: Any] = ["recording": metadata]
      if let transcript = jobs.jobs[id]?["transcript"] as? String { input["transcript"] = transcript }
      worker.execute(id: id, spec: claimed.spec, input: input,
        checkpoint: { [weak self] text in
          guard let self else { return false }
          let saved = try self.jobs.checkpoint(claimed, transcript: text); self.owner?.journalChanged(); return saved
        }, completed: { [weak self] result in
          guard let self else { return }
          self.executing = false
          if self.claim?.id == claimed.id && self.claim?.fence == claimed.fence { self.claim = nil }
          if self.jobs.owns(claimed) {
            do {
              let response = try result.get()
              guard let body = response["result"] as? [String: Any] else { throw IOSDartVoiceWorker.Failure(code: "INVALID_RESULT") }
              if try self.jobs.complete(claimed, result: body) { self.resultReady(claimed.id) }
            } catch {
              let code = (error as? IOSDartVoiceWorker.Failure)?.code ?? "PROCESSING_FAILED"
              try? self.jobs.fail(claimed.id, code: code == "NO_SPEECH" ? "no_speech" : code.lowercased(), blocked: code == "MODEL_MISSING")
              self.backgroundFailed = true
            }
          }
          self.owner?.journalChanged(); self.deliverResults(); self.advance()
        })
      owner.queue.asyncAfter(deadline: .now() + 900) { [weak self] in
        guard let self, self.claim?.id == claimed.id, self.claim?.fence == claimed.fence else { return }
        try? self.jobs.fail(claimed.id, code: "execution_timeout", blocked: true); self.claim = nil
        self.owner?.journalChanged(); self.worker.cancel(claimed.id)
      }
    } catch {
      try? jobs.fail(id, code: "input_unavailable", blocked: true); owner.journalChanged()
      owner.queue.async { self.advance() }
    }
  }
}

/// Phone-side Undo for a voice result, shown for the same window as the watch popup.
enum VoiceUndoNotification {
  static let category = "zswatch.voice.result"
  static let undoAction = "UNDO"
  static func identifier(_ id: String) -> String { "zswatch.voice.undo." + id }
  static func register() {
    let undo = UNNotificationAction(identifier: undoAction, title: "Undo", options: [.destructive])
    UNUserNotificationCenter.current().setNotificationCategories([
      UNNotificationCategory(identifier: category, actions: [undo], intentIdentifiers: [], options: [])])
  }
  static func show(_ id: String, result: [String: Any], until: Int) {
    let first = (result["actions"] as? [[String: Any]])?.first
    let content = UNMutableNotificationContent()
    content.title = result["summary"] as? String ?? "Voice memo"
    content.body = [first?["type"] as? String, (first?["start_time"] as? String) ?? (first?["due_date"] as? String)]
      .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • ")
    content.categoryIdentifier = category
    content.userInfo = ["voice_job_id": id]
    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier(id), content: content, trigger: nil))
  }
  static func remove(_ id: String) {
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier(id)])
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(id)])
  }
}
