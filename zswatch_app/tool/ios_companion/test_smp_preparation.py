#!/usr/bin/env python3
"""Exercise the app's actual preparation-echo method with a deterministic SDK double.

No Bluetooth/device access. Only the idempotent initialization echo may retry;
late retries must respect stopped/replaced sessions and the original deadline.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / 'ios/Runner/IOSCompanionSmp.swift').read_text()
method = source.split('  private func echoPreparation(', 1)[1].split('  private func prepared(', 1)[0]
method = '  private func echoPreparation(' + method
support = r'''
import Foundation

enum CompanionFailure: Error { case unavailable(String) }
enum McuMgrBleTransportError: Error { case centralManagerPoweredOff, centralManagerNotReady, missingService }
final class McuMgrBleTransport {
  var plan: [McuMgrBleTransportError?]
  var calls = 0
  var invalidated = false
  init(_ plan: [McuMgrBleTransportError?]) { self.plan = plan }
  func invalidate() { invalidated = true }
}
struct EchoResponse {
  let response: String
  func getError() -> Error? { nil }
}
struct DefaultManager {
  let transport: McuMgrBleTransport
  func echo(_ text: String, completion: (EchoResponse?, Error?) -> Void) {
    transport.calls += 1
    let error = transport.plan.removeFirst()
    if let error { completion(nil, error) }
    else { completion(EchoResponse(response: text), nil) }
  }
}
final class Owner {
  let queue = DispatchQueue(label: "preparation-proof")
  var generation = 1
  var desired = true
  func isReadySession(_ generation: Int) -> Bool { desired && self.generation == generation }
  func publish(_ event: String, _ fields: [String: Any]) throws {}
}
final class Harness {
  struct Pending { let id: UUID; let generation: Int }
  let owner: Owner?
  var pending: Pending?
  var attempt = UUID()
  var transport: McuMgrBleTransport?
  var preparedGeneration: Int?
  var stages: [String] = []
  let done = DispatchSemaphore(value: 0)
  var succeeded = false
  init(_ owner: Owner) { self.owner = owner }
  func preparationReceipt(_ stage: String, error: Error? = nil) { stages.append(stage) }
  func finish(_ result: Result<[String: Any], Error>) {
    pending = nil
    if case .success = result { succeeded = true }
    done.signal()
  }
  func sessionClosed() { finish(.failure(CompanionFailure.unavailable("closed"))) }
  func start(_ sdk: McuMgrBleTransport) {
    let id = UUID(); pending = Pending(id: id, generation: 1); transport = sdk
    echoPreparation(sdk, id: id, generation: 1, token: attempt, echo: "owned-echo", retryCentral: true)
  }
'''
tests = r'''
}
func check(_ plan: [McuMgrBleTransportError?], calls: Int, success: Bool, mutation: String? = nil) {
  let owner = Owner(), sdk = McuMgrBleTransport(plan)
  let harness = Harness(owner)
  owner.queue.sync {
    harness.start(sdk)
    if let mutation {
      owner.queue.asyncAfter(deadline: .now() + 0.05) {
        if mutation == "stop" { owner.desired = false }
        else if mutation == "generation" { owner.generation += 1 }
        else { harness.finish(.failure(CompanionFailure.unavailable("original deadline"))) }
      }
      if mutation != "deadline" {
        owner.queue.asyncAfter(deadline: .now() + 0.4) { harness.sessionClosed() }
      }
    }
  }
  precondition(harness.done.wait(timeout: .now() + 2) == .success, "missing bounded completion")
  // Let a delayed retry try to run after Stop, replacement or deadline.
  Thread.sleep(forTimeInterval: 0.35)
  owner.queue.sync {
    precondition(sdk.calls == calls, "unexpected echo replay")
    precondition(harness.succeeded == success, "unexpected preparation result")
    if success { precondition(harness.preparedGeneration == 1) }
  }
}
DispatchQueue.global().async {
  check([.centralManagerPoweredOff, nil], calls: 2, success: true)
  check([.centralManagerNotReady, nil], calls: 2, success: true)
  check([.centralManagerPoweredOff, .centralManagerPoweredOff], calls: 2, success: false)
  check([.missingService], calls: 1, success: false)
  check([.centralManagerPoweredOff, nil], calls: 1, success: false, mutation: "deadline")
  check([.centralManagerPoweredOff, nil], calls: 1, success: false, mutation: "stop")
  check([.centralManagerPoweredOff, nil], calls: 1, success: false, mutation: "generation")
  print("PASS: actual preparation echo: transient startup, one retry, terminal errors, deadline, Stop and generation fences")
  exit(0)
}
dispatchMain()
'''
with tempfile.TemporaryDirectory(prefix='zswatch-smp-preparation-') as temp:
    test = Path(temp) / 'Proof.swift'
    test.write_text(support + method + tests)
    subprocess.run(['swift', str(test)], check=True)
