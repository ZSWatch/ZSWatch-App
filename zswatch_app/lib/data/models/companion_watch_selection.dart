/// Android system picker selection, not evidence of bonding or protocol Ready.
class CompanionWatchSelection {
  final String address;
  final int generation;

  const CompanionWatchSelection(this.address, this.generation);

  factory CompanionWatchSelection.decode(Object? value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['associated'] != true ||
        value['address'] is! String ||
        !RegExp(
          r'^[0-9A-F]{2}(:[0-9A-F]{2}){5}$',
        ).hasMatch(value['address'] as String) ||
        value['generation'] is! int ||
        (value['generation'] as int) < 0) {
      throw const FormatException('Invalid native watch selection');
    }
    return CompanionWatchSelection(
      value['address'] as String,
      value['generation'] as int,
    );
  }
}
