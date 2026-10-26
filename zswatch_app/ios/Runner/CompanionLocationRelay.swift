import CoreLocation
import Foundation
#if os(iOS)
import UIKit
#endif

struct CompanionLocationPacket {
  static func encode(_ fix: CLLocation, now: Date = Date()) -> String? {
    let age = now.timeIntervalSince(fix.timestamp)
    guard age >= -1, age <= 1800, fix.horizontalAccuracy >= 0,
          fix.horizontalAccuracy <= 50000,
          CLLocationCoordinate2DIsValid(fix.coordinate), fix.coordinate.latitude.isFinite,
          fix.coordinate.longitude.isFinite else { return nil }
    var fields: [String: Any] = ["t": "gps", "lat": fix.coordinate.latitude,
      "lon": fix.coordinate.longitude, "time": Int(fix.timestamp.timeIntervalSince1970 * 1000),
      "externalSource": true, "gpsSource": "phone", "hdop": fix.horizontalAccuracy]
    if fix.verticalAccuracy >= 0, fix.altitude.isFinite { fields["alt"] = fix.altitude }
    if fix.speed >= 0, fix.speed.isFinite { fields["speed"] = fix.speed * 3.6 }
    if fix.course >= 0, fix.course <= 360, fix.course.isFinite { fields["course"] = fix.course }
    guard let bytes = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else { return nil }
    return "GB(\(String(data: bytes, encoding: .utf8)!))"
  }
}

#if os(iOS)
/// CLLocationManager lives on main; the coordinator admits every response on
/// its own session queue. No location or permission prompt is persisted here.
final class CompanionLocationRelay: NSObject, CLLocationManagerDelegate {
  private var manager: CLLocationManager?
  private var token = UUID()
  private var generation = 0
  private var watchToken = UUID()
  private var requested = false
  private var lastWrite: Date?
  private var cachedTimestamp: Date?
  private let send: (Int, UUID, CLLocation, @escaping () -> Void) -> Void
  private let observe: (Int, UUID, String, Bool) -> Void
  init(send: @escaping (Int, UUID, CLLocation, @escaping () -> Void) -> Void,
       observe: @escaping (Int, UUID, String, Bool) -> Void) { self.send = send; self.observe = observe }
  static var permissions: [String: Bool] {
    let auth = CLLocationManager.authorizationStatus()
    return ["foreground": auth == .authorizedAlways || auth == .authorizedWhenInUse,
            "background": auth == .authorizedAlways, "services": CLLocationManager.locationServicesEnabled()]
  }
  func request(_ generation: Int, token: UUID, wanted: Bool, enabled: Bool) {
    DispatchQueue.main.async {
      self.stopOnMain(); self.generation = generation; self.watchToken = token
      guard wanted, enabled else { self.observe(generation, self.watchToken, enabled ? "idle" : "disabled", false); return }
      let permissions = Self.permissions
      guard permissions["foreground"] == true,
            UIApplication.shared.applicationState == .active || permissions["background"] == true else {
        self.observe(generation, self.watchToken, "permission_required", false); return
      }
      guard permissions["services"] == true else { self.observe(generation, self.watchToken, "services_disabled", false); return }
      let manager = self.manager ?? CLLocationManager(); self.manager = manager
      manager.delegate = self
      manager.desiredAccuracy = kCLLocationAccuracyBest
      manager.distanceFilter = 10
      manager.allowsBackgroundLocationUpdates = permissions["background"] == true
      // The watch asked for fixes. An automatic pause in the background only
      // resumes in the foreground, which would silently starve the watch.
      manager.pausesLocationUpdatesAutomatically = false
      self.requested = true; let token = self.token
      self.observe(generation, self.watchToken, "acquiring", true)
      manager.startUpdatingLocation()
      if let cached = manager.location {
        self.locationManager(manager, didUpdateLocations: [cached])
        if self.lastWrite != nil { self.cachedTimestamp = cached.timestamp }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        if self.token == token, self.requested, self.lastWrite == nil {
          self.stopOnMain(); self.observe(generation, self.watchToken, "location_unavailable", false)
        }
      }
    }
  }
  func close() { DispatchQueue.main.async { self.stopOnMain() } }
  func backgrounded() {
    DispatchQueue.main.async {
      if self.requested, Self.permissions["background"] != true {
        self.stopOnMain(); self.observe(self.generation, self.watchToken, "permission_required", false)
      }
    }
  }
  private func stopOnMain() {
    token = UUID(); requested = false; lastWrite = nil; cachedTimestamp = nil
    manager?.stopUpdatingLocation(); manager?.allowsBackgroundLocationUpdates = false
  }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard requested, let fix = locations.last, CompanionLocationPacket.encode(fix) != nil else { return }
    if let cachedTimestamp {
      // The first newer fix replaces the seed immediately, even inside the rate limit.
      guard fix.timestamp > cachedTimestamp else { return }
    } else {
      guard lastWrite == nil || Date().timeIntervalSince(lastWrite!) >= 5 else { return }
    }
    cachedTimestamp = nil
    lastWrite = Date(); let token = self.token; let generation = self.generation
    send(generation, watchToken, fix) {
      DispatchQueue.main.async {
        if self.token == token, self.requested { self.observe(generation, self.watchToken, "written", true) }
      }
    }
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard requested else { return }
    let denied = (error as? CLError)?.code == .denied
    stopOnMain(); observe(generation, watchToken, denied ? "permission_required" : "location_unavailable", false)
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if requested, Self.permissions["foreground"] != true {
      stopOnMain(); observe(generation, watchToken, "permission_required", false)
    }
  }
}
#endif
