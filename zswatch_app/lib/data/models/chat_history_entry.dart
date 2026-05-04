/// Domain model for a chat history entry.
///
/// Represents one question-answer exchange in the voice chat feature.
class ChatHistoryEntry {
  final int? id;
  final DateTime timestampUtc;
  final String transcript;
  final String? answer;
  final String? modelUsed;
  final int? latencyMs;
  final bool success;
  final String? errorMessage;

  const ChatHistoryEntry({
    this.id,
    required this.timestampUtc,
    required this.transcript,
    this.answer,
    this.modelUsed,
    this.latencyMs,
    this.success = true,
    this.errorMessage,
  });

  ChatHistoryEntry copyWith({
    int? id,
    DateTime? timestampUtc,
    String? transcript,
    String? answer,
    String? modelUsed,
    int? latencyMs,
    bool? success,
    String? errorMessage,
  }) {
    return ChatHistoryEntry(
      id: id ?? this.id,
      timestampUtc: timestampUtc ?? this.timestampUtc,
      transcript: transcript ?? this.transcript,
      answer: answer ?? this.answer,
      modelUsed: modelUsed ?? this.modelUsed,
      latencyMs: latencyMs ?? this.latencyMs,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatHistoryEntry &&
            other.id == id &&
            other.timestampUtc == timestampUtc &&
            other.transcript == transcript &&
            other.answer == answer &&
            other.modelUsed == modelUsed &&
            other.latencyMs == latencyMs &&
            other.success == success &&
            other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestampUtc,
    transcript,
    answer,
    modelUsed,
    latencyMs,
    success,
    errorMessage,
  );
}
