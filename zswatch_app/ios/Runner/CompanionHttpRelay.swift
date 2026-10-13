import Foundation
import CoreFoundation
import libxml2

/// Short, session-scoped watch requests. Requests/bodies are never journaled.
final class CompanionHttpRelay {
  struct Request { let id: String; let url: URL; let xpath: String?; let insecure: Bool }
  typealias Fetch = (Request, @escaping (Result<String, Error>) -> Void) -> (() -> Void)
  private final class Pending {
    let generation: Int
    let deadline: Double
    var cancel: () -> Void = {}
    var replying = false
    init(_ generation: Int, _ deadline: Double) { self.generation = generation; self.deadline = deadline }
  }
  private var pending: [String: Pending] = [:]
  private var finished: [String] = []
  private let now: () -> Double
  private let later: (Double, @escaping () -> Void) -> Void
  private let fetch: Fetch
  private let enabled: () -> Bool
  private let send: (String, Int, @escaping () -> Bool, @escaping () -> Void) -> Bool
  private let observe: (Int, String, Int) -> Void
  init(now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime },
       later: @escaping (Double, @escaping () -> Void) -> Void,
       fetch: @escaping Fetch,
       enabled: @escaping () -> Bool,
       send: @escaping (String, Int, @escaping () -> Bool, @escaping () -> Void) -> Bool,
       observe: @escaping (Int, String, Int) -> Void) {
    self.now = now; self.later = later; self.fetch = fetch
    self.enabled = enabled; self.send = send; self.observe = observe
  }
  @discardableResult func receive(_ message: [String: Any], generation: Int) -> Bool {
    guard message["t"] as? String == "http", message["url"] != nil else { return false }
    let booleanId = (message["id"] as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() } ?? false
    let id = booleanId ? "" : ((message["id"] as? String) ?? (message["id"] as? Int).map(String.init) ?? "")
    guard id.range(of: "^[A-Za-z0-9_.:-]{1,64}$", options: .regularExpression) != nil else {
      observe(generation, "invalid_id", pending.count); return true
    }
    if pending[id] != nil || finished.contains(id) { return true }
    guard pending.count < 4 else { observe(generation, "busy", pending.count); return true }
    let entry = Pending(generation, now() + 8)
    pending[id] = entry; observe(generation, "pending", pending.count)
    later(6.5) { self.complete(id, entry, .failure(CompanionFailure.unavailable("Request timed out"))) }
    later(8) { if self.pending[id] === entry { self.finish(id, entry, "delivery_expired") } }
    guard enabled() else { complete(id, entry, .failure(CompanionFailure.unavailable("HTTP relay disabled"))); return true }
    guard let text = message["url"] as? String, text.utf8.count <= 2048,
          let url = URL(string: text), Self.validURL(url),
          message["xpath"] == nil || message["xpath"] is String,
          message["insecure"] == nil || (message["insecure"] as? NSNumber).map({ CFGetTypeID($0) == CFBooleanGetTypeID() }) == true else {
      complete(id, entry, .failure(CompanionFailure.invalid("Invalid request"))); return true
    }
    let request = Request(id: id, url: url, xpath: message["xpath"] as? String, insecure: message["insecure"] as? Bool == true)
    let cancel = fetch(request) { self.complete(id, entry, $0) }
    if pending[id] === entry && !entry.replying { entry.cancel = cancel } else { cancel() }
    return true
  }
  private func complete(_ id: String, _ entry: Pending, _ result: Result<String, Error>) {
    guard pending[id] === entry, !entry.replying else { return }
    entry.replying = true; entry.cancel()
    guard now() < entry.deadline else { finish(id, entry, "delivery_expired"); return }
    var fields: [String: Any] = ["t": "http", "id": id]
    switch result {
    case .success(let body): fields["resp"] = body
    case .failure(let error): fields["err"] = String(error.localizedDescription.prefix(100))
    }
    var packet = Self.packet(fields)
    if packet.utf8.count >= 1900 { fields.removeValue(forKey: "resp"); fields["err"] = "Response too large"; packet = Self.packet(fields) }
    let success = fields["resp"] != nil
    let accepted = send(packet, entry.generation, { self.pending[id] === entry && self.now() < entry.deadline }, {
      if self.pending[id] === entry { self.finish(id, entry, success ? "written" : "error_written") }
    })
    if !accepted, pending[id] === entry { finish(id, entry, "delivery_unavailable") }
  }
  private func finish(_ id: String, _ entry: Pending, _ outcome: String) {
    guard pending[id] === entry else { return }
    pending.removeValue(forKey: id); entry.cancel()
    finished.append(id); finished = Array(finished.suffix(16))
    observe(entry.generation, outcome, pending.count)
  }
  func close() {
    let old = pending; pending.removeAll(); finished.removeAll()
    for entry in old.values { entry.cancel(); observe(entry.generation, "connection_closed", 0) }
  }
  func disable() { for (id, entry) in pending { complete(id, entry, .failure(CompanionFailure.unavailable("HTTP relay disabled"))) } }
  static func validURL(_ url: URL) -> Bool {
    ["http", "https"].contains(url.scheme?.lowercased() ?? "") && !(url.host ?? "").isEmpty && url.user == nil && url.password == nil
  }
  private static func packet(_ fields: [String: Any]) -> String {
    let bytes = try! JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys, .withoutEscapingSlashes])
    return "GB(\(String(data: bytes, encoding: .utf8)!))\n"
  }
  static func xpath(_ body: String, expression: String) throws -> String {
    guard body.utf8.count <= 65536, expression.utf8.count <= 1024,
          body.range(of: "<!DOCTYPE", options: .caseInsensitive) == nil,
          body.range(of: "<!ENTITY", options: .caseInsensitive) == nil else {
      throw CompanionFailure.invalid("XPath error")
    }
    guard let doc = body.withCString({ xmlReadMemory($0, Int32(body.utf8.count), nil, "UTF-8", Int32(XML_PARSE_NONET.rawValue)) }) else {
      throw CompanionFailure.invalid("XPath error")
    }
    defer { xmlFreeDoc(doc) }
    guard let context = xmlXPathNewContext(doc) else { throw CompanionFailure.invalid("XPath error") }
    defer { xmlXPathFreeContext(context) }
    let object = expression.utf8CString.withUnsafeBufferPointer { buffer in
      xmlXPathEvalExpression(UnsafeRawPointer(buffer.baseAddress!).assumingMemoryBound(to: UInt8.self), context)
    }
    guard let object else { throw CompanionFailure.invalid("XPath error") }
    defer { xmlXPathFreeObject(object) }
    guard object.pointee.type == XPATH_NODESET, let nodes = object.pointee.nodesetval, nodes.pointee.nodeNr > 0,
          let table = nodes.pointee.nodeTab else { throw CompanionFailure.invalid("XPath returned no results") }
    var texts: [String] = []
    for index in 0..<Int(nodes.pointee.nodeNr) {
      guard let content = xmlNodeGetContent(table[index]) else { continue }
      let text = String(cString: UnsafeRawPointer(content).assumingMemoryBound(to: CChar.self))
      xmlFree(content); texts.append(text)
      if texts.reduce(0, { $0 + $1.utf8.count }) > 65536 { throw CompanionFailure.invalid("XPath response too large") }
    }
    return texts.joined(separator: "\n")
  }
}

/// URLSession delegate bounds streamed bytes and redirects before decoding.
final class CompanionHttpRequest: NSObject, URLSessionDataDelegate {
  private let request: CompanionHttpRelay.Request
  private let deliver: (Result<String, Error>) -> Void
  private var session: URLSession!
  private var bytes = Data()
  private var redirects = 0
  private var rejection: String?
  private var finished = false
  private var encoding = String.Encoding.utf8
  init(request: CompanionHttpRelay.Request, deliver: @escaping (Result<String, Error>) -> Void) {
    self.request = request; self.deliver = deliver
    super.init()
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 6; config.timeoutIntervalForResource = 6
    config.urlCredentialStorage = nil; config.httpCookieStorage = nil; config.urlCache = nil
    let callbacks = OperationQueue(); callbacks.maxConcurrentOperationCount = 1
    session = URLSession(configuration: config, delegate: self, delegateQueue: callbacks)
    var query = URLRequest(url: request.url); query.httpMethod = "GET"
    query.setValue("ZSWatch-Companion/1.0", forHTTPHeaderField: "User-Agent")
    query.setValue("*/*", forHTTPHeaderField: "Accept")
    session.dataTask(with: query).resume()
  }
  func cancel() { session.invalidateAndCancel() }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                  completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), response.expectedContentLength <= 65536 else {
      rejection = "HTTP error or response too large"; completionHandler(.cancel); return
    }
    if http.textEncodingName?.lowercased() == "iso-8859-1" { encoding = .isoLatin1 }
    completionHandler(.allow)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    guard rejection == nil else { return }
    guard bytes.count + data.count <= 65536 else { rejection = "Response too large"; dataTask.cancel(); return }
    bytes.append(data)
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    redirects += 1
    guard redirects <= 4, let target = newRequest.url, CompanionHttpRelay.validURL(target),
          task.currentRequest?.url?.scheme?.lowercased() != "https" || target.scheme?.lowercased() == "https" else {
      rejection = "Invalid or insecure redirect"; completionHandler(nil); return
    }
    completionHandler(newRequest)
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                  completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    if request.insecure, challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
       let trust = challenge.protectionSpace.serverTrust {
      completionHandler(.useCredential, URLCredential(trust: trust))
    } else { completionHandler(.performDefaultHandling, nil) }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard !finished else { return }; finished = true
    defer { session.finishTasksAndInvalidate() }
    guard rejection == nil, error == nil, let body = String(data: bytes, encoding: encoding), !body.isEmpty else {
      deliver(.failure(CompanionFailure.unavailable(rejection ?? "Network, TLS or response error"))); return
    }
    do {
      let value = try request.xpath.map { $0.isEmpty ? body : try CompanionHttpRelay.xpath(body, expression: $0) } ?? body
      deliver(.success(value))
    } catch { deliver(.failure(error)) }
  }
}
