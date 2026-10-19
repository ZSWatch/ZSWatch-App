/// CoreBluetooth exposes peripheral UUIDs; Android exposes BLE MAC addresses.
bool isAndroidWatchAddress(String value) =>
    RegExp(r'^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$').hasMatch(value);

bool isIosWatchAddress(String value) => RegExp(
  r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
).hasMatch(value);

bool isCompanionWatchAddress(String value) =>
    isAndroidWatchAddress(value) || isIosWatchAddress(value);
