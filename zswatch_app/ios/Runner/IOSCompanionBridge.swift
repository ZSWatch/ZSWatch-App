import CoreBluetooth
import CoreLocation
import Flutter
import Foundation
import UserNotifications

/// One UI engine's observation/command bridge. Cancelling a stream never stops BLE.
final class IOSCompanionBridge: NSObject, FlutterStreamHandler {
  private let owner: IOSCompanionCoordinator
  private let methods: FlutterMethodChannel
  private let events: FlutterEventChannel
  private var observation: UUID?
  private var sink: FlutterEventSink?
  private var streamToken = UUID()
  private var diagnosticStreams: [CompanionDiagnosticStream] = []
  init(messenger: FlutterBinaryMessenger, owner: IOSCompanionCoordinator) {
    self.owner = owner
    methods = FlutterMethodChannel(name: "dev.zswatch.app/companion_v1", binaryMessenger: messenger)
    events = FlutterEventChannel(name: "dev.zswatch.app/companion_events_v1", binaryMessenger: messenger)
    super.init()
    methods.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    events.setStreamHandler(self)
    diagnosticStreams = ["logs", "traffic", "sensors"].map {
      CompanionDiagnosticStream(messenger: messenger, owner: owner, kind: $0)
    }
  }
  deinit { if let observation { owner.unobserve(observation) } }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard (arguments as? [String: Any])?["version"] as? Int == 1 else {
      return FlutterError(code: "VERSION", message: "Unsupported companion version", details: nil)
    }
    streamToken = UUID()
    let token = streamToken
    sink = events
    if let observation { owner.unobserve(observation) }
    observation = owner.observe { [weak self] snapshot in
      DispatchQueue.main.async {
        guard let self, self.streamToken == token else { return }
        self.sink?(snapshot)
      }
    }
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    streamToken = UUID()
    sink = nil
    if let observation { owner.unobserve(observation) }
    observation = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], args["version"] as? Int == 1 else {
      result(FlutterError(code: "VERSION", message: "Unsupported companion version", details: nil)); return
    }
    let reply: (Any?) -> Void = { value in DispatchQueue.main.async { result(value) } }
    owner.queue.async { [owner] in
      do {
        switch call.method {
        case "snapshot": reply(owner.snapshot())
        case "requestConnectionPermissions":
          owner.requestPermission { answer in
            switch answer {
            case .success(let granted): reply(["version": 1, "bluetooth": granted])
            case .failure(let error): reply(FlutterError(code: "PERMISSION", message: error.localizedDescription, details: nil))
            }
          }
        case "permissionStatus":
          let location = CLLocationManager.authorizationStatus()
          let bluetooth = owner.bluetoothAuthorized
          let ancs = owner.snapshot()["ancs_authorized"] as? Bool ?? false
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            reply(["version": 1, "bluetooth": bluetooth,
                   "notifications": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
                   "notification_access": ancs,
                   "location": location == .authorizedAlways || location == .authorizedWhenInUse,
                   "background_location": location == .authorizedAlways, "battery_exemption": false])
          }
        case "discoverWatch", "authorizeAccessory":
          let completed: (Result<[String: Any], Error>) -> Void = { answer in
            switch answer {
            case .success(let fields): reply(fields)
            case .failure(let error): reply(FlutterError(code: "ACCESSORY_SETUP", message: error.localizedDescription, details: nil))
            }
          }
          if call.method == "discoverWatch" { owner.discoverAccessory(completed) }
          else { owner.authorizeAccessory(completed) }
        case "scanStart": try owner.scanStart(); reply(owner.snapshot())
        case "scanStop": owner.scanStop(); reply(owner.snapshot())
        case "start", "startDiscovered":
          guard let id = args["address"] as? String else { throw CompanionFailure.invalid("Watch identifier required") }
          var expected: Int?
          if call.method == "startDiscovered" {
            guard let generation = args["generation"] as? Int else { throw CompanionFailure.invalid("Selection generation required") }
            expected = generation
          }
          owner.startWithSetup(id, expected: expected) { answer in
            switch answer {
            case .success: reply(["version": 1, "accepted": true])
            case .failure(let error): reply(FlutterError(code: "CONNECTION", message: error.localizedDescription, details: nil))
            }
          }
        case "stop": try owner.stop(); reply(owner.snapshot())
        case "forgetWatch":
          guard let id = args["address"] as? String else { throw CompanionFailure.invalid("Watch identifier required") }
          try owner.forget(id); reply(owner.snapshot())
        case "prepareShell", "executeShell", "inspectLogs", "restartWatch", "inspectCoredump", "downloadCoredump":
          guard let generation = args["generation"] as? Int else { throw CompanionFailure.invalid("Session generation required") }
          let completed: (Result<[String: Any], Error>) -> Void = { answer in
            switch answer {
            case .success(var fields):
              if let bytes = fields["bytes"] as? Data { fields["bytes"] = FlutterStandardTypedData(bytes: bytes) }
              reply(fields)
            case .failure(let error): reply(FlutterError(code: "SMP_FAILED", message: error.localizedDescription, details: nil))
            }
          }
          if call.method == "restartWatch" { try owner.smp.restart(generation, complete: completed) }
          else if call.method == "inspectCoredump" {
            guard let erase = args["erase"] as? Bool else { throw CompanionFailure.invalid("Erase policy required") }
            try owner.smp.inspectCoredump(generation, erase: erase, complete: completed)
          } else if call.method == "downloadCoredump" { try owner.smp.downloadCoredump(generation, complete: completed) }
          else if call.method == "prepareShell" { try owner.smp.prepare(generation, complete: completed) }
          else if call.method == "executeShell" {
            guard let command = args["command"] as? String else { throw CompanionFailure.invalid("Shell command required") }
            try owner.smp.shell(generation, command: command, complete: completed)
          } else {
            if let path = args["path"], !(path is NSNull), !(path is String) { throw CompanionFailure.invalid("Invalid log path") }
            try owner.smp.inspectLogs(generation, path: args["path"] as? String, complete: completed)
          }
        case "startWatchface", "resetWatchface":
          guard let generation = args["generation"] as? Int else { throw CompanionFailure.invalid("Watchface session required") }
          if call.method == "startWatchface" {
            guard let bytes = args["bytes"] as? FlutterStandardTypedData, let name = args["name"] as? String else { throw CompanionFailure.invalid("Background image required") }
            reply(try owner.smp.startWatchface(generation, bytes: bytes.data, name: name))
          } else { reply(try owner.smp.startWatchface(generation, bytes: nil, name: "Default")) }
        case "startFirmware":
          guard let generation = CompanionRecordingFiles.integer(args["generation"]),
                let raw = args["images"] as? [[String: Any]], raw.count <= 3,
                args["resources"] == nil || args["resources"] is FlutterStandardTypedData else { throw CompanionFailure.invalid("Firmware payload required") }
          let images = try raw.map { item -> (Int, Data) in
            guard let index = CompanionRecordingFiles.integer(item["index"]), let bytes = item["bytes"] as? FlutterStandardTypedData else { throw CompanionFailure.invalid("Firmware image required") }
            return (index, bytes.data)
          }
          reply(try owner.firmware.start(generation, payloads: images, resources: (args["resources"] as? FlutterStandardTypedData)?.data))
        case "cancelFirmware":
          guard let id = args["id"] as? String else { throw CompanionFailure.invalid("Firmware operation required") }
          try owner.firmware.cancel(id); reply(["version": 1, "accepted": true])
        case "verifyWorkerRuntime":
          guard let voice = owner.voice else { throw CompanionFailure.unavailable("Voice owner unavailable") }
          try voice.verifyWorker { answer in
            switch answer {
            case .success(let fields): reply(fields)
            case .failure(let error): reply(FlutterError(code: "WORKER_FAILED", message: error.localizedDescription, details: nil))
            }
          }
        case "processRecording":
          guard let voice = owner.voice else { throw CompanionFailure.unavailable("Voice job storage unavailable") }
          reply(["version": 1, "job_id": try voice.start(args)])
        case "editVoiceTranscript":
          guard let voice = owner.voice, let id = args["job_id"] as? String,
                let text = args["transcript"] as? String else { throw CompanionFailure.invalid("Current transcript required") }
          reply(["version": 1, "job_id": try voice.editTranscript(id, transcript: text)])
        case "updateRecording", "restoreRecording":
          guard let inbox = owner.inbox, let identity = args["identity"] as? String else { throw CompanionFailure.invalid("Recording identity required") }
          if call.method == "restoreRecording" { try inbox.restore(identity) }
          else {
            guard args["title"] == nil || args["title"] is String,
                  args["archived"] == nil || CompanionRecordingFiles.boolean(args["archived"]) != nil else { throw CompanionFailure.invalid("Invalid recording changes") }
            try inbox.update(identity, title: args["title"] as? String, archived: CompanionRecordingFiles.boolean(args["archived"]))
          }
          reply(owner.snapshot())
        case "removeRecordings", "purgeRecordings":
          guard let inbox = owner.inbox, let identities = args["identities"] as? [String] else { throw CompanionFailure.invalid("Selected recordings required") }
          if call.method == "purgeRecordings" { try inbox.purge(identities) } else { try inbox.remove(identities) }
          reply(owner.snapshot())
        case "searchRecordings":
          guard let query = args["query"] as? String, query.utf8.count <= 512 else { throw CompanionFailure.invalid("Search query too long") }
          var matches = owner.voice?.jobs.search(query) ?? []
          let records = owner.journal.fields["recordings"] as? [String: [String: Any]] ?? [:]
          for (key, record) in records {
            if [record["title"] as? String ?? "", record["filename"] as? String ?? ""].contains(where: { $0.localizedCaseInsensitiveContains(query) }) { matches.insert(key) }
          }
          matches.formIntersection(records.keys)
          reply(["version": 1, "identities": matches.sorted()])
        case "voiceJob", "cancelVoiceJob":
          guard let voice = owner.voice, let id = args["job_id"] as? String,
                id.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { throw CompanionFailure.invalid("Voice job required") }
          if call.method == "cancelVoiceJob" { try voice.cancel(id) }
          reply(["version": 1, "job_id": id, "job": try voice.jobs.detail(id)])
        case "configureVoiceActions":
          guard let autoCreate = args["auto_create"] as? Bool else { throw CompanionFailure.invalid("Voice action policy required") }
          try owner.publish("voice_actions", ["voice_actions": ["auto_create": autoCreate]])
          reply(owner.snapshot())
        case "undoVoiceResult":
          guard let voice = owner.voice, let id = args["job_id"] as? String,
                id.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { throw CompanionFailure.invalid("Voice job required") }
          reply(["version": 1, "undone": voice.undo(id)])
        case "configureVoiceProcessing":
          guard let voice = owner.voice else { throw CompanionFailure.unavailable("Voice job storage unavailable") }
          try voice.configure(args); reply(owner.snapshot())
        case "setRecordingSync":
          guard let enabled = args["enabled"] as? Bool else { throw CompanionFailure.invalid("Recording sync policy required") }
          try owner.publish("recording_sync_policy", ["recording_sync_enabled": enabled])
          if enabled { owner.inbox?.resumeSync() }
          else { owner.inbox?.pauseSync() }
          reply(owner.snapshot())
        case "retryRecordings": try owner.inbox?.retryFailed(); reply(owner.snapshot())
        case "sensorState": reply(owner.sensors.state)
        case "setSensor":
          guard let generation = args["generation"] as? Int, owner.isReadySession(generation),
                let sensor = args["sensor"] as? String, let enabled = args["enabled"] as? Bool else {
            throw CompanionFailure.invalid("Current sensor session required")
          }
          try owner.sensors.request(sensor, enabled: enabled) { answer in
            switch answer {
            case .success: reply(["version": 1, "completed": true])
            case .failure(let error): reply(FlutterError(code: "SENSOR_FAILED", message: error.localizedDescription, details: nil))
            }
          }
        case "configureGps":
          guard let enabled = args["enabled"] as? Bool else { throw CompanionFailure.invalid("Location sharing policy required") }
          try owner.configureGps(enabled); reply(owner.snapshot())
        case "configureHttp":
          guard let enabled = args["enabled"] as? Bool else { throw CompanionFailure.invalid("HTTP policy required") }
          try owner.configureHttp(enabled); reply(owner.snapshot())
        case "setLogStreaming":
          guard let enabled = args["enabled"] as? Bool else { throw CompanionFailure.invalid("Log policy required") }
          try owner.setLogStreaming(enabled)
          reply(nil)
        case "syncTime": try owner.syncTime(); reply(owner.snapshot())
        case "requestDeviceInfo": try owner.send("GB({\"t\":\"ver\"})"); reply(owner.snapshot())
        case "requestRecordingList": try owner.send("GB({\"t\":\"voice_memo\",\"action\":\"list\"})"); reply(owner.snapshot())
        case "findWatch":
          guard args["generation"] as? Int == owner.journal.generation else { throw CompanionFailure.invalid("Session expired") }
          try owner.send("GB({\"t\":\"find\",\"n\":true})")
          try owner.journal.update("find_requested", ["find_receipt": ["accepted": true, "generation": owner.journal.generation]])
          reply(owner.snapshot())
        case "stopFindWatch":
          guard args["generation"] as? Int == owner.journal.generation else { throw CompanionFailure.invalid("Session expired") }
          try owner.send("GB({\"t\":\"find\",\"n\":false})"); reply(["version": 1, "completed": true])
        case "notificationStatus":
          let authorized = owner.snapshot()["ancs_authorized"] as? Bool ?? false
          reply(["version": 1, "access_granted": authorized, "listener_connected": authorized, "apps": []])
        case "presenceStatus", "associatePresence":
          reply(["version": 1, "address": args["address"] ?? "", "supported": false, "associated": false])
        case "ackTelemetry":
          guard args["journal_id"] as? String == owner.journal.fields["journal_id"] as? String,
                let cursor = args["sequence"] as? Int else { throw CompanionFailure.invalid("Invalid telemetry receipt") }
          try owner.journal.ackTelemetry(cursor)
          reply(owner.snapshot())
        case "ackEvents":
          guard let cursor = args["cursor"] as? Int, cursor >= 0, cursor <= owner.journal.cursor else {
            throw CompanionFailure.invalid("Invalid event cursor")
          }
          // Acknowledgement never changes selected watch or connection intent.
          if cursor > (owner.journal.fields["acked_cursor"] as? Int ?? 0) {
            try owner.journal.update("events_acknowledged", ["acked_cursor": cursor])
          }
          reply(owner.snapshot())
        default:
          reply(FlutterError(code: "UNAVAILABLE", message: "This operation is currently unavailable", details: nil))
        }
      } catch {
        owner.storageFailedIfNeeded()
        reply(FlutterError(code: "COMPANION_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }
}


/// Diagnostic streams are ephemeral. Observation never opens or stops BLE.
private final class CompanionDiagnosticStream: NSObject, FlutterStreamHandler {
  let owner: IOSCompanionCoordinator
  let kind: String
  let channel: FlutterEventChannel
  private var token = UUID()
  private var sink: FlutterEventSink?
  private var registeredToken: UUID?
  init(messenger: FlutterBinaryMessenger, owner: IOSCompanionCoordinator, kind: String) {
    self.owner = owner; self.kind = kind
    channel = FlutterEventChannel(name: "dev.zswatch.app/companion_\(kind)_v1", binaryMessenger: messenger)
    super.init()
    channel.setStreamHandler(self)
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard (arguments as? [String: Any])?["version"] as? Int == 1 else {
      return FlutterError(code: "VERSION", message: "Unsupported companion version", details: nil)
    }
    token = UUID(); let stream = token; sink = events
    let callback: ([String: Any]) -> Void = { [weak self] value in
      DispatchQueue.main.async {
        guard let self, self.token == stream else { return }
        var fields = value
        if let bytes = fields["bytes"] as? Data { fields["bytes"] = FlutterStandardTypedData(bytes: bytes) }
        self.sink?(fields)
      }
    }
    owner.queue.async {
      self.registeredToken = stream
      if self.kind == "logs" {
        self.owner.logObserver = callback
        callback(self.owner.logStreamingState)
      } else if self.kind == "sensors" {
        self.owner.sensors.observer = callback; self.owner.sensors.attached()
      } else { self.owner.trafficObserver = callback }
    }
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    let cancelled = token; token = UUID(); sink = nil
    owner.queue.async {
      guard self.registeredToken == cancelled else { return }
      self.registeredToken = nil
      if self.kind == "logs" { self.owner.logObserver = nil }
      else if self.kind == "sensors" { self.owner.sensors.observer = nil; self.owner.sensors.stopAll() }
      else { self.owner.trafficObserver = nil }
    }
    return nil
  }
}
