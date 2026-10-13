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
