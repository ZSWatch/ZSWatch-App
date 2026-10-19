import Foundation
@main struct VoiceJobTests {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let journal = CompanionJournal(url: root.appendingPathComponent("state.json"))
    let jobs = try CompanionVoiceJobs(journal: journal)
    let receipt: [String: Any] = ["address": "FE88C737-593F-DB9B-732D-E11FF4C463F5", "sha256": String(repeating:"a",count:64), "state":"downloaded"]
    let id = try jobs.start(identity: "watch:memo", receipt: receipt, stt: "whisperTinyEn", llm: "qwen", correct: false, operation: "transcribe")
    let claim = try jobs.claim(id)!
    let saved = try jobs.checkpoint(claim, transcript: "Load my watch 🔋"); precondition(saved)
    try jobs.deferClaim(claim, code: "background_expired")
    let stale = try jobs.checkpoint(claim, transcript: "old callback"); precondition(!stale)
    let reopened = try CompanionVoiceJobs(journal: CompanionJournal(url: journal.url)); try reopened.recover()
    let resumed = try reopened.claim(id)!; precondition(resumed.fence > claim.fence)
    let only: [String: Any] = ["version":1, "transcript":"Load my watch 🔋", "summary":"", "category":"", "actions":[[String:Any]]()]
    let done = try reopened.complete(resumed, result: only); precondition(done)
    let analysis = try reopened.start(identity: "watch:memo", receipt: receipt, stt: "whisperTinyEn", llm: "qwen", correct: false, operation: "reanalyze")
    let detail = try reopened.detail(analysis); precondition(detail["transcript"] as? String == "Load my watch 🔋")
    let selected = try reopened.claim(analysis)!
    let full: [String: Any] = ["version":1, "transcript":"Load my watch 🔋", "summary":"Load watch", "category":"reminder", "actions":[["type":"reminder", "title":"Load watch"]]]
    let analyzed = try reopened.complete(selected, result: full); precondition(analyzed)
    let draft: [String: Any] = ["actionType":"reminder", "title":"Load watch", "notes":"Confirmed note"]
    _ = try reopened.beginAction(analysis, index: 0, draft: draft)
    try reopened.admitAction(analysis, index: 0)
    let changed: [String: Any] = ["actionType":"reminder", "title":"Changed after confirmation"]
    let recoveredAction = try reopened.beginAction(analysis, index: 0, draft: changed)
    precondition((recoveredAction["draft"] as? [String: Any])?["title"] as? String == "Load watch")
    precondition(recoveredAction["effect_admitted"] as? Bool == true)
    try reopened.finishAction(analysis, index: 0, response: ["platformId":"fixture-only", "targetType":"reminder"])
    _ = try reopened.beginUndo(analysis, index: 0); try reopened.finishUndo(analysis, index: 0)
    let packet = try reopened.deliveryPacket(analysis, filename: "memo_1")
    var ack = packet; ack["action"] = "result_ack"; ack["status"] = "accepted"
    var forged = ack; forged["generation"] = true
    let rejected = try reopened.acknowledge(analysis, ack: forged, filename: "memo_1"); precondition(!rejected)
    let accepted = try reopened.acknowledge(analysis, ack: ack, filename: "memo_1"); precondition(accepted)
    let delivered = try reopened.detail(analysis); precondition(delivered["state"] as? String == "delivered")
    let retry = try reopened.start(identity:"watch:memo",receipt:receipt,stt:"whisperTinyEn",llm:"qwen",correct:false,operation:"retranscribe")
    let cancelled = try reopened.claim(retry)!
    _ = try reopened.checkpoint(cancelled, transcript: "Load my watch 🔋")
    try reopened.cancel(retry)
    let late = try reopened.complete(cancelled, result: only); precondition(!late)
    // Editing a checkpoint while an older inference attempt runs creates a
    // durable selected generation; neither its checkpoint nor result can win.
    let editing = try reopened.start(identity:"watch:memo", receipt:receipt, stt:"whisperTinyEn", llm:"qwen", correct:false, operation:"reanalyze")
    let oldAttempt = try reopened.claim(editing)!
    let edited = try reopened.editTranscript(editing, transcript: "Corrected 🔋 speech")
    precondition(!reopened.owns(oldAttempt))
    let ignored = try reopened.complete(oldAttempt, result: full); precondition(!ignored)
    let manual = try reopened.detail(edited)
    precondition(manual["transcript"] as? String == "Corrected 🔋 speech")
    precondition(manual["state"] as? String == "transcribed")
    precondition((manual["result"] as? [String:Any])?["summary"] as? String == "")
    do { _ = try reopened.editTranscript(editing, transcript:"stale dialog"); fatalError("Stale edit admitted") } catch {}
    precondition(reopened.search("corrected").contains("watch:memo"))
    precondition(!reopened.search("old callback").contains("watch:memo"))
    let editedAnalysis = try reopened.start(identity:"watch:memo", receipt:receipt, stt:"whisperTinyEn", llm:"qwen", correct:false, operation:"reanalyze")
    let editedDetail = try reopened.detail(editedAnalysis); precondition(editedDetail["transcript"] as? String == "Corrected 🔋 speech")
    let beforeDelete = try reopened.claim(editedAnalysis)!
    let untouched = try reopened.start(identity:"watch:other", receipt:receipt, stt:"whisperTinyEn", llm:"qwen", correct:false, operation:"transcribe")
    try reopened.cancelRecordings(["watch:memo"])
    precondition(!reopened.owns(beforeDelete))
    let unaffected = try reopened.detail(untouched); precondition(unaffected["state"] as? String == "ready")
    let reopenedAgain = try CompanionVoiceJobs(journal: CompanionJournal(url: journal.url))
    let persisted = try reopenedAgain.detail(edited); precondition(persisted["transcript"] as? String == "Corrected 🔋 speech")
    let canonical = try CompanionVoiceJobs.canonical(["z":"é🔋/", "a":false])
    precondition(canonical == "{\"a\":false,\"z\":\"é🔋/\"}")
    let beforePurge = reopened.jobs
    try reopened.purgeRecordings(["watch:memo"])
    precondition(!reopened.jobs.values.contains { ($0["spec"] as? [String: Any])?["recording_id"] as? String == "watch:memo" })
    precondition(!reopened.owns(oldAttempt))
    let afterPurge = try reopened.complete(oldAttempt, result: full); precondition(!afterPurge)
    for (key, job) in beforePurge where (job["spec"] as? [String: Any])?["recording_id"] as? String != "watch:memo" {
      let unchanged = try CompanionVoiceJobs.canonical(reopened.jobs[key]!) == CompanionVoiceJobs.canonical(job); precondition(unchanged)
    }
    let afterRestart = try CompanionVoiceJobs(journal: CompanionJournal(url: journal.url))
    precondition(afterRestart.jobs.count == reopened.jobs.count)
    // Expected lifecycle pauses are not failed inference attempts. More than
    // five app/background switches must preserve the same job and checkpoint.
    let paused = try reopened.start(identity:"watch:lifecycle", receipt:receipt, stt:"whisperTinyEn", llm:"qwen", correct:false, operation:"process")
    var previousFence = -1
    for _ in 0..<8 {
      guard let attempt = try reopened.claim(paused) else { fatalError("Lifecycle pause exhausted failure budget") }
      precondition(attempt.fence > previousFence); previousFence = attempt.fence
      _ = try reopened.checkpoint(attempt, transcript:"The blue bicycle is in the garage.")
      try reopened.deferClaim(attempt, code:"background_deferred")
      precondition(!reopened.owns(attempt))
      let late = try reopened.complete(attempt, result:full); precondition(!late)
    }
    let resumedLifecycle = try CompanionVoiceJobs(journal:CompanionJournal(url:journal.url))
    try resumedLifecycle.recover()
    let lifecycleDetail = try resumedLifecycle.detail(paused)
    precondition(lifecycleDetail["transcript"] as? String == "The blue bicycle is in the garage.")
    let finalLifecycleClaim = try resumedLifecycle.claim(paused)!
    let lifecycleCompleted = try resumedLifecycle.complete(finalLifecycleClaim, result:full)
    precondition(lifecycleCompleted)
    // Explicit retry of a blocked model job resets both counters together.
    let retryBlocked = try resumedLifecycle.start(identity:"watch:blocked-retry", receipt:receipt, stt:"whisperTinyEn", llm:"qwen", correct:false, operation:"process")
    let firstBlockedClaim = try resumedLifecycle.claim(retryBlocked)!
    try resumedLifecycle.deferClaim(firstBlockedClaim, code:"background_expired")
    _ = try resumedLifecycle.claim(retryBlocked)
    try resumedLifecycle.fail(retryBlocked, code:"model_missing", blocked:true)
    let retryBlockedID = try resumedLifecycle.start(identity:"watch:blocked-retry", receipt:receipt, stt:"whisperTinyEn", llm:"qwen", correct:false, operation:"process")
    precondition(retryBlockedID == retryBlocked)
    let reset = try resumedLifecycle.detail(retryBlockedID)
    precondition(reset["attempts"] as? Int == 0 && reset["deferred_attempts"] as? Int == 0)
    // Unclean process deaths still consume the bounded failure budget.
    let crashing = try resumedLifecycle.start(identity:"watch:crash", receipt:receipt, stt:"whisperTinyEn", llm:"qwen", correct:false, operation:"process")
    for _ in 0..<5 {
      let crashClaim = try resumedLifecycle.claim(crashing); precondition(crashClaim != nil)
      try resumedLifecycle.recover()
    }
    let excessiveCrash = try resumedLifecycle.claim(crashing)
    precondition(excessiveCrash == nil)
    let crashDetail = try resumedLifecycle.detail(crashing)
    precondition(crashDetail["last_error"] as? String == "execution_attempt_limit")
    print("PASS: checkpoints, immutable edits/reanalysis, selected-only deletion fences, private search, ACKs, repeated lifecycle deferrals and bounded crash recovery")
  }
}
