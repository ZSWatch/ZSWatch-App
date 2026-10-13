import CryptoKit
import CoreFoundation
import Foundation

/// Native source receipts only; Drift and the Ogg converter remain Dart-owned.
final class CompanionRecordingFiles {
  let directory: URL
  init(root: URL) { directory = root.resolvingSymlinksInPath().appendingPathComponent("companion-prototype/recordings", isDirectory: true) }
  static func sha(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
  static func integer(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
          number.doubleValue.isFinite, number.doubleValue >= 0, number.doubleValue <= Double(Int.max - 1024),
          Double(number.intValue) == number.doubleValue else { return nil }
    return number.intValue
  }
  static func metadata(_ value: [String: Any], address: String) -> (String, [String: Any])? {
    guard UUID(uuidString: address)?.uuidString == address,
          let name = value["filename"] as? String,
          name.range(of: "^[A-Za-z0-9_-]{1,32}$", options: .regularExpression) != nil,
          let size = integer(value["size_bytes"]), (34...16 * 1024 * 1024).contains(size),
          let timestamp = integer(value["timestamp"]), timestamp <= 0xffffffff,
          let duration = integer(value["duration_ms"]), duration > 0, duration <= 0xffffffff else { return nil }
    return ("\(address):\(name):\(timestamp):\(size):\(duration)",
      ["address": address, "filename": name, "timestamp": timestamp, "size_bytes": size,
       "duration_ms": duration, "state": "pending"])
  }
  static func valid(_ data: Data, metadata: [String: Any]) -> Bool {
    guard let size = integer(metadata["size_bytes"]), data.count == size, data.count >= 34,
          String(data: data.prefix(4), encoding: .ascii) == "ZSWO" else { return false }
    func u16(_ offset: Int) -> Int { Int(data[offset]) | Int(data[offset + 1]) << 8 }
    func u32(_ offset: Int) -> Int { u16(offset) | u16(offset + 2) << 16 }
    // Match the existing shared Dart converter's supported mono 10 ms profile.
    guard u16(4) == 1, u16(6) == 16000, u16(8) == 160,
          u32(16) == integer(metadata["timestamp"]), u32(20) != 0xffffffff,
          u32(24) != 0xffffffff else { return false }
    var offset = 32; var frames = 0
    while offset + 2 <= data.count {
      let length = u16(offset)
      guard length > 0, offset + 2 + length <= data.count else { return false }
      offset += 2 + length; frames += 1
    }
    return offset == data.count && frames > 0 && frames == u32(20) &&
      u32(24) == frames * 10 && u32(24) == integer(metadata["duration_ms"])
  }
  func destination(_ identity: String) -> URL { directory.appendingPathComponent(Self.sha(Data(identity.utf8)) + ".zsw_opus") }
  func partial(_ identity: String) -> URL { destination(identity).appendingPathExtension("partial") }
  private func prepareDirectory() throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    guard directory.resolvingSymlinksInPath() == directory else { throw CompanionFailure.storage("Recording directory is not canonical") }
    #if os(iOS)
    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
    #endif
  }
  private func read(_ file: URL, limit: Int) throws -> Data? {
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    guard attributes[.type] as? FileAttributeType == .typeRegular,
          file.resolvingSymlinksInPath() == file, let count = attributes[.size] as? NSNumber,
          count.intValue <= limit else { throw CompanionFailure.storage("Invalid recording file/path/size") }
    return try Data(contentsOf: file)
  }
  func recover(_ identity: String, metadata: [String: Any]) throws -> [String: Any]? {
    try prepareDirectory()
    let target = destination(identity)
    if let bytes = try read(target, limit: 16 * 1024 * 1024), Self.valid(bytes, metadata: metadata) {
      let hash = Self.sha(bytes)
      guard metadata["sha256"] == nil || metadata["sha256"] as? String == hash else { return nil }
      return receipt(metadata, target, hash)
    }
    if !FileManager.default.fileExists(atPath: target.path),
       let bytes = try read(partial(identity), limit: 16 * 1024 * 1024), Self.valid(bytes, metadata: metadata) {
      try FileManager.default.moveItem(at: partial(identity), to: target)
      return receipt(metadata, target, Self.sha(bytes))
    }
    return nil
  }
  func prefix(_ identity: String, expected: Int) throws -> Data {
    try prepareDirectory()
    return try read(partial(identity), limit: expected) ?? Data()
  }
  func append(_ identity: String, offset: Int, bytes: Data, expected: Int) throws {
    guard !bytes.isEmpty, offset >= 0, offset + bytes.count <= expected else { throw CompanionFailure.invalid("Invalid recording chunk") }
    try prepareDirectory()
    let file = partial(identity)
    if !FileManager.default.fileExists(atPath: file.path) {
      guard offset == 0 else { throw CompanionFailure.storage("Recording prefix missing") }
      #if os(iOS)
      try Data().write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
      #else
      try Data().write(to: file, options: .atomic)
      #endif
    }
    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    guard attributes[.type] as? FileAttributeType == .typeRegular, file.resolvingSymlinksInPath() == file,
          (attributes[.size] as? NSNumber)?.intValue == offset else { throw CompanionFailure.storage("Recording offset/path mismatch") }
    let handle = try FileHandle(forWritingTo: file); defer { try? handle.close() }
    try handle.seekToEnd(); try handle.write(contentsOf: bytes)
    if (offset + bytes.count) / 65536 != offset / 65536 || offset + bytes.count == expected { try handle.synchronize() }
  }
  func publish(_ identity: String, metadata: [String: Any]) throws -> [String: Any] {
    try prepareDirectory()
    let staged = partial(identity); let target = destination(identity)
    guard let bytes = try read(staged, limit: 16 * 1024 * 1024), Self.valid(bytes, metadata: metadata) else {
      throw CompanionFailure.invalid("Recording container/metadata mismatch")
    }
    if FileManager.default.fileExists(atPath: target.path) {
      try FileManager.default.moveItem(at: target, to: target.appendingPathExtension("invalid-" + UUID().uuidString))
    }
    try FileManager.default.moveItem(at: staged, to: target)
    return receipt(metadata, target, Self.sha(bytes))
  }
  private func receipt(_ metadata: [String: Any], _ target: URL, _ hash: String) -> [String: Any] {
    var next = metadata; next["state"] = "downloaded"; next["local_path"] = target.path; next["sha256"] = hash
    next.removeValue(forKey: "error"); return next
  }
}
