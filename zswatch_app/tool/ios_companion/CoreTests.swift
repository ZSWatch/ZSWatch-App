import Foundation

@main
struct CoreTests {
  static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
  }
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("state.json")
    let id = "F31A05BD-1C30-4B66-AAC0-157004320111"
    let other = "F31A05BD-1C30-4B66-AAC0-157004320222"
    let journal = CompanionJournal(url: url)
    check(!journal.desired && journal.generation == 0, "fresh journal is stopped")
    try journal.start(id.lowercased())
    let started = journal.generation
    check(journal.owns(started, id), "start normalizes UUID and owns session")
    try journal.start(id)
    check(journal.generation == started, "reattaching start is idempotent")
    do { try journal.start(other); preconditionFailure("switched active watch") } catch {}
    let restored = CompanionJournal(url: url)
    check(restored.desired && restored.owns(started, id), "durable intent restores")
    try restored.stop()
    check(!restored.owns(started, id) && restored.generation > started, "stop fences late events")
    try restored.start(id)
    let beforeForget = restored.generation
    try restored.forget(id)
    check(!restored.desired && restored.address.isEmpty, "forget clears intent and selection")
    check(!restored.owns(beforeForget, id), "forget fences old session")
    let receipt = restored.fields["forget_receipt"] as! [String: Any]
    check(receipt["system_unpair_required"] as? Bool == true, "forget does not claim system unpair")
    for _ in 0..<200 { try restored.update("test") }
    check((restored.fields["events"] as! [[String: Any]]).count == 128, "replay bounded")
    try restored.update("health", restored.telemetryChanges(kind: "health", payload: ["stp": 1234]))
    let receiptSequence = restored.fields["telemetry_sequence"] as! Int
    check((restored.fields["telemetry"] as! [[String: Any]]).count == 1, "telemetry is durable until acknowledged")
    let replay = CompanionJournal(url: url)
    check((replay.fields["telemetry"] as! [[String: Any]]).count == 1, "telemetry survives process restart")
    do { try replay.ackTelemetry(receiptSequence + 1); preconditionFailure("acknowledged unseen telemetry") } catch {}
    try replay.ackTelemetry(receiptSequence)
    check((replay.fields["telemetry"] as! [[String: Any]]).isEmpty, "committed acknowledgement removes pending receipts")
    try Data("{\"generation\":true,\"desired_running\":true,\"address\":\"\(id)\"}".utf8).write(to: url)
    check(CompanionJournal(url: url).loadError != nil, "Boolean generation cannot restore intent")
    let damaged = Data("{invalid".utf8)
    try damaged.write(to: url)
    let corrupt = CompanionJournal(url: url)
    check(!corrupt.desired && corrupt.loadError != nil, "unreadable state fails closed")
    do { try corrupt.start(id); preconditionFailure("overwrote corrupt state") } catch {}
    check(try! Data(contentsOf: url) == damaged, "corrupt state remains recoverable")

    let framer = CompanionNusFramer()
    var messages = [[String: Any]]()
    var logs = [String]()
    func feed(_ bytes: Data, _ now: Double = 0) {
      framer.feed(bytes, now: now, message: { messages.append($0) }, logger: { logs.append($0) })
    }
    let stream = "noise<BLELOG>héllo {log}</BLELOG>{\"t\":\"ver\",\"nested\":{\"name\":\"klocka ⌚ \\\"}\\\"\"}}\r\n{\"t\":\"status\",\"bat\":87}"
    for byte in Data(stream.utf8) { feed(Data([byte])) }
    check(logs == ["héllo {log}"], "split UTF8 logs remain intact")
    check(messages.count == 2 && messages[0]["t"] as? String == "ver", "split nested quoted braces parsed")
    check(messages[1]["bat"] as? Int == 87, "multiple frames parsed")
    feed(Data("{\"t\":\"bad\"\n{\"t\":\"ok\"}".utf8))
    check(messages.last?["t"] as? String == "ok", "newline resynchronizes malformed JSON")
    feed(Data("<BLELOG>unfinished".utf8), 1)
    feed(Data("{\"t\":\"after_timeout\"}".utf8), 7)
    check(messages.last?["t"] as? String == "after_timeout", "interrupted log expires")
    framer.reset()
    feed(Data("{\"t\":\"incomplete".utf8), 8)
    feed(Data("{\"t\":\"next_session\"}".utf8), 14)
    check(messages.last?["t"] as? String == "next_session", "incomplete JSON expires")
    let small = CompanionNusFramer(maximum: 32)
    var recovered = false
    small.feed(Data(("<BLELOG>" + String(repeating: "x", count: 64) + "</BLELOG>{\"t\":\"ok\"}").utf8),
               message: { recovered = $0["t"] as? String == "ok" }, logger: { _ in preconditionFailure("oversized log emitted") })
    check(recovered, "oversized log recovers without emitting content")
    print("PASS: native journal persistence/fencing and NUS framing")
  }
}
