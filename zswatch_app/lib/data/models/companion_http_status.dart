/// Metadata only. URLs, credentials and response bodies stay in the native core.
class CompanionHttpStatus {
  final bool enabled;
  final bool ready;
  final int pendingCount;
  final String? lastOutcome;

  const CompanionHttpStatus(
    this.enabled,
    this.ready,
    this.pendingCount,
    this.lastOutcome,
  );

  factory CompanionHttpStatus.decode(Map<String, Object?> fields) {
    final enabled = fields.containsKey('http_enabled')
        ? fields['http_enabled']
        : true;
    final pending = fields.containsKey('http_pending_count')
        ? fields['http_pending_count']
        : 0;
    if (enabled is! bool || pending is! int || pending < 0 || pending > 4) {
      throw const FormatException('Invalid native HTTP status');
    }
    final active = fields['runtime_active'] == true;
    final last = fields['last_http'];
    String? outcome;
    if (last != null) {
      if (last is! Map ||
          last['generation'] is! int ||
          last['utc_ms'] is! int ||
          (last['generation'] as int) < 0 ||
          (last['utc_ms'] as int) < 0 ||
          !outcomes.containsKey(last['outcome'])) {
        throw const FormatException('Invalid native HTTP result');
      }
      if (active && last['generation'] == fields['generation']) {
        outcome = last['outcome'] as String;
      }
    }
    return CompanionHttpStatus(
      enabled,
      active && fields['protocol_ready'] == true,
      active ? pending : 0,
      outcome,
    );
  }

  static const outcomes = {
    'pending': 'Request in progress',
    'written': 'Reply sent',
    'error_written': 'Error reply sent',
    'delivery_expired': 'Reply timed out',
    'delivery_unavailable': 'Reply could not be sent',
    'connection_closed': 'Request cancelled on disconnect',
    'process_interrupted': 'Request interrupted',
    'invalid_id': 'Request rejected',
    'busy': 'Too many requests',
  };
}
