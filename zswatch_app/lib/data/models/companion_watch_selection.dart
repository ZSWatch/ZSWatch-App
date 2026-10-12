import 'companion_watch_identity.dart';

/// Explicit selection; it is not evidence of bonding or protocol readiness.
class CompanionWatchSelection {
  final String address;
  final int generation;
  final String platform;

  const CompanionWatchSelection(
    this.address,
    this.generation, {
    this.platform = 'android',
  });

  Map<String, Object> get fields => {
    'version': 1,
    'platform': platform,
    if (platform == 'ios') 'selected': true else 'associated': true,
    'address': address,
    'generation': generation,
  };

  factory CompanionWatchSelection.decode(Object? value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['address'] is! String ||
        value['generation'] is! int ||
        (value['generation'] as int) < 0) {
      throw const FormatException('Invalid native watch selection');
    }
    final platform = value['platform'] ?? 'android';
    final address = value['address'] as String;
    final valid = platform == 'ios'
        ? value['selected'] == true && isIosWatchAddress(address)
        : platform == 'android' &&
              value['associated'] == true &&
              isAndroidWatchAddress(address);
    if (!valid || address != address.toUpperCase()) {
      throw const FormatException('Invalid native watch selection');
    }
    return CompanionWatchSelection(
      address,
      value['generation'] as int,
      platform: platform as String,
    );
  }
}
