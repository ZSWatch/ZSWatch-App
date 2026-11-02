import CryptoKit
import Foundation

/// ICA's unofficial mobile shopping-list API. The app signs in and hands the
/// OAuth session here; voice actions add rows after the undo window and Undo
/// deletes them. Calls block: run them on [queue], never on the owner queue.
enum IOSIcaShoppingList {
  /// [noEffect] failures prove ICA's list was not changed.
  struct Failure: Error, LocalizedError {
    let code: String; let message: String; let noEffect: Bool
    var errorDescription: String? { message }
  }
  struct Row { let id: String; let text: String; let checked: Bool }
  struct ShoppingList { let id: String; let serverId: Int?; let title: String; let rows: [Row] }

  static let maxItems = 64
  /// One at a time, so token refreshes never race.
  static let queue = DispatchQueue(label: "dev.zswatch.app.ica")
  private static let tokenURL = "https://ims.icagruppen.se/oauth/v2/token"
  private static let listsURL = "https://apimgw-pub.ica.se/sverige/digx/mobile/shoppinglistservice/v1/shoppinglists"
  private static let keychain: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "dev.zswatch.app.ica", kSecAttrAccount as String: "session"]

  /// Same IDs as Android's UUID.nameUUIDFromBytes: a retried add finds the rows it already wrote.
  static func rowIds(_ token: String, count: Int) -> [String] {
    (0..<count).map { index in
      var bytes = Array(Insecure.MD5.hash(data: Data("\(token)/\(index)".utf8)))
      bytes[6] = (bytes[6] & 0x0f) | 0x30; bytes[8] = (bytes[8] & 0x3f) | 0x80
      return NSUUID(uuidBytes: bytes).uuidString
    }
  }

  /// ICA's numeric list IDs grow with creation; edits do not reorder them like latestChange does.
  static func newest(_ lists: [ShoppingList]) -> ShoppingList? {
    let ids = lists.compactMap(\.serverId)
    guard ids.count == lists.count, Set(ids).count == ids.count else { return nil }
    return lists.max { $0.serverId! < $1.serverId! }
  }

  static func parseList(_ json: [String: Any]) throws -> ShoppingList {
    guard let id = json["offlineId"] as? String else { throw Failure(code: "ICA_HTTP", message: "Unexpected ICA list", noEffect: true) }
    let rows = (json["rows"] as? [[String: Any]] ?? []).compactMap { row -> Row? in
      guard let id = row["offlineId"] as? String else { return nil }
      return Row(id: id, text: row["productName"] as? String ?? "", checked: row["isStrikedOver"] as? Bool ?? false)
    }
    return ShoppingList(id: id, serverId: CompanionRecordingFiles.integer(json["id"]), title: json["title"] as? String ?? "", rows: rows)
  }

  /// A session from the app's sign-in, as stored. [previous] keeps the list choice.
  static func session(_ input: [String: Any], previous: [String: Any]?, now: Int) throws -> [String: Any] {
    var session: [String: Any] = [:]
    for field in ["client_id", "client_secret", "access_token", "refresh_token"] {
      guard let value = input[field] as? String, !value.isEmpty, value.utf8.count <= 8192 else { throw CompanionFailure.invalid("Invalid ICA session") }
      session[field] = value
    }
    session["expires_at"] = now + (CompanionRecordingFiles.integer(input["expires_in"]) ?? 0) * 1000
    session["newest"] = previous?["newest"] as? Bool ?? true
    session["list_id"] = previous?["list_id"] as? String ?? NSNull()
    return session
  }

  // Readable after first unlock so background auto-adds work; never synced or backed up.
  static func stored() -> [String: Any]? {
    var q = keychain; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }
  static func store(_ session: [String: Any]) throws {
    SecItemDelete(keychain as CFDictionary)
    var q = keychain; q[kSecValueData as String] = try JSONSerialization.data(withJSONObject: session)
    q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw CompanionFailure.storage("Could not save the ICA session") }
  }
  static func clear() { SecItemDelete(keychain as CFDictionary) }

  /// The list voice actions add to: the newest one, or the chosen one.
  static func setTarget(newest: Bool, listId: String?) throws {
    guard var session = stored() else { throw notConnected }
    guard newest || !(listId ?? "").isEmpty else { throw CompanionFailure.invalid("Choose an ICA list") }
    session["newest"] = newest; session["list_id"] = listId ?? NSNull()
    try store(session)
  }

  static func lists() throws -> [ShoppingList] {
    let body = try api("GET", listsURL, nil).json
    return try (body["shoppingLists"] as? [[String: Any]] ?? []).map(parseList)
  }

  static func target(_ lists: [ShoppingList]) throws -> ShoppingList? {
    guard let session = stored() else { throw notConnected }
    if session["newest"] as? Bool ?? true { return newest(lists) }
    return lists.first { $0.id == session["list_id"] as? String }
  }

  /// Adds [items] for the action [token] and returns the journal response.
  static func add(token: String, items: [String]) throws -> [String: Any] {
    guard (1...maxItems).contains(items.count) else { throw CompanionFailure.invalid("Invalid shopping items") }
    let ids = rowIds(token, count: items.count)
    let all: [ShoppingList]
    do { all = try lists() } catch let failure as Failure { throw failure } catch {
      throw Failure(code: "ICA_OFFLINE", message: "Could not reach ICA", noEffect: true)
    }
    // An interrupted earlier attempt may have written the rows already.
    if let done = all.first(where: { $0.rows.contains { $0.id == ids[0] } }) { return response(done, ids) }
    guard let target = try target(all) else {
      throw Failure(code: "ICA_NO_LIST", message: "No ICA list to add to. Create one or choose a list.", noEffect: true)
    }
    let rows: [[String: Any]] = zip(ids, items).map { id, item in
      // ICA's app marks free-text rows with a negative source ID.
      ["offlineId": id, "productName": item, "sourceId": -1, "isStrikedOver": false, "recipes": [Any]()]
    }
    let unknown = Failure(code: "ICA_OUTCOME_UNKNOWN", message: "ICA did not answer. The items may have been added.", noEffect: false)
    let status: Int
    do { status = try api("POST", "\(listsURL)/\(encode(target.id))/sync", ["createdRows": rows], check: false).status }
    catch let failure as Failure { throw failure } catch { throw unknown }
    if (400...499).contains(status) { throw Failure(code: "ICA_REJECTED", message: "ICA rejected the items (HTTP \(status))", noEffect: true) }
    let written: ShoppingList
    do { written = try list(target.id) } catch { throw unknown }
    guard Set(written.rows.map(\.id)).isSuperset(of: ids) else {
      throw Failure(code: "ICA_OUTCOME_UNKNOWN", message: "ICA did not confirm the items (HTTP \(status))", noEffect: false)
    }
    return response(written, ids)
  }

  /// Removes the rows a voice action added. Rows already gone count as removed.
  static func remove(listId: String, ids: [String]) throws {
    _ = try api("POST", "\(listsURL)/\(encode(listId))/sync", ["deletedRows": ids])
    if try list(listId).rows.contains(where: { ids.contains($0.id) }) {
      throw Failure(code: "ICA_OUTCOME_UNKNOWN", message: "ICA did not confirm the removal", noEffect: false)
    }
  }

  private static func list(_ id: String) throws -> ShoppingList { try parseList(api("GET", "\(listsURL)/\(encode(id))", nil).json) }

  private static func response(_ list: ShoppingList, _ ids: [String]) -> [String: Any] {
    ["platformId": list.id, "targetType": "ica_list", "listTitle": list.title, "rowIds": ids]
  }

  private static let notConnected = Failure(code: "ICA_NOT_CONNECTED", message: "Connect ICA in Settings → Integrations", noEffect: true)
  private static let authFailure = Failure(code: "ICA_AUTH", message: "ICA signed this phone out. Reconnect ICA in Settings → Integrations.", noEffect: true)

  private static func encode(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? value
  }

  /// A list API call. An expired token is refreshed once on HTTP 401.
  private static func api(_ method: String, _ url: String, _ body: [String: Any]?, check: Bool = true) throws -> (status: Int, json: [String: Any]) {
    let data = try body.map { try JSONSerialization.data(withJSONObject: $0) }
    var reply = try http(method, url, data, "application/json", "Bearer \(accessToken(force: false))")
    if reply.status == 401 { reply = try http(method, url, data, "application/json", "Bearer \(accessToken(force: true))") }
    if reply.status == 401 { throw authFailure }
    if check && !(200...299).contains(reply.status) {
      throw Failure(code: "ICA_HTTP", message: "ICA shopping lists returned HTTP \(reply.status)", noEffect: method == "GET")
    }
    return (reply.status, (try? JSONSerialization.jsonObject(with: reply.data)) as? [String: Any] ?? [:])
  }

  private static func accessToken(force: Bool) throws -> String {
    guard var session = stored(), let client = session["client_id"] as? String, let secret = session["client_secret"] as? String,
          let refresh = session["refresh_token"] as? String else { throw notConnected }
    if !force, let token = session["access_token"] as? String,
       (CompanionRecordingFiles.integer(session["expires_at"]) ?? 0) > CompanionJournal.now + 60_000 { return token }
    let basic = Data("\(client):\(secret)".utf8).base64EncodedString()
    var form = URLComponents(); form.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token"), URLQueryItem(name: "refresh_token", value: refresh)]
    let encoded = (form.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
    let (status, data) = try http("POST", tokenURL, Data(encoded.utf8), "application/x-www-form-urlencoded", "Basic \(basic)")
    if (400...499).contains(status) { throw authFailure }
    guard (200...299).contains(status), let token = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let access = token["access_token"] as? String else {
      throw Failure(code: "ICA_HTTP", message: "ICA sign-in returned HTTP \(status)", noEffect: true)
    }
    session["access_token"] = access
    session["expires_at"] = CompanionJournal.now + (CompanionRecordingFiles.integer(token["expires_in"]) ?? 300) * 1000
    if let rotated = token["refresh_token"] as? String, !rotated.isEmpty { session["refresh_token"] = rotated }
    try store(session)
    return access
  }

  private static let urlSession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 30
    return URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
  }()

  private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
  }

  private static func http(_ method: String, _ url: String, _ body: Data?, _ contentType: String, _ authorization: String) throws -> (status: Int, data: Data) {
    var request = URLRequest(url: URL(string: url)!)
    request.httpMethod = method
    request.setValue(authorization, forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body { request.httpBody = body; request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
    let done = DispatchSemaphore(value: 0)
    var outcome: Result<(Int, Data), Error> = .failure(URLError(.unknown))
    urlSession.dataTask(with: request) { data, response, error in
      if let response = response as? HTTPURLResponse { outcome = .success((response.statusCode, data ?? Data())) }
      else { outcome = .failure(error ?? URLError(.badServerResponse)) }
      done.signal()
    }.resume()
    done.wait()
    return try outcome.get()
  }
}
