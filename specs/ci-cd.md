# CI/CD for ZSWatch Companion App

## Overview

Two GitHub Actions workflows covering PR validation and nightly release builds.

---

## Phase 1: PR Workflow ✅

**File:** `.github/workflows/pr.yml`
**Trigger:** `pull_request` (opened, synchronize, reopened)

### Jobs

| Job | Runner | Depends on | Purpose |
|-----|--------|------------|---------|
| `analyze` | ubuntu-latest | — | Format check + `flutter analyze` |
| `test` | ubuntu-latest | analyze | `flutter test` |
| `build-android` | ubuntu-latest | analyze | Debug APK (no signing secrets needed) |
| `build-ios` | macos-latest | analyze | `flutter build ios --no-codesign` |

### Notes
- SSH submodule (`fllama`) rewritten to HTTPS before checkout via `git config --global url."https://github.com/".insteadOf "git@github.com:"`
- Code generation (`dart run build_runner build --delete-conflicting-outputs`) runs in every job before build
- Android debug APK uploaded as workflow artifact for manual inspection
- `android/key.properties` is gitignored — CI uses debug signing fallback for PRs (see `build.gradle.kts`)

---

## Phase 2: Nightly Release Builds

**File:** `.github/workflows/nightly.yml`
**Triggers:** `schedule: cron('0 2 * * *')` (2 AM UTC) + `workflow_dispatch`

### Android Release Signing

**One-time local setup:**
```bash
base64 -w 0 /path/to/zswatch-release.keystore
```

**GitHub Secrets required** (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | base64 of the `.keystore` file |
| `ANDROID_KEY_ALIAS` | `zswatch` |
| `ANDROID_KEY_PASSWORD` | keystore key password |
| `ANDROID_STORE_PASSWORD` | keystore store password |

**Workflow step — decode at runtime:**
```yaml
- name: Decode Android keystore
  run: |
    echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > zswatch_app/android/zswatch-release.keystore
    cat > zswatch_app/android/key.properties << EOF
    storePassword=${{ secrets.ANDROID_STORE_PASSWORD }}
    keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
    keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
    storeFile=zswatch-release.keystore
    EOF
```

Then `flutter build apk --release`. Publish to rolling GitHub Release tagged `nightly` via `softprops/action-gh-release@v2` with `prerelease: true`.

---

### iOS Release Signing (Apple Developer account required)

**One-time local setup:**
1. Xcode → Settings → Accounts → Manage Certificates → create **Apple Distribution** cert → Export as `.p12` with a password
2. [developer.apple.com](https://developer.apple.com) → Profiles → create **Ad Hoc** (or **App Store**) profile for `com.zswatch.app` → download `.mobileprovision`
3. Base64-encode both files:
   ```bash
   base64 -w 0 certificate.p12
   base64 -w 0 profile.mobileprovision
   ```

**GitHub Secrets required:**

| Secret | Value |
|--------|-------|
| `IOS_CERTIFICATE_BASE64` | base64 of `.p12` |
| `IOS_CERTIFICATE_PASSWORD` | password set when exporting `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | base64 of `.mobileprovision` |

**Workflow steps (macos-latest):**
```yaml
- name: Install certificate and provisioning profile
  run: |
    security create-keychain -p "" build.keychain
    security set-keychain-settings -lut 21600 build.keychain
    security unlock-keychain -p "" build.keychain
    echo "${{ secrets.IOS_CERTIFICATE_BASE64 }}" | base64 -d > cert.p12
    security import cert.p12 -k build.keychain -P "${{ secrets.IOS_CERTIFICATE_PASSWORD }}" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple: -s -k "" build.keychain
    echo "${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}" | base64 -d > profile.mobileprovision
    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
    cp profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

- name: Build iOS IPA
  working-directory: zswatch_app
  run: flutter build ipa --release
```

Attach the IPA to the same `nightly` GitHub Release.

**For TestFlight upload**, additionally add App Store Connect API key secrets and an `xcrun altool` or `fastlane deliver` upload step.

---

## Verification

**Phase 1:** Open a test PR → confirm all 4 jobs pass.

**Phase 2:**
- Trigger `nightly.yml` manually via `workflow_dispatch`
- Android: check GitHub Releases for tag `nightly` with APK attached
- Android signing: `apksigner verify --print-certs app-release.apk`
- iOS: confirm IPA installable on registered devices (Ad Hoc) or visible in TestFlight
