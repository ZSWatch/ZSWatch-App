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
    diagnosticStreams = ["logs", "traffic"].map {
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
          let bluetooth = CBCentralManager.authorization == .allowedAlways
          let ancs = owner.snapshot()["ancs_authorized"] as? Bool ?? false
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            reply(["version": 1, "bluetooth": bluetooth,
                   "notifications": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
                   "notification_access": ancs,
                   "location": location == .authorizedAlways || location == .authorizedWhenInUse,
                   "background_location": location == .authorizedAlways, "battery_exemption": false])
          }
        case "scanStart": try owner.scanStart(); reply(owner.snapshot())
        case "scanStop": owner.scanStop(); reply(owner.snapshot())
        case "start", "startDiscovered":
          guard let id = args["address"] as? String else { throw CompanionFailure.invalid("Watch identifier required") }
          var expected: Int?
          if call.method == "startDiscovered" {
            guard let generation = args["generation"] as? Int else { throw CompanionFailure.invalid("Selection generation required") }
            expected = generation
          }
          try owner.start(id, expected: expected)
          reply(["version": 1, "accepted": true])
        case "stop": try owner.stop(); reply(owner.snapshot())
        case "forgetWatch":
          guard let id = args["address"] as? String else { throw CompanionFailure.invalid("Watch identifier required") }
          try owner.forget(id); reply(owner.snapshot())
        case "setLogStreaming":
          guard let enabled = args["enabled"] as? Bool else { throw CompanionFailure.invalid("Log policy required") }
          try owner.send("GB({\"t\":\"log\",\"status\":\(enabled ? "true" : "false")})")
          try owner.journal.update("log_policy", ["log_streaming": enabled])
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
        self.sink?(value)
      }
    }
    owner.queue.async {
      if self.kind == "logs" {
        self.owner.logObserver = callback
        callback(["version": 1, "kind": "state", "generation": self.owner.journal.generation])
      } else { self.owner.trafficObserver = callback }
    }
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    token = UUID(); sink = nil
    owner.queue.async {
      if self.kind == "logs" { self.owner.logObserver = nil }
      else { self.owner.trafficObserver = nil }
    }
    return nil
  }
}
