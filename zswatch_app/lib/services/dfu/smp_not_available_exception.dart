/// Exception thrown when the MCUmgr/SMP service is not available on the watch.
///
/// This typically means the watch firmware was built without CONFIG_ZSW_FW_UPDATE,
/// or auto-enable failed (e.g. the watch disconnected during the process).
class SmpNotAvailableException implements Exception {
  final String message;
  final Object? cause;

  SmpNotAvailableException([this.cause])
      : message = 'SMP service not available on the watch. '
            'The app tried to enable it automatically but failed. '
            'Try disconnecting and reconnecting, then retry the update.';

  @override
  String toString() => message;
}
