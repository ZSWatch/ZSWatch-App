import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testTrafficCapturedWithoutAViewerRetainsOrderAndMetadata() {
    let traffic = CompanionTraffic()
    let first: [String: Any] = ["data": "räven 🦊", "size_bytes": 11, "direction": "rx",
                                "generation": 10, "utc_ms": 1234, "chunk_count": 2]
    traffic.append(first)
    traffic.append(["data": "while detached", "size_bytes": 14])
    XCTAssertEqual(traffic.replay.compactMap { $0["data"] as? String }, ["räven 🦊", "while detached"])
    XCTAssertEqual(traffic.replay.first?["utc_ms"] as? Int, 1234)
    XCTAssertEqual(traffic.replay.first?["chunk_count"] as? Int, 2)
    XCTAssertEqual(traffic.clear(), 2)
    XCTAssertTrue(traffic.replay.isEmpty)
    traffic.append(first)
    XCTAssertEqual(traffic.replay.count, 1)
    XCTAssertEqual(traffic.replay.first?["sequence"] as? Int, 3)
  }

  func testTrafficRotatesAtEntryAndByteLimits() {
    let traffic = CompanionTraffic()
    for index in 0..<5002 { traffic.append(["data": "\(index)", "size_bytes": 4]) }
    XCTAssertEqual(traffic.replay.count, 5000)
    XCTAssertEqual(traffic.replay.first?["data"] as? String, "2")
    traffic.clear()
    for index in 0..<81 { traffic.append(["data": "\(index)", "size_bytes": 65536]) }
    XCTAssertEqual(traffic.replay.count, 80)
    XCTAssertEqual(traffic.replay.first?["data"] as? String, "1")
    XCTAssertNil(traffic.append(["data": "oversized", "size_bytes": 65537]))
    XCTAssertNil(traffic.append(["data": "empty", "size_bytes": 0]))
    XCTAssertEqual(traffic.replay.count, 80)
  }

}
