import Foundation
@main struct RecordingTests {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = CompanionRecordingFiles(root: root)
    let address = "FE88C737-593F-DB9B-732D-E11FF4C463F5"
    let raw: [String: Any] = ["filename": "memo_1", "timestamp": 1000, "size_bytes": 36, "duration_ms": 10]
    let (key, metadata) = CompanionRecordingFiles.metadata(raw, address: address)!
    var bytes = Data(repeating: 0, count: 36)
    func put(_ value: UInt32, _ offset: Int, _ count: Int) { for i in 0..<count { bytes[offset + i] = UInt8((value >> (8 * i)) & 255) } }
    bytes.replaceSubrange(0..<4, with: Data("ZSWO".utf8)); put(1,4,2); put(16000,6,2); put(160,8,2); put(1000,16,4); put(1,20,4); put(10,24,4); put(2,32,2); bytes[34] = 1; bytes[35] = 2
    precondition(CompanionRecordingFiles.valid(bytes, metadata: metadata))
    try store.append(key, offset: 0, bytes: bytes.prefix(20), expected: 36)
    let incomplete = try store.recover(key, metadata: metadata); precondition(incomplete == nil)
    let prefix = try store.prefix(key, expected: 36); precondition(prefix == bytes.prefix(20))
    try store.append(key, offset: 20, bytes: bytes.suffix(16), expected: 36)
    // Adopt publication after a process loss before committing its journal row.
    let receipt = try store.recover(key, metadata: metadata)!
    precondition(receipt["state"] as? String == "downloaded")
    precondition(receipt["sha256"] as? String == CompanionRecordingFiles.sha(bytes))
    precondition(!FileManager.default.fileExists(atPath: store.partial(key).path))
    let playbackRoot = root.appendingPathComponent("companion-recording-imports-v1")
    try FileManager.default.createDirectory(at: playbackRoot, withIntermediateDirectories: true)
    let playback = playbackRoot.appendingPathComponent("\(CompanionRecordingFiles.sha(Data(key.utf8)))-\(receipt["sha256"]!).ogg")
    // Use the exact importer filename; unrelated recordings/files survive.
    let exactPlayback = playbackRoot.appendingPathComponent("\(CompanionRecordingFiles.sha(Data(key.utf8)))-\(receipt["sha256"]!)-ogg-v1.ogg")
    try bytes.write(to: exactPlayback)
    try bytes.write(to: playback)
    try store.removeLocal(key, metadata: receipt)
    precondition(!FileManager.default.fileExists(atPath: store.destination(key).path))
    precondition(!FileManager.default.fileExists(atPath: exactPlayback.path))
    precondition(FileManager.default.fileExists(atPath: playback.path))
    // A lost process after a tombstone/file move can repeat it safely.
    try store.removeLocal(key, metadata: receipt)
    // Repair a late converter publication without overwriting the removed copy.
    try bytes.write(to: exactPlayback)
    try store.removeLocal(key, metadata: receipt)
    precondition(!FileManager.default.fileExists(atPath: exactPlayback.path))
    let restored = try store.restoreLocal(key, metadata: receipt)
    precondition(restored["sha256"] as? String == receipt["sha256"] as? String)
    precondition(FileManager.default.fileExists(atPath: exactPlayback.path))
    let restoredAgain = try store.restoreLocal(key, metadata: receipt)
    precondition(restoredAgain["state"] as? String == "downloaded")
    var bad = bytes; bad[32] = 255; precondition(!CompanionRecordingFiles.valid(bad, metadata: metadata))
    var wrong = raw; wrong["timestamp"] = true; precondition(CompanionRecordingFiles.metadata(wrong, address: address) == nil)
    wrong = raw; wrong["filename"] = "../memo"; precondition(CompanionRecordingFiles.metadata(wrong, address: address) == nil)
    // A forged symlink is never followed or overwritten.
    let (other, _) = CompanionRecordingFiles.metadata(raw.merging(["filename":"other"]) { _, new in new }, address: address)!
    try FileManager.default.createSymbolicLink(at: store.partial(other), withDestinationURL: store.destination(key))
    do { _ = try store.prefix(other, expected: 36); fatalError("Symlink accepted") } catch {}
    try store.removeLocal(key, metadata: receipt)
    try bytes.write(to: exactPlayback) // A late converter publication is included.
    let deleted = store.directory.appendingPathComponent("recently-deleted").appendingPathComponent(CompanionRecordingFiles.sha(Data(key.utf8)))
    let unknown = deleted.appendingPathComponent("unrelated-user-file")
    try bytes.write(to: unknown)
    do { try store.purgeLocal(key, metadata: receipt); fatalError("Unknown trash file purged") } catch {}
    precondition(FileManager.default.fileExists(atPath: exactPlayback.path))
    try FileManager.default.removeItem(at: unknown)
    try store.purgeLocal(key, metadata: receipt)
    precondition(!FileManager.default.fileExists(atPath: store.destination(key).path))
    precondition(!FileManager.default.fileExists(atPath: exactPlayback.path))
    precondition(!FileManager.default.fileExists(atPath: deleted.path))
    precondition(FileManager.default.fileExists(atPath: playback.path))
    try store.purgeLocal(key, metadata: receipt) // Recovery may repeat cleanup.
    print("PASS: partial/source recovery, selected-only local removal/restore/purge, integrity and path bounds")
  }
}
