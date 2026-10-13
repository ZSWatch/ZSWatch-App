import CoreBluetooth
import Foundation
import iOSMcuManagerLibrary

/// The process owner admits one Nordic operation at a time. The SDK retains its
/// own central/peripheral; it never takes the NUS peripheral's delegate.
final class IOSCompanionSmp {
  private weak var owner: IOSCompanionCoordinator?
  private var transport: McuMgrBleTransport?
  private var preparedGeneration: Int?
  private var pending: Pending?
  private var attempt = UUID()
  private var preparing = false
  private var constructing = false
  private var downloadManager: FileSystemManager?
  private struct Pending {
    let id: UUID
    let address: String
    let generation: Int
    let complete: (Result<[String: Any], Error>) -> Void
  }
  init(owner: IOSCompanionCoordinator) { self.owner = owner }

  func sessionClosed(allowPreparationRecovery: Bool = false) {
    attempt = UUID(); constructing = false
    transport?.invalidate(); transport = nil; preparedGeneration = nil
    if let manager = downloadManager { DispatchQueue.main.async { manager.cancelTransfer() } }
    downloadManager = nil
    if allowPreparationRecovery, preparing, let owner, owner.journal.desired { return }
    finish(.failure(CompanionFailure.unavailable("Watch session closed; any admitted command result may be unknown")))
  }

  private func begin(_ generation: Int, timeout: Double,
                     complete: @escaping (Result<[String: Any], Error>) -> Void) throws -> UUID {
    guard let owner, owner.isReadySession(generation) else { throw CompanionFailure.unavailable("Watch session expired") }
    guard pending == nil else { throw CompanionFailure.unavailable("Another watch operation is in progress") }
    let next = Pending(id: UUID(), address: owner.journal.address, generation: generation, complete: complete)
    pending = next
    owner.queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
      guard let self, self.pending?.id == next.id else { return }
      self.transport?.invalidate(); self.transport = nil; self.preparedGeneration = nil
      self.finish(.failure(CompanionFailure.unavailable("Watch operation timed out; check the device before retrying an admitted command")))
    }
    return next.id
  }
  private func current(_ id: UUID, _ generation: Int) -> Bool {
    guard let owner, let pending else { return false }
    return pending.id == id && pending.address == owner.journal.address && owner.isReadySession(generation)
  }
  private func finish(_ result: Result<[String: Any], Error>) {
    let old = pending; pending = nil; preparing = false; constructing = false
    downloadManager = nil
    old?.complete(result)
    owner?.queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.owner?.inbox?.downloadNext() }
  }

  func prepare(_ generation: Int, complete: @escaping (Result<[String: Any], Error>) -> Void) throws {
    guard let owner, owner.isReadySession(generation) else { throw CompanionFailure.unavailable("Connect the watch first") }
    if pending == nil, preparedGeneration == generation, transport != nil {
      complete(.success(["version": 1, "prepared_from_generation": generation, "generation": generation])); return
    }
    let id = try begin(generation, timeout: 25, complete: complete)
    preparing = true
    do { try owner.send("GB({\"t\":\"smp\",\"status\":true})") }
    catch { finish(.failure(error)); return }
    pollPreparation(id)
  }
  private func pollPreparation(_ id: UUID) {
    guard let owner, let pending, pending.id == id, preparing else { return }
    let generation = owner.journal.generation
    guard owner.journal.desired, owner.journal.address == pending.address,
          generation >= pending.generation, generation <= pending.generation + 1 else {
      finish(.failure(CompanionFailure.unavailable("SMP preparation session expired"))); return
    }
    if owner.isReadySession(generation), transport == nil, !constructing, let uuid = UUID(uuidString: pending.address) {
      constructing = true
      let token = UUID(); attempt = token
      DispatchQueue.main.async {
        let created = McuMgrBleTransport(uuid)
        created.chunkSendDataToMtuSize = true
        created.retryOnMissingResponse = false
        owner.queue.async {
          guard self.pending?.id == id, self.attempt == token, owner.isReadySession(generation) else {
            created.invalidate(); return
          }
          self.constructing = false
          self.transport = created
          let echo = "ZSWatch-\(id.uuidString.prefix(8))"
          DispatchQueue.main.async {
            DefaultManager(transport: created).echo(echo) { response, error in
              owner.queue.async {
                guard self.pending?.id == id, self.attempt == token else { return }
                if !owner.isReadySession(generation) { self.sessionClosed(); return }
                guard error == nil, response?.getError() == nil, response?.response == echo else {
                  created.invalidate(); self.transport = nil
                  self.finish(.failure(error ?? CompanionFailure.unavailable("Nordic SMP did not acknowledge preparation"))); return
                }
                self.preparedGeneration = generation
                try? owner.publish("smp_prepared", ["smp_prepared_generation": generation])
                self.finish(.success(["version": 1, "prepared_from_generation": pending.generation, "generation": generation]))
              }
            }
          }
        }
      }
      // Mark construction in-flight without admitting another transport.
      owner.queue.asyncAfter(deadline: .now() + 0.25) { if self.pending?.id == id { self.pollPreparation(id) } }
      return
    }
    owner.queue.asyncAfter(deadline: .now() + 0.25) { self.pollPreparation(id) }
  }
  private func prepared(_ generation: Int) throws -> McuMgrBleTransport {
    guard preparedGeneration == generation, let transport, let owner, owner.isReadySession(generation) else {
      throw CompanionFailure.unavailable("Prepare Nordic SMP for this watch session first")
    }
    return transport
  }
  func shell(_ generation: Int, command: String, complete: @escaping (Result<[String: Any], Error>) -> Void) throws {
    guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          command.utf8.count <= 512, !command.contains("\0") else { throw CompanionFailure.invalid("Invalid shell command") }
    let sdk = try prepared(generation)
    let id = try begin(generation, timeout: 30, complete: complete)
    guard let owner else { return }
    DispatchQueue.main.async {
      ShellManager(transport: sdk).execute(command: command) { response, error in
        owner.queue.async {
          guard self.current(id, generation) else { return }
          guard error == nil, let response, response.getError() == nil,
                let output = response.output, output.utf8.count <= 65536, let code = response.returnCode else {
            self.finish(.failure(error ?? CompanionFailure.unavailable("Invalid shell response"))); return
          }
          guard Int64(Int32.min)...Int64(Int32.max) ~= code else {
            self.finish(.failure(CompanionFailure.unavailable("Invalid shell return code"))); return
          }
          self.finish(.success(["version": 1, "generation": generation, "output": output, "return_code": Int(code)]))
        }
      }
    }
  }

  func restart(_ generation: Int, complete: @escaping (Result<[String: Any], Error>) -> Void) throws {
    try prepare(generation) { prepared in
      do {
        let fields = try prepared.get()
        guard let current = fields["generation"] as? Int else { throw CompanionFailure.invalid("Invalid preparation") }
        let sdk = try self.prepared(current)
        let id = try self.begin(current, timeout: 20, complete: complete)
        guard let owner = self.owner else { return }
        DispatchQueue.main.async {
          DefaultManager(transport: sdk).reset { response, error in
            owner.queue.async {
              guard self.current(id, current) else { return }
              guard error == nil, let response, response.getError() == nil else {
                self.finish(.failure(error ?? CompanionFailure.unavailable("Watch did not acknowledge restart; it was not retried"))); return
              }
              self.finish(.success(["version": 1, "acknowledged": true, "generation": current]))
            }
          }
        }
      } catch { complete(.failure(error)) }
    }
  }
  func inspectCoredump(_ generation: Int, erase: Bool, complete: @escaping (Result<[String: Any], Error>) -> Void) throws {
    try prepare(generation) { prepared in
      do {
        guard let current = try prepared.get()["generation"] as? Int else { throw CompanionFailure.invalid("Invalid preparation") }
        func summary() {
          do { try self.shell(current, command: "coredump summary") { result in
            do {
              let response = try result.get()
              guard let output = response["output"] as? String, let code = response["return_code"] as? Int,
                    let owner = self.owner, owner.isReadySession(current) else { throw CompanionFailure.invalid("Invalid coredump response") }
              let packet = try CompanionCoredump.summary(output, code: code)
              guard !erase || packet["available"] as? Bool == false else { throw CompanionFailure.unavailable("Watch still has a coredump") }
              var info = owner.journal.fields["watch_info"] as? [String: Any] ?? [:]
              info["coredump"] = packet["available"] as? Bool == true ? packet : NSNull()
              try owner.publish("watch_info_received", ["watch_info": info])
              complete(.success(["version": 1, "completed": true]))
            } catch { complete(.failure(error)) }
          } } catch { complete(.failure(error)) }
        }
        if !erase { summary(); return }
        try self.shell(current, command: "coredump erase 0") { result in
          do {
            guard try result.get()["return_code"] as? Int == 0 else { throw CompanionFailure.unavailable("Coredump erase was not acknowledged") }
            summary()
          } catch { complete(.failure(error)) }
        }
      } catch { complete(.failure(error)) }
    }
  }
  func downloadCoredump(_ generation: Int, complete: @escaping (Result<[String: Any], Error>) -> Void) throws {
    try prepare(generation) { result in
      do {
        guard let current = try result.get()["generation"] as? Int else { throw CompanionFailure.invalid("Invalid preparation") }
        try self.readDiagnostic(current, path: "/user/coredump.txt", complete: complete)
      } catch { complete(.failure(error)) }
    }
  }

  var isIdle: Bool { pending == nil }
  func cancelActive(_ reason: String) {
    transport?.invalidate(); transport = nil; preparedGeneration = nil
    finish(.failure(CompanionFailure.unavailable(reason)))
  }
  /// Resume only after verifying the entire saved prefix against the watch.
  /// SDK APIs encode SMP; this owner only validates returned offsets/lengths.
  func downloadRecording(_ generation: Int, path: String, expected: Int, prefix: Data,
                         append: @escaping (Int, Data) throws -> Void,
                         complete: @escaping (Result<[String: Any], Error>) -> Void) throws {
    guard path.range(of: "^/user/recordings/[A-Za-z0-9_-]{1,32}\\.zsw_opus$", options: .regularExpression) != nil,
          (34...16 * 1024 * 1024).contains(expected), prefix.count <= expected else { throw CompanionFailure.invalid("Invalid recording download") }
    let sdk = try prepared(generation)
    let id = try begin(generation, timeout: 300, complete: complete)
    let manager = FileSystemManager(transport: sdk); downloadManager = manager
    guard let owner else { return }
    DispatchQueue.main.async {
      manager.status(name: path) { response, error in
        owner.queue.async {
          guard self.current(id, generation) else { return }
          guard error == nil, response?.getError() == nil, response?.len == UInt64(expected) else {
            self.finish(.failure(error ?? CompanionFailure.unavailable("Recording size changed"))); return
          }
          self.recordingChunk(id, generation, manager, path: path, expected: expected, prefix: prefix, offset: 0, verifying: !prefix.isEmpty, append: append)
        }
      }
    }
  }
  private func recordingChunk(_ id: UUID, _ generation: Int, _ manager: FileSystemManager,
                              path: String, expected: Int, prefix: Data, offset: Int, verifying: Bool,
                              append: @escaping (Int, Data) throws -> Void) {
    guard let owner, current(id, generation) else { return }
    if verifying, offset >= prefix.count {
      recordingChunk(id, generation, manager, path: path, expected: expected, prefix: Data(), offset: prefix.count, verifying: false, append: append); return
    }
    if !verifying, offset == expected { finish(.success(["version": 1, "completed": true])); return }
    DispatchQueue.main.async {
      manager.download(name: path, offset: UInt(offset)) { response, error in
        owner.queue.async {
          guard self.current(id, generation) else { return }
          guard error == nil, response?.getError() == nil, let response, response.off == UInt64(offset),
                response.len == nil || response.len == UInt64(expected), let chunk = response.data,
                !chunk.isEmpty, offset + chunk.count <= expected else {
            self.finish(.failure(error ?? CompanionFailure.unavailable("Recording chunk/length mismatch"))); return
          }
          let data = Data(chunk)
          do {
            if verifying {
              let end = min(offset + data.count, prefix.count)
              guard data.prefix(end - offset) == prefix.subdata(in: offset..<end) else { throw CompanionFailure.invalid("Saved recording prefix differs from the watch") }
            } else { try append(offset, data) }
            self.recordingChunk(id, generation, manager, path: path, expected: expected, prefix: prefix, offset: offset + data.count, verifying: verifying, append: append)
          } catch { self.finish(.failure(error)) }
        }
      }
    }
  }

  func inspectLogs(_ generation: Int, path: String?, complete: @escaping (Result<[String: Any], Error>) -> Void) throws {
    if let path, !Self.validLogPath(path) { throw CompanionFailure.invalid("Invalid log path") }
    try readDiagnostic(generation, path: path, complete: complete)
  }
  private func readDiagnostic(_ generation: Int, path: String?, complete: @escaping (Result<[String: Any], Error>) -> Void) throws {
    let sdk = try prepared(generation)
    let id = try begin(generation, timeout: path == nil ? 30 : 120, complete: complete)
    let manager = FileSystemManager(transport: sdk)
    downloadManager = manager
    inspect(id, generation, manager, paths: path.map { [$0] } ?? (0..<8).map { "/user/logs/log000\($0)" }, entries: [], download: path != nil)
  }
  private func inspect(_ id: UUID, _ generation: Int, _ manager: FileSystemManager,
                       paths: [String], entries: [[String: Any]], download: Bool) {
    guard let owner, current(id, generation) else { return }
    guard let path = paths.first else {
      finish(.success(["version": 1, "generation": generation, "files": entries])); return
    }
    DispatchQueue.main.async {
      manager.status(name: path) { response, error in
        owner.queue.async {
          guard self.current(id, generation) else { return }
          if let length = response?.len, error == nil, response?.getError() == nil, length <= UInt64(Int32.max) {
            let next = entries + [["path": path, "size_bytes": Int(length)]]
            if download {
              guard length <= 4 * 1024 * 1024 else { self.finish(.failure(CompanionFailure.invalid("Log file exceeds download limit"))); return }
              self.read(id, generation, manager, path: path, expected: Int(length), bytes: Data(), entries: next)
            } else { self.inspect(id, generation, manager, paths: Array(paths.dropFirst()), entries: next, download: false) }
          } else if !download, response?.rc == .noEntry || response?.groupRC?.rc.rawValue == FileSystemManagerError.notFound.rawValue {
            self.inspect(id, generation, manager, paths: Array(paths.dropFirst()), entries: entries, download: false)
          } else { self.finish(.failure(error ?? response?.getError() ?? CompanionFailure.unavailable("Log status unavailable"))) }
        }
      }
    }
  }
  private func read(_ id: UUID, _ generation: Int, _ manager: FileSystemManager,
                    path: String, expected: Int, bytes: Data, entries: [[String: Any]]) {
    guard let owner, current(id, generation) else { return }
    if bytes.count == expected {
      downloadManager = nil
      finish(.success(["version": 1, "generation": generation, "files": entries, "bytes": bytes])); return
    }
    DispatchQueue.main.async {
      manager.download(name: path, offset: UInt(bytes.count)) { response, error in
        owner.queue.async {
          guard self.current(id, generation) else { return }
          guard error == nil, response?.getError() == nil, let response,
                response.off == UInt64(bytes.count), let chunk = response.data, !chunk.isEmpty,
                response.len == nil || response.len == UInt64(expected), bytes.count + chunk.count <= expected else {
            self.finish(.failure(error ?? CompanionFailure.unavailable("File changed or returned invalid download data"))); return
          }
          var next = bytes; next.append(contentsOf: chunk)
          self.read(id, generation, manager, path: path, expected: expected, bytes: next, entries: entries)
        }
      }
    }
  }
  static func validLogPath(_ path: String) -> Bool {
    path.range(of: "^/user/logs/log000[0-7]$", options: .regularExpression) != nil
  }
}
