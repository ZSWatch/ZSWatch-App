import CoreBluetooth
import Foundation

/// Process-owned CoreBluetooth session. No Flutter object is retained here.
final class IOSCompanionCoordinator: NSObject, CBCentralManagerDelegate {
  static let restorationID = "dev.zswatch.companion.central.v1"
  static let nus = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
  static let receive = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
  static let transmit = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
  let queue = DispatchQueue(label: "dev.zswatch.companion", qos: .userInitiated)
  let journal: CompanionJournal
  private(set) var voice: IOSVoiceCoordinator?
  private(set) var inbox: IOSRecordingInbox?
  lazy var sensors = CompanionSensors(
    later: { [weak self] delay, work in self?.queue.asyncAfter(deadline: .now() + delay, execute: work) },
    notify: { [weak self] characteristic, enabled in self?.peripheral?.setNotifyValue(enabled, for: characteristic) },
    failed: { [weak self] in self?.lost("Sensor subscription timed out") })
  private var smpOwner: IOSCompanionSmp?
  lazy var firmware = IOSCompanionFirmware(owner: self)
  private var gpsRequested = false
  private var gpsToken = UUID()
  private lazy var gps = CompanionLocationRelay(
    send: { [weak self] generation, token, fix, done in
      self?.queue.async {
        guard let self, self.gpsToken == token, self.gpsRequested, self.isReadySession(generation), self.journal.fields["gps_enabled"] as? Bool == true,
              let packet = CompanionLocationPacket.encode(fix) else { return }
        try? self.send(packet, admission: { self.gpsToken == token && self.gpsRequested && self.isReadySession(generation) &&
          self.journal.fields["gps_enabled"] as? Bool == true && CompanionLocationPacket.encode(fix) != nil }, done: done)
      }
    },
    observe: { [weak self] generation, token, state, requested in
      self?.queue.async {
        guard let self, self.gpsToken == token, self.isReadySession(generation) else { return }
        self.gpsRequested = requested
        try? self.publish("gps_state", ["gps_runtime": ["generation": generation, "state": state, "requested": requested]])
      }
    })
  func configureGps(_ enabled: Bool) throws {
    guard journal.fields["gps_enabled"] as? Bool != enabled else { return }
    gpsRequested = false; gpsToken = UUID(); gps.close()
    try publish("gps_configuration", ["gps_enabled": enabled,
      "gps_runtime": ["generation": journal.generation, "state": enabled ? "idle" : "disabled", "requested": false]])
  }
  func uiForegrounded() { firmware.foregrounded(); inbox?.foregrounded(); voice?.foregrounded() }
  func uiInactive() { voice?.inactive() }
  func journalChanged() {
    if journal.loadError != nil { storageFailedIfNeeded(); return }
    let value = snapshot()
    for observer in observers.values { observer(value) }
  }
  func uiBackgrounded() {
    firmware.backgrounded()
    inbox?.backgrounded()
    scanStop()
    if gpsRequested, CompanionLocationRelay.permissions["background"] != true {
      gpsRequested = false; gpsToken = UUID()
      try? publish("gps_background_paused", ["gps_runtime": ["generation": journal.generation, "state": "permission_required", "requested": false]])
    }
    gps.backgrounded()
  }
  private var httpBatch = UUID()
  private let httpLease = CompanionBackgroundLease()
  private lazy var http: CompanionHttpRelay = CompanionHttpRelay(
    later: { [weak self] delay, work in self?.queue.asyncAfter(deadline: .now() + delay, execute: work) },
    fetch: { [weak self] request, done in
      let work = CompanionHttpRequest(request: request) { result in self?.queue.async { done(result) } }
      return { work.cancel() }
    },
    enabled: { [weak self] in self?.journal.fields["http_enabled"] as? Bool == true },
    send: { [weak self] packet, generation, admit, done in
      guard let self, self.isReadySession(generation) else { return false }
      do { try self.send(packet, admission: admit, done: done); return true } catch { return false }
    },
    observe: { [weak self] generation, outcome, count in
      guard let self else { return }
      if count == 0 { self.httpBatch = UUID(); self.httpLease.end() }
      else { let batch = self.httpBatch; self.httpLease.hold("ZSWatch HTTP response") { [weak self] in
        self?.queue.async {
          guard let self, self.httpBatch == batch, self.isReadySession(generation) else { return }
          self.http.close()
          try? self.publish("http_background_expired", ["http_pending_count": 0,
            "last_http": ["generation": generation, "outcome": "background_expired", "utc_ms": CompanionJournal.now]])
        }
      } }
      try? self.publish("http_state", ["http_pending_count": count,
        "last_http": ["generation": generation, "outcome": outcome, "utc_ms": CompanionJournal.now]])
    })
  func configureHttp(_ enabled: Bool) throws {
    try publish("http_configuration", ["http_enabled": enabled])
    if !enabled { http.disable() }
  }
  var smp: IOSCompanionSmp {
    if let smpOwner { return smpOwner }
    let created = IOSCompanionSmp(owner: self); smpOwner = created; return created
  }
  func isReadySession(_ generation: Int) -> Bool {
    journal.desired && journal.generation == generation && phase == "ready" && peripheral != nil
  }
  func publish(_ event: String, _ fields: [String: Any] = [:]) throws { try changed(event, fields) }
  private var central: CBCentralManager?
  private var peripheral: CBPeripheral?
  private var linkDelegate: CompanionLinkDelegate?
  private var rx: CBCharacteristic?
  private var tx: CBCharacteristic?
  private var phase = "stopped"
  private var cancellations = Set<UUID>()
  private var cancellationHandles: [UUID: CBPeripheral] = [:]
  private var writes: [(data: Data, offset: Int, chunks: Int, generation: Int, admission: () -> Bool, done: () -> Void)] = []
  private var awaitingWrite = false
  private let framer = CompanionNusFramer()
  private var scans: [UUID: [String: Any]] = [:]
  private var scanToken = 0
  private var scanSeenAt: [UUID: TimeInterval] = [:]
  private var scanning = false
  private var retryToken = 0
  private var discoveryToken = 0
  private var retryDelay: Double = 2
  private var observers: [UUID: ([String: Any]) -> Void] = [:]
  private var permissionWaiters: [UUID: (Result<Bool, Error>) -> Void] = [:]
  var logObserver: (([String: Any]) -> Void)?
  var trafficObserver: (([String: Any]) -> Void)?

  init(root: URL, restoredLaunch: Bool) {
    journal = CompanionJournal(url: root.appendingPathComponent("ios-companion/state.json"))
    super.init()
    queue.async {
      if var old = self.journal.fields["watchface_operation"] as? [String: Any],
         ["uploading", "verifying", "applying", "resetting"].contains(old["phase"] as? String ?? "") {
        old["application_uncertain"] = ["applying", "resetting"].contains(old["phase"] as? String ?? "")
        old["phase"] = "failed"; old["error"] = "interrupted"
        try? self.publish("watchface_process_interrupted", ["watchface_operation": old])
      }
      self.firmware.recover()
      do { self.voice = try IOSVoiceCoordinator(owner: self, root: root) }
      catch { try? self.publish("voice_storage_unavailable", ["voice_error": "Voice job storage unavailable"]) }
      self.inbox = IOSRecordingInbox(owner: self, root: root)
      self.inbox?.recover()
      if (self.journal.fields["http_pending_count"] as? Int ?? 0) > 0 {
        try? self.publish("http_process_interrupted", ["http_pending_count": 0,
          "last_http": ["generation": self.journal.generation, "outcome": "process_interrupted", "utc_ms": CompanionJournal.now]])
      }
      if self.journal.desired || restoredLaunch {
        self.ensureCentral()
      }
    }
  }

  private func ensureCentral() {
    if central == nil {
      central = CBCentralManager(delegate: self, queue: queue, options: [
        CBCentralManagerOptionRestoreIdentifierKey: Self.restorationID,
        CBCentralManagerOptionShowPowerAlertKey: true,
      ])
    }
  }

  func observe(_ callback: @escaping ([String: Any]) -> Void) -> UUID {
    let id = UUID()
    queue.async { self.observers[id] = callback; callback(self.snapshot()) }
    return id
  }
  func unobserve(_ id: UUID) { queue.async { self.observers.removeValue(forKey: id) } }

  func snapshot() -> [String: Any] {
    var fields = journal.fields
    fields["telemetry"] = Array((journal.fields["telemetry"] as? [[String: Any]] ?? []).prefix(200))
    let firstEvent = (journal.fields["events"] as? [[String: Any]])?.first?["seq"] as? Int ?? 1
    fields["event_gap"] = firstEvent > (journal.fields["acked_cursor"] as? Int ?? 0) + 1
    fields["telemetry_pending_count"] = (journal.fields["telemetry"] as? [[String: Any]] ?? []).count
    fields["gps_permissions"] = CompanionLocationRelay.permissions
    fields["bluetooth_state"] = central?.state.rawValue ?? CBManagerState.unknown.rawValue
    fields["pending_cancellations"] = cancellationHandles.values.map { ["address": $0.identifier.uuidString, "state": $0.state.rawValue] }
    fields.merge([
      "version": 1, "owner": "ios_companion_native", "platform": "ios",
      "runtime_active": journal.desired, "protocol_ready": journal.desired && phase == "ready",
      "phase": journal.loadError == nil ? phase : "error", "scan_active": scanning,
      "scan_results": scans.values.sorted { ($0["rssi"] as? Int ?? -127) > ($1["rssi"] as? Int ?? -127) },
      "ancs_authorized": peripheral?.ancsAuthorized ?? false,
      "capabilities": ["ble_restoration": true, "system_unpair": false,
                       "notification_filters": false, "ancs": true, "ams": true,
                       "smp": true, "voice_processing": voice != nil],
    ]) { _, live in live }
    if let error = journal.loadError { fields["last_error"] = error }
    return fields
  }

  private func changed(_ event: String, _ fields: [String: Any] = [:]) throws {
    var changes = fields
    var telemetry: (String, [String: Any])?
    if event == "health_received", let health = fields["latest_health"] as? [String: Any] {
      telemetry = ("health", health)
    } else if event == "watch_info_received", let info = fields["watch_info"] as? [String: Any],
              info["status_observed_ms"] as? Int != (journal.fields["watch_info"] as? [String: Any])?["status_observed_ms"] as? Int,
              let battery = info["battery_level"] as? Int {
      telemetry = ("battery", ["level": battery, "is_charging": info["is_charging"] as? Bool ?? false])
    } else if event == "connection_state", !journal.address.isEmpty {
      let old = journal.fields["phase"] as? String
      if phase == "ready", old != "ready" { telemetry = ("connection", ["event_type": "connected"]) }
      else if phase == "connecting", old != "connecting" { telemetry = ("connection", ["event_type": "reconnect_attempt"]) }
      else if phase != "ready", old == "ready" { telemetry = ("connection", ["event_type": "disconnected", "reason": "connection_lost"]) }
    }
    if let (kind, payload) = telemetry {
      changes.merge(journal.telemetryChanges(kind: kind, payload: payload)) { _, new in new }
    }
    do { try journal.update(event, changes) }
    catch {
      firmware.abort("storage_unavailable")
      closeLink(); phase = "error"
      for observer in observers.values { observer(snapshot()) }
      throw error
    }
    NSLog("[iOSCompanion] %@ generation=%ld phase=%@", event, journal.generation, phase)
    let value = snapshot()
    for observer in observers.values { observer(value) }
  }

  func storageFailedIfNeeded() {
    guard journal.loadError != nil else { return }
    firmware.abort("storage_unavailable")
    closeLink(); phase = "error"
    for observer in observers.values { observer(snapshot()) }
  }

  private func setPhase(_ value: String, error: String? = nil) {
    phase = value
    var fields: [String: Any] = ["phase": value, "last_error": error.map { $0 as Any } ?? NSNull()]
    if value == "ready" {
      fields["last_ready"] = ["address": journal.address, "generation": journal.generation,
                              "utc_ms": CompanionJournal.now]
    }
    do { try changed("connection_state", fields) }
    catch { NSLog("[iOSCompanion] storage error while changing connection state") }
  }

  func requestPermission(_ completion: @escaping (Result<Bool, Error>) -> Void) {
    ensureCentral()
    if let central, central.state != .unknown && central.state != .resetting {
      completion(.success(CBCentralManager.authorization == .allowedAlways)); return
    }
    let request = UUID()
    permissionWaiters[request] = completion
    queue.asyncAfter(deadline: .now() + 25) { [weak self] in
      guard let waiter = self?.permissionWaiters.removeValue(forKey: request) else { return }
      waiter(.failure(CompanionFailure.unavailable("Bluetooth permission is pending; respond to the iPhone prompt and try again")))
    }
  }

  func start(_ id: String, expected: Int? = nil) throws {
    guard !firmware.isActive else { throw CompanionFailure.unavailable("Wait for the firmware operation or stop it first") }
    if let expected {
      guard let selected = UUID(uuidString: id), scans[selected] != nil,
            expected == journal.generation, !journal.desired else {
        throw CompanionFailure.unavailable("Watch selection expired; choose again")
      }
    }
    let wasRunning = journal.desired
    try journal.start(id)
    if wasRunning { return }
    retryToken += 1; retryDelay = 2
    scanStop()
    ensureCentral()
    setPhase("connecting")
    if central?.state == .poweredOn { connectSelected() }
  }

  func stop() throws {
    // Persist intent and fence all operations before cancelling native handles.
    if phase == "ready" {
      try changed("user_disconnect", journal.telemetryChanges(kind: "connection", payload: ["event_type": "disconnected", "reason": "user_requested"]))
    }
    try journal.stop()
    firmware.abort("stopped")
    retryToken += 1
    scanStop(); closeLink()
    phase = "stopped"
    try changed("runtime_stopped")
  }

  func forget(_ id: String) throws {
    let selected = UUID(uuidString: id)?.uuidString == journal.address
    try journal.forget(id)
    if selected { firmware.abort("forgotten") }
    if selected { retryToken += 1; scanStop(); closeLink(); phase = "stopped" }
    try changed("watch_forgotten")
  }

  func scanStart() throws {
    guard !journal.desired else { throw CompanionFailure.unavailable("Stop before choosing another watch") }
    guard CBCentralManager.authorization == .allowedAlways else {
      throw CompanionFailure.unavailable("Bluetooth permission required")
    }
    ensureCentral()
    guard central?.state == .poweredOn else { throw CompanionFailure.unavailable("Turn on Bluetooth") }
    scans.removeAll(); scanSeenAt.removeAll(); scanning = true; scanToken += 1
    let token = scanToken
    for item in central!.retrieveConnectedPeripherals(withServices: [Self.nus]) {
      cacheScan(item, name: item.name, rssi: -127)
    }
    central!.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    try changed("scan_started")
    queue.asyncAfter(deadline: .now() + 20) { if self.scanToken == token { self.scanStop() } }
  }

  func scanStop() {
    scanToken += 1
    if scanning { central?.stopScan(); scanning = false; try? changed("scan_stopped") }
  }

  @discardableResult private func cacheScan(_ peripheral: CBPeripheral, name: String?, rssi: Int) -> Bool {
    guard let name, name.localizedCaseInsensitiveContains("ZSWatch") else { return false }
    let now = Date.timeIntervalSinceReferenceDate
    if let seen = scanSeenAt[peripheral.identifier], now - seen < 1 { return false }
    guard scans[peripheral.identifier] != nil || scans.count < 32 else { return false }
    scanSeenAt[peripheral.identifier] = now
    scans[peripheral.identifier] = ["address": peripheral.identifier.uuidString, "name": String(name.prefix(160)), "rssi": rssi]
    return true
  }

  private func connectSelected() {
    guard !firmware.holdsLink, journal.loadError == nil, peripheral == nil, journal.desired, central?.state == .poweredOn,
          let id = UUID(uuidString: journal.address), !cancellations.contains(id) else { return }
    guard let found = central?.retrievePeripherals(withIdentifiers: [id]).first else {
      setPhase("error", error: "Watch unavailable; scan and choose it again"); return
    }
    peripheral = found
    linkDelegate = CompanionLinkDelegate(owner: self, generation: journal.generation)
    found.delegate = linkDelegate
    if found.state == .connected { discover(found) }
    else { setPhase("connecting"); central?.connect(found, options: nil) }
  }
  func suspendForFirmware(_ generation: Int) throws {
    guard isReadySession(generation), firmware.isActive else { throw CompanionFailure.unavailable("Firmware session expired") }
    retryToken += 1
    try changed("firmware_session_fenced", ["generation": generation + 1])
    closeLink(); phase = "updating"
    try changed("firmware_session_suspended", ["phase": "updating"])
  }
  func resumeAfterFirmware() {
    guard journal.loadError == nil, journal.desired, !firmware.holdsLink else { return }
    connectSelected()
  }

  private func discover(_ item: CBPeripheral) {
    guard owns(item, journal.generation) else { return }
    sensors.reset(journal.generation)
    rx = nil; tx = nil; framer.reset()
    setPhase("discovering")
    item.discoverServices(nil)
    discoveryToken += 1
    let discovery = discoveryToken
    let generation = journal.generation
    queue.asyncAfter(deadline: .now() + 15) {
      guard self.discoveryToken == discovery, self.owns(item, generation), self.phase != "ready" else { return }
      if self.phase == "subscribing" {
        // An encrypted CCCD can be held while the user answers iOS pairing.
        self.setPhase("bonding", error: "Confirm ZSWatch pairing on the iPhone")
        self.queue.asyncAfter(deadline: .now() + 75) {
          if self.discoveryToken == discovery, self.owns(item, generation), self.phase != "ready" {
            self.lost("Pairing or service setup timed out; confirm pairing on the iPhone")
          }
        }
      } else { self.lost("Service setup timed out") }
    }
  }

  fileprivate func owns(_ item: CBPeripheral, _ generation: Int) -> Bool {
    peripheral === item && journal.owns(generation, item.identifier.uuidString)
  }

  private func cancel(_ item: CBPeripheral) {
    // Cancelling an already-disconnected restored handle produces no disconnect
    // callback. Do not wait forever for a callback CoreBluetooth will not emit.
    guard item.state != .disconnected else {
      cancellations.remove(item.identifier); cancellationHandles.removeValue(forKey: item.identifier); return
    }
    cancellations.insert(item.identifier); cancellationHandles[item.identifier] = item
    if central?.state == .poweredOn { central?.cancelPeripheralConnection(item) }
    NSLog("[iOSCompanion] cancellation pending peripheral=%ld central=%ld", item.state.rawValue, central?.state.rawValue ?? 0)
    pollCancellation(item)
  }
  private func pollCancellation(_ item: CBPeripheral) {
    queue.asyncAfter(deadline: .now() + 2) { [weak self] in
      guard let self, self.cancellations.contains(item.identifier) else { return }
      if item.state == .disconnected {
        self.cancellations.remove(item.identifier); self.cancellationHandles.removeValue(forKey: item.identifier)
        if self.journal.desired, self.peripheral == nil { self.connectSelected() }
      } else { self.pollCancellation(item) }
    }
  }

  private func closeLink() {
    phase = "disconnected"
    gpsRequested = false; gpsToken = UUID()
    http.close(); gps.close()
    smpOwner?.sessionClosed()
    inbox?.closed()
    voice?.sessionClosed()
    sensors.reset(journal.generation)
    discoveryToken += 1
    writes.removeAll(); awaitingWrite = false; rx = nil; tx = nil; framer.reset()
    if let peripheral {
      peripheral.delegate = nil
      cancel(peripheral)
    }
    peripheral = nil; linkDelegate = nil
  }

  private func lost(_ error: String) {
    guard journal.desired else { return }
    retryToken += 1
    let token = retryToken
    closeLink()
    try? changed("session_fenced", ["generation": journal.generation + 1])
    setPhase("disconnected", error: error)
    let generation = journal.generation
    queue.asyncAfter(deadline: .now() + retryDelay) {
      if self.retryToken == token, self.journal.desired, self.journal.generation == generation {
        self.connectSelected()
      }
    }
    retryDelay = min(60, retryDelay * 2)
  }

  func send(_ command: String, admission: @escaping () -> Bool = { true }, done: @escaping () -> Void = {}) throws {
    guard journal.desired, phase == "ready", let item = peripheral, let tx else {
      throw CompanionFailure.unavailable("Connect the watch first")
    }
    let data = Data(command.utf8)
    guard !data.isEmpty, data.count <= 32768, writes.count < 32 else {
      throw CompanionFailure.unavailable("Watch command queue is full")
    }
    let type: CBCharacteristicWriteType = tx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
    guard item.maximumWriteValueLength(for: type) > 0 else { throw CompanionFailure.unavailable("Bluetooth write size unavailable") }
    writes.append((data, 0, 0, journal.generation, admission, done))
    pump()
  }

  private func pump() {
    guard !awaitingWrite, let item = peripheral, let tx, phase == "ready", journal.desired else { return }
    let type: CBCharacteristicWriteType = tx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
    while let first = writes.first {
      guard first.generation == journal.generation else { writes.removeFirst(); continue }
      if first.offset == 0 && !first.admission() { writes.removeFirst(); continue }
      if type == .withoutResponse && !item.canSendWriteWithoutResponse { return }
      let end = min(first.data.count, first.offset + item.maximumWriteValueLength(for: type))
      item.writeValue(first.data.subdata(in: first.offset..<end), for: tx, type: type)
      writes[0].offset = end
      writes[0].chunks += 1
      if type == .withResponse { awaitingWrite = true; return }
      finishWrite()
    }
  }

  private func finishWrite() {
    guard let first = writes.first, first.offset == first.data.count else { return }
    writes.removeFirst()
    trafficObserver?(["version": 1, "direction": "tx", "data": String(data: first.data, encoding: .utf8) ?? "",
      "size_bytes": first.data.count, "chunk_count": first.chunks, "utc_ms": CompanionJournal.now, "generation": journal.generation])
    first.done()
  }

  func syncTime() throws {
    let now = Date()
    let offset = Double(TimeZone.current.secondsFromGMT(for: now)) / 3600
    // Firmware parses each clock command before JSON reassembly. Never split it.
    let packets = ["setTime(\(Int(now.timeIntervalSince1970)));", ";E.setTimeZone(\(offset));"]
    guard let item = peripheral, let tx else { throw CompanionFailure.unavailable("Connect the watch first") }
    let type: CBCharacteristicWriteType = tx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
    guard packets.allSatisfy({ $0.utf8.count <= item.maximumWriteValueLength(for: type) }) else {
      throw CompanionFailure.unavailable("Time command exceeds negotiated write size")
    }
    try send(packets[0])
    try send(packets[1], done: { [weak self] in
      try? self?.changed("time_written", ["last_time_write_utc_ms": CompanionJournal.now,
                                        "last_time_zone_offset_hours": offset])
    })
  }

  private func ready() {
    guard let item = peripheral, let rx, rx.isNotifying, tx != nil, journal.desired else { return }
    if phase == "ready" { return }
    retryDelay = 2
    try? changed("payload_negotiated", ["att_payload_bytes": item.maximumWriteValueLength(for: .withoutResponse)])
    setPhase("ready")
    // CTS supplies iOS system time; app sync is explicit or responds to the watch's request.
    try? send("GB({\"t\":\"ver\"})")
    try? send("GB({\"t\":\"voice_memo\",\"action\":\"list\"})")
    // Firmware publishes current battery/status after the connection event.
  }

  fileprivate func services(_ item: CBPeripheral, _ generation: Int, _ error: Error?) {
    guard owns(item, generation) else { return }
    if error != nil { lost("Service discovery failed"); return }
    guard let nus = item.services?.first(where: { $0.uuid == Self.nus }) else { lost("Watch protocol service missing"); return }
    item.discoverCharacteristics(nil, for: nus)
    for service in item.services ?? [] where CompanionSensors.specs.contains(where: { $0.service == service.uuid }) {
      item.discoverCharacteristics(nil, for: service)
    }
    for service in item.services ?? [] where service.uuid == CBUUID(string: "180F") {
      item.discoverCharacteristics([CBUUID(string: "2A19")], for: service)
    }
  }

  fileprivate func characteristics(_ item: CBPeripheral, _ generation: Int, _ service: CBService, _ error: Error?) {
    guard owns(item, generation) else { return }
    if error != nil { if service.uuid == Self.nus { lost("Characteristic discovery failed") }; return }
    sensors.discovered(service)
    for characteristic in service.characteristics ?? [] {
      if characteristic.uuid == Self.transmit { tx = characteristic }
      if characteristic.uuid == Self.receive { rx = characteristic }
      if characteristic.uuid == CBUUID(string: "2A19") {
        item.readValue(for: characteristic)
        if characteristic.properties.contains(.notify) { item.setNotifyValue(true, for: characteristic) }
      }
    }
    if service.uuid == Self.nus {
      guard let rx, let tx, rx.properties.contains(.notify),
            tx.properties.contains(.write) || tx.properties.contains(.writeWithoutResponse) else { lost("Watch protocol characteristics unavailable"); return }
      setPhase("subscribing")
      if rx.isNotifying { ready() } else { item.setNotifyValue(true, for: rx) }
    }
  }

  fileprivate func notification(_ item: CBPeripheral, _ generation: Int, _ characteristic: CBCharacteristic, _ error: Error?) {
    guard owns(item, generation) else { return }
    if sensors.notification(characteristic, error: error) { return }
    guard characteristic === rx else { return }
    if error != nil || !characteristic.isNotifying { lost("Watch subscription failed") } else { ready() }
  }

  fileprivate func value(_ item: CBPeripheral, _ generation: Int, _ characteristic: CBCharacteristic, _ error: Error?) {
    guard owns(item, generation), error == nil, let data = characteristic.value else { return }
    if sensors.receive(characteristic, bytes: data) { return }
    if characteristic.uuid == CBUUID(string: "2A19"), let battery = data.first, battery <= 100 {
      updateInfo(["battery_level": Int(battery), "status_generation": generation,
                  "status_observed_ms": CompanionJournal.now]); return
    }
    guard characteristic === rx else { return }
    framer.feed(data, message: {
      self.trafficObserver?(["version": 1, "direction": "rx", "generation": generation,
        "utc_ms": CompanionJournal.now, "data": String(data: self.framer.lastMessageData, encoding: .utf8) ?? "",
        "size_bytes": self.framer.lastMessageData.count, "chunk_count": self.framer.lastMessageChunks])
      self.receiveMessage($0)
    }, logger: {
      self.logObserver?(["version": 1, "kind": "log", "generation": generation, "utc_ms": CompanionJournal.now, "message": $0])
    })
  }

  private func updateInfo(_ additions: [String: Any]) {
    var info = journal.fields["watch_info"] as? [String: Any] ?? [:]
    if info["address"] as? String != journal.address { info = ["address": journal.address, "first_seen_ms": CompanionJournal.now] }
    info.merge(additions) { _, value in value }
    try? changed("watch_info_received", ["watch_info": info])
  }

  private func receiveMessage(_ value: [String: Any]) {
    guard phase == "ready", journal.desired, let type = value["t"] as? String else { return }
    if type == "gps_power", let wanted = value["status"] as? Bool {
      gpsRequested = wanted; gpsToken = UUID()
      gps.request(journal.generation, token: gpsToken, wanted: wanted, enabled: journal.fields["gps_enabled"] as? Bool == true)
      return
    }
    if http.receive(value, generation: journal.generation) { return }
    if smpOwner?.receiveWatchface(value) == true { return }
    if voice?.receiveAck(value) == true { return }
    if inbox?.receive(value) == true { voice?.deliverResults(); return }
    if type == "ver" {
      var info: [String: Any] = ["version_generation": journal.generation]
      for (wire, field) in [("fw", "firmware_version"), ("hw", "hardware_version"), ("sha", "firmware_sha")] {
        if let text = value[wire] as? String, !text.isEmpty, text.utf8.count <= 160 { info[field] = text }
      }
      if let debug = value["dbg"] as? Int { info["firmware_debug"] = debug == 1 }
      updateInfo(info)
    } else if type == "status", let battery = value["bat"] as? Int, (0...100).contains(battery) {
      updateInfo(["battery_level": battery, "is_charging": value["chg"] as? Int == 1,
                  "status_generation": journal.generation, "status_observed_ms": CompanionJournal.now])
    } else if type == "time" { try? syncTime() }
    else if type == "act" {
      var health = value
      health["address"] = journal.address; health["generation"] = journal.generation
      health["sequence"] = journal.cursor + 1; health["ts"] = value["ts"] ?? CompanionJournal.now
      try? changed("health_received", ["latest_health": health])
    } else if type == "coredump" {
      if value["available"] as? Bool == false { updateInfo(["coredump": NSNull()]) }
      else if let file = value["file"] as? String, let line = value["line"] as? Int, let time = value["time"] as? String {
        updateInfo(["coredump": ["file": String(file.prefix(512)), "line": line, "time": String(time.prefix(80))]])
      }
    }
  }

  fileprivate func writeCompleted(_ item: CBPeripheral, _ generation: Int, _ characteristic: CBCharacteristic, _ error: Error?) {
    guard owns(item, generation), characteristic === tx, awaitingWrite else { return }
    awaitingWrite = false
    if error != nil { lost("Watch write failed") } else { finishWrite(); pump() }
  }
  fileprivate func pump(_ item: CBPeripheral, _ generation: Int) { if owns(item, generation) { pump() } }
  fileprivate func modified(_ item: CBPeripheral, _ generation: Int) {
    guard owns(item, generation) else { return }
    do { try changed("services_fenced", ["generation": journal.generation + 1]) }
    catch { return }
    gpsRequested = false; gpsToken = UUID()
    http.close(); gps.close()
    smpOwner?.sessionClosed(allowPreparationRecovery: true)
    sensors.reset(journal.generation)
    writes.removeAll(); awaitingWrite = false
    linkDelegate = CompanionLinkDelegate(owner: self, generation: journal.generation)
    item.delegate = linkDelegate
    discover(item)
  }
  fileprivate func ancsChanged(_ item: CBPeripheral, _ generation: Int) { if owns(item, generation) { try? changed("ancs_authorization_changed") } }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    let waiters = permissionWaiters; permissionWaiters.removeAll()
    if central.state == .unknown || central.state == .resetting { permissionWaiters = waiters; return }
    for waiter in waiters.values { waiter(.success(CBCentralManager.authorization == .allowedAlways)) }
    if central.state == .poweredOn {
      // Restoration may precede poweredOn. Rejected intent must be cancelled
      // when the central can actually accept cancellation.
      for item in cancellationHandles.values { central.cancelPeripheralConnection(item) }
      if journal.desired && peripheral == nil {
        try? changed("runtime_restored", ["generation": journal.generation + 1])
        connectSelected()
      }
    } else {
      firmware.abort("radio_unavailable")
      scanStop(); closeLink(); cancellations.removeAll(); cancellationHandles.removeAll()
      if journal.desired {
        try? changed("radio_fenced", ["generation": journal.generation + 1])
        setPhase("disconnected", error: central.state == .unauthorized ? "Bluetooth permission required" : "Bluetooth is off")
      }
    }
    try? changed("bluetooth_state_changed")
  }
  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    central.stopScan() // Picker discovery never establishes connection intent.
    let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
    try? changed("core_bluetooth_restore_callback", ["restoration_callback_utc_ms": CompanionJournal.now])
    for item in restored {
      guard journal.desired, item.identifier.uuidString == journal.address else {
        cancel(item); continue
      }
      try? changed("restored_peripheral_attached", ["generation": journal.generation + 1])
      peripheral = item; linkDelegate = CompanionLinkDelegate(owner: self, generation: journal.generation)
      item.delegate = linkDelegate
      if item.state == .connected { discover(item) }
      else { setPhase("connecting"); central.connect(item, options: nil) }
    }
  }
  func centralManager(_ central: CBCentralManager, didDiscover item: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    guard scanning else { return }
    if cacheScan(item, name: advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? item.name, rssi: RSSI.intValue) {
      try? changed("watch_discovered")
    }
  }
  func centralManager(_ central: CBCentralManager, didConnect item: CBPeripheral) {
    if cancellations.contains(item.identifier) || !journal.desired || item.identifier.uuidString != journal.address {
      central.cancelPeripheralConnection(item); return
    }
    guard peripheral === item else { central.cancelPeripheralConnection(item); return }
    discover(item)
  }
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral item: CBPeripheral, error: Error?) {
    if cancellations.remove(item.identifier) != nil {
      cancellationHandles.removeValue(forKey: item.identifier)
      if journal.desired, peripheral == nil { connectSelected() }; return
    }
    if peripheral === item, journal.desired { lost("Watch disconnected") }
  }
  func centralManager(_ central: CBCentralManager, didFailToConnect item: CBPeripheral, error: Error?) {
    if cancellations.remove(item.identifier) != nil {
      cancellationHandles.removeValue(forKey: item.identifier)
      if journal.desired, peripheral == nil { connectSelected() }; return
    }
    if peripheral === item, journal.desired { lost("Watch connection failed") }
  }
}

/// Delegates carry their session token; old notifications cannot revive Stop.
private final class CompanionLinkDelegate: NSObject, CBPeripheralDelegate {
  weak var owner: IOSCompanionCoordinator?
  let generation: Int
  init(owner: IOSCompanionCoordinator, generation: Int) { self.owner = owner; self.generation = generation }
  func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) { owner?.services(p, generation, error) }
  func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) { owner?.characteristics(p, generation, s, error) }
  func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor c: CBCharacteristic, error: Error?) { owner?.notification(p, generation, c, error) }
  func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) { owner?.value(p, generation, c, error) }
  func peripheral(_ p: CBPeripheral, didWriteValueFor c: CBCharacteristic, error: Error?) { owner?.writeCompleted(p, generation, c, error) }
  func peripheralIsReady(toSendWriteWithoutResponse p: CBPeripheral) { owner?.pump(p, generation) }
  func peripheral(_ p: CBPeripheral, didModifyServices invalidatedServices: [CBService]) { owner?.modified(p, generation) }
  func peripheral(_ p: CBPeripheral, didUpdateANCSAuthorization isAuthorized: Bool) { owner?.ancsChanged(p, generation) }
}
