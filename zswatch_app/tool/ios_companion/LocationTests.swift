import Foundation
import CoreLocation

@main struct LocationTests {
  static func main() throws {
    let now = Date(timeIntervalSince1970: 1791872000)
    func fix(age: Double = 0, accuracy: Double = 10, latitude: Double = 55.6) -> CLLocation {
      CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 13.0),
        altitude: 35, horizontalAccuracy: accuracy, verticalAccuracy: 5,
        course: 40, speed: 2, timestamp: now.addingTimeInterval(-age))
    }
    let packet = CompanionLocationPacket.encode(fix(), now: now)!
    let fields = try JSONSerialization.jsonObject(with: Data(packet.dropFirst(3).dropLast().utf8)) as! [String: Any]
    precondition(fields["speed"] as? Double == 7.2, "Preserve existing watch km/h mapping")
    precondition(fields["hdop"] as? Double == 10 && fields["gpsSource"] as? String == "phone")
    precondition(CompanionLocationPacket.encode(fix(age: 31), now: now) == nil, "Cached fixes expire")
    precondition(CompanionLocationPacket.encode(fix(age: -10), now: now) == nil, "Future clock skew is rejected")
    precondition(CompanionLocationPacket.encode(fix(accuracy: -1), now: now) == nil, "Invalid precision is rejected")
    precondition(CompanionLocationPacket.encode(fix(accuracy: 1001), now: now) == nil, "Coarse fixes cannot masquerade as precise GPS")
    precondition(CompanionLocationPacket.encode(fix(latitude: 91), now: now) == nil, "Invalid coordinates are rejected")
    precondition(CompanionLocationPacket.encode(fix(age: 600, accuracy: 5000), now: now, weather: true) != nil,
      "Weather accepts a recent approximate cached fix")
    precondition(CompanionLocationPacket.encode(fix(accuracy: 50001), now: now, weather: true) == nil,
      "Weather still requires bounded approximate accuracy")
    precondition(CompanionLocationPacket.encode(fix(age: 1801), now: now, weather: true) == nil,
      "Weather still rejects locations older than 30 minutes")
    precondition(CompanionLocationPacket.encode(fix(age: 600, accuracy: 5000), now: now) == nil,
      "Weather policy must not relax live GPS")
    print("PASS: GPS age/precision/coordinate bounds and existing units")
  }
}
