import Foundation
import iOSMcuManagerLibrary

/// One process-owned update reservation, spanning Nordic's reset and a fresh
/// NUS/SMP boot check. Flutter observers never own its delegates or transport.
final class IOSCompanionFirmware {
  private weak var owner: IOSCompanionCoordinator?
  let operation: CompanionFirmwareOperation
  private var transport: McuMgrBleTransport?
  private var manager: FirmwareUpgradeManager?
  private var upgradeDelegate: IOSFirmwareDelegate?
  private var fileManager: FileSystemManager?
  private var fileDelegate: IOSResourceDelegate?
  private var images: [ImageManager.Image] = []
  private var targets: [CompanionFirmwareContract.Target] = []
  private var resources: Data?
  private var token = UUID()
  private var foreground = false
  private let lease = CompanionBackgroundLease()
  private var checking = false
  private var checkAttempts = 0
  private var activationSent = false
  private var verificationDeadline: Date?
  private var transferMeter: CompanionFirmwareTransferMeter?
  private var transferExpected = false
  private var lastProgress: (phase: String, count: Int, total: Int)?
  private var pipelineDepth = 1
  private var sarBuffer: UInt64 = 0
  private var finishing = false
  private var backgroundEpoch = UUID()
  private var transportCounters = IOSFirmwareTransportCounters()
  private(set) var holdsLink = false
  var isActive: Bool { operation.busy }
  init(owner: IOSCompanionCoordinator) { self.owner = owner; operation = CompanionFirmwareOperation(journal: owner.journal) }
  func recover() { do { try operation.recover(); owner?.journalChanged() } catch { owner?.storageFailedIfNeeded() } }
  private func current(_ token: UUID) -> Bool {
    guard self.token == token, operation.busy, let owner else { return false }
    return owner.journal.desired && owner.journal.address == operation.state?["address"] as? String
  }
  private func publish(_ action: () throws -> Void) -> Bool {
    do { try action(); owner?.journalChanged(); return true }
    catch { abort("storage_unavailable"); return false }
  }
  /// SDK calls run on main; admission is checked on the native owner queue.
  private func sdk(_ work: @escaping (McuMgrBleTransport) -> Void) {
    guard let owner, let transport else { return }
    let token = self.token
    DispatchQueue.main.async {
      guard owner.queue.sync(execute: { self.current(token) }) else { return }
      work(transport)
    }
  }
  func start(_ generation: Int, payloads: [(Int, Data)], resources: Data?) throws -> [String: Any] {
    guard let owner, !isActive, owner.isReadySession(generation) else { throw CompanionFailure.unavailable("Current Ready watch session required") }
    let parsed = try payloads.map { index, bytes -> ImageManager.Image in
      guard (0...2).contains(index), (32...CompanionFirmwareContract.maxBytes).contains(bytes.count) else { throw CompanionFailure.invalid("Invalid firmware image size/index") }
      let image = try McuMgrImage(data: bytes)
      guard image.hash.count == 32 else { throw CompanionFailure.invalid("SDK image hash is invalid") }
      return ImageManager.Image(image: index, slot: 1, hash: image.hash, data: bytes)
    }
    let targets = parsed.map { CompanionFirmwareContract.Target(index: $0.image, bytes: $0.data.count,
      hash: $0.hash.map { String(format: "%02x", $0) }.joined()) }
    try CompanionFirmwareContract.targets(targets, resources: resources)
    if let resources {
      let info = owner.journal.fields["watch_info"] as? [String: Any]
      try CompanionFirmwareContract.resources(resources, hardware: info?["hardware_version"] as? String ?? "")
      let measurement = owner.journal.fields["ios_firmware_transfer_measurement"] as? [String: Any]
      if resources.count > 512 * 1024, owner.journal.fields["ios_firmware_transfer_verified"] as? Bool != true || measurement?["address"] as? String != owner.journal.address {
        throw CompanionFailure.unavailable("Install and verify ordinary firmware first, then update large resource images")
      }
    }
    let sdk = try owner.smp.takePrepared(generation)
    do {
      let id = try operation.begin(address: owner.journal.address, generation: generation + 1, targets: targets, resources: resources)
      self.transport = sdk; self.images = parsed; self.targets = targets; self.resources = resources
      transportCounters = IOSFirmwareTransportCounters()
      sdk.logDelegate = transportCounters
      token = UUID(); finishing = false; holdsLink = true; checking = false; activationSent = false; checkAttempts = 0
      transferMeter = nil
      transferExpected = false; lastProgress = nil
      pipelineDepth = 1; sarBuffer = 0
      try owner.suspendForFirmware(generation)
      owner.queue.asyncAfter(deadline: .now() + 1200) { if self.operation.id == id, self.isActive { self.abort("operation_timeout") } }
      if !foreground { backgrounded() }
      preflight()
      return ["version": 1, "accepted": true, "id": id, "generation": generation + 1]
    } catch {
      sdk.invalidate(); abort("start_failed"); throw error
    }
  }
  private func preflight() {
    guard let owner else { return }
    let token = self.token
    sdk { sdk in DefaultManager(transport: sdk).params { response, error in owner.queue.async {
      guard self.current(token) else { return }
      if error == nil, response?.getError() == nil, let count = response?.bufferCount, count > 0,
         let size = response?.bufferSize, size > 0 {
        self.pipelineDepth = Int(min(3, count > 1 ? count - 1 : 1))
        self.sarBuffer = min(size, UInt64(UInt16.max))
      }
      self.preflightImages()
    } } }
  }
  private func preflightImages() {
    guard let owner else { return }
    if targets.isEmpty { uploadResources(); return }
    let token = self.token
    sdk { sdk in ImageManager(transport: sdk).list { response, error in owner.queue.async {
      guard self.current(token) else { return }
      guard error == nil, response?.getError() == nil, let reported = response?.images, reported.count <= 16 else { self.abort("image_state_rejected"); return }
      guard self.targets.allSatisfy({ target in reported.contains { $0.image == UInt64(target.index) } }) else { self.abort("boot_check_unavailable"); return }
      if let target = self.targets.first(where: { $0.index == 0 }) {
        self.transferExpected = !reported.contains { $0.image == UInt64(target.index) && $0.active &&
          $0.hash.map { String(format: "%02x", $0) }.joined() == target.hash }
      }
      self.transferMeter = CompanionFirmwareTransferMeter(targets: self.targets, transferExpected: self.transferExpected, hasResources: self.resources != nil)
      if self.resources != nil { self.uploadResources() } else { self.upgrade() }
    } } }
  }
  private func uploadResources() {
    guard let owner, let bytes = resources else { return }
    guard publish({ try operation.phase("resource_uploading"); try operation.progress(0, total: bytes.count); try operation.admitted() }) else { return }
    let token = self.token
    sdk { sdk in
      let manager = FileSystemManager(transport: sdk)
      let delegate = IOSResourceDelegate { event, count, total in owner.queue.async {
        guard self.current(token) else { return }
        if event == "progress" { self.progress(count, total: total) }
        else if event == "finished" {
          guard self.publish({ try self.operation.phase("resource_verifying"); try self.operation.progress(0, total: bytes.count) }) else { return }
          self.verifyResources(postBoot: false)
        } else { self.abort("resource_transfer_failed") }
      } }
      owner.queue.sync { self.fileManager = manager; self.fileDelegate = delegate }
      if !manager.upload(name: "/S/full_fs", data: bytes,
        using: FirmwareUpgradeConfiguration(pipelineDepth: self.pipelineDepth, byteAlignment: .fourByte,
          reassemblyBufferSize: self.sarBuffer), delegate: delegate) {
        owner.queue.async { if self.current(token) { self.abort("resource_transfer_failed") } }
      }
    }
  }
  private func verifyResources(postBoot: Bool) {
    guard let owner, let expected = resources else { return }
    let token = self.token
    sdk { sdk in
      let files = FileSystemManager(transport: sdk)
      owner.queue.sync { self.fileManager = files }
      files.status(name: "/S/full_fs") { response, error in owner.queue.async {
        guard self.current(token) else { return }
        guard error == nil, response?.getError() == nil, response?.len == UInt64(expected.count) else { self.abort("resource_transfer_failed"); return }
        self.resourceChunk(expected, offset: 0, postBoot: postBoot)
      } }
    }
  }
  private func resourceChunk(_ expected: Data, offset: Int, postBoot: Bool) {
    guard let owner, let files = fileManager else { return }
    if offset == expected.count {
      guard publish({ try operation.verifiedResource() }) else { return }
      if postBoot { complete() } else if images.isEmpty { resetResources() } else { upgrade() }
      return
    }
    let token = self.token
    sdk { _ in files.download(name: "/S/full_fs", offset: UInt(offset)) { response, error in owner.queue.async {
      guard self.current(token) else { return }
      guard error == nil, response?.getError() == nil, let response, response.off == UInt64(offset),
            response.len == nil || response.len == UInt64(expected.count), let chunk = response.data,
            !chunk.isEmpty, offset + chunk.count <= expected.count,
            Data(chunk) == expected.subdata(in: offset..<offset + chunk.count) else { self.abort("resource_transfer_failed"); return }
      // Post-boot resource readback is part of verifying, after the image check.
      self.progress(offset + chunk.count, total: expected.count)
      self.resourceChunk(expected, offset: offset + chunk.count, postBoot: postBoot)
    } } }
  }
  private func upgrade() {
    guard let owner, !images.isEmpty else { abort("invalid_images"); return }
    guard publish({ try operation.phase("validating"); try operation.admitted() }) else { return }
    let token = self.token; let images = self.images
    sdk { sdk in
      let delegate = IOSFirmwareDelegate { event, state, count, total, error in
        let observedAt = DispatchTime.now().uptimeNanoseconds // Capture before journal/owner-queue delay.
        owner.queue.async {
        guard self.current(token) else { return }
        switch event {
        case "state":
          let phase: String
          switch state { case .upload: phase = "uploading"; case .test, .confirm, .eraseAppSettings: phase = "applying"
          case .reset: phase = "rebooting"; case .success, .none: return; default: phase = "validating" }
          _ = self.publish { try self.operation.phase(phase) }
        case "progress":
          self.transferMeter?.progress(count, total: total, now: observedAt)
          self.progress(count, total: total)
        case "finished": self.postflight()
        case "cancelled": self.finish("cancelled", error: "cancelled", unknown: false)
        case "failed":
          if let error {
            let native = error as NSError
            var details: [String: Any] = ["state": String(describing: state), "operation_id": self.operation.id ?? "",
              "foreground": self.foreground, "transport": self.transportCounters.snapshot(),
              "domain": String(native.domain.prefix(120)), "code": native.code]
            // Transport cases contain only identifiers/numeric MTU, never raw
            // payloads or potentially private localized NSError userInfo.
            if let transportError = error as? McuMgrTransportError {
              details["reason"] = String(describing: transportError)
            }
            try? owner.publish("firmware_sdk_failure", ["last_firmware_sdk_failure": details])
          }
          self.abort("sdk_upgrade_failed")
        default: self.abort("sdk_upgrade_failed")
        }
      } }
      let manager = FirmwareUpgradeManager(transport: sdk, delegate: delegate)
      owner.queue.sync { self.manager = manager; self.upgradeDelegate = delegate }
      manager.start(images: images, using: FirmwareUpgradeConfiguration(eraseAppSettings: false,
        pipelineDepth: self.pipelineDepth, byteAlignment: .fourByte,
        reassemblyBufferSize: self.sarBuffer, upgradeMode: .confirmOnly))
    }
  }
  private func resetResources() {
    guard let owner, publish({ try operation.phase("rebooting"); try operation.admitted() }) else { return }
    let token = self.token
    sdk { sdk in DefaultManager(transport: sdk).reset { response, error in owner.queue.async {
      guard self.current(token) else { return }
      guard error == nil, response?.getError() == nil, response != nil else { self.abort("resource_reset_failed"); return }
      self.postflight()
    } } }
  }
  private func postflight() {
    guard let owner, current(token), publish({ try operation.phase("reconnecting") }) else { return }
    token = UUID() // Retire all upgrade/upload callbacks before boot verification.
    transport?.invalidate(); transport = nil; fileManager = nil; fileDelegate = nil
    holdsLink = false; checking = false; activationSent = false
    verificationDeadline = Date().addingTimeInterval(180 + Double((resources?.count ?? 0) / 8192))
    let token = self.token
    owner.queue.asyncAfter(deadline: .now() + 180 + Double((resources?.count ?? 0) / 8192)) {
      if self.current(token) { self.abort("boot_check_timeout") }
    }
    owner.resumeAfterFirmware(); pollBoot()
  }
  private func pollBoot() {
    guard let owner, current(token), let deadline = verificationDeadline else { return }
    if Date() >= deadline { abort("boot_check_timeout"); return }
    let info = owner.journal.fields["watch_info"] as? [String: Any]
    if owner.isReadySession(owner.journal.generation), !checking,
       info?["version_generation"] as? Int == owner.journal.generation,
       info?["status_generation"] as? Int == owner.journal.generation {
      if !activationSent {
        activationSent = true
        do { try owner.send("GB({\"t\":\"smp\",\"status\":true})") }
        catch { abort("boot_check_failed"); return }
      } else { checking = true; prepareBootCheck(); return }
    }
    let token = self.token
    owner.queue.asyncAfter(deadline: .now() + 1) { if self.current(token) { self.pollBoot() } }
  }
  private func prepareBootCheck() {
    guard let owner, let address = operation.state?["address"] as? String, let uuid = UUID(uuidString: address) else { return }
    let token = self.token; checkAttempts += 1
    DispatchQueue.main.async {
      guard owner.queue.sync(execute: { self.current(token) }) else { return }
      let sdk = McuMgrBleTransport(uuid); sdk.chunkSendDataToMtuSize = true; sdk.retryOnMissingResponse = false
      owner.queue.sync { self.transport = sdk }
      let value = "boot-\(token.uuidString.prefix(8))"
      DefaultManager(transport: sdk).echo(value) { response, error in owner.queue.async {
        guard self.current(token) else { return }
        guard error == nil, response?.getError() == nil, response?.response == value else {
          sdk.invalidate(); self.transport = nil; self.checking = false
          if self.checkAttempts < 3 {
            owner.queue.asyncAfter(deadline: .now() + 1) { if self.current(token) { self.pollBoot() } }
          } else { self.abort("boot_check_failed") }
          return
        }
        guard self.publish({ try self.operation.phase("verifying") }) else { return }
        self.checkImages()
      } }
    }
  }
  private func checkImages() {
    guard let owner else { return }
    if targets.isEmpty {
      guard publish({ try operation.verifiedImages([], reports: []) }) else { return }
      verifyResources(postBoot: true); return
    }
    let token = self.token
    sdk { sdk in ImageManager(transport: sdk).list { response, error in owner.queue.async {
      guard self.current(token) else { return }
      guard error == nil, response?.getError() == nil, let reported = response?.images, reported.count <= 16 else { self.abort("boot_check_failed"); return }
      let reports = reported.filter { $0.image <= 2 }.map { CompanionFirmwareContract.Report(index: Int($0.image),
        hash: $0.hash.map { String(format: "%02x", $0) }.joined(), active: $0.active) }
      do { try self.operation.verifiedImages(self.targets, reports: reports); owner.journalChanged() }
      catch { self.abort(error.localizedDescription == "boot_check_unavailable" ? "boot_check_unavailable" : "boot_check_failed"); return }
      if self.resources != nil { self.verifyResources(postBoot: true) } else { self.complete() }
    } } }
  }
  private func complete() {
    guard let owner, owner.isReadySession(owner.journal.generation),
          (owner.journal.fields["watch_info"] as? [String: Any])?["version_generation"] as? Int == owner.journal.generation,
          (owner.journal.fields["watch_info"] as? [String: Any])?["status_generation"] as? Int == owner.journal.generation else {
      abort("boot_check_failed"); return
    }
    if var measurement = transferMeter?.measurement, let target = targets.first(where: { $0.index == 0 }) {
      measurement["address"] = owner.journal.address; measurement["hash"] = target.hash
      measurement["pipeline_depth"] = pipelineDepth; measurement["server_buffer_bytes"] = sarBuffer
      do { try owner.publish("firmware_transfer_verified", ["ios_firmware_transfer_verified": true,
        "ios_firmware_transfer_measurement": measurement]) }
      catch { abort("storage_unavailable"); return }
    }
    finish("completed")
  }
  private func progress(_ count: Int, total: Int) {
    guard (1...CompanionFirmwareContract.maxBytes).contains(total), (0...total).contains(count) else { abort("invalid_sdk_progress"); return }
    let phase = operation.state?["phase"] as? String ?? ""
    if let previous = lastProgress, previous.phase == phase, previous.total == total,
       count >= previous.count, count < total, count - previous.count < max(1, total / 100) { return }
    lastProgress = (phase, count, total)
    _ = publish { try operation.progress(count, total: total) }
  }
  func cancel(_ id: String) throws {
    guard operation.id == id else { throw CompanionFailure.invalid("Firmware operation expired") }
    try operation.requestCancel(); owner?.journalChanged()
    let manager = self.manager
    sdk { _ in manager?.cancel() }
  }
  func abort(_ reason: String) { if operation.busy, !finishing { finish("failed", error: reason, unknown: operation.state?["effect_admitted"] as? Bool == true) } }
  private func finish(_ phase: String, error: String? = nil, unknown: Bool = false) {
    guard !finishing else { return }
    finishing = true
    let manager = self.manager; let files = fileManager
    transport?.invalidate(); transport = nil; token = UUID(); holdsLink = false; verificationDeadline = nil
    self.manager = nil; fileManager = nil; images = []; resources = nil; lease.end()
    DispatchQueue.main.async {
      files?.cancelTransfer()
      if phase != "completed" { manager?.abort(with: CompanionFailure.unavailable(error ?? "interrupted")) }
    }
    do { try operation.terminal(phase, error: error, unknown: unknown) } catch { owner?.storageFailedIfNeeded() }
    upgradeDelegate = nil; fileDelegate = nil
    if owner?.journal.loadError == nil { finishing = false }
    owner?.journalChanged(); owner?.resumeAfterFirmware()
  }
  private func executionReceipt(_ event: String, granted: Bool? = nil, remaining: TimeInterval? = nil) {
    guard let owner, operation.busy else { return }
    var receipt: [String: Any] = ["operation_id": operation.id ?? "", "event": event,
      "foreground": foreground, "transport": transportCounters.snapshot(),
      "timestamp_ms": Int64(Date().timeIntervalSince1970 * 1000)]
    if let granted { receipt["background_granted"] = granted }
    if let remaining, remaining.isFinite { receipt["background_seconds_remaining"] = min(3600, remaining) }
    var receipts = (owner.journal.fields["firmware_execution_receipts"] as? [[String: Any]] ?? [])
      .filter { $0["operation_id"] as? String == operation.id }
    receipts.append(receipt)
    try? owner.publish("firmware_execution", ["last_firmware_execution": receipt,
      "firmware_execution_receipts": Array(receipts.suffix(8))])
  }
  func foregrounded() {
    foreground = true; backgroundEpoch = UUID(); lease.end()
    executionReceipt("foreground")
  }
  func backgrounded() {
    foreground = false
    guard operation.busy, let owner else { return }
    backgroundEpoch = UUID()
    let id = operation.id, epoch = backgroundEpoch
    executionReceipt("background")
    lease.hold("ZSWatch firmware update", acquired: { granted, remaining in owner.queue.async {
      if self.operation.id == id, self.backgroundEpoch == epoch { self.executionReceipt("background_lease", granted: granted, remaining: remaining) }
    } }) { owner.queue.async {
      if self.operation.id == id, self.backgroundEpoch == epoch, self.isActive, !self.foreground { self.abort("background_expired") }
    } }
    owner.queue.asyncAfter(deadline: .now() + 20) {
      if self.operation.id == id, self.backgroundEpoch == epoch, self.isActive, !self.foreground { self.abort("background_expired") }
    }
  }
}

/// Count only known transport control events. Never retain SDK messages, packet
/// bytes, filenames, or localized errors in the persistent diagnostic journal.
private final class IOSFirmwareTransportCounters: McuMgrLogDelegate {
  private let lock = NSLock()
  private var counts: [String: Int] = [:]
  func log(_ msg: String, ofCategory category: McuMgrLogCategory, atLevel level: McuMgrLogLevel) {
    guard category == .transport else { return }
    let key: String
    if msg.hasPrefix("⏸︎ [Seq:") { key = "flow_pauses" }
    else if msg.hasPrefix("► [Seq:") { key = "flow_resumes" }
    else if msg.hasPrefix("(Retry ") { key = "flow_retries" }
    else if msg.hasPrefix("Retry ") { key = "response_retries" }
    else if msg.hasPrefix("-> [Seq:") { key = "written_chunks" }
    else if msg.hasPrefix("<- [Seq:") { key = "responses" }
    else { return }
    lock.lock(); counts[key, default: 0] += 1; lock.unlock()
  }
  func snapshot() -> [String: Int] { lock.lock(); defer { lock.unlock() }; return counts }
}

private final class IOSFirmwareDelegate: FirmwareUpgradeDelegate {
  let callback: (String, FirmwareUpgradeState, Int, Int, Error?) -> Void
  init(_ callback: @escaping (String, FirmwareUpgradeState, Int, Int, Error?) -> Void) { self.callback = callback }
  func upgradeDidStart(controller: FirmwareUpgradeController) {}
  func upgradeStateDidChange(from previousState: FirmwareUpgradeState, to newState: FirmwareUpgradeState) { callback("state", newState, 0, 0, nil) }
  func upgradeDidComplete() { callback("finished", .none, 0, 0, nil) }
  func upgradeDidFail(inState state: FirmwareUpgradeState, with error: Error) { callback("failed", state, 0, 0, error) }
  func upgradeDidCancel(state: FirmwareUpgradeState) { callback("cancelled", state, 0, 0, nil) }
  func uploadProgressDidChange(bytesSent: Int, imageSize: Int, timestamp: Date) { callback("progress", .upload, bytesSent, imageSize, nil) }
}
private final class IOSResourceDelegate: FileUploadDelegate {
  let callback: (String, Int, Int) -> Void
  init(_ callback: @escaping (String, Int, Int) -> Void) { self.callback = callback }
  func uploadProgressDidChange(bytesSent: Int, fileSize: Int, timestamp: Date) { callback("progress", bytesSent, fileSize) }
  func uploadDidFail(with error: Error) { callback("failed", 0, 0) }
  func uploadDidCancel() { callback("cancelled", 0, 0) }
  func uploadDidFinish() { callback("finished", 0, 0) }
}
