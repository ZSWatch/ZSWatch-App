import AccessorySetupKit
import CoreBluetooth
import UIKit

/// Availability-erased facade so the iOS 14–17 owner keeps its existing path.
protocol CompanionAccessorySetup: AnyObject {
  var activated: Bool { get }
  var identifiers: Set<UUID> { get }
  var presenting: Bool { get }
  func choose(existing: UUID?, completion: @escaping (Result<UUID, Error>) -> Void)
}

/// Accessory authorization belongs to the process, independently of Flutter.
/// All state and ASK callbacks run on the companion owner's serial queue.
@available(iOS 18.0, *)
final class IOSAccessorySetup: CompanionAccessorySetup {
  private let session = ASAccessorySession()
  private let queue: DispatchQueue
  private let changed: () -> Void
  private var completion: ((Result<UUID, Error>) -> Void)?
  private var selected: UUID?
  private var migrating: UUID?
  private var pickerError: Error?
  private(set) var activated = false
  private(set) var identifiers = Set<UUID>()
  var presenting: Bool { completion != nil }

  init(queue: DispatchQueue, changed: @escaping () -> Void) {
    self.queue = queue; self.changed = changed
    session.activate(on: queue) { [weak self] event in self?.handle(event) }
  }
  deinit { session.invalidate() }

  private func handle(_ event: ASAccessoryEvent) {
    switch event.eventType {
    case .activated:
      activated = true; refresh()
    case .accessoryAdded, .accessoryChanged, .migrationComplete:
      refresh()
      if presenting, let id = event.accessory?.bluetoothIdentifier { selected = id }
    case .accessoryRemoved:
      refresh()
    case .pickerSetupFailed:
      pickerError = CompanionFailure.unavailable("iPhone accessory setup failed; try again")
    case .pickerDidDismiss:
      refresh()
      if let selected = selected ?? migrating, identifiers.contains(selected) { finish(.success(selected)) }
      else { finish(.failure(pickerError ?? CompanionFailure.unavailable("Accessory setup cancelled"))) }
    case .invalidated:
      activated = false; identifiers.removeAll()
      finish(.failure(CompanionFailure.unavailable("iPhone accessory setup unavailable; reopen ZSWatch")))
      changed()
    default: break
    }
  }
  private func refresh() {
    identifiers = Set(session.accessories.filter { $0.state == .authorized }.compactMap(\.bluetoothIdentifier))
    changed()
  }
  private func finish(_ result: Result<UUID, Error>) {
    let done = completion; completion = nil; selected = nil; migrating = nil; pickerError = nil
    done?(result)
    changed()
  }

  func choose(existing: UUID?, completion: @escaping (Result<UUID, Error>) -> Void) {
    guard activated, !presenting else {
      completion(.failure(CompanionFailure.unavailable("Wait for iPhone accessory setup"))); return
    }
    if let existing, identifiers.contains(existing) { completion(.success(existing)); return }
    self.completion = completion
    selected = nil; migrating = existing; pickerError = nil
    // UI is only initiated by a foreground user command. Restoration never
    // presents a picker or requires a Flutter engine.
    DispatchQueue.main.async { [weak self] in
      let foreground = UIApplication.shared.applicationState == .active
      self?.queue.async { [weak self] in
        guard let self, self.presenting else { return }
        guard foreground, let image = UIImage(named: "AccessoryWatch") else {
          self.finish(.failure(CompanionFailure.unavailable("Open ZSWatch to set up your watch"))); return
        }
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = IOSCompanionCoordinator.nus
        descriptor.bluetoothNameSubstring = "ZSWatch"
        // No .bluetoothPairingLE: iOS drops the link as ASK-driven SMP completes
        // with the watch. Bonding happens on first connect via the watch's
        // security request, as before ASK.
        if #available(iOS 18.4, *) { descriptor.supportedOptions.insert(.bluetoothHID) }
        let item: ASPickerDisplayItem
        if let existing {
          let migration = ASMigrationDisplayItem(name: "ZSWatch", productImage: image, descriptor: descriptor)
          migration.peripheralIdentifier = existing
          item = migration
        } else {
          item = ASPickerDisplayItem(name: "ZSWatch", productImage: image, descriptor: descriptor)
        }
        self.session.showPicker(for: [item]) { [weak self] error in
          guard let error else { return } // Success is delivered by picker events.
          self?.queue.async { [weak self] in
            self?.finish(.failure(CompanionFailure.unavailable("Could not show iPhone accessory setup (\((error as NSError).code)); try again")))
          }
        }
      }
    }
  }
}
