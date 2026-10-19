import Foundation

@main struct FirmwareTests {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let journal = CompanionJournal(url: root.appendingPathComponent("journal.json"))
    let operation = CompanionFirmwareOperation(journal: journal)
    let address = "FE88C737-593F-DB9B-732D-E11FF4C463F5"
    let hash = String(repeating: "a", count: 64)
    let target = CompanionFirmwareContract.Target(index: 0, bytes: 100, hash: hash)
    let id = try operation.begin(address: address, generation: 5, targets: [target], resources: nil)
    do { try operation.terminal("completed"); fatalError("SDK progress alone established completion") } catch {}
    try operation.phase("uploading"); try operation.admitted(); try operation.progress(100, total: 100)
    do { try operation.terminal("completed"); fatalError("Upload established boot proof") } catch {}
    do { try operation.progress(101, total: 100); fatalError("Invalid progress accepted") } catch {}
    do { try operation.verifiedImages([target], reports: []); fatalError("Missing image accepted") } catch {}
    do { try operation.verifiedImages([], reports: []); fatalError("Verification targets silently removed") } catch {}
    do { try operation.verifiedImages([target], reports: [.init(index: 0, hash: hash, active: false)]); fatalError("Inactive slot accepted") } catch {}
    do { try operation.verifiedImages([target], reports: [.init(index: 0, hash: String(repeating:"b",count:64), active: true)]); fatalError("Wrong hash accepted") } catch {}
    try operation.phase("verifying")
    try operation.verifiedImages([target], reports: [.init(index: 0, hash: hash, active: true)])
    try operation.terminal("completed")
    precondition(operation.state?["phase"] as? String == "completed")
    do { try operation.phase("uploading"); fatalError("Terminal callback revived operation") } catch {}
    precondition(operation.id == id)

    // A matched internal/external bundle can establish a primary-image measure.
    let external = CompanionFirmwareContract.Target(index: 2, bytes: 200, hash: hash)
    var meter = CompanionFirmwareTransferMeter(targets: [target, external], transferExpected: true, hasResources: false)
    meter.progress(20, total: 100, now: 1_000_000_000) // Initial offset may be old/resumed bytes.
    meter.progress(100, total: 200, now: 2_000_000_000) // Other image is not counted.
    meter.progress(80, total: 100, now: 3_000_000_000)
    meter.progress(100, total: 100, now: 5_000_000_000)
    precondition(meter.measurement?["bytes"] as? Int == 80)
    precondition(meter.measurement?["from_offset"] as? Int == 20)
    precondition(meter.measurement?["seconds"] as? Double == 4)
    meter.progress(0, total: 100, now: 6_000_000_000)
    precondition(meter.measurement?["bytes"] as? Int == 80) // Terminal measurement is immutable.
    for configuration in [(false, false), (true, true)] {
      var excluded = CompanionFirmwareTransferMeter(targets: [target], transferExpected: configuration.0, hasResources: configuration.1)
      excluded.progress(0, total: 100, now: 1); excluded.progress(100, total: 100, now: 2)
      precondition(excluded.measurement == nil)
    }
    var cached = CompanionFirmwareTransferMeter(targets: [target], transferExpected: true, hasResources: false)
    cached.progress(100, total: 100, now: 1); cached.progress(100, total: 100, now: 2)
    precondition(cached.measurement == nil)
    var ambiguous = CompanionFirmwareTransferMeter(targets: [target, .init(index: 2, bytes: 100, hash: hash)], transferExpected: true, hasResources: false)
    ambiguous.progress(0, total: 100, now: 1); ambiguous.progress(100, total: 100, now: 2)
    precondition(ambiguous.measurement == nil)
    var regressed = CompanionFirmwareTransferMeter(targets: [target], transferExpected: true, hasResources: false)
    regressed.progress(20, total: 100, now: 1); regressed.progress(10, total: 100, now: 2); regressed.progress(100, total: 100, now: 3)
    precondition(regressed.measurement == nil)

    var reversedTime = CompanionFirmwareTransferMeter(targets: [target], transferExpected: true, hasResources: false)
    reversedTime.progress(20, total: 100, now: 5); reversedTime.progress(100, total: 100, now: 4)
    precondition(reversedTime.measurement == nil)
    var noElapsedTime = CompanionFirmwareTransferMeter(targets: [target], transferExpected: true, hasResources: false)
    noElapsedTime.progress(20, total: 100, now: 5); noElapsedTime.progress(100, total: 100, now: 5)
    precondition(noElapsedTime.measurement == nil)

    // Validate actual resource table bounds, names and supported board sizes.
    func table(two: Bool = false) -> Data {
      let count = two ? 2 : 1, header = 16 + 40 * count
      var bytes = Data(repeating: 0, count: header + 12)
      func put(_ value: Int, _ offset: Int) { for i in 0..<4 { bytes[offset + i] = UInt8((value >> (i * 8)) & 255) } }
      put(0x0a0a0a0a,0); put(header,4); put(bytes.count,8); put(count,12); put(0x0a0a0a0a,bytes.count-4)
      bytes.replaceSubrange(16..<20, with: Data("icon".utf8)); put(0,48); put(8,52)
      if two { bytes.replaceSubrange(56..<60, with: Data("face".utf8)); put(4,88); put(4,92) }
      return bytes
    }
    let resource = table()
    try CompanionFirmwareContract.resources(resource, hardware: "zswatch@5/nrf5340/cpuapp")
    do { try CompanionFirmwareContract.resources(resource, hardware: "unknown"); fatalError("Unknown partition accepted") } catch {}
    do { try CompanionFirmwareContract.resourceTable(table(two:true)); fatalError("Overlapping entries accepted") } catch {}
    for length in 0..<20 { do { try CompanionFirmwareContract.resourceTable(Data(repeating: 0, count: length)); fatalError("Short resource accepted") } catch {} }
    var bad = resource; bad[16] = 0xff
    do { try CompanionFirmwareContract.resourceTable(bad); fatalError("Invalid UTF8 resource accepted") } catch {}
    bad = resource; bad[48] = 255
    do { try CompanionFirmwareContract.resourceTable(bad); fatalError("Resource bounds accepted") } catch {}
    _ = try operation.begin(address: address, generation: 6, targets: [], resources: resource)
    try operation.phase("resource_uploading"); try operation.admitted()
    do { try operation.requestCancel(); fatalError("Unsafe resource cancellation accepted") } catch {}
    try operation.verifiedImages([], reports: [])
    do { try operation.terminal("completed"); fatalError("Resource upload established mounted integrity") } catch {}
    try operation.verifiedResource(); try operation.terminal("completed")
    _ = try operation.begin(address: address, generation: 7, targets: [target], resources: nil)
    try operation.admitted(); try operation.phase("applying")
    let reopened = CompanionFirmwareOperation(journal: CompanionJournal(url: journal.url))
    try reopened.recover()
    precondition(reopened.state?["phase"] as? String == "failed")
    precondition(reopened.state?["result_unknown"] as? Bool == true)
    do { try reopened.phase("uploading"); fatalError("Interrupted update replayed") } catch {}
    print("PASS: firmware boot/hash proof, resource envelopes, cancellation bounds and interrupted-operation recovery")
  }
}
