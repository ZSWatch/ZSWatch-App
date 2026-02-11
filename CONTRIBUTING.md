# Contributing to ZSWatch Companion App

Thank you for your interest in contributing! This project is under active development and we welcome bug reports, feature requests, and code contributions.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.10+ (stable channel)
- [Android Studio](https://developer.android.com/studio) or VS Code with Flutter extensions
- For iOS: Xcode 15+ on macOS

### Development Setup

```bash
# Clone with submodules (includes MCUmgr fork)
git clone --recurse-submodules https://github.com/ZSWatch/ZSWatch-App.git

# Or if already cloned:
# git submodule update --init

cd ZSWatch-App/zswatch_app

# Install dependencies
flutter pub get

# Generate code (Drift database, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

## Code Style

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Run `flutter analyze` before committing — no warnings or errors should remain
- Run `dart format .` to format code consistently
- Use `debugPrint('[ClassName] message')` for logging, not `print()`

## Pull Request Process

1. **Fork** the repository and create your branch from `main`
2. **Make your changes** with clear, atomic commits
3. **Test** your changes on a real device if possible (BLE features don't work on simulators)
4. **Run linting**: `flutter analyze`
5. **Run tests**: `flutter test`
6. **Push** your branch and open a Pull Request
7. **Describe** your changes clearly in the PR description

## Reporting Bugs

Open an issue on GitHub with:

- Steps to reproduce
- Expected vs actual behavior
- Device model and OS version
- ZSWatch firmware version
- App version (if applicable)
- Any relevant logs

## Feature Requests

Open a GitHub issue describing:

- The problem you're trying to solve
- Your proposed solution
- Any alternatives you've considered

## Architecture Overview

- **State management**: Riverpod — providers in `lib/providers/`
- **Database**: Drift (SQLite) — schemas in `lib/data/database/tables/`
- **BLE protocol**: Gadgetbridge/BangleJS JSON format over NUS
- **Platform bridges**: Kotlin (Android) and Swift (iOS) for native features

See `zswatch_app/README.md` for detailed architecture documentation.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
