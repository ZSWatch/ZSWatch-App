# Quickstart: ZSWatch Companion App

**Branch**: `001-companion-app` | **Date**: 2025-11-26

## Development Workflow

### Recommended: Develop on Windows/Linux + Auxiliary Mac

This project follows the standard **distributed Flutter iOS workflow**:

| Activity | Platform | Frequency |
|----------|----------|-----------|
| UI development | Windows/Linux | Daily |
| Business logic | Windows/Linux | Daily |
| BLE Android development | Windows/Linux | Daily |
| Unit & widget tests | Windows/Linux | Daily |
| Android builds & testing | Windows/Linux | Daily |
| iOS builds & signing | macOS | Weekly/Release |
| iOS hardware testing | macOS | Weekly/Release |
| App Store submission | macOS | Release only |

**Key Points**:
- **95% of development** happens on Windows/Linux
- Mac needed **only** for iOS builds, signing, and physical device testing
- All Dart/Flutter code is cross-platform and testable without Mac
- Use Android device/emulator for day-to-day BLE testing
- iOS-specific code (Info.plist, permissions) can be edited on any platform

**Workflow Example**:
```
Developer (Linux/Windows):
  1. Write Flutter code
  2. Test on Android device/emulator
  3. Run unit tests: flutter test
  4. Commit and push

Build Mac (when iOS build needed):
  1. Pull latest code
  2. cd ios && pod install
  3. flutter build ios --release
  4. Test on physical iOS device
  5. Archive and upload to App Store Connect
```

**CI/CD Options for iOS Builds** (if no local Mac available):
- **GitHub Actions** with macOS runners (free tier limited)
- **Codemagic** - Flutter-focused CI/CD with iOS support
- **Bitrise** - Mobile CI/CD with generous free tier
- **Mac in Cloud** services (MacStadium, MacinCloud) for remote access

---

## Prerequisites

### Development Environment

- **Flutter SDK**: 3.x stable ([Install Guide](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: 3.x (included with Flutter)
- **Android Studio** or **VS Code** with Flutter extensions
- **Xcode** 15+ (for iOS development, macOS only - see workflow above)
- **Git**: For version control

### Hardware

- **Android device**: API 21+ (Android 5.0+) with BLE support
- **iOS device**: iOS 13.0+ (iPhone 6s or newer)
- **ZSWatch**: With compatible firmware

### Verify Installation

```bash
flutter doctor -v
```

All checkmarks should be green for your target platform(s).

---

## Project Initialization

### ⚠️ Important: Project Creation Rules

The Flutter project **MUST** be created using the official Flutter command:

```bash
flutter create zswatch_app
```

**Rules**:
- ✅ Use `flutter create` - the official Flutter CLI
- ❌ No custom scaffolding tools
- ❌ No third-party project templates
- ❌ No AI-generated directory structures from scratch

AI assistants working on this project **MUST assume** the base project already exists, created by a human using `flutter create`. They should only add/modify files within the existing structure.

---

## Project Setup

### 1. Create Flutter Project (First Time Only)

```bash
flutter create zswatch_app
cd zswatch_app
```

Or clone if repository already exists:

```bash
git clone https://github.com/ZSWatch/ZSWatchApp.git
cd ZSWatchApp
```

### 2. Switch to Feature Branch

```bash
git checkout 001-companion-app
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Generate Code (drift database, etc.)

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Platform-Specific Setup

### Android

#### Minimum SDK
Ensure `android/app/build.gradle` has:
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Required for BLE reliability
        targetSdkVersion 34
    }
}
```

#### Permissions
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<!-- Bluetooth permissions -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<!-- Notification access (requires user to enable in settings) -->
<uses-permission android:name="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" />

<!-- Foreground service for background BLE -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
```

#### Notification Listener Service
Register in `AndroidManifest.xml` under `<application>`:
```xml
<service
    android:name=".NotificationListenerServiceImpl"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

### iOS

#### Minimum Version
Ensure `ios/Podfile` has:
```ruby
platform :ios, '13.0'
```

#### Info.plist Permissions
Add to `ios/Runner/Info.plist`:
```xml
<!-- Bluetooth -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>ZSWatch needs Bluetooth to communicate with your watch</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>ZSWatch needs Bluetooth to communicate with your watch</string>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

#### Install Pods
```bash
cd ios && pod install && cd ..
```

---

## Running the App

### Debug Mode

```bash
# Android
flutter run -d <android_device_id>

# iOS
flutter run -d <ios_device_id>

# List available devices
flutter devices
```

### Release Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

---

## Project Structure Quick Reference

```
zswatch_app/
├── lib/
│   ├── core/           # Constants, utils, theme
│   ├── data/           # Models, repositories, database
│   ├── services/       # BLE, protocol, DFU, notifications
│   ├── providers/      # Riverpod state management
│   └── ui/             # Screens and widgets
├── android/            # Android-specific code
├── ios/                # iOS-specific code
├── test/               # Unit and widget tests
└── integration_test/   # Integration tests
```

---

## Development Workflow

### 1. Start with BLE Layer

```dart
// lib/services/ble/ble_service.dart
abstract class BleService {
  Stream<ConnectionState> get connectionState;
  Future<List<ScanResult>> scan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  // ...
}
```

### 2. Implement Protocol Layer

```dart
// lib/services/protocol/protocol_service.dart
abstract class ProtocolService {
  Future<void> sendNotification(Notification notif);
  Stream<HealthSample> get healthUpdates;
  // ...
}
```

### 3. Create Providers

```dart
// lib/providers/ble_providers.dart
final bleServiceProvider = Provider<BleService>((ref) {
  return BleServiceImpl();
});

final connectionStateProvider = StreamProvider<ConnectionState>((ref) {
  return ref.watch(bleServiceProvider).connectionState;
});
```

### 4. Build UI

```dart
// lib/ui/screens/dashboard/dashboard_screen.dart
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);
    // ...
  }
}
```

---

## Testing

### Run Unit Tests

```bash
flutter test
```

### Run Integration Tests

```bash
flutter test integration_test/app_test.dart
```

### Run with Coverage

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Debugging Tips

### BLE Debugging

1. Enable verbose logging in flutter_blue_plus:
```dart
FlutterBluePlus.setLogLevel(LogLevel.verbose);
```

2. Use nRF Connect app to verify watch characteristics

### Database Debugging

1. Use drift's `.watch()` for reactive queries
2. Check database file: `getApplicationDocumentsDirectory()`

### State Debugging

1. Use Riverpod DevTools extension
2. Add logging to providers:
```dart
final myProvider = Provider((ref) {
  ref.onDispose(() => print('Provider disposed'));
  return MyService();
});
```

---

## Common Issues

### "Bluetooth permission denied" on Android

1. Check runtime permissions are requested
2. Verify manifest permissions
3. For Android 12+, need `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`

### "Background BLE disconnects" on iOS

1. Verify `bluetooth-central` in UIBackgroundModes
2. Check CoreBluetooth state restoration is implemented
3. iOS may kill app after ~30s background without activity

### "NotificationListenerService not working"

1. User must manually enable in Android Settings > Apps > Special Access
2. App must guide user to this settings page
3. Service may need to be re-enabled after app updates

---

## Useful Commands

```bash
# Clean build
flutter clean && flutter pub get

# Regenerate code
dart run build_runner build --delete-conflicting-outputs

# Update dependencies
flutter pub upgrade

# Analyze code
flutter analyze

# Format code
dart format .

# Check outdated packages
flutter pub outdated
```

---

## Resources

- [Flutter BLE Plus Docs](https://pub.dev/packages/flutter_blue_plus)
- [mcumgr_flutter Docs](https://pub.dev/packages/mcumgr_flutter)
- [Riverpod Docs](https://riverpod.dev/)
- [drift Docs](https://drift.simonbinder.eu/)
- [ZSWatch Firmware](https://github.com/ZSWatch/ZSWatch)
- [Gadgetbridge Protocol](https://www.espruino.com/Gadgetbridge)

