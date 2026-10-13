/// Sharing policy and diagnostic state only; no coordinates cross this boundary.
class CompanionGpsStatus {
  final bool enabled;
  final bool foregroundPermission;
  final bool backgroundPermission;
  final bool servicesEnabled;
  final String state;
  final bool isIos;

  const CompanionGpsStatus(
    this.enabled,
    this.foregroundPermission,
    this.backgroundPermission,
    this.servicesEnabled,
    this.state, {
    this.isIos = false,
  });

  factory CompanionGpsStatus.decode(Map<String, Object?> fields) {
    final enabled = fields.containsKey('gps_enabled')
        ? fields['gps_enabled']
        : false;
    final permissions = fields['gps_permissions'];
    if (enabled is! bool || (permissions != null && permissions is! Map)) {
      throw const FormatException('Invalid native location status');
    }
    bool granted(String key) {
      if (permissions == null) return false;
      final value = (permissions as Map)[key];
      if (value is! bool) {
        throw const FormatException('Invalid location permission');
      }
      return value;
    }

    final access = [
      granted('foreground'),
      granted('background'),
      granted('services'),
    ];
    final runtime = fields['gps_runtime'];
    var state = 'idle';
    if (runtime != null) {
      if (runtime is! Map ||
          runtime['generation'] is! int ||
          runtime['requested'] is! bool ||
          !states.containsKey(runtime['state'])) {
        throw const FormatException('Invalid location runtime state');
      }
      if (fields['runtime_active'] == true &&
          fields['protocol_ready'] == true &&
          runtime['generation'] == fields['generation']) {
        state = runtime['state'] as String;
      }
    }
    return CompanionGpsStatus(
      enabled,
      access[0],
      access[1],
      access[2],
      state,
      isIos: fields['owner'] == 'ios_companion_native',
    );
  }

  String get description => !enabled
      ? 'Location sharing off'
      : !foregroundPermission || (!isIos && !backgroundPermission)
      ? isIos
            ? 'Allow location access in iPhone settings'
            : 'Allow location all the time in Android permissions'
      : !servicesEnabled
      ? 'Turn on phone location services'
      : isIos && !backgroundPermission
      ? 'Location works while this app is open. Allow Always for background watch requests.'
      : states[state]!;

  static const states = {
    'idle': 'Waiting for a watch location request',
    'acquiring': 'Getting phone location',
    'written': 'Location sent to watch',
    'disabled': 'Location sharing off',
    'permission_required': 'Location permission needed',
    'services_disabled': 'Phone location services are off',
    'location_unavailable': 'Phone location unavailable; retry from the watch',
  };
}
