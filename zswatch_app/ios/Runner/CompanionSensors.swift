import CoreBluetooth
import Foundation

/// Ephemeral subscriptions on the companion peripheral. Never starts BLE.
final class CompanionSensors {
  struct Spec {
    let name: String; let code: String; let bytes: Int
    var service: CBUUID { CBUUID(string: "adaf\(code)00-c332-42a8-93bd-25e905756cb8") }
    var characteristic: CBUUID { CBUUID(string: "adaf\(code)01-c332-42a8-93bd-25e905756cb8") }
  }
  static let specs = [Spec(name: "temperature", code: "01", bytes: 4),
    Spec(name: "accelerometer", code: "02", bytes: 12), Spec(name: "light", code: "03", bytes: 4),
    Spec(name: "gyroscope", code: "04", bytes: 12), Spec(name: "magnetometer", code: "05", bytes: 12),
    Spec(name: "humidity", code: "07", bytes: 4), Spec(name: "pressure", code: "08", bytes: 4),
    Spec(name: "fusion", code: "0d", bytes: 16)]
  private struct Change {
    let id = UUID(); let name: String; let enabled: Bool
    let done: (Result<Void, Error>) -> Void
  }
  private var generation = 0
  private var characteristics: [String: CBCharacteristic] = [:]
  private var enabled = Set<String>()
  private var changes: [Change] = []
  private var current: Change?
  private var closing = false
  private let later: (Double, @escaping () -> Void) -> Void
  private let notify: (CBCharacteristic, Bool) -> Void
  private let failed: () -> Void
  var observer: (([String: Any]) -> Void)?
  init(later: @escaping (Double, @escaping () -> Void) -> Void,
       notify: @escaping (CBCharacteristic, Bool) -> Void, failed: @escaping () -> Void) {
    self.later = later; self.notify = notify; self.failed = failed
  }
  var state: [String: Any] { ["version": 1, "kind": "state", "generation": generation,
    "available": characteristics.keys.sorted(), "enabled": enabled.sorted()] }
  func reset(_ generation: Int) {
    let pending = changes + (current.map { [$0] } ?? [])
    current = nil; changes = []; enabled = []; characteristics = [:]; closing = false
    self.generation = generation
    pending.forEach { $0.done(.failure(CompanionFailure.unavailable("Sensor session closed"))) }
    observer?(state)
  }
  func discovered(_ service: CBService) {
    for spec in Self.specs where spec.service == service.uuid {
      if let characteristic = service.characteristics?.first(where: { $0.uuid == spec.characteristic && $0.properties.contains(.notify) }) {
        characteristics[spec.name] = characteristic
      }
    }
    observer?(state)
  }
  func request(_ name: String, enabled: Bool, done: @escaping (Result<Void, Error>) -> Void) throws {
    guard characteristics[name] != nil else { throw CompanionFailure.unavailable("Sensor unavailable") }
    guard !enabled || observer != nil, !closing else { throw CompanionFailure.unavailable("Open the sensor view first") }
    guard changes.count < 16 else { throw CompanionFailure.unavailable("Sensor request queue full") }
    changes.append(Change(name: name, enabled: enabled, done: done)); pump()
  }
  func stopAll() {
    let queued = changes; changes = []; closing = true
    queued.forEach { $0.done(.failure(CompanionFailure.unavailable("Sensor view closed"))) }
    let names = enabled.union(current?.enabled == true ? [current!.name] : [])
    for name in names { changes.append(Change(name: name, enabled: false, done: { _ in })) }
    pump()
  }
  func attached() { closing = false; observer?(state) }
  private func pump() {
    guard current == nil else { return }
    while !changes.isEmpty {
      let next = changes.removeFirst()
      if enabled.contains(next.name) == next.enabled { next.done(.success(())); continue }
      guard let characteristic = characteristics[next.name] else { next.done(.failure(CompanionFailure.unavailable("Sensor unavailable"))); continue }
      current = next; notify(characteristic, next.enabled)
      later(10) { [weak self] in
        guard let self, self.current?.id == next.id else { return }
        // A timed-out CCCD has an unknown result. Fence the peripheral instead
        // of letting its late callback acknowledge a newer request.
        self.failed()
      }
      return
    }
  }
  @discardableResult func notification(_ characteristic: CBCharacteristic, error: Error?) -> Bool {
    guard let name = characteristics.first(where: { $0.value === characteristic })?.key else { return false }
    guard let change = current, change.name == name else { return true }
    current = nil
    if error == nil, characteristic.isNotifying == change.enabled {
      if change.enabled { enabled.insert(name) } else { enabled.remove(name) }
      change.done(.success(()))
    } else { change.done(.failure(error ?? CompanionFailure.unavailable("Sensor subscription failed"))) }
    observer?(state); pump(); return true
  }
  @discardableResult func receive(_ characteristic: CBCharacteristic, bytes: Data) -> Bool {
    guard let name = characteristics.first(where: { $0.value === characteristic })?.key else { return false }
    guard enabled.contains(name), let spec = Self.specs.first(where: { $0.name == name }), bytes.count == spec.bytes else { return true }
    observer?(["version": 1, "kind": "sample", "generation": generation, "sensor": name, "bytes": bytes])
    return true
  }
}
