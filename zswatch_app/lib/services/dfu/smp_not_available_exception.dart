/// Exception thrown when the MCUmgr/SMP service is not available on the watch.
///
/// This typically means the watch firmware was built without CONFIG_ZSW_FW_UPDATE,
/// or the user hasn't enabled update mode (Apps → Update) on the watch.
class SmpNotAvailableException implements Exception {
  final String message;
  final Object? cause;

  SmpNotAvailableException([this.cause])
      : message = 'SMP service not available on the watch. '
            'Please enable update mode on the watch: go to Apps → Update '
            'and set USB/BLE to ON. '
            'See zswatch.dev/docs/firmware/firmware_updates for details.';

  @override
  String toString() => message;
}
