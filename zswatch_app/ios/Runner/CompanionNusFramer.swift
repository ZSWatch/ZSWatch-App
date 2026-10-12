import Foundation

/// NUS JSON and wrapped logs may be split at any ATT byte, including UTF-8.
final class CompanionNusFramer {
  private var json = Data()
  private var depth = 0
  private var quoted = false
  private var escaped = false
  private var marker = Data()
  private var log = Data()
  private var inLog = false
  private var oversizedLog = false
  private var lastByteAt: TimeInterval?
  private let prefix = Data("<BLELOG>".utf8)
  private let suffix = Data("</BLELOG>".utf8)
  private let maximum: Int
  private(set) var droppedFrames = 0
  private(set) var lastMessageData = Data()
  private(set) var lastMessageChunks = 0
  private var feedIndex = 0
  private var frameStartIndex = 0
  init(maximum: Int = 32768) { self.maximum = maximum }
  func reset() {
    json.removeAll(); depth = 0; quoted = false; escaped = false
    marker.removeAll(); log.removeAll(); inLog = false; oversizedLog = false; lastByteAt = nil
  }

  func feed(_ data: Data, now: TimeInterval = Date.timeIntervalSinceReferenceDate, message: ([String: Any]) -> Void, logger: (String) -> Void) {
    // An interrupted log or JSON frame must not consume later watch messages.
    if let lastByteAt, now - lastByteAt >= 5, inLog || depth > 0 || !marker.isEmpty {
      droppedFrames += 1
      reset()
    }
    if !data.isEmpty { lastByteAt = now }
    feedIndex += 1
    for byte in data {
      if inLog || depth == 0 {
        marker.append(byte)
        let tag = inLog ? suffix : prefix
        while !marker.isEmpty && !tag.starts(with: marker) {
          let first = marker.removeFirst()
          if inLog {
            if log.count < maximum { log.append(first) } else { oversizedLog = true }
          } else {
            jsonByte(first, message: message)
          }
        }
        if marker == tag {
          marker.removeAll()
          if inLog {
            if !oversizedLog, let text = String(data: log, encoding: .utf8) { logger(text) }
            log.removeAll(); oversizedLog = false; inLog = false
          } else { inLog = true }
        }
      } else { jsonByte(byte, message: message) }
    }
  }

  private func jsonByte(_ byte: UInt8, message: ([String: Any]) -> Void) {
    if byte == 10 || byte == 13 {
      if depth > 0 { droppedFrames += 1 }
      json.removeAll(); depth = 0; quoted = false; escaped = false
      return
    }
    if depth == 0 {
      guard byte == 123 else { return }
      depth = 1; frameStartIndex = feedIndex; json.append(byte); return
    }
    json.append(byte)
    if json.count > maximum {
      droppedFrames += 1; json.removeAll(); depth = 0; quoted = false; escaped = false; return
    }
    if quoted {
      if escaped { escaped = false }
      else if byte == 92 { escaped = true }
      else if byte == 34 { quoted = false }
    } else if byte == 34 { quoted = true }
    else if byte == 123 { depth += 1 }
    else if byte == 125 {
      depth -= 1
      if depth == 0 {
        if let object = try? JSONSerialization.jsonObject(with: json), let value = object as? [String: Any] {
          lastMessageData = json
          lastMessageChunks = feedIndex - frameStartIndex + 1
          message(value)
        } else { droppedFrames += 1 }
        json.removeAll()
      }
    }
  }
}
