# ZSWatch Companion App

A cross-platform Flutter companion app for [ZSWatch](https://github.com/jakkra/ZSWatch) smartwatch, providing BLE communication, firmware updates, health data visualization, notification forwarding, and developer tools.

<p align="center">
  <img src="assets/images/ZSWatch_Logo_Round.svg" width="150" alt="ZSWatch Logo">
</p>

## Features

### 🔗 Connection & Communication
- **BLE Scanning & Pairing** - Discover and connect to ZSWatch devices
- **Auto-Reconnect** - Automatic reconnection when watch comes back in range
- **Persistent BLE Connection** - Maintains connection even when app is backgrounded
- **Multiple Watch Support** - Manage multiple paired watches

### 📱 Notification Forwarding (Android)
- **Bi-directional Sync** - Notifications synced between phone and watch
- **App Filtering** - Select which apps forward notifications
- **Dismiss Sync** - Dismiss on phone removes from watch and vice versa
- **Media Controls** - Control music playback from watch

### 🔧 Firmware Updates
- **GitHub Releases** - Download prebuilt firmware from GitHub
- **CI Builds** - Access latest CI builds for testing
- **Local Files** - Load firmware from local storage
- **MCUmgr/SMP Protocol** - Reliable DFU via MCUmgr
- **Filesystem Upload** - Update LVGL resources separately

### ❤️ Health & Activity
- **Step Tracking** - Daily steps with hourly breakdown
- **Heart Rate** - Live heart rate streaming and history
- **Activity Breakdown** - Time spent in each activity state
- **60-day History** - Historical data with automatic cleanup

### 🛠️ Developer Tools
- **BLE Diagnostics** - MTU, PHY, RSSI, connection stats
- **Log Viewer** - Stream logs from watch in real-time
- **Communication Log** - View all BLE protocol messages
- **Sensor Streaming** - Raw accelerometer, gyroscope, and other sensors
- **IMU Sensor Fusion** - 3D orientation visualization with quaternion data
- **Debug Tools** - Send test notifications and music metadata

### 📊 Analytics
- **Battery Analytics** - 24-hour and 7-day battery drain graphs
- **Connection Analytics** - Connection uptime, disconnection stats

### 📍 GPS Location
- **Location Relay** - Provide phone GPS to watch for weather and fitness

### 🌐 HTTP Relay
- **Web Requests** - Watch can request HTTP data through phone

---

## Prerequisites

### Development Environment
- **Flutter SDK** 3.x stable - [Install Guide](https://docs.flutter.dev/get-started/install)
- **Dart SDK** 3.x (included with Flutter)
- **Android Studio** or **VS Code** with Flutter extensions
- **Xcode** 15+ (macOS only, for iOS development)
- **Git** for version control

### Hardware Requirements
- **Android device**: API 21+ (Android 5.0+) with BLE support
- **iOS device**: iOS 13.0+ (iPhone 6s or newer)
- **ZSWatch**: With compatible firmware

### Verify Installation
```bash
flutter doctor -v
```
All checkmarks should be green for your target platform(s).

---

## Project Setup

### 1. Clone Repository
```bash
git clone https://github.com/jakkra/ZSWatch-App.git
cd ZSWatch-App
```

### 2. Install Dependencies
```bash
cd zswatch_app
flutter pub get
```

### 3. Generate Code (Drift Database)
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Platform-Specific Setup

### Android Setup

#### Minimum SDK Configuration
The app requires Android API 21+ for reliable BLE operations. This is configured in `android/app/build.gradle.kts`:
```kotlin
defaultConfig {
    minSdk = 21
    targetSdk = 34
}
```

#### Required Permissions (Pre-configured)
The following permissions are already configured in `AndroidManifest.xml`:

**Bluetooth (Android 12+)**
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

**Bluetooth (Android 11 and below)**
```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
```

**Location (for BLE scanning on older Android and GPS relay)**
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**Foreground Service (for background BLE)**
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
```

**Notifications**
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

#### Notification Listener Service
The `NotificationListenerService` is pre-configured for forwarding phone notifications to the watch. Users must manually enable it in:
**Settings → Apps → Special Access → Notification Access → ZSWatch**

#### Build Android
```bash
# Debug build
flutter run

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

---

### iOS Setup

#### Minimum iOS Version
iOS 13.0+ is required. This is configured in the Xcode project settings.

#### Required Permissions (Pre-configured)
The following permissions are already configured in `ios/Runner/Info.plist`:

**Bluetooth**
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>ZSWatch needs Bluetooth to communicate with your smartwatch for syncing data, notifications, and firmware updates.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>ZSWatch needs Bluetooth to communicate with your smartwatch.</string>
```

**Location (for GPS relay)**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>ZSWatch needs location access to provide GPS data to your smartwatch for weather and fitness features.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>ZSWatch needs location access to provide GPS data to your smartwatch, even when the app is in the background.</string>
```

**Background Modes**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>fetch</string>
</array>
```

#### Install CocoaPods Dependencies
```bash
cd ios
pod install
cd ..
```

#### Build iOS
```bash
# Debug build (requires connected iOS device or simulator)
flutter run

# Release build
flutter build ios --release

# Archive for App Store
# Use Xcode: Product → Archive
```

#### iOS-Specific Notes
- **Notifications**: iOS uses native ANCS/AMS services. The watch communicates directly with iOS for notifications and media - the app only provides configuration.
- **Background BLE**: Uses `bluetooth-central` background mode for persistent connections.
- **Media Control**: Uses Apple Media Service (AMS) directly from watch.

---

## Running the App

### Debug Mode
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Run on all connected devices
flutter run -d all
```

### Release Mode
```bash
flutter run --release
```

### Hot Reload/Restart
- **Hot Reload**: Press `r` in terminal or save a file (VS Code)
- **Hot Restart**: Press `R` in terminal

---

## Project Structure

```
zswatch_app/
├── lib/
│   ├── main.dart              # App entry point
│   ├── app.dart               # App configuration, routing
│   ├── core/                  # Constants, theme, utilities
│   │   ├── constants/         # BLE UUIDs, app constants
│   │   ├── theme/             # Dark theme configuration
│   │   └── utils/             # Utility functions
│   ├── data/                  # Data layer
│   │   ├── models/            # Data classes (Watch, Connection, etc.)
│   │   ├── repositories/      # Data access abstraction
│   │   └── database/          # SQLite/Drift setup
│   ├── services/              # Business logic
│   │   ├── watch_service.dart # Unified watch communication
│   │   ├── ble/               # BLE scanning, sensor services
│   │   ├── protocol/          # Gadgetbridge protocol
│   │   ├── dfu/               # Firmware update service
│   │   ├── notification/      # Android notification bridge
│   │   ├── media/             # Media session bridge
│   │   ├── health/            # Health data sync
│   │   └── http/              # HTTP relay service
│   ├── providers/             # Riverpod state management
│   └── ui/                    # Presentation layer
│       ├── screens/           # App screens
│       └── widgets/           # Reusable widgets
├── android/                   # Android platform code
│   └── app/src/main/kotlin/   # Native Kotlin (NotificationListener, etc.)
├── ios/                       # iOS platform code
├── test/                      # Unit tests
└── assets/                    # Images, models
```

---

## Configuration

### BLE Service UUIDs
The app uses these BLE services (defined in `lib/core/constants/ble_constants.dart`):

| Service | UUID | Description |
|---------|------|-------------|
| Nordic UART (NUS) | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | Gadgetbridge protocol |
| Battery | `0000180F-0000-1000-8000-00805F9B34FB` | Battery level |
| Device Info | `0000180A-0000-1000-8000-00805F9B34FB` | Device information |
| Sensor | `ADAF0100-C332-42A8-93BD-25E905756CB8` | Raw sensor streaming |
| Sensor Fusion | `ADAF0D00-C332-42A8-93BD-25E905756CB8` | IMU orientation |

### Settings
App settings are stored in SharedPreferences:
- Auto-reconnect preferences
- Notification filtering
- Developer mode toggle
- Battery optimization warnings

---

## Development Workflow

### Recommended: Windows/Linux + Mac
| Activity | Platform | Frequency |
|----------|----------|-----------|
| UI development | Windows/Linux | Daily |
| Business logic | Windows/Linux | Daily |
| BLE Android testing | Windows/Linux | Daily |
| Unit tests | Windows/Linux | Daily |
| iOS builds & testing | macOS | Weekly/Release |

**95% of development** happens on Windows/Linux. Mac is needed **only** for iOS builds, signing, and device testing.

### Regenerate Code
After modifying Drift schemas or Riverpod annotations:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Run Tests
```bash
flutter test
```

### Analyze Code
```bash
flutter analyze
```

### Format Code
```bash
dart format .
```

---

## Troubleshooting

### "Bluetooth permission denied" on Android
1. Check runtime permissions are requested
2. For Android 12+: Need `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`
3. For Android 11-: Need `ACCESS_FINE_LOCATION`

### "Background BLE disconnects" on iOS
1. Verify `bluetooth-central` in UIBackgroundModes
2. iOS may kill app after ~30s background without activity
3. Use the foreground service for Android

### "NotificationListenerService not working"
1. User must manually enable in Android Settings → Apps → Special Access → Notification Access
2. Service may need re-enabling after app updates
3. App guides user to settings page

### Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### iOS Build Errors
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter build ios
```

---

## Dependencies

### Core
- **flutter_blue_plus** - BLE communication
- **mcumgr_flutter** - MCUmgr/SMP firmware updates
- **flutter_riverpod** - State management
- **drift** - SQLite database
- **go_router** - Navigation

### UI
- **fl_chart** - Real-time charts
- **flutter_svg** - SVG rendering

### Networking
- **http** - HTTP requests
- **geolocator** - GPS location

See `pubspec.yaml` for complete list.

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run tests: `flutter test`
5. Commit: `git commit -m 'Add my feature'`
6. Push: `git push origin feature/my-feature`
7. Create a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

## Related Projects

- [ZSWatch Firmware](https://github.com/jakkra/ZSWatch) - The smartwatch firmware
- [mcumgr_flutter](https://github.com/NordicSemiconductor/Flutter-nRF-Connect-Device-Manager) - MCUmgr Flutter plugin

---

## Support

- **Issues**: [GitHub Issues](https://github.com/jakkra/ZSWatch-App/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jakkra/ZSWatch/discussions)
- **Discord**: [ZSWatch Discord](https://discord.gg/8XfNBmDfbY)
