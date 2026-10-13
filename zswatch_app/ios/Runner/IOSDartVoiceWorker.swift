import Flutter
import Foundation
import path_provider_foundation
import ffmpeg_kit_flutter_new_min

/// One processing engine, created only for a claimed local job. No BLE plugins.
final class IOSDartVoiceWorker {
  struct Failure: LocalizedError { let code: String; var errorDescription: String? { code } }
  private let queue: DispatchQueue
  private var engine: FlutterEngine?
  private var channel: FlutterMethodChannel?
  private var memory: FlutterMethodChannel?
  private var ready = false
  private var pending: (() -> Void)?
  private var job: String?
  private var executing = false
  private var checkpoint: ((String) throws -> Bool)?
  private var completion: ((Result<[String: Any], Error>) -> Void)?
  init(queue: DispatchQueue) { self.queue = queue }
  func execute(id: String, spec: [String: Any], input: [String: Any],
               checkpoint: @escaping (String) throws -> Bool,
               completed: @escaping (Result<[String: Any], Error>) -> Void) {
    DispatchQueue.main.async {
      guard self.job == nil else { self.queue.async { completed(.failure(Failure(code: "BUSY"))) }; return }
      self.job = id; self.checkpoint = checkpoint; self.completion = completed
      self.pending = {
        self.executing = true
        var fields = input; fields["version"] = 1; fields["job_id"] = id; fields["spec"] = spec
        self.channel?.invokeMethod(spec["provider"] as? String == "dart-fixture" ? "executeFixture" : "executeRecording", arguments: fields) { value in
          guard self.job == id else { return }
          if let error = value as? FlutterError { self.finish(.failure(Failure(code: error.code))) }
          else if let result = value as? [String: Any], result["job_id"] as? String == id,
                  CompanionRecordingFiles.integer(result["version"]) == 1, result["plugin_ready"] as? Bool == true {
            self.finish(.success(result))
          } else { self.finish(.failure(Failure(code: "INVALID_WORKER_REPLY"))) }
        }
      }
      if self.engine == nil { self.createEngine() }
      if self.ready { let work = self.pending; self.pending = nil; work?() }
      DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
        if self.job == id, !self.ready { self.pending = nil; self.finish(.failure(Failure(code: "WORKER_START_TIMEOUT"))) }
      }
    }
  }
  private func createEngine() {
    let engine = FlutterEngine(name: "zswatch-local-voice", project: nil, allowHeadlessExecution: true)
    self.engine = engine
    if !engine.run(withEntrypoint: "companionWorkerMain", libraryURI: "package:zswatch_app/main.dart") { finish(.failure(Failure(code: "WORKER_START_FAILED"))); return }
    guard let paths = engine.registrar(forPlugin: "PathProviderPlugin"),
          let audio = engine.registrar(forPlugin: "FFmpegKitFlutterPlugin") else {
      finish(.failure(Failure(code: "WORKER_PLUGIN_REGISTRATION_FAILED"))); return
    }
    PathProviderPlugin.register(with: paths)
    FFmpegKitFlutterPlugin.register(with: audio)
    let channel = FlutterMethodChannel(name: "dev.zswatch.app/companion_worker_v1", binaryMessenger: engine.binaryMessenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      if call.method == "ready", (call.arguments as? [String: Any])?["version"] as? Int == 1 {
        self.ready = true; result(nil)
        let work = self.pending; self.pending = nil; work?()
      } else if call.method == "checkpoint", let args = call.arguments as? [String: Any],
                let id = args["job_id"] as? String, let text = args["transcript"] as? String, id == self.job {
        let save = self.checkpoint
        self.queue.async {
          do {
            guard try save?(text) == true else { throw Failure(code: "CHECKPOINT_REJECTED") }
            DispatchQueue.main.async { result(nil) }
          } catch { DispatchQueue.main.async { result(FlutterError(code: "CHECKPOINT_REJECTED", message: "Job attempt expired", details: nil)) } }
        }
      } else { result(FlutterMethodNotImplemented) }
    }
    // The shared processor uses only memory information on this channel.
    memory = FlutterMethodChannel(name: "dev.zswatch.app/productivity", binaryMessenger: engine.binaryMessenger)
    memory?.setMethodCallHandler { call, result in
      switch call.method {
      case "getDeviceMemoryMB": result(Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024)))
      case "getAvailableMemoryMB": result(Int(os_proc_available_memory() / (1024 * 1024)))
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
  private func finish(_ result: Result<[String: Any], Error>) {
    let completion = self.completion
    self.completion = nil; checkpoint = nil; job = nil; executing = false; pending = nil
    queue.async { completion?(result) }
    // The pinned fllama helper explicitly retains native logger callbacks until
    // its next request. Keep this one idle engine for the process lifetime;
    // destroying its isolate after inference can leave C++ with stale pointers.
    // Models are created only for work; an idle engine grants no background time.

  }
  func cancel(_ id: String) {
    DispatchQueue.main.async {
      guard self.job == id else { return }
      if !self.executing { self.pending = nil; self.finish(.failure(Failure(code: "CANCELLED"))); return }
      self.channel?.invokeMethod("cancel", arguments: ["job_id": id])
    }
  }
}
