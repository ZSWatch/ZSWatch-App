import 'package:drift/drift.dart';

/// Chat history table — stores question/answer exchanges from voice chat.
///
/// Each row represents one completed (or failed) chat turn.
/// Raw audio is never stored; only transcript text and answer text persist.
@DataClassName('ChatHistoryEntity')
class ChatHistory extends Table {
  /// Auto-incrementing row identifier
  IntColumn get id => integer().autoIncrement()();

  /// Timestamp when the question was asked (UTC epoch seconds)
  IntColumn get timestampUtc => integer().named('timestamp_utc')();

  /// Recognized transcript of the user's question
  TextColumn get transcript => text()();

  /// LLM-generated answer text (null if the request failed before answer)
  TextColumn get answer => text().nullable()();

  /// LLM model ID used for this exchange (e.g., "gemma4_e2b_litertlm")
  TextColumn get modelUsed => text().nullable().named('model_used')();

  /// End-to-end latency in milliseconds (stop-recording to reply-ready)
  IntColumn get latencyMs => integer().nullable().named('latency_ms')();

  /// Whether the exchange completed successfully
  BoolColumn get success =>
      boolean().withDefault(const Constant(true)).named('success')();

  /// Error message if the exchange failed
  TextColumn get errorMessage =>
      text().nullable().named('error_message')();
}
