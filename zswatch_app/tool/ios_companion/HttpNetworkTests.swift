import Foundation

@main struct HttpNetworkTests {
  static func fetch(_ base: String, _ path: String, cancel: Bool = false) -> Result<String, Error> {
    let done = DispatchSemaphore(value: 0)
    var result: Result<String, Error>?
    let request = CompanionHttpRequest(request: .init(id: path, url: URL(string: base + path)!, xpath: nil, insecure: false)) {
      result = $0; done.signal()
    }
    if cancel { request.cancel() }
    precondition(done.wait(timeout: .now() + 8) == .success)
    withExtendedLifetime(request) {}
    return result!
  }
  static func main() {
    let base = CommandLine.arguments[1]
    guard case .success(let body) = fetch(base, "/recover"), body == "recovered" else { preconditionFailure("503 must recover through one real URLSession retry") }
    let failure = fetch(base, "/unavailable")
    precondition(CompanionHttpRequest.diagnostic(failure)["reason"] as? String == "HTTP status 503")
    let started = ProcessInfo.processInfo.systemUptime
    let late = fetch(base, "/late-unavailable")
    precondition(CompanionHttpRequest.diagnostic(late)["reason"] as? String == "HTTP status 503")
    precondition(ProcessInfo.processInfo.systemUptime - started < 6.5, "A retry cannot extend the original budget")
    let limited = fetch(base, "/rate-limited")
    precondition(CompanionHttpRequest.diagnostic(limited)["reason"] as? String == "HTTP status 429")
    guard case .failure = fetch(base, "/cancel", cancel: true) else { preconditionFailure("Cancellation must remain terminal") }
    print("PASS: real URLSession transient retry, terminal 503, no 429 retry and cancellation")
  }
}
