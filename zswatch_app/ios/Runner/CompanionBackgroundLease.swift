import UIKit

/// A short system-granted opportunity; expiration cancels work, never extends it.
final class CompanionBackgroundLease {
  private var identifier = UIBackgroundTaskIdentifier.invalid
  private var token = UUID()
  func hold(_ name: String, expired: @escaping () -> Void) {
    DispatchQueue.main.async {
      guard self.identifier == .invalid else { return }
      let token = UUID(); self.token = token
      self.identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
        guard let self, self.token == token else { return }
        self.endOnMain(); expired()
      }
      if self.identifier == .invalid { expired() }
    }
  }
  func end() { DispatchQueue.main.async { self.endOnMain() } }
  private func endOnMain() {
    token = UUID()
    let previous = identifier; identifier = .invalid
    if previous != .invalid { UIApplication.shared.endBackgroundTask(previous) }
  }
}
