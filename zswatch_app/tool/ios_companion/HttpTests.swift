import Foundation

@main struct HttpTests {
  final class Rig {
    var time = 0.0
    var tasks: [(Double, () -> Void)] = []
    var fetches: [String: (Result<String, Error>) -> Void] = [:]
    var packets: [String] = []
    var admissions: [() -> Bool] = []
    var completions: [() -> Void] = []
    var outcomes: [String] = []
    var cancelled = 0
    var enabled = true
    lazy var relay = CompanionHttpRelay(now: { self.time }, later: { self.tasks.append((self.time + $0, $1)) },
      fetch: { request, done in self.fetches[request.id] = done; return { self.cancelled += 1 } },
      enabled: { self.enabled }, send: { packet, _, admit, done in
        self.packets.append(packet); self.admissions.append(admit); self.completions.append(done); return true
      }, observe: { _, outcome, _ in self.outcomes.append(outcome) })
    func receive(_ id: Any, generation: Int = 1, url: String = "https://example.com/weather") {
      relay.receive(["t": "http", "id": id, "url": url], generation: generation)
    }
    func advance(_ target: Double) {
      while let next = tasks.enumerated().filter({ $0.element.0 <= target }).min(by: { $0.element.0 < $1.element.0 }) {
        tasks.remove(at: next.offset); time = next.element.0; next.element.1()
      }
      time = target
    }
  }
  static func main() throws {
    let first = Rig(); first.receive("1")
    let body = "{\"weather\":\"rain ☔\",\"line\":\"a\\nb\"}"
    first.fetches["1"]?(.success(body)); first.fetches["1"]?(.success("duplicate"))
    precondition(first.packets.count == 1 && first.admissions[0]())
    let wire = first.packets[0]
    let json = String(wire.dropFirst(3).dropLast(2))
    let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: String]
    precondition(decoded["resp"] == body, "Escaped UTF8 response roundtrips exactly")
    first.completions[0](); first.receive("1")
    precondition(first.packets.count == 1 && first.outcomes.last == "written", "Duplicates do not resend")
    let expired = Rig(); expired.receive(2); expired.advance(8.1)
    precondition(expired.packets.count == 1 && !expired.admissions[0](), "Timeout reply cannot enter ATT after its deadline")
    expired.fetches["2"]?(.success("late")); precondition(expired.packets.count == 1)
    let stopped = Rig(); stopped.receive("3"); let old = stopped.fetches["3"]!
    stopped.relay.close(); stopped.receive("3", generation: 2)
    old(.success("old session")); precondition(stopped.packets.isEmpty)
    stopped.fetches["3"]?(.success("new session")); precondition(stopped.packets.count == 1)
    stopped.relay.close(); precondition(!stopped.admissions[0](), "Stop revokes queued admission")
    let limits = Rig(); limits.receive(true); limits.receive("bad id"); limits.receive("user", url: "https://user:secret@example.com/")
    precondition(limits.fetches.isEmpty, "Invalid IDs and URL credentials never reach networking")
    limits.receive("big"); limits.fetches["big"]?(.success(String(repeating: "é", count: 1900)))
    precondition(limits.packets.last!.contains("Response too large") && limits.packets.last!.utf8.count < 1900)
    let disabled = Rig(); disabled.receive("4"); disabled.enabled = false; disabled.relay.disable()
    precondition(disabled.cancelled > 0 && disabled.packets.last!.contains("disabled"))
    let extracted = try CompanionHttpRelay.xpath("<root><n>one</n><n>två</n></root>", expression: "/root/n")
    precondition(extracted == "one\ntvå")
    do { _ = try CompanionHttpRelay.xpath("<!DOCTYPE a [<!ENTITY x SYSTEM 'file:///private/secret'>]><a>&x;</a>", expression: "/a"); preconditionFailure("DTD accepted") } catch {}
    precondition(CompanionHttpRequest.diagnostic(.success("☔"))["response_bytes"] as? Int == 3)
    precondition(CompanionHttpRequest.diagnostic(.failure(CompanionFailure.unavailable("HTTP status 429")))["reason"] as? String == "HTTP status 429")
    precondition(CompanionHttpRequest.diagnostic(.failure(CompanionFailure.unavailable("private URL and response")))["reason"] as? String == "Response rejected")
    print("PASS: HTTP deadline/session cancellation, duplicate suppression, bounded UTF8 replies and XPath")
  }
}
